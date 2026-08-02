package vn.safefleet.safe_fleet_driver_ui

import android.Manifest
import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.ImageFormat
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.hardware.camera2.CaptureRequest
import android.media.ImageReader
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.SystemClock
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.Face
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetector
import com.google.mlkit.vision.face.FaceDetectorOptions
import com.google.mlkit.vision.facemesh.FaceMesh
import com.google.mlkit.vision.facemesh.FaceMeshDetection
import com.google.mlkit.vision.facemesh.FaceMeshDetector
import com.google.android.gms.tasks.Tasks
import kotlin.math.abs
import kotlin.math.sqrt

class CabinMonitoringService : Service() {
    private var model = "STGT"
    private var status = "Đang khởi động camera"
    private var warningCount = 0
    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var imageReader: ImageReader? = null
    private var cameraThread: HandlerThread? = null
    private var cameraHandler: Handler? = null
    private var processingFrame = false
    private var sensorRotation = 0
    private var eyesClosedSince: Long? = null
    private var lastWarningAt = 0L
    private val eyeHistory = ArrayDeque<Pair<Long, Boolean>>()
    private lateinit var faceDetector: FaceDetector
    private lateinit var faceMeshDetector: FaceMeshDetector

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        faceDetector = FaceDetection.getClient(
            FaceDetectorOptions.Builder()
                .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_FAST)
                .setClassificationMode(FaceDetectorOptions.CLASSIFICATION_MODE_ALL)
                .enableTracking()
                .setMinFaceSize(0.18f)
                .build(),
        )
        faceMeshDetector = FaceMeshDetection.getClient()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP_FROM_NOTIFICATION -> {
                stopMonitoring(notifyFlutter = true)
                return START_NOT_STICKY
            }
            ACTION_STOP -> {
                stopMonitoring(notifyFlutter = false)
                return START_NOT_STICKY
            }
            ACTION_APP_BACKGROUND -> {
                markBackground(true)
                status = "Đang theo dõi nền · camera trước hoạt động"
                startNativeCamera()
                notificationManager.notify(NOTIFICATION_ID, buildNotification())
            }
            ACTION_APP_FOREGROUND -> {
                markBackground(false)
                stopNativeCamera()
                status = "Đang theo dõi trong ứng dụng"
                notificationManager.notify(NOTIFICATION_ID, buildNotification())
            }
            ACTION_UPDATE -> {
                intent.getStringExtra("model")?.let { model = it }
                intent.getStringExtra("status")?.let { status = it }
                warningCount = intent.getIntExtra("warningCount", warningCount)
                notificationManager.notify(NOTIFICATION_ID, buildNotification())
            }
            else -> {
                model = intent?.getStringExtra("model") ?: model
                status = intent?.getStringExtra("status") ?: status
                if (intent != null) markBackground(false)
                markRunning(true)
                startAsCameraForeground(buildNotification())
                // A null intent means Android recreated this sticky service.
                // Resume the native camera only when the app was last in the
                // background; Flutter owns the camera while it is foreground.
                if (intent == null && isBackground()) {
                    status = "Đã khôi phục giám sát nền · camera trước hoạt động"
                    startNativeCamera()
                    notificationManager.notify(NOTIFICATION_ID, buildNotification())
                }
            }
        }
        return START_STICKY
    }

    @SuppressLint("MissingPermission")
    private fun startNativeCamera() {
        if (cameraDevice != null || cameraThread != null) return
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) !=
            android.content.pm.PackageManager.PERMISSION_GRANTED
        ) {
            status = "Không có quyền camera để theo dõi nền"
            notificationManager.notify(NOTIFICATION_ID, buildNotification())
            return
        }
        val manager = getSystemService(CameraManager::class.java)
        val cameraId = manager.cameraIdList.firstOrNull { id ->
            manager.getCameraCharacteristics(id)
                .get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_FRONT
        } ?: manager.cameraIdList.firstOrNull() ?: return
        sensorRotation = manager.getCameraCharacteristics(cameraId)
            .get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 0
        cameraThread = HandlerThread("SafeFleetCabinCamera").also { it.start() }
        cameraHandler = Handler(cameraThread!!.looper)
        // Face Mesh needs enough pixels around the eyes and lips. 640x480 is
        // still light enough for background processing but avoids the very
        // noisy EAR/MAR values produced by the former 320x240 stream.
        imageReader = ImageReader.newInstance(640, 480, ImageFormat.YUV_420_888, 2).apply {
            setOnImageAvailableListener({ reader -> processImage(reader) }, cameraHandler)
        }
        try {
            manager.openCamera(cameraId, object : CameraDevice.StateCallback() {
                override fun onOpened(device: CameraDevice) {
                    cameraDevice = device
                    createCaptureSession(device)
                }

                override fun onDisconnected(device: CameraDevice) {
                    device.close()
                    cameraDevice = null
                }

                override fun onError(device: CameraDevice, error: Int) {
                    device.close()
                    cameraDevice = null
                    status = "Camera nền tạm thời không khả dụng"
                    notificationManager.notify(NOTIFICATION_ID, buildNotification())
                }
            }, cameraHandler)
        } catch (_: Exception) {
            stopNativeCamera()
            status = "Không thể tiếp quản camera khi chạy nền"
            notificationManager.notify(NOTIFICATION_ID, buildNotification())
        }
    }

    @Suppress("DEPRECATION")
    private fun createCaptureSession(device: CameraDevice) {
        val reader = imageReader ?: return
        device.createCaptureSession(
            listOf(reader.surface),
            object : CameraCaptureSession.StateCallback() {
                override fun onConfigured(session: CameraCaptureSession) {
                    if (cameraDevice == null) return
                    captureSession = session
                    val request = device.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW).apply {
                        addTarget(reader.surface)
                        set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
                        set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON)
                    }.build()
                    session.setRepeatingRequest(request, null, cameraHandler)
                    status = "Đang theo dõi nền · camera trước hoạt động"
                    notificationManager.notify(NOTIFICATION_ID, buildNotification())
                }

                override fun onConfigureFailed(session: CameraCaptureSession) {
                    status = "Không thể đọc hình ảnh camera nền"
                    notificationManager.notify(NOTIFICATION_ID, buildNotification())
                }
            },
            cameraHandler,
        )
    }

    private fun processImage(reader: ImageReader) {
        val mediaImage = reader.acquireLatestImage() ?: return
        if (processingFrame) {
            mediaImage.close()
            return
        }
        processingFrame = true
        val input = InputImage.fromMediaImage(mediaImage, normalizeRotation(sensorRotation))
        val faceTask = faceDetector.process(input)
        val meshTask = faceMeshDetector.process(input)
        Tasks.whenAllComplete(faceTask, meshTask)
            .addOnSuccessListener {
                val faces = if (faceTask.isSuccessful) faceTask.result else emptyList()
                val meshes = if (meshTask.isSuccessful) meshTask.result else emptyList()
                analyzeFaces(faces, meshes)
            }
            .addOnCompleteListener {
                mediaImage.close()
                processingFrame = false
            }
    }

    private fun analyzeFaces(faces: List<Face>, meshes: List<FaceMesh>) {
        val now = SystemClock.elapsedRealtime()
        val face = faces.maxByOrNull { it.boundingBox.width() * it.boundingBox.height() }
        val faceMesh = meshes.maxByOrNull { it.boundingBox.width() * it.boundingBox.height() }
        val meshMetrics = faceMesh?.let { extractMeshMetrics(it) }
        val probabilities = listOfNotNull(
            face?.leftEyeOpenProbability,
            face?.rightEyeOpenProbability,
        )
        if (meshMetrics == null && probabilities.isEmpty()) return
        val ear = meshMetrics?.first
        val mar = meshMetrics?.second ?: 0.0
        val closed = ear?.let { it < 0.16 } ?: (probabilities.average() < 0.25)
        eyeHistory.addLast(now to closed)
        while (eyeHistory.isNotEmpty() && now - eyeHistory.first().first > 30_000) {
            eyeHistory.removeFirst()
        }
        eyesClosedSince = if (closed) eyesClosedSince ?: now else null
        val closedLongEnough = eyesClosedSince?.let { now - it >= 2_000 } == true
        val perclos = if (eyeHistory.isEmpty()) 0.0 else
            eyeHistory.count { it.second }.toDouble() / eyeHistory.size
        val perclosRisk = eyeHistory.size >= 6 && perclos >= 0.4
        val poseRisk = face != null && (
            abs(face.headEulerAngleX) >= 25f || abs(face.headEulerAngleY) >= 25f
        )
        val hardEyeClosure = ear != null && ear < 0.10
        val yawnRisk = mar > 0.60
        if ((hardEyeClosure || closedLongEnough || perclosRisk || (poseRisk && yawnRisk)) && now - lastWarningAt >= 30_000) {
            lastWarningAt = now
            val reason = when {
                hardEyeClosure -> "Mắt nhắm sâu khi ứng dụng chạy nền"
                closedLongEnough -> "Mắt nhắm liên tục khi ứng dụng chạy nền"
                perclosRisk -> "PERCLOS ${(perclos * 100).toInt()}% khi ứng dụng chạy nền"
                else -> "Ngáp kết hợp tư thế đầu bất thường khi chạy nền"
            }
            val metricReason = "$reason · EAR ${ear?.let { "%.3f".format(it) } ?: "--"} · MAR ${"%.3f".format(mar)}"
            warningCount++
            status = metricReason
            notificationManager.notify(NOTIFICATION_ID, buildNotification())
            sendBroadcast(
                Intent(ACTION_BACKGROUND_DETECTION)
                    .setPackage(packageName)
                    .putExtra("confidence", if (hardEyeClosure || closedLongEnough) 0.92 else 0.82)
                    .putExtra("reason", metricReason),
            )
        }
    }

    private fun extractMeshMetrics(faceMesh: FaceMesh): Pair<Double, Double>? {
        val points = faceMesh.allPoints.associateBy { it.index }
        val leftEye = listOf(362, 385, 387, 263, 373, 380)
        val rightEye = listOf(33, 160, 158, 133, 153, 144)
        val lips = listOf(78, 308, 13, 14)
        if ((leftEye + rightEye + lips).any { !points.containsKey(it) }) return null

        fun distance(first: Int, second: Int): Double {
            val a = points.getValue(first).position
            val b = points.getValue(second).position
            val dx = (a.x - b.x).toDouble()
            val dy = (a.y - b.y).toDouble()
            return sqrt(dx * dx + dy * dy)
        }

        fun ear(indices: List<Int>): Double {
            val horizontal = distance(indices[0], indices[3])
            if (horizontal <= 0.0) return 0.0
            return (distance(indices[1], indices[5]) + distance(indices[2], indices[4])) /
                (2.0 * horizontal)
        }

        val averageEar = (ear(leftEye) + ear(rightEye)) / 2.0
        val mouthWidth = distance(lips[0], lips[1])
        val mar = if (mouthWidth <= 0.0) 0.0 else distance(lips[2], lips[3]) / mouthWidth
        return averageEar to mar
    }

    private fun normalizeRotation(rotation: Int): Int = when (rotation) {
        90, 180, 270 -> rotation
        else -> 0
    }

    private fun stopNativeCamera() {
        processingFrame = false
        try { captureSession?.stopRepeating() } catch (_: Exception) { }
        captureSession?.close()
        captureSession = null
        cameraDevice?.close()
        cameraDevice = null
        imageReader?.close()
        imageReader = null
        cameraThread?.quitSafely()
        cameraThread = null
        cameraHandler = null
        eyeHistory.clear()
        eyesClosedSince = null
    }

    private fun startAsCameraForeground(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun buildNotification(): Notification {
        val openIntent = PendingIntent.getActivity(
            this,
            10,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val stopIntent = PendingIntent.getService(
            this,
            11,
            Intent(this, CabinMonitoringService::class.java).apply {
                action = ACTION_STOP_FROM_NOTIFICATION
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val detail = "Camera trước · $warningCount cảnh báo"
        return Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_safefleet)
            .setColor(Color.rgb(8, 127, 115))
            .setContentTitle("SafeFleet đang giám sát tài xế")
            .setContentText(detail)
            .setSubText(status)
            .setStyle(Notification.BigTextStyle().bigText("$detail\n$status"))
            .setContentIntent(openIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setWhen(System.currentTimeMillis())
            .setUsesChronometer(true)
            .addAction(Notification.Action.Builder(null, "MỞ SAFEFLEET", openIntent).build())
            .addAction(Notification.Action.Builder(null, "DỪNG GIÁM SÁT", stopIntent).build())
            .build()
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Giám sát an toàn tài xế",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Hiển thị trạng thái camera và AI cabin khi SafeFleet chạy nền"
            setShowBadge(false)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        notificationManager.createNotificationChannel(channel)
    }

    private fun stopMonitoring(notifyFlutter: Boolean) {
        stopNativeCamera()
        markBackground(false)
        markRunning(false)
        if (notifyFlutter) {
            sendBroadcast(Intent(ACTION_STOPPED_FROM_NOTIFICATION).setPackage(packageName))
        }
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun markRunning(running: Boolean) {
        getSharedPreferences(PREFS, MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_RUNNING, running)
            .apply()
    }

    private fun markBackground(background: Boolean) {
        getSharedPreferences(PREFS, MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_BACKGROUND, background)
            .apply()
    }

    private fun isBackground(): Boolean =
        getSharedPreferences(PREFS, MODE_PRIVATE).getBoolean(KEY_BACKGROUND, false)

    private val notificationManager: NotificationManager
        get() = getSystemService(NotificationManager::class.java)

    override fun onDestroy() {
        stopNativeCamera()
        faceDetector.close()
        faceMeshDetector.close()
        super.onDestroy()
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        if (getSharedPreferences(PREFS, MODE_PRIVATE).getBoolean(KEY_RUNNING, false)) {
            markBackground(true)
            startNativeCamera()
        }
        super.onTaskRemoved(rootIntent)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        const val CHANNEL = "vn.safefleet/cabin_monitoring"
        const val CHANNEL_ID = "safefleet_cabin_monitoring"
        const val NOTIFICATION_ID = 4107
        const val PREFS = "safefleet_monitoring"
        const val KEY_RUNNING = "running"
        const val KEY_BACKGROUND = "background"
        const val ACTION_START = "vn.safefleet.action.START_MONITORING"
        const val ACTION_UPDATE = "vn.safefleet.action.UPDATE_MONITORING"
        const val ACTION_APP_BACKGROUND = "vn.safefleet.action.MONITORING_APP_BACKGROUND"
        const val ACTION_APP_FOREGROUND = "vn.safefleet.action.MONITORING_APP_FOREGROUND"
        const val ACTION_STOP = "vn.safefleet.action.STOP_MONITORING"
        const val ACTION_STOP_FROM_NOTIFICATION =
            "vn.safefleet.action.STOP_MONITORING_FROM_NOTIFICATION"
        const val ACTION_STOPPED_FROM_NOTIFICATION =
            "vn.safefleet.action.MONITORING_STOPPED_FROM_NOTIFICATION"
        const val ACTION_BACKGROUND_DETECTION =
            "vn.safefleet.action.BACKGROUND_DROWSINESS_DETECTION"
    }
}
