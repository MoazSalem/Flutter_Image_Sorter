package com.moazsalem.image.sorter

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.exifinterface.media.ExifInterface // Import modern ExifInterface
import java.io.IOException
import android.content.Intent // For Media Scanner
import android.net.Uri // For Media Scanner
import java.io.File // For Media Scanner path conversion
import android.util.Log

class MainActivity: FlutterActivity() {
    // channel name - must match the one used in Dart
    private val CHANNEL = "com.moazsalem/exif_modifier"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            // This method is invoked on the main thread.
                call, result ->
            if (call.method == "setExifDateTime") {
                // Extract arguments sent from Dart
                val filePath = call.argument<String>("filePath")
                val dateTimeString = call.argument<String>("dateTimeString")

                if (filePath == null || dateTimeString == null) {
                    result.error("INVALID_ARGUMENTS", "File path or date time string is null.", null)
                } else {
                    // Perform EXIF modification in a background thread to avoid blocking the main thread
                    // Although ExifInterface operations are often fast, file I/O can be slow.
                    // Consider using Kotlin Coroutines or a ThreadPoolExecutor for more complex scenarios.
                    Thread {
                        var success = false
                        try {
                            val exifInterface = ExifInterface(filePath)

                            // Set the EXIF tags
                            exifInterface.setAttribute(ExifInterface.TAG_DATETIME, dateTimeString)
                            exifInterface.setAttribute(ExifInterface.TAG_DATETIME_ORIGINAL, dateTimeString)
                            exifInterface.setAttribute(ExifInterface.TAG_DATETIME_DIGITIZED, dateTimeString)

                            // Save the changes back to the file
                            exifInterface.saveAttributes()
                            success = true

                            // After successful save, trigger Media Scanner
                            triggerMediaScan(filePath)

                        } catch (e: IOException) {
                            // Log the error (consider a more robust logging mechanism)
                            Log.e("ExifModifier", "Error writing EXIF data to $filePath: ${e.message}")
                            // Optionally send specific error details back to Dart
                            // result.error("IO_ERROR", "Failed to write EXIF data: ${e.message}", null)
                            // For simplicity here, we just return false via the success flag
                        } catch (e: Exception) {
                            // Catch any other unexpected errors
                            Log.e("ExifModifier", "Unexpected error modifying EXIF for $filePath: ${e.message}")
                            // result.error("UNEXPECTED_ERROR", "An unexpected error occurred: ${e.message}", null)
                        }

                        // Switch back to the main thread to send the result
                        activity.runOnUiThread {
                            if (success) {
                                result.success(true)
                            } else {
                                // You could send specific errors back here if needed
                                // For this example, just returning false indicates failure
                                result.success(false)
                            }
                        }
                    }.start() // Start the background thread
                }
            } else {
                result.notImplemented()
            }
        }
    }

    // Helper function to notify the Media Scanner about the file change
    private fun triggerMediaScan(filePath: String) {
        try {
            val file = File(filePath)
            if (file.exists()) {
                val intent = Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE)
                intent.data = Uri.fromFile(file)
                sendBroadcast(intent)
                Log.d("ExifModifier", "Media Scanner triggered for: $filePath")
            } else {
                Log.w("ExifModifier", "File not found for Media Scanner: $filePath")
            }
        } catch (e: Exception) {
            Log.e("ExifModifier", "Error triggering Media Scanner for $filePath: ${e.message}")
        }
    }
}

