import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';

part 'sort_state.dart';

class SortCubit extends Cubit<SortState> {
  SortCubit()
    : super(
        SortState(
          selectedDirectory: null,
          isProcessing: false,
          totalFiles: 0,
          processedFiles: 0,
          sortedFiles: 0,
          unsortedFiles: 0,
          currentAction: '',
          sortByCreationDate: true,
        ),
      );

  Future<void> selectFolder() async {
    String? selectedDir = await FilePicker.platform.getDirectoryPath();
    if (selectedDir != null) {
      emit(state.copyWith(selectedDirectory: Directory(selectedDir)));
    }
  }

  setSortMethod(bool sortByCreationDate) =>
      emit(state.copyWith(sortByCreationDate: sortByCreationDate));

  sortImages({
    required String selectedDirectory,
    required bool useCreationDate,
  }) async {
    emit(
      state.copyWith(
        isProcessing: true,
        currentAction: 'Asking for Permissions...',
      ),
    );
    final granted = await requestAllStoragePermissions();

    if (granted) {
      final Directory unsortedDir = Directory(
        path.join(selectedDirectory, 'unsorted'),
      );
      if (!await unsortedDir.exists()) {
        await unsortedDir.create();
      }
      emit(state.copyWith(currentAction: 'Moving Images to unsorted...'));
      await movePhotosToUnsorted(
        sourceDir: selectedDirectory,
        unsortedDir: unsortedDir,
      );
      emit(state.copyWith(currentAction: 'Sorting...'));
      await sortAndMovePhotos(
        targetDir: Directory(selectedDirectory),
        unsortedDir: unsortedDir,
        useCreationDate: useCreationDate,
      );
    }
    emit(state.copyWith(isProcessing: false, currentAction: 'Finished !'));
  }

  Future<bool> requestAllStoragePermissions() async {
    bool granted = true;

    // For Android 13+ (API 33+): request specific media permissions
    if (Platform.isAndroid) {
      await Permission.storage.status;

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

  Future<void> movePhotosToUnsorted({
    required String sourceDir,
    required Directory unsortedDir,
  }) async {
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.heic', '.webp'];
    final files = Directory(sourceDir).listSync().whereType<File>();
    emit(state.copyWith(totalFiles: files.length, processedFiles: 0));
    for (final file in files) {
      emit(state.copyWith(processedFiles: state.processedFiles + 1));
      final ext = path.extension(file.path).toLowerCase();
      if (imageExtensions.contains(ext)) {
        final newPath = path.join(unsortedDir.path, path.basename(file.path));
        try {
          await file.rename(newPath);
          //debugPrint('Moved: ${file.path} -> $newPath');
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

  Future<void> sortAndMovePhotos({
    required Directory unsortedDir,
    required Directory targetDir,
    required bool useCreationDate,
  }) async {
    // Get sorted list of photo files
    final sortedFiles = await findOldestPhoto(
      useCreationDate: useCreationDate,
      dir: unsortedDir,
    );
    final list = List<File>.from(sortedFiles);
    debugPrint("$sortedFiles");
    emit(state.copyWith(currentAction: 'Moving Processed Images...'));
    // Process each file in order
    emit(state.copyWith(unsortedFiles: sortedFiles.length));
    for (var file in list) {
      await moveFileToDirectory(file, targetDir);
      await touchFile(file.path);
      sortedFiles.remove(file);
      emit(
        state.copyWith(
          sortedFiles: list.length - sortedFiles.length,
          unsortedFiles: state.totalFiles - (list.length - sortedFiles.length),
          processedFiles: state.totalFiles - sortedFiles.length,
        ),
      );
    }
    handleUnsortedFiles(targetDir: unsortedDir);
  }

  handleUnsortedFiles({required Directory targetDir}) {
    final files = targetDir.listSync().whereType<File>();
    if (files.isNotEmpty) {
      //TODO: Handle unsorted files
      emit(state.copyWith(unsortedFiles: files.length));
    } else {
      emit(state.copyWith(currentAction: 'Deleting Unsorted Folder...'));
      targetDir.delete();
    }
  }

  Future<List<File>> findOldestPhoto({
    required Directory dir,
    required bool useCreationDate,
  }) async {
    if (!await dir.exists()) return [];

    // Buffer list to hold all photo files with their timestamps
    List<MapEntry<File, DateTime>> timestampedFiles = [];

    for (var file in dir.listSync(followLinks: false)) {
      if (file is File) {
        DateTime? timestamp;
        if (useCreationDate) {
          // Get timestamp from file creation date
          final FileStat stats = await file.stat();
          timestamp = stats.changed;
        } else {
          // Get timestamp from filename
          final filename = path.basename(file.path);
          timestamp = extractTimestampFromFilename(filename);
        }

        if (timestamp != null) {
          timestampedFiles.add(MapEntry(file, timestamp));
        }
      }
    }

    // Sort files by timestamp (oldest first)
    timestampedFiles.sort((a, b) => a.value.compareTo(b.value));
    // Extract just the files from the sorted list and return them
    return timestampedFiles.map((entry) => entry.key).toList();
  }

  Future<void> moveFileToDirectory(File file, Directory targetDir) async {
    final newPath = path.join(targetDir.path, path.basename(file.path));

    try {
      await file.rename(newPath);
      debugPrint('File moved to: $newPath');
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

      debugPrint('File timestamp updated: $filePath, success: $result');
    } catch (e) {
      debugPrint('Error updating file timestamp: $e');
    }
  }
}
