package com.example.photo_organizer

import android.os.Environment
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val storageChannel = "photo_organizer/storage"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            storageChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getStorageInfo" -> {
                    try {
                        val stat = StatFs(Environment.getDataDirectory().path)
                        result.success(
                            mapOf(
                                "totalBytes" to stat.totalBytes,
                                "freeBytes" to stat.availableBytes,
                            ),
                        )
                    } catch (error: Exception) {
                        result.error(
                            "STORAGE_ERROR",
                            error.message,
                            null,
                        )
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}
