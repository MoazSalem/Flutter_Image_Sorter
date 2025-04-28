//Background Service Entry Point

import 'dart:io';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:image_sorter/logic/notification_handling.dart';
import 'package:path/path.dart' as path;

import 'background_functions.dart';

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  initializeNotificationService();

  // Listen for commands from the Cubit to start sorting
  service.on('startSort').listen((event) async {
    final String selectedDirectory = event!['selectedDirectory'];
    final bool metadataSearching = event['metadataSearching'];
    final Directory targetDir = Directory(selectedDirectory);
    final Directory unsortedDir = Directory(
      path.join(selectedDirectory, 'unsorted'),
    );

    try {
      // 1. Update Status & Notification
      service.invoke('update', {
        'currentAction': 'Preparing...',
        'totalFiles': 0,
        'processedFiles': 0,
      });
      changeNotification(
        title: 'Sorting',
        body: 'Preparing...',
        onGoing: false,
      );

      // 2. Create unsorted folder
      if (!await unsortedDir.exists()) {
        await unsortedDir.create();
      }

      // 3. Move images to unsorted
      service.invoke('update', {
        'currentAction': 'Moving Images to unsorted...',
      });
      changeNotification(
        title: 'Sorting',
        body: 'Moving Images to unsorted...',
        onGoing: false,
      );
      await backgroundMoveImagesToUnsorted(
        sourceDir: selectedDirectory,
        unsortedDir: unsortedDir,
        service: service,
      );

      // 4. Sort and move images
      await backgroundSortAndMoveImages(
        targetDir: targetDir,
        unsortedDir: unsortedDir,
        metadataSearching: metadataSearching,
        service: service,
      );

      // 5. Finalization
      changeNotification(
        title: 'Sorting',
        body: 'Sorting Process Finished',
        onGoing: true,
      );
      service.invoke('finished');
    } catch (e) {
      service.invoke('error', {'message': e.toString()});
      changeNotification(title: 'Error', body: 'e.toString()', onGoing: false);
    } finally {
      // Stop the service
      service.stopSelf();
    }
  });
}
