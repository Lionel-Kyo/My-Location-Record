package com.example.my_location_record

import android.content.Intent
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val CHANNEL = "com.example.my_location_record/service"
    }

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {
                "startService" -> {
                    try {
                        val intervalSeconds = call.argument<Int>("interval_seconds") ?: 60

                        if (intervalSeconds < 15 || intervalSeconds > 86400) {
                            result.error(
                                "INVALID_INTERVAL",
                                "Interval must be a value between 15 and 86400.",
                                null
                            )
                            return@setMethodCallHandler
                        }

                        val intent = Intent(
                            this,
                            LocationService::class.java
                        ).apply {
                            putExtra("interval_seconds", intervalSeconds.toLong())
                        }

                        ContextCompat.startForegroundService(
                            this,
                            intent
                        )

                        result.success(true)
                    } catch (e: Exception) {
                        result.error(
                            "START_FAILED",
                            e.message ?: "Unable to start location service.",
                            null
                        )
                    }
                }

                "stopService" -> {
                    try {
                        stopService(
                            Intent(this, LocationService::class.java)
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        result.error(
                            "STOP_FAILED",
                            e.message ?: "Unable to stop location service.",
                            null
                        )
                    }
                }

                "getTrackingStatus" -> {
                    result.success(
                        mapOf(
                            "isRecording" to LocationService.isRecording
                        )
                    )
                }

                else -> result.notImplemented()
            }
        }
    }
}