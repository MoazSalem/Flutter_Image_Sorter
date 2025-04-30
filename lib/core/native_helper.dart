import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class NativeHelper {
  // Define the channel name. Must match the one used in MainActivity.kt
  static const MethodChannel _channel = MethodChannel(
    'com.moazsalem/native_channel',
  );

  /// Gets Filesystem Timestamps Natively.
  static Future<List<DateTime?>> getFileSystemTimestampsAndroid(
    String filePath,
  ) async {
    if (!Platform.isAndroid) return [];
    try {
      final Map<dynamic, dynamic>? result = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('getFileSystemTimestamps', {
            'filePath': filePath,
          });
      if (result == null) return [];
      DateTime? dateTimeFromMillis(int? millis) =>
          (millis == null || millis <= 0)
              ? null
              : DateTime.fromMillisecondsSinceEpoch(millis);
      return [
        dateTimeFromMillis(result['modified'] as int?),
        dateTimeFromMillis(result['accessed'] as int?),
        dateTimeFromMillis(result['changed'] as int?),
        dateTimeFromMillis(result['created'] as int?),
      ];
    } catch (e) {
      print("Error getting native FS timestamps: $e");
      return [];
    }
  }

  ///  Retrieves specific EXIF date/time tag strings natively from Android.
  ///   Returns a List<DateTime> containing the successfully parsed DateTime objects for
  ///   DateTimeOriginal, DateTimeDigitized, and DateTime tags found natively.
  ///   Returns an empty list if not on Android, an error occurs, or no valid tags are found.
  static Future<List<DateTime>> getExifTimestampsNativelyAndroid(
    String filePath,
  ) async {
    if (!Platform.isAndroid) {
      print("Native EXIF timestamp retrieval is only supported on Android.");
      return []; // Return empty list if not Android
    }

    try {
      // Call the native method, expecting a Map<String, String?>
      final Map<dynamic, dynamic>? result = await _channel
          .invokeMethod<Map<dynamic, dynamic>>(
            'getExifTimestamps', // Method name must match native handler
            <String, String>{'filePath': filePath},
          );

      if (result == null) {
        print("Native EXIF timestamp retrieval returned null.");
        return [];
      }

      final List<DateTime> parsedDates = [];

      // Parse the string values using the helper function
      DateTime? dtOriginal = _parseExifDateTime(
        result['dateTimeOriginal'] as String?,
      );
      DateTime? dtDigitized = _parseExifDateTime(
        result['dateTimeDigitized'] as String?,
      );
      DateTime? dtDateTime = _parseExifDateTime(result['dateTime'] as String?);

      if (dtOriginal != null) parsedDates.add(dtOriginal);
      if (dtDigitized != null) parsedDates.add(dtDigitized);
      if (dtDateTime != null) parsedDates.add(dtDateTime);

      if (parsedDates.isNotEmpty) {
        debugPrint(
          "Native EXIF timestamps parsed for ${filePath}: $parsedDates",
        );
      } else {
        debugPrint(
          "No valid native EXIF date timestamps found or parsed for ${filePath}",
        );
      }
      return parsedDates;
    } on PlatformException catch (e) {
      debugPrint(
        "Failed to get native EXIF timestamps via platform channel: '${e.message}'.",
      );
      return []; // Return empty list on platform exception
    } catch (e) {
      debugPrint(
        "An unexpected error occurred calling native EXIF timestamp retrieval: $e",
      );
      return []; // Return empty list on other errors
    }
  }

  static Future<bool> setExifDateTimeAndroid(
    String filePath,
    DateTime dateTime,
  ) async {
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
        'setExifDateTime',
        // Method name must match the one handled in MainActivity.kt
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

  static Future<bool> setLastModifiedTimeAndroid(
    String filePath,
    DateTime dateTime,
  ) async {
    // Platform check
    if (!Platform.isAndroid) {
      debugPrint(
        "Setting last modified time natively is only supported on Android.",
      );
      return false;
    }

    try {
      // Convert DateTime to milliseconds since epoch for the native side
      final int timeMillis = dateTime.millisecondsSinceEpoch;

      // Invoke the method on the native side
      final bool? result = await _channel.invokeMethod<bool>(
        'setLastModifiedTime', // Must match the handler key in MainActivity.kt
        <String, dynamic>{
          'filePath': filePath,
          'timeMillis': timeMillis, // Pass time as milliseconds
        },
      );

      if (result == true) {
        print("Successfully set last modified time for $filePath");
      } else {
        print("Failed to set last modified time for $filePath");
      }
      // Return the result from native code, default to false if null
      return result ?? false;
    } on PlatformException catch (e) {
      // Handle errors coming from the native side
      debugPrint(
        "Failed to set last modified time via platform channel: '${e.message}'. Code: ${e.code}. Details: ${e.details}",
      );
      return false;
    } catch (e) {
      // Handle any other potential errors during the call
      debugPrint(
        "An unexpected error occurred calling setLastModifiedTime: $e",
      );
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
        'triggerMediaScan',
        // Method name must match the one handled in MainActivity.kt
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

// Helper function to parse EXIF date string (Your existing implementation)
DateTime? _parseExifDateTime(String? exifDateString) {
  if (exifDateString == null) return null;
  try {
    final String iso8601String = exifDateString
        .replaceFirst(':', '-')
        .replaceFirst(':', '-')
        .replaceFirst(' ', 'T');
    return DateTime.parse(iso8601String);
  } catch (e) {
    debugPrint("Error parsing EXIF date string '$exifDateString': $e");
    return null;
  }
}
