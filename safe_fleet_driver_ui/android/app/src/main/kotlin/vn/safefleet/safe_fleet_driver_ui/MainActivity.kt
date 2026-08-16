package vn.safefleet.safe_fleet_driver_ui

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var channel: MethodChannel
    private var stopReceiver: BroadcastReceiver? = null
    private var vietOcrBridge: VietOcrOnDeviceBridge? = null
    private var ocrNotificationChannel: MethodChannel? = null
    private var tripNotificationChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        vietOcrBridge = VietOcrOnDeviceBridge(
            this,
            flutterEngine.dartExecutor.binaryMessenger,
        )
        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CabinMonitoringService.CHANNEL,
        )
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val intent = Intent(this, CabinMonitoringService::class.java).apply {
                        action = CabinMonitoringService.ACTION_START
                        putExtra("model", call.argument<String>("model") ?: "STGT")
                        putExtra("status", call.argument<String>("status") ?: "Đang khởi động")
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "update" -> {
                    startService(Intent(this, CabinMonitoringService::class.java).apply {
                        action = CabinMonitoringService.ACTION_UPDATE
                        putExtra("model", call.argument<String>("model"))
                        putExtra("status", call.argument<String>("status"))
                        putExtra("warningCount", call.argument<Int>("warningCount") ?: 0)
                    })
                    result.success(true)
                }
                "enterBackground" -> {
                    startService(Intent(this, CabinMonitoringService::class.java).apply {
                        action = CabinMonitoringService.ACTION_APP_BACKGROUND
                    })
                    result.success(true)
                }
                "enterForeground" -> {
                    startService(Intent(this, CabinMonitoringService::class.java).apply {
                        action = CabinMonitoringService.ACTION_APP_FOREGROUND
                    })
                    result.success(true)
                }
                "stop" -> {
                    startService(Intent(this, CabinMonitoringService::class.java).apply {
                        action = CabinMonitoringService.ACTION_STOP
                    })
                    result.success(true)
                }
                "isRunning" -> result.success(
                    getSharedPreferences(CabinMonitoringService.PREFS, MODE_PRIVATE)
                        .getBoolean(CabinMonitoringService.KEY_RUNNING, false),
                )
                else -> result.notImplemented()
            }
        }

        createOcrNotificationChannel()
        createTripNotificationChannel()
        ocrNotificationChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            OCR_NOTIFICATION_METHOD_CHANNEL,
        ).also { methodChannel ->
            methodChannel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "showCompleted" -> {
                        showOcrNotification(
                            title = "OCR phiếu đã hoàn thành",
                            content = call.argument<String>("projectAddress")
                                ?: "Mở SafeFleet để kiểm tra kết quả.",
                            failed = false,
                        )
                        result.success(true)
                    }
                    "showFailed" -> {
                        showOcrNotification(
                            title = "OCR phiếu chưa thành công",
                            content = call.argument<String>("message")
                                ?: "Mở SafeFleet để thử lại.",
                            failed = true,
                        )
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        tripNotificationChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            TRIP_NOTIFICATION_METHOD_CHANNEL,
        ).also { methodChannel ->
            methodChannel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "showAssignment" -> {
                        val shown = showTripAssignmentNotification(
                            notificationId = call.argument<Int>("id") ?: 0,
                            title = call.argument<String>("title") ?: "Bạn có chuyến mới",
                            content = call.argument<String>("content")
                                ?: "Mở SafeFleet để xem chi tiết chuyến được giao.",
                            tripId = call.argument<Int>("tripId"),
                        )
                        result.success(shown)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        stopReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    CabinMonitoringService.ACTION_STOPPED_FROM_NOTIFICATION ->
                        channel.invokeMethod("stoppedFromNotification", null)
                    CabinMonitoringService.ACTION_BACKGROUND_DETECTION ->
                        channel.invokeMethod(
                            "backgroundDetection",
                            mapOf(
                                "confidence" to intent.getDoubleExtra("confidence", 0.9),
                                "reason" to (intent.getStringExtra("reason")
                                    ?: "Phát hiện buồn ngủ khi chạy nền"),
                            ),
                        )
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(CabinMonitoringService.ACTION_STOPPED_FROM_NOTIFICATION)
            addAction(CabinMonitoringService.ACTION_BACKGROUND_DETECTION)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(stopReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(stopReceiver, filter)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        stopReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: IllegalArgumentException) {
                // Receiver was already detached with the activity.
            }
        }
        stopReceiver = null
        vietOcrBridge?.close()
        vietOcrBridge = null
        ocrNotificationChannel?.setMethodCallHandler(null)
        ocrNotificationChannel = null
        tripNotificationChannel?.setMethodCallHandler(null)
        tripNotificationChannel = null
        channel.setMethodCallHandler(null)
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun createOcrNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                OCR_NOTIFICATION_CHANNEL_ID,
                "Kết quả OCR phiếu",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Thông báo khi máy chủ hoàn tất nhận dạng phiếu"
            },
        )
    }

    private fun createTripNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                TRIP_NOTIFICATION_CHANNEL_ID,
                "Chuyến được giao",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Thông báo khi quản lý giao chuyến mới cho tài xế"
                enableVibration(true)
            },
        )
    }

    private fun showTripAssignmentNotification(
        notificationId: Int,
        title: String,
        content: String,
        tripId: Int?,
    ): Boolean {
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return false
        val launchIntent = (packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)).apply {
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            tripId?.let { putExtra("tripId", it) }
        }
        val requestCode = TRIP_NOTIFICATION_ID_BASE + notificationId
        val pendingIntent = PendingIntent.getActivity(
            this,
            requestCode,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(this, TRIP_NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_safefleet)
            .setContentTitle(title)
            .setContentText(content)
            .setStyle(NotificationCompat.BigTextStyle().bigText(content))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .build()
        NotificationManagerCompat.from(this).notify(requestCode, notification)
        return true
    }

    private fun showOcrNotification(title: String, content: String, failed: Boolean) {
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return
        val notificationId = nextOcrNotificationId()
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            notificationId,
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(this, OCR_NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_safefleet)
            .setContentTitle(title)
            .setContentText(content)
            .setStyle(NotificationCompat.BigTextStyle().bigText(content))
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setCategory(if (failed) NotificationCompat.CATEGORY_ERROR else NotificationCompat.CATEGORY_STATUS)
            .build()
        NotificationManagerCompat.from(this).notify(notificationId, notification)
    }

    private fun nextOcrNotificationId(): Int {
        val preferences = getSharedPreferences(OCR_NOTIFICATION_PREFS, MODE_PRIVATE)
        val next = (preferences.getInt(OCR_NOTIFICATION_SEQUENCE, 0) + 1) % 10000
        preferences.edit().putInt(OCR_NOTIFICATION_SEQUENCE, next).apply()
        return OCR_NOTIFICATION_ID_BASE + next
    }

    companion object {
        private const val OCR_NOTIFICATION_METHOD_CHANNEL =
            "vn.safefleet.safe_fleet_driver_ui/document_ocr"
        private const val OCR_NOTIFICATION_CHANNEL_ID = "document_ocr_results"
        private const val OCR_NOTIFICATION_ID_BASE = 42000
        private const val OCR_NOTIFICATION_PREFS = "document_ocr_notifications"
        private const val OCR_NOTIFICATION_SEQUENCE = "sequence"
        private const val TRIP_NOTIFICATION_METHOD_CHANNEL =
            "vn.safefleet.safe_fleet_driver_ui/trip_notifications"
        private const val TRIP_NOTIFICATION_CHANNEL_ID = "trip_assignments"
        private const val TRIP_NOTIFICATION_ID_BASE = 52000
    }
}
