import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

Future<bool> requestAllStoragePermissions() async {
  bool granted = true;

  // For Android 13+ (API 33+): request specific media permissions
  if (Platform.isAndroid) {
    await Permission.storage.status;
    // Request Notification Permission
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    // Optional: Request access to manage external storage (Android 11+)
    if (await Permission.manageExternalStorage.isDenied) {
      final result = await Permission.manageExternalStorage.request();
      if (!result.isGranted) {
        granted = false;
        debugPrint('Storage management permission denied.');
      }
    }
  }
  // Confirm if all permissions are granted
  final statuses = await [Permission.manageExternalStorage].request();

  for (final permission in statuses.entries) {
    if (!permission.value.isGranted) {
      granted = false;
      debugPrint('${permission.key} permission denied.');
    }
  }

  return granted;
}
