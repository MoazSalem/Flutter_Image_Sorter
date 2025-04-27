import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:path/path.dart' as path;

Future<File?> moveFileToDirectory(File file, Directory targetDir) async {
  final newPath = path.join(targetDir.path, path.basename(file.path));

  try {
    return await file.rename(newPath);
  } catch (e) {
    debugPrint('Error moving file: $e');
    // If rename fails try copy and delete
    try {
      final newFile = await file.copy(newPath);
      await file.delete();
      return newFile;
    } catch (e) {
      debugPrint('Error copying and deleting file: $e');
      return null;
    }
  }
}
