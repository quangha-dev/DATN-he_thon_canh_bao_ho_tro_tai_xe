package vn.safefleet.safe_fleet_driver_ui

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var channel: MethodChannel
    private var stopReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
        channel.setMethodCallHandler(null)
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
