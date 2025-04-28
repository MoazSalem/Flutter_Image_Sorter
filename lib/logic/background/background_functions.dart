import 'dart:io';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:image_sorter/core/consts.dart';
import 'package:image_sorter/logic/file_date_parser.dart';
import 'package:image_sorter/logic/file_handling.dart';
import 'package:image_sorter/logic/file_name_parser.dart';
import 'package:image_sorter/logic/notification_handling.dart';
import 'package:path/path.dart' as path;

Future<void> backgroundMoveImagesToUnsorted({
  required String sourceDir,
  required Directory unsortedDir,
  required ServiceInstance service,
}) async {
  final files = Directory(sourceDir).listSync().whereType<File>();
  int index = 0;

  // Move each image file to the unsorted directory
  for (final file in files) {
    final ext = path.extension(file.path).toLowerCase();
    if (imageExtensions.contains(ext) || commonVideoExtensions.contains(ext)) {
      final newPath = path.join(unsortedDir.path, path.basename(file.path));
      try {
        await file.rename(newPath);
      } catch (e) {
        service.invoke('debug', {
          "debugMessage": "Failed to move ${file.path}: $e",
        });
      }
    }
    service.invoke('update', {
      'totalFiles': files.length,
      'processedFiles': ++index,
    });
    changeNotification(
      title: 'Sorting',
      body: 'Moving Images to unsorted: $index / ${files.length}',
      progress: (index / files.length * 100).toInt(),
      onGoing: true,
    );
  }
}

Future<List<MapEntry<File, DateTime>>> backgroundFindOldestImages({
  required Directory dir,
  required bool metadataSearching,
  required ServiceInstance service, // Example parameter
}) async {
  if (!await dir.exists()) return [];

  // Buffer list to hold all image files with their timestamps
  List<MapEntry<File, DateTime>> timestampedFiles = [];
  int index = 0;
  int totalFiles = dir.listSync().whereType<File>().length;

  service.invoke('update', {'processedFiles': 0});
  for (var file in dir.listSync(followLinks: false)) {
    if (file is File) {
      DateTime? timestampCreationDate;
      DateTime? timestampFilename;
      DateTime? timestamp;

      service.invoke('update', {
        'currentAction': 'Getting Timestamp from Filename...',
      });
      // Get timestamp from filename
      final filename = path.basename(file.path);
      timestampFilename = extractTimestampFromFilename(filename);

      service.invoke('update', {
        'currentAction': 'Getting Timestamp from File Stats...',
      });
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

      service.invoke('update', {'processedFiles': ++index});
      changeNotification(
        title: 'Sorting',
        body: 'Getting Timestamps: $index / $totalFiles',
        progress: (index / totalFiles * 100).toInt(),
        onGoing: true,
      );

      if (timestamp != null) {
        timestampedFiles.add(MapEntry(file, timestamp));
      }
    }
  }
  service.invoke('update', {'currentAction': 'Sorting...'});
  // Sort files by timestamp (oldest first)
  timestampedFiles.sort((a, b) => a.value.compareTo(b.value));
  return timestampedFiles;
}

Future<void> backgroundSortAndMoveImages({
  required Directory unsortedDir,
  required Directory targetDir,
  required bool metadataSearching,
  required ServiceInstance service, // Example parameter
}) async {
  final totalFiles = unsortedDir.listSync().whereType<File>().length;
  // Get sorted list of image files
  final sortedFiles = await backgroundFindOldestImages(
    dir: unsortedDir,
    metadataSearching: metadataSearching,
    service: service,
  );
  // Another list to avoid problems with removing files from the list in the for loop
  final list = List<File>.from(sortedFiles.map((entry) => entry.key).toList());
  service.invoke('update', {'currentAction': 'Moving Processed Images...'});
  // Process each file in order
  for (var file in list) {
    final movedFile = await moveFileToDirectory(file, targetDir);
    final entry = sortedFiles.firstWhere((e) => e.key == file);
    await movedFile!.setLastModified(entry.value);
    sortedFiles.remove(entry);
    service.invoke('update', {
      'sortedFiles': list.length - sortedFiles.length,
      'unsortedFiles': totalFiles - (list.length - sortedFiles.length),
      'processedFiles': totalFiles - sortedFiles.length,
    });
    changeNotification(
      title: 'Sorting',
      body:
          'Moving Processed Images: ${totalFiles - sortedFiles.length} / $totalFiles',
      progress: ((totalFiles - sortedFiles.length) / totalFiles * 100).toInt(),
      onGoing: true,
    );
  }
  backgroundHandleUnsortedFiles(unsortedDir: unsortedDir, service: service);
}

void backgroundHandleUnsortedFiles({
  required Directory unsortedDir,
  required ServiceInstance service, // Example parameter
}) {
  final files = unsortedDir.listSync().whereType<File>();
  if (files.isNotEmpty) {
    service.invoke('update', {'unsortedFiles': files.length});
  } else {
    service.invoke('update', {'currentAction': 'Deleting Unsorted Folder...'});
    unsortedDir.delete(); // Ensure service has permissions
  }
}
