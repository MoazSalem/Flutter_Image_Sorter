import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';

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

Future<void> movePhotosToUnsorted(String imgPath) async {
  requestAllStoragePermissions();
  final sourceDir = Directory(imgPath);

  if (!await sourceDir.exists()) {
    return;
  }

  final unsortedDir = Directory(path.join(imgPath, 'unsorted'));

  if (!await unsortedDir.exists()) {
    await unsortedDir.create();
  }
  final imageExtensions = ['.jpg', '.jpeg', '.png', '.heic', '.webp'];
  final files = sourceDir.listSync().whereType<File>();

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
