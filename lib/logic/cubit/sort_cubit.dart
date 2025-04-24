import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:image_sorter/core/consts.dart';
import 'package:image_sorter/logic/file_date_parser.dart';
import 'package:image_sorter/logic/file_handling.dart';
import 'package:image_sorter/logic/file_name_parser.dart';
import 'package:image_sorter/logic/permissions_handling.dart';
import 'package:path/path.dart' as path;

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
      emit(
        state.copyWith(
          selectedDirectory: Directory(selectedDir),
          sortedFiles: 0,
          unsortedFiles: 0,
          processedFiles: 0,
          totalFiles: 0,
        ),
      );
    }
  }

  setSortMethod(bool sortByCreationDate) =>
      emit(state.copyWith(sortByCreationDate: sortByCreationDate));

  // Main Function
  sortImages({
    required String selectedDirectory,
    required bool useCreationDate,
  }) async {
    // Start Processing
    emit(
      state.copyWith(
        isProcessing: true,
        currentAction: 'Asking for Permissions...',
      ),
    );
    // Check for Storage Permissions
    final granted = await requestAllStoragePermissions();

    if (granted) {
      // Create unsorted folder
      final Directory unsortedDir = Directory(
        path.join(selectedDirectory, 'unsorted'),
      );
      if (!await unsortedDir.exists()) {
        await unsortedDir.create();
      }

      // Move all images to unsorted folder
      emit(state.copyWith(currentAction: 'Moving Images to unsorted...'));
      await moveImagesToUnsorted(
        sourceDir: selectedDirectory,
        unsortedDir: unsortedDir,
      );

      // Once all Images are in the unsorted folder start sorting
      emit(state.copyWith(currentAction: 'Sorting...'));
      await sortAndMoveImages(
        targetDir: Directory(selectedDirectory),
        unsortedDir: unsortedDir,
        useCreationDate: useCreationDate,
      );
    }
    emit(state.copyWith(isProcessing: false, currentAction: 'Finished !'));
  }

  Future<void> moveImagesToUnsorted({
    required String sourceDir,
    required Directory unsortedDir,
  }) async {
    // Find all image files in the source directory
    final files = Directory(sourceDir).listSync().whereType<File>();

    emit(state.copyWith(totalFiles: files.length, processedFiles: 0));

    // Move each image file to the unsorted directory
    for (final file in files) {
      emit(state.copyWith(processedFiles: state.processedFiles + 1));
      final ext = path.extension(file.path).toLowerCase();
      if (imageExtensions.contains(ext)) {
        final newPath = path.join(unsortedDir.path, path.basename(file.path));
        try {
          await file.rename(newPath);
        } catch (e) {
          debugPrint('Failed to move ${file.path}: $e');
        }
      }
    }
  }

  // Function to find oldest images and sort them in order of oldest to newest
  Future<List<File>> findOldestImages({
    required Directory dir,
    required bool useCreationDate,
  }) async {
    if (!await dir.exists()) return [];

    // Buffer list to hold all image files with their timestamps
    List<MapEntry<File, DateTime>> timestampedFiles = [];

    for (var file in dir.listSync(followLinks: false)) {
      if (file is File) {
        DateTime? timestamp;
        if (useCreationDate) {
          // Get timestamp from file creation date
          timestamp = await findOldestFileTimestamp(file);
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

  // Combine findOldestImages and moveFileToDirectory functions to sort and move images
  Future<void> sortAndMoveImages({
    required Directory unsortedDir,
    required Directory targetDir,
    required bool useCreationDate,
  }) async {
    // Get sorted list of image files
    final sortedFiles = await findOldestImages(
      useCreationDate: useCreationDate,
      dir: unsortedDir,
    );
    // Another list to avoid problems with removing files from the list in the for loop
    final list = List<File>.from(sortedFiles);

    emit(state.copyWith(currentAction: 'Moving Processed Images...'));

    // Process each file in order
    for (var file in list) {
      await touchFile(file.path);
      await moveFileToDirectory(file, targetDir);
      sortedFiles.remove(file);
      // Wait for 1 second (it seems that android doesn't register file changes if it's too fast)
      await Future.delayed(const Duration(seconds: 1));
      emit(
        state.copyWith(
          sortedFiles: list.length - sortedFiles.length,
          unsortedFiles: state.totalFiles - (list.length - sortedFiles.length),
          processedFiles: state.totalFiles - sortedFiles.length,
        ),
      );
    }
    // Handle unsorted files
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
}
