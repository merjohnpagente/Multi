package com.example.photo_organizer

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.media.FaceDetector
import android.os.Environment
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayInputStream
import kotlin.math.max

class MainActivity : FlutterActivity() {
    private val storageChannel = "photo_organizer/storage"
    private val visionChannel = "photo_organizer/vision"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            visionChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "detectFaces" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    if (bytes == null || bytes.isEmpty()) {
                        result.success(0)
                        return@setMethodCallHandler
                    }
                    try {
                        result.success(detectFaces(bytes))
                    } catch (error: Exception) {
                        result.error("FACE_DETECT_ERROR", error.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
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

    private fun detectFaces(bytes: ByteArray): Int {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
            return 0
        }

        var sampleSize = 1
        val largest = max(bounds.outWidth, bounds.outHeight)
        while (largest / sampleSize > 1600) {
            sampleSize *= 2
        }

        val options = BitmapFactory.Options().apply {
            inSampleSize = sampleSize
            inPreferredConfig = Bitmap.Config.RGB_565
        }
        val decoded = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options) ?: return 0
        val orientation = try {
            ExifInterface(ByteArrayInputStream(bytes)).getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL,
            )
        } catch (_: Exception) {
            ExifInterface.ORIENTATION_NORMAL
        }
        val oriented = orientBitmap(decoded, orientation)
        val scaled = if (max(oriented.width, oriented.height) > 1024) {
            val ratio = 1024f / max(oriented.width, oriented.height)
            Bitmap.createScaledBitmap(
                oriented,
                max(1, (oriented.width * ratio).toInt()),
                max(1, (oriented.height * ratio).toInt()),
                true,
            )
        } else {
            oriented
        }
        val detectorBitmap = if (scaled.config == Bitmap.Config.RGB_565) {
            scaled
        } else {
            scaled.copy(Bitmap.Config.RGB_565, false) ?: return 0
        }
        val detector = FaceDetector(detectorBitmap.width, detectorBitmap.height, 10)
        val faces = arrayOfNulls<FaceDetector.Face>(10)
        val found = detector.findFaces(detectorBitmap, faces)
        var confident = 0
        for (index in 0 until found) {
            val face = faces[index]
            if (face != null && face.confidence() >= 0.3f) {
                confident++
            }
        }
        return confident
    }

    private fun orientBitmap(bitmap: Bitmap, orientation: Int): Bitmap {
        val matrix = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.setScale(-1f, 1f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.setRotate(180f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.setScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> {
                matrix.setRotate(90f)
                matrix.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.setRotate(90f)
            ExifInterface.ORIENTATION_TRANSVERSE -> {
                matrix.setRotate(-90f)
                matrix.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.setRotate(-90f)
            else -> return bitmap
        }
        return try {
            Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
        } catch (_: Exception) {
            bitmap
        }
    }
}
