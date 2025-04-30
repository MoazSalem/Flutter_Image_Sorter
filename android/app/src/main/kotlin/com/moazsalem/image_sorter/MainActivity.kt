package com.moazsalem.image.sorter

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.exifinterface.media.ExifInterface
import java.io.IOException
import android.content.Intent
import android.net.Uri
import java.io.File
import android.util.Log
import java.nio.file.Files
import java.nio.file.Paths
import java.nio.file.attribute.BasicFileAttributes
import java.nio.file.attribute.FileTime

class MainActivity: FlutterActivity() {
    // channel name - must match the one used in Dart
    private val CHANNEL = "com.moazsalem/native_channel"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            // This method is invoked on the main thread.
                call, result ->
            when (call.method) {
                "setExifDateTime" -> {
                    // Extract arguments sent from Dart
                    val filePath = call.argument<String>("filePath")
                    val dateTimeString = call.argument<String>("dateTimeString")

                    if (filePath == null || dateTimeString == null) {
                        result.error(
                            "INVALID_ARGUMENTS",
                            "File path or date time string is null.",
                            null
                        )
                    } else {
                        // Perform EXIF modification in a background thread to avoid blocking the main thread
                        // Although ExifInterface operations are often fast, file I/O can be slow.
                        // Consider using Kotlin Coroutines or a ThreadPoolExecutor for more complex scenarios.
                        Thread {
                            var success = false
                            try {
                                val exifInterface = ExifInterface(filePath)

                                // Set the EXIF tags
                                exifInterface.setAttribute(
                                    ExifInterface.TAG_DATETIME,
                                    dateTimeString
                                )
                                exifInterface.setAttribute(
                                    ExifInterface.TAG_DATETIME_ORIGINAL,
                                    dateTimeString
                                )
                                exifInterface.setAttribute(
                                    ExifInterface.TAG_DATETIME_DIGITIZED,
                                    dateTimeString
                                )

                                // Save the changes back to the file
                                exifInterface.saveAttributes()
                                success = true

                            } catch (e: IOException) {
                                // Log the error (consider a more robust logging mechanism)
                                Log.e(
                                    "NativeHelper",
                                    "Error writing EXIF data to $filePath: ${e.message}"
                                )
                                // Optionally send specific error details back to Dart
                                // result.error("IO_ERROR", "Failed to write EXIF data: ${e.message}", null)
                                // For simplicity here, we just return false via the success flag
                            } catch (e: Exception) {
                                // Catch any other unexpected errors
                                Log.e(
                                    "NativeHelper",
                                    "Unexpected error modifying EXIF for $filePath: ${e.message}"
                                )
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
                }
                "setLastModifiedTime" -> {
                    // Extract arguments
                    val filePath = call.argument<String>("filePath")
                    // Get time as Long (milliseconds since epoch)
                    val timeMillis = call.argument<Long>("timeMillis")

                    if (filePath == null || timeMillis == null) {
                        result.error(
                            "INVALID_ARGUMENTS",
                            "File path or timeMillis is null for setLastModifiedTime.",
                            null
                        )
                    } else {
                        // Perform file operation in a background thread
                        Thread {
                            var success = false
                            var errorMsg: String? = null
                            try {
                                val file = File(filePath)
                                if (file.exists()) {
                                    // Attempt to set the last modified time
                                    success = file.setLastModified(timeMillis)
                                    if (!success) {
                                        errorMsg = "setLastModified returned false for $filePath (check permissions?)"
                                        Log.w("NativeTimestampSet", errorMsg)
                                    }
                                } else {
                                    errorMsg = "File not found: $filePath"
                                    Log.w("NativeTimestampSet", errorMsg)
                                }
                            } catch (e: SecurityException) {
                                errorMsg = "SecurityException setting last modified time for $filePath: ${e.message}"
                                Log.e("NativeTimestampSet", errorMsg)
                            } catch (e: Exception) {
                                errorMsg = "Error setting last modified time for $filePath: ${e.message}"
                                Log.e("NativeTimestampSet", errorMsg)
                            }

                            // Send result back to Flutter on the main thread
                            activity.runOnUiThread {
                                if (success) {
                                    result.success(true)
                                } else {
                                    // Provide a more specific error if available
                                    result.error(
                                        "NATIVE_SET_MODIFIED_ERROR",
                                        errorMsg ?: "Failed to set last modified time.",
                                        null
                                    )
                                    // Alternatively, just return false: result.success(false)
                                    // Returning an error is often more informative.
                                }
                            }
                        }.start() // Start the background thread
                    }
                }
                "getFileSystemTimestamps" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath == null) {
                        result.error("INVALID_ARGUMENTS", "File path is null for getting timestamps.", null)
                    } else {
                        Thread {
                            val timestamps = mutableMapOf<String, Long?>()
                            var errorMsg: String? = null
                            try {
                                val path = Paths.get(filePath)
                                val attrs = Files.readAttributes(path, BasicFileAttributes::class.java)
                                fun fileTimeToMillis(fileTime: FileTime?): Long? = fileTime?.toMillis()?.takeIf { it > 0 }
                                timestamps["modified"] = fileTimeToMillis(attrs.lastModifiedTime())
                                timestamps["accessed"] = fileTimeToMillis(attrs.lastAccessTime())
                                timestamps["created"] = fileTimeToMillis(attrs.creationTime())
                                timestamps["changed"] = fileTimeToMillis(attrs.lastModifiedTime()) // Using mtime as proxy for ctime
                            } catch (e: Exception) { // Simplified catch block for brevity
                                errorMsg = "Error getting file attributes for $filePath: ${e.message}"
                                Log.e("NativeTimestamp", errorMsg)
                            }
                            activity.runOnUiThread {
                                if (errorMsg == null) {
                                    result.success(timestamps)
                                } else {
                                    result.error("NATIVE_STAT_ERROR", errorMsg, null)
                                }
                            }
                        }.start()
                    }
                }
                "getExifTimestamps" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath == null) {
                        result.error("INVALID_ARGUMENTS", "File path is null for getting EXIF timestamps.", null)
                    } else {
                        // Perform file I/O in background thread
                        Thread {
                            val exifTimestamps = mutableMapOf<String, String?>()
                            var errorMsg: String? = null
                            try {
                                val exifInterface = ExifInterface(filePath)

                                // Read the specific EXIF tags
                                // getAttribute returns null if the tag doesn't exist
                                exifTimestamps["dateTimeOriginal"] = exifInterface.getAttribute(ExifInterface.TAG_DATETIME_ORIGINAL)
                                exifTimestamps["dateTimeDigitized"] = exifInterface.getAttribute(ExifInterface.TAG_DATETIME_DIGITIZED)
                                exifTimestamps["dateTime"] = exifInterface.getAttribute(ExifInterface.TAG_DATETIME)

                            } catch (e: IOException) {
                                errorMsg = "IOException reading EXIF data for $filePath: ${e.message}"
                                Log.e("NativeExif", errorMsg)
                            } catch (e: Exception) {
                                errorMsg = "Unexpected error reading EXIF data for $filePath: ${e.message}"
                                Log.e("NativeExif", errorMsg)
                            }

                            // Send result back to main thread
                            activity.runOnUiThread {
                                if (errorMsg == null) {
                                    // Send the map of timestamp strings (value can be null if tag missing)
                                    result.success(exifTimestamps)
                                } else {
                                    // Send error back
                                    result.error("NATIVE_EXIF_READ_ERROR", errorMsg, null)
                                }
                            }
                        }.start()
                    }
                }
                "triggerMediaScan" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath == null) {
                        result.error("INVALID_ARGUMENTS", "File path is null for media scan.", null)
                    } else {
                        Thread {
                            val scanSuccess = triggerMediaScan(filePath)
                            activity.runOnUiThread { result.success(scanSuccess) }
                        }.start()
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }

        }
    }

    // Helper function to notify the Media Scanner about the file change
    private fun triggerMediaScan(filePath: String): Boolean {
        return try {
            val file = File(filePath)
            if (file.exists()) {
                val intent = Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE)
                intent.data = Uri.fromFile(file)
                context.sendBroadcast(intent)
                true
            } else {
                Log.w("NativeHelper", "File not found for Media Scanner: $filePath")
                false
            }
        } catch (e: Exception) {
            Log.e("NativeHelper", "Error triggering Media Scanner for $filePath: ${e.message}")
            false
        }
    }
}

