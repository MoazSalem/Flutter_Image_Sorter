import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:image_sorter/core/consts.dart';
import 'package:image_sorter/core/native_helper.dart';
import 'package:image_sorter/core/strings.dart';
import 'package:image_sorter/logic/file_name_parser.dart';
import 'package:image_sorter/logic/permissions_handling.dart';
import 'package:path/path.dart' as path;
import 'package:wakelock_plus/wakelock_plus.dart';

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
        ),
      );

  Future<void> selectFolder() async {
    String? selectedDir = await FilePicker.platform.getDirectoryPath();
    if (selectedDir != null) {
      emit(
        state.copyWith(
          selectedDirectory: Directory(selectedDir),
          // Reset progress when a new folder is selected
          sortedFiles: 0,
          unsortedFiles: 0,
          processedFiles: 0,
          totalFiles: 0,
          currentAction: '',
          isProcessing: false,
        ),
      );
    }
  }

  // Main Function
  startSortingProcess({required Directory selectedDirectory}) async {
    // Check for Storage Permissions
    final granted = await requestAllStoragePermissions();
    // Check if folder is empty
    final totalFiles = selectedDirectory.listSync().whereType<File>().length;
    if (totalFiles == 0) {
      emit(state.copyWith(currentAction: AppStrings.noFilesFound));
      return;
    }
    // Keep Screen On While Processing
    WakelockPlus.enable();
    // Start Processing
    emit(
      state.copyWith(
        isProcessing: true,
        currentAction: AppStrings.askingForPermissions,
        // Reset counts for the new process
        totalFiles: totalFiles,
        processedFiles: 0,
        sortedFiles: 0,
        unsortedFiles: 0,
      ),
    );

    if (granted) {
      // Sort and move images
      await sortAndMoveImages(targetDir: selectedDirectory);
    }
    emit(
      state.copyWith(isProcessing: false, currentAction: AppStrings.finished),
    );
    // Disable Screen On After Processing
    WakelockPlus.disable();
  }

  // Combine findOldestImages and moveFileToDirectory functions to sort and move images
  Future<void> sortAndMoveImages({required Directory targetDir}) async {
    // Get sorted list of image files
    final sortedFiles = await findOldestImages(dir: targetDir);
    // Another list to avoid problems with removing files from the list in the for loop
    final list = List<File>.from(
      sortedFiles.map((entry) => entry.key).toList(),
    );

    emit(
      state.copyWith(
        currentAction: AppStrings.processing,
        processedFiles: 0,
        sortedFiles: 0,
        unsortedFiles: 0,
      ),
    );

    // Process each file in order
    for (var file in list) {
      final entry = sortedFiles.firstWhere((e) => e.key == file);
      await updateImageTimestamp(file, entry.value);
      sortedFiles.remove(entry);
      emit(
        state.copyWith(
          sortedFiles: list.length - sortedFiles.length,
          unsortedFiles: state.totalFiles - (list.length - sortedFiles.length),
          processedFiles: state.totalFiles - sortedFiles.length,
        ),
      );
    }
    // Handle unsorted files
    await handleUnsortedFiles(
      unsortedDir: Directory(path.join(targetDir.path, 'unsorted')),
    );
  }

  // Function to find oldest images and sort them in order of oldest to newest
  Future<List<MapEntry<File, DateTime>>> findOldestImages({
    required Directory dir,
  }) async {
    if (!await dir.exists()) return [];

    // Buffer list to hold all image files with their timestamps
    List<MapEntry<File, DateTime>> timestampedFiles = [];

    emit(state.copyWith(processedFiles: 0));
    for (var file in dir.listSync(followLinks: false).whereType<File>()) {
      final ext = path.extension(file.path).toLowerCase();
      if (imageExtensions.contains(ext) ||
          commonVideoExtensions.contains(ext)) {
        DateTime? timestampFileStats;
        DateTime? timestampFilename;
        DateTime? timestamp;

        emit(state.copyWith(currentAction: AppStrings.gettingTimestamp));
        // Get timestamp from filename
        final filename = path.basename(file.path);
        timestampFilename = extractTimestampFromFilename(filename);

        emit(state.copyWith(currentAction: AppStrings.gettingFileStats));
        // Get timestamp from files stats
        timestampFileStats = await findOldestTimestamp(file);

        // Compare timestamps and use the oldest
        timestamp = chooseBestTimestamp(timestampFileStats, timestampFilename);

        emit(state.copyWith(processedFiles: state.processedFiles + 1));

        if (timestamp != null) {
          timestampedFiles.add(MapEntry(file, timestamp));
        } else {
          // If no timestamp found, Move image file to the unsorted directory
          await moveImageToUnsorted(
            file: file,
            unsortedDir: Directory(path.join(dir.path, 'unsorted')),
          );
        }
      }
    }
    emit(state.copyWith(currentAction: AppStrings.sorting));
    // Sort files by timestamp (oldest first)
    timestampedFiles.sort((a, b) => a.value.compareTo(b.value));
    // Extract just the files from the sorted list and return them
    return timestampedFiles;
  }

  Future<void> moveImageToUnsorted({
    required File file,
    required Directory unsortedDir,
  }) async {
    // Create unsorted folder if it doesn't exist
    if (!await unsortedDir.exists()) {
      await unsortedDir.create();
    }
    // Move image file to the unsorted directory
    final newPath = path.join(unsortedDir.path, path.basename(file.path));
    try {
      await file.rename(newPath);
    } catch (e) {
      debugPrint('Failed to move ${file.path}: $e');
    }
  }

  handleUnsortedFiles({required Directory unsortedDir}) async {
    if (await unsortedDir.exists()) {
      final files = unsortedDir.listSync().whereType<File>();
      if (files.isNotEmpty) {
        emit(state.copyWith(unsortedFiles: files.length));
      } else {
        emit(state.copyWith(currentAction: AppStrings.deletingUnsorted));
        unsortedDir.delete();
      }
    }
  }

  DateTime? chooseBestTimestamp(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;

    // Both same date?
    if (a.year == b.year && a.month == b.month && a.day == b.day) {
      final aHasTime = a.hour != 0 || a.minute != 0 || a.second != 0;
      final bHasTime = b.hour != 0 || b.minute != 0 || b.second != 0;

      if (aHasTime && !bHasTime) return a;
      if (bHasTime && !aHasTime) return b;
    }

    // Fall back to earlier of the two
    return a.isBefore(b) ? a : b;
  }

  Future<DateTime?> findOldestTimestamp(File file) async {
    final timestampsExif = await NativeHelper.getExifTimestampsNativelyAndroid(
      file.path,
    );
    List<DateTime?> timestampsFs =
        await NativeHelper.getFileSystemTimestampsAndroid(file.path);

    // Handle EXIF timestamps
    if (timestampsExif.isNotEmpty) {
      return timestampsExif.reduce((a, b) => a.isBefore(b) ? a : b);
    }

    // Handle file system timestamps
    final uniqueTimestamps = Set<DateTime>.from(timestampsFs);
    if (uniqueTimestamps.length > 1) {
      timestampsFs.sort();
    } else {
      timestampsFs.clear();
    }
    return timestampsFs.isNotEmpty ? timestampsFs.first : null;
  }

  Future<void> updateImageTimestamp(
    File imageFile,
    DateTime oldestTimestamp,
  ) async {
    try {
      await NativeHelper.setExifDateTimeAndroid(
        imageFile.path,
        oldestTimestamp,
      );
      debugPrint("Successfully updated EXIF timestamp for ${imageFile.path}");
    } catch (e) {
      debugPrint("Failed to set EXIF timestamp: $e");
    }
    try {
      await NativeHelper.setLastModifiedTimeAndroid(
        imageFile.path,
        oldestTimestamp,
      );
      debugPrint(
        "Successfully updated filesystem timestamp for ${imageFile.path}",
      );
    } catch (e) {
      debugPrint("Failed to set filesystem timestamp: $e");
    }
    try {
      await NativeHelper.triggerMediaScanAndroid(imageFile.path);
      debugPrint("Successfully triggered media scan for ${imageFile.path}");
    } catch (e) {
      debugPrint("Failed to trigger media scan: $e");
    }
  }
}
