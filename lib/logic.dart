import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';

sortByFileName(String selectedDirectory) async {
  late File? photo;
  final Directory unsortedDir = await getUnsortedDir(selectedDirectory);
  await movePhotosToUnsorted(selectedDirectory, unsortedDir);
  for (var entity in unsortedDir.listSync(followLinks: false)) {
    photo = await findOldestPhotoByFilename(unsortedDir);
    moveFileToDirectory(photo!, selectedDirectory);
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
  requestAllStoragePermissions();
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
  final regex = RegExp(r'IMG_(\d{8})_(\d{6})');
  final match = regex.firstMatch(filename);
  if (match != null) {
    final datePart = match.group(1)!;
    final timePart = match.group(2)!;

    final year = int.parse(datePart.substring(0, 4));
    final month = int.parse(datePart.substring(4, 6));
    final day = int.parse(datePart.substring(6, 8));
    final hour = int.parse(timePart.substring(0, 2));
    final minute = int.parse(timePart.substring(2, 4));
    final second = int.parse(timePart.substring(4, 6));

    return DateTime(year, month, day, hour, minute, second);
  }
  return null;
}

Future<File?> findOldestPhotoByFilename(Directory dirc) async {
  final Directory dir = Directory(dirc.path);
  if (!await dir.exists()) return null;

  File? oldestFile;
  DateTime? oldestTime;

  for (var entity in dir.listSync(followLinks: false)) {
    if (entity is File) {
      final filename = path.basename(entity.path);
      final timestamp = extractTimestampFromFilename(filename);
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
