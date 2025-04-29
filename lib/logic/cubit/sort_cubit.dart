import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:image_sorter/logic/background/background_service.dart';
import 'package:image_sorter/logic/permissions_handling.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

part 'sort_state.dart';

class SortCubit extends Cubit<SortState> {
  final FlutterBackgroundService _backgroundService = service;

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

  // Initialize listener only when starting the background service
  Future<void> initializeBackgroundServiceListener() async {
    _backgroundService.on('update').listen((event) {
      if (event != null) {
        // Assuming the event map contains state updates
        emit(
          state.copyWith(
            isProcessing: event['isProcessing'] ?? state.isProcessing,
            totalFiles: event['totalFiles'] ?? state.totalFiles,
            processedFiles: event['processedFiles'] ?? state.processedFiles,
            sortedFiles: event['sortedFiles'] ?? state.sortedFiles,
            unsortedFiles: event['unsortedFiles'] ?? state.unsortedFiles,
            currentAction: event['currentAction'] ?? state.currentAction,
          ),
        );
      }
    });

    _backgroundService.on('finished').listen((event) {
      emit(state.copyWith(isProcessing: false, currentAction: 'Finished !'));
      WakelockPlus.disable();
    });

    _backgroundService.on('error').listen((event) {
      // Handle errors reported by the background service
      emit(
        state.copyWith(
          isProcessing: false,
          currentAction: 'Error: ${event?['message']}',
        ),
      );
      WakelockPlus.disable();
    });

    _backgroundService.on('debug').listen((event) {
      debugPrint(event!['debugMessage']);
    });
  }

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

  // Main Function using Background Service
  Future<void> startSortProcess({
    required String selectedDirectory,
    bool metadataSearching = false,
  }) async {
    // Start listening for service updates
    await initializeBackgroundServiceListener();

    // Keep Screen On While Processing
    WakelockPlus.enable();

    // Update state to indicate processing start
    emit(
      state.copyWith(
        isProcessing: true,
        currentAction: 'Asking for Permissions...',
        // Reset counts for the new process
        totalFiles: 0,
        processedFiles: 0,
        sortedFiles: 0,
        unsortedFiles: 0,
      ),
    );

    // Check for Storage Permissions
    final granted = await requestAllStoragePermissions();

    if (granted) {
      emit(state.copyWith(currentAction: 'Starting background process...'));
      // Start the service only when permissions are granted
      await _backgroundService.startService();
      _backgroundService.invoke('startSort', {
        'selectedDirectory': selectedDirectory,
        'metadataSearching': metadataSearching,
      });
    } else {
      // Handle permission denial
      emit(
        state.copyWith(
          isProcessing: false,
          currentAction: 'Storage permissions denied.',
        ),
      );
      WakelockPlus.disable();
    }
  }

  @override
  Future<void> close() {
    // Clean up listeners or background service connections
    WakelockPlus.disable();
    return super.close();
  }
}
