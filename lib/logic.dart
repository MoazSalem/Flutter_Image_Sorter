import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';

sortImages({
  required String selectedDirectory,
  required bool useCreationDate,
}) async {
  late File? photo;
  final Directory unsortedDir = await getUnsortedDir(selectedDirectory);
  await movePhotosToUnsorted(selectedDirectory, unsortedDir);
  for (var entity in unsortedDir.listSync(followLinks: false)) {
    photo = await findOldestPhoto(unsortedDir, useCreationDate: true);
    await moveFileToDirectory(photo!, selectedDirectory);
    await touchFile(
      path.join(Directory(selectedDirectory).path, path.basename(photo!.path)),
    );
  }
}

Future<bool> requestAllStoragePermissions() async {
  bool granted = true;

  // For Android 13+ (API 33+): request specific media permissions
  if (Platform.isAndroid) {
    await Permission.storage.status;

    if (await Permission.photos.status.isDenied) {
      await Permission.photos.request();
    }

    // Android 13+ requires more granular permissions
    if (await Permission.videos.status.isDenied) {
      await Permission.videos.request();
    }

    if (await Permission.audio.status.isDenied) {
      await Permission.audio.request();
    }

    // Optional: Request access to manage external storage (Android 11+)
    if (await Permission.manageExternalStorage.isDenied) {
      final result = await Permission.manageExternalStorage.request();
      if (!result.isGranted) {
        granted = false;
        debugPrint('Storage management permission denied.');
      }
    }
  } else {
    // iOS or other platforms: request photos
    if (await Permission.photos.status.isDenied) {
      await Permission.photos.request();
    }
  }

  // Confirm if all permissions are granted
  final statuses =
      await [
        Permission.photos,
        Permission.videos,
        Permission.audio,
        Permission.manageExternalStorage,
      ].request();

  for (final permission in statuses.entries) {
    if (!permission.value.isGranted) {
      granted = false;
      debugPrint('${permission.key} permission denied.');
    }
  }

  return granted;
}

Future<Directory> getUnsortedDir(String imgPath) async {
  await requestAllStoragePermissions();
  final sourceDir = Directory(imgPath);

  if (!await sourceDir.exists()) {
    throw Exception('Source directory does not exist: $imgPath');
  }

  return Directory(path.join(imgPath, 'unsorted'));
}

Future<void> movePhotosToUnsorted(
  String sourceDir,
  Directory unsortedDir,
) async {
  if (!await unsortedDir.exists()) {
    await unsortedDir.create();
  }
  final imageExtensions = ['.jpg', '.jpeg', '.png', '.heic', '.webp'];
  final files = Directory(sourceDir).listSync().whereType<File>();

  for (final file in files) {
    final ext = path.extension(file.path).toLowerCase();
    if (imageExtensions.contains(ext)) {
      final newPath = path.join(unsortedDir.path, path.basename(file.path));
      try {
        await file.rename(newPath);
        debugPrint('Moved: ${file.path} -> $newPath');
      } catch (e) {
        debugPrint('Failed to move ${file.path}: $e');
      }
    }
  }
}

DateTime? extractTimestampFromFilename(String filename) {
  // Pattern for YYYYMMDD_HHMMSS anywhere in the filename
  final basicPattern = RegExp(r'(\d{8})_(\d{6})');
  final match = basicPattern.firstMatch(filename);
  if (match != null) {
    try {
      final datePart = match.group(1)!;
      final timePart = match.group(2)!;

      final year = int.parse(datePart.substring(0, 4));
      final month = int.parse(datePart.substring(4, 6));
      final day = int.parse(datePart.substring(6, 8));
      final hour = int.parse(timePart.substring(0, 2));
      final minute = int.parse(timePart.substring(2, 4));
      final second = int.parse(timePart.substring(4, 6));

      // Validate the date (basic validation)
      if (year >= 1990 &&
          year <= 2100 &&
          month >= 1 &&
          month <= 12 &&
          day >= 1 &&
          day <= 31 &&
          hour >= 0 &&
          hour < 24 &&
          minute >= 0 &&
          minute < 60 &&
          second >= 0 &&
          second < 60) {
        return DateTime(year, month, day, hour, minute, second);
      }
    } catch (e) {
      // Continue if parsing fails
    }
  }

  // Alternative pattern: YYYY-MM-DD_HH-MM-SS
  final dashedPattern = RegExp(
    r'(\d{4})-(\d{2})-(\d{2})[_-](\d{2})[:-](\d{2})[:-](\d{2})',
  );
  final dashMatch = dashedPattern.firstMatch(filename);
  if (dashMatch != null) {
    try {
      final year = int.parse(dashMatch.group(1)!);
      final month = int.parse(dashMatch.group(2)!);
      final day = int.parse(dashMatch.group(3)!);
      final hour = int.parse(dashMatch.group(4)!);
      final minute = int.parse(dashMatch.group(5)!);
      final second = int.parse(dashMatch.group(6)!);

      // Validate the date
      if (year >= 1990 &&
          year <= 2100 &&
          month >= 1 &&
          month <= 12 &&
          day >= 1 &&
          day <= 31 &&
          hour >= 0 &&
          hour < 24 &&
          minute >= 0 &&
          minute < 60 &&
          second >= 0 &&
          second < 60) {
        return DateTime(year, month, day, hour, minute, second);
      }
    } catch (e) {
      // Continue if parsing fails
    }
  }

  return null;
}

Future<File?> findOldestPhoto(
  Directory dirc, {
  bool useCreationDate = false,
}) async {
  final Directory dir = Directory(dirc.path);
  if (!await dir.exists()) return null;

  File? oldestFile;
  DateTime? oldestTime;

  for (var entity in dir.listSync(followLinks: false)) {
    if (entity is File) {
      DateTime? timestamp;

      if (useCreationDate) {
        // Get timestamp from file creation date
        final FileStat stats = await entity.stat();
        timestamp = stats.changed;
      } else {
        // Get timestamp from filename
        final filename = path.basename(entity.path);
        timestamp = extractTimestampFromFilename(filename);
      }

      if (timestamp != null) {
        if (oldestTime == null || timestamp.isBefore(oldestTime)) {
          oldestTime = timestamp;
          oldestFile = entity;
        }
      }
    }
  }

  return oldestFile;
}

Future<void> moveFileToDirectory(File file, String targetDirectoryPath) async {
  final targetDir = Directory(targetDirectoryPath);
  final newPath = path.join(targetDir.path, path.basename(file.path));

  try {
    await file.rename(newPath);
    debugPrint('File moved to: $newPath');
  } catch (e) {
    debugPrint('Error moving file: $e');
  }
}

Future<void> touchFile(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) return;

  try {
    // Get current time in milliseconds
    final DateTime now = DateTime.now();

    // Update the last modified timestamp
    final result = await file.setLastModified(now);

    debugPrint('File timestamp updated: $filePath, success: $result');
  } catch (e) {
    debugPrint('Error updating file timestamp: $e');
  }
}
