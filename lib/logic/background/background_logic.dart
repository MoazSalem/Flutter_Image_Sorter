import 'dart:io';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'background_functions.dart';

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    DartPluginRegistrant.ensureInitialized();

    // Listen for commands from the Cubit to start sorting
    service.on('startSort').listen((event) async {
      final String selectedDirectory = event!['selectedDirectory'];
      final bool metadataSearching = event['metadataSearching'];
      final Directory targetDir = Directory(selectedDirectory);

      try {
        // Update Status & Notification
        service.invoke('update', {
          'currentAction': 'Preparing...',
          'totalFiles': 0,
          'processedFiles': 0,
        });
        if (await service.isForegroundService()) {
          service.setForegroundNotificationInfo(
            title: "Sorting",
            content: "Preparing...",
          );
        }
        // Sort and move images
        await backgroundSortAndMoveImages(
          targetDir: targetDir,
          metadataSearching: metadataSearching,
          service: service,
        );

        // Finalization
        service.setForegroundNotificationInfo(
          title: "Sorting",
          content: "Sorting Process Finished",
        );
        service.invoke('finished');
        service.stopSelf();
      } catch (e) {
        service.invoke('error', {'message': e.toString()});
        service.setForegroundNotificationInfo(
          title: "Error",
          content: e.toString(),
        );
      } finally {
        // Stop the service
        service.stopSelf();
      }
    });
  }
}
