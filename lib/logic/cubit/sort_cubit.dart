import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:image_sorter/core/consts.dart';
import 'package:image_sorter/core/native_helper.dart';
import 'package:image_sorter/logic/file_date_parser.dart';
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
          metadataSearching: false,
        ),
      );

  setMetadata(bool value) {
    emit(state.copyWith(metadataSearching: value));
  }

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
  startSortingProcess({
    required Directory selectedDirectory,
    bool metadataSearching = false,
  }) async {
    // Check for Storage Permissions
    final granted = await requestAllStoragePermissions();
    // Check if folder is empty
    final totalFiles = selectedDirectory.listSync().whereType<File>().length;
    if (totalFiles == 0) {
      emit(state.copyWith(currentAction: 'No Files Found in Folder'));
      return;
    }
    // Keep Screen On While Processing
    WakelockPlus.enable();
    // Start Processing
    emit(
      state.copyWith(
        isProcessing: true,
        currentAction: 'Asking for Permissions...',
        // Reset counts for the new process
        totalFiles: totalFiles,
        processedFiles: 0,
        sortedFiles: 0,
        unsortedFiles: 0,
      ),
    );

    if (granted) {
      // Sort and move images
      await sortAndMoveImages(
        targetDir: selectedDirectory,
        metadataSearching: metadataSearching,
      );
    }
    emit(state.copyWith(isProcessing: false, currentAction: 'Finished !'));
    // Disable Screen On After Processing
    WakelockPlus.disable();
  }

  // Combine findOldestImages and moveFileToDirectory functions to sort and move images
  Future<void> sortAndMoveImages({
    required Directory targetDir,
    required bool metadataSearching,
  }) async {
    // Get sorted list of image files
    final sortedFiles = await findOldestImages(
      dir: targetDir,
      metadataSearching: metadataSearching,
    );
    // Another list to avoid problems with removing files from the list in the for loop
    final list = List<File>.from(
      sortedFiles.map((entry) => entry.key).toList(),
    );

    emit(
      state.copyWith(
        currentAction: 'Processing Images...',
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
    required bool metadataSearching,
  }) async {
    if (!await dir.exists()) return [];

    // Buffer list to hold all image files with their timestamps
    List<MapEntry<File, DateTime>> timestampedFiles = [];

    emit(state.copyWith(processedFiles: 0));
    for (var file in dir.listSync(followLinks: false).whereType<File>()) {
      final ext = path.extension(file.path);
      if (imageExtensions.contains(ext) ||
          commonVideoExtensions.contains(ext)) {
        DateTime? timestampCreationDate;
        DateTime? timestampFilename;
        DateTime? timestamp;

        emit(
          state.copyWith(currentAction: 'Getting Timestamp from Filename...'),
        );
        // Get timestamp from filename
        final filename = path.basename(file.path);
        timestampFilename = extractTimestampFromFilename(filename);

        emit(
          state.copyWith(currentAction: 'Getting Timestamp from File Stats...'),
        );
        // Get timestamp from file creation date
        timestampCreationDate = await findOldestFileTimestamp(
          file,
          metadataSearching: metadataSearching,
        );

        // Compare timestamps and use the oldest
        if (timestampFilename != null && timestampCreationDate != null) {
          timestamp =
              timestampFilename.isBefore(timestampCreationDate)
                  ? timestampFilename
                  : timestampCreationDate;
        } else if (timestampFilename != null) {
          timestamp = timestampFilename;
        } else if (timestampCreationDate != null) {
          timestamp = timestampCreationDate;
        }

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
    emit(state.copyWith(currentAction: 'Sorting...'));
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
        emit(state.copyWith(currentAction: 'Deleting Unsorted Folder...'));
        unsortedDir.delete();
      }
    }
  }

  Future<void> updateImageTimestamp(
    File imageFile,
    DateTime oldestTimestamp,
  ) async {
    bool exifSuccess = await NativeHelper.setExifDateTimeAndroid(
      imageFile.path,
      oldestTimestamp,
    );

    if (exifSuccess) {
      debugPrint("Successfully updated EXIF timestamps for ${imageFile.path}");
      try {
        await imageFile.setLastModified(oldestTimestamp);
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
    } else {
      debugPrint("Failed to update EXIF timestamps for ${imageFile.path}");
    }
    return;
  }
}
