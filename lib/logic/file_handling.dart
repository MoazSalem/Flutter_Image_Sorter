import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:path/path.dart' as path;

Future<void> moveFileToDirectory(File file, Directory targetDir) async {
  final newPath = path.join(targetDir.path, path.basename(file.path));

  try {
    await file.rename(newPath);
  } catch (e) {
    debugPrint('Error moving file: $e');
    // If rename fails try copy and delete
    try {
      await file.copy(newPath);
      await file.delete();
    } catch (e) {
      debugPrint('Error copying and deleting file: $e');
    }
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
  } catch (e) {
    debugPrint('Error updating file timestamp: $e');
  }
}
