import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_sorter/core/consts.dart';

// Finds the oldest timestamp among modification, access, change, and EXIF DateTimeOriginal
Future<DateTime?> findOldestFileTimestamp(File file) async {
  final List<DateTime> timestamps = [];
  DateTime? exifDateTime;

  try {
    // Get File System Timestamps
    final FileStat stats = await file.stat();
    timestamps.add(stats.modified);
    timestamps.add(stats.accessed);
    timestamps.add(stats.changed);

    DateTime modifiedRounded = stats.modified.subtract(
      Duration(
        seconds: stats.modified.second,
        milliseconds: stats.modified.millisecond,
        microseconds: stats.modified.microsecond,
      ),
    );
    DateTime accessedRounded = stats.accessed.subtract(
      Duration(
        seconds: stats.modified.second,
        milliseconds: stats.accessed.millisecond,
        microseconds: stats.accessed.microsecond,
      ),
    );

    if (modifiedRounded == accessedRounded) {
      debugPrint("Creation date is Missed up for ${file.path}");
      // the timestamps won't work
      timestamps.clear();
    }

    // 2. Attempt to Read EXIF DateTimeOriginal
    String fileExtension = file.path.split('.').last.toLowerCase();
    if ([
      'jpg',
      'jpeg',
      'tif',
      'tiff',
      'heic',
      'heif',
    ].contains(fileExtension)) {
      try {
        final Uint8List fileBytes = await file.readAsBytes();
        final img.Image? image = img.decodeImage(fileBytes);

        if (image != null) {
          final img.ExifData? exifData = image.exif; // Get the ExifData object

          // Check if exifData is not null AND directly check for the key using containsKey
          if (exifData != null &&
              exifData.exifIfd.containsKey(dateTimeOriginalTagId)) {
            // Access the value directly using the [] operator on exifData
            final exifValue = exifData.exifIfd[dateTimeOriginalTagId];
            exifDateTime = _parseExifDateTime(exifValue?.toString());
            if (exifDateTime != null) {
              debugPrint(
                "Found valid EXIF DateTimeOriginal for ${file.path}: $exifDateTime",
              );
              // Add valid parsed EXIF date
              timestamps.add(exifDateTime);
            } else {
              debugPrint(
                "Found EXIF DateTimeOriginal tag but failed to parse value '${exifValue?.toString()}' for ${file.path}",
              );
            }
          }
        }
      } catch (e) {
        debugPrint("Error reading/parsing EXIF for ${file.path}: $e");
      }
    }

    // 3. Find the Oldest Timestamp
    if (timestamps.isEmpty) {
      debugPrint(
        "Warning: No valid timestamps (filesystem or EXIF) retrieved for ${file.path}",
      );
      return null;
    }

    // Find the minimum DateTime in the list
    DateTime oldest = timestamps[0];
    for (int i = 1; i < timestamps.length; i++) {
      if (timestamps[i].isBefore(oldest)) {
        oldest = timestamps[i];
      }
    }

    debugPrint("Oldest timestamp determined for ${file.path}: $oldest");
    return oldest;
  } on FileSystemException catch (e) {
    debugPrint("FileSystemException processing file ${file.path}: $e");
    return null;
  } catch (e) {
    debugPrint("Unexpected error processing file ${file.path}: $e");
    return null;
  }
}

DateTime? _parseExifDateTime(String? exifDateString) {
  if (exifDateString == null) return null;
  try {
    // EXIF format is "YYYY:MM:DD HH:MM:SS"
    // Convert to ISO 8601 format "YYYY-MM-DDTHH:MM:SS" for DateTime.parse
    final String iso8601String = exifDateString
        .replaceFirst(':', '-') // Replace first colon
        .replaceFirst(':', '-') // Replace second colon
        .replaceFirst(' ', 'T'); // Replace space with T
    return DateTime.parse(iso8601String);
  } catch (e) {
    debugPrint("Error parsing EXIF date string '$exifDateString': $e");
    return null;
  }
}
