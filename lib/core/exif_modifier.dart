import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ExifModifier {
  // Define the channel name. Must match the one used in MainActivity.kt
  static const MethodChannel _channel = MethodChannel(
    'com.moazsalem/exif_modifier',
  );

  /// Modifies EXIF date/time tags (DateTimeOriginal, DateTimeDigitized, DateTime)
  /// for the given image file path on Android.
  ///
  /// Args:
  ///   filePath: The absolute path to the image file.
  ///   dateTime: The DateTime object to set in the EXIF tags.
  ///
  /// Returns:
  ///   `true` if the modification was successful on the native side.
  ///   `false` if an error occurred (permission issue, file not found, invalid format, etc.).
  ///
  /// Note: This only works on Android. It will return `false` on other platforms.
  /// Ensure you have necessary file write permissions before calling.

  static Future<bool> setExifDateTimeAndroid(
    String filePath,
    DateTime dateTime,
  ) async {
    // Platform check - only proceed for Android
    if (!Platform.isAndroid) {
      debugPrint(
        "EXIF modification via this channel is only supported on Android.",
      );
      return false;
    }

    // Format the DateTime object into the required EXIF string format
    // EXIF Standard format: "yyyy:MM:dd HH:mm:ss"
    final String formattedDateTime = DateFormat(
      "yyyy:MM:dd HH:mm:ss",
    ).format(dateTime);

    try {
      // Invoke the method on the native side
      final bool? result = await _channel.invokeMethod<bool>(
        'setExifDateTime', // Method name must match the one handled in MainActivity.kt
        <String, String>{
          'filePath': filePath,
          'dateTimeString': formattedDateTime,
        },
      );
      // Return the result from native code, default to false if null
      return result ?? false;
    } on PlatformException catch (e) {
      // Handle errors coming from the native side
      debugPrint(
        "Failed to set EXIF date time via platform channel: '${e.message}'. Code: ${e.code}. Details: ${e.details}",
      );
      return false;
    } catch (e) {
      // Handle any other potential errors during the call
      debugPrint("An unexpected error occurred calling EXIF modification: $e");
      return false;
    }
  }

  static Future<bool> triggerMediaScanAndroid(String filePath) async {
    // Platform check - only proceed for Android
    if (!Platform.isAndroid) {
      debugPrint("Media Scanner trigger is only supported on Android.");
      return false;
    }
    try {
      // Invoke the method on the native side
      final bool? result = await _channel.invokeMethod<bool>(
        'triggerMediaScan', // Method name must match the one handled in MainActivity.kt
        <String, String>{'filePath': filePath},
      );
      // Return the result from native code, default to false if null
      return result ?? false;
    } on PlatformException catch (e) {
      // Handle errors coming from the native side
      debugPrint(
        "Failed to trigger media scan via platform channel: '${e.message}'. Code: ${e.code}. Details: ${e.details}",
      );
      return false;
    } catch (e) {
      // Handle any other potential errors during the call
      debugPrint("An unexpected error occurred calling media scan trigger: $e");
      return false;
    }
  }
}

/// Updates the EXIF timestamps and filesystem timestamps for the given image file.
Future<void> updateImageTimestamp(
  File imageFile,
  DateTime oldestTimestamp,
) async {
  bool exifSuccess = await ExifModifier.setExifDateTimeAndroid(
    imageFile.path,
    oldestTimestamp,
  );

  if (exifSuccess) {
    debugPrint("Successfully updated EXIF timestamps for ${imageFile.path}");
    try {
      await imageFile.setLastModified(oldestTimestamp);
      debugPrint(
        "Successfully updated filesystem timestamp for ${imageFile.path}",
      );
    } catch (e) {
      debugPrint("Failed to set filesystem timestamp: $e");
    }
    try {
      await ExifModifier.triggerMediaScanAndroid(imageFile.path);
      debugPrint("Successfully triggered media scan for ${imageFile.path}");
    } catch (e) {
      debugPrint("Failed to trigger media scan: $e");
    }
  } else {
    debugPrint("Failed to update EXIF timestamps for ${imageFile.path}");
  }
}
