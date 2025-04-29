import 'dart:io';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:image_sorter/core/consts.dart';
import 'package:image_sorter/logic/file_date_parser.dart';
import 'package:image_sorter/logic/file_handling.dart';
import 'package:image_sorter/logic/file_name_parser.dart';
import 'package:path/path.dart' as path;

Future<void> backgroundMoveImageToUnsorted({
  required Directory unsortedDir,
  required AndroidServiceInstance service,
  required File file,
}) async {
  // Create unsorted folder if it doesn't exist
  if (!await unsortedDir.exists()) {
    await unsortedDir.create();
  }
  // Move image file to the unsorted directory
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
}

Future<List<MapEntry<File, DateTime>>> backgroundFindOldestImages({
  required Directory dir,
  required bool metadataSearching,
  required AndroidServiceInstance service, // Example parameter
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
      service.setForegroundNotificationInfo(
        title: "Sorting",
        content: 'Getting Timestamps: $index / $totalFiles',
      );

      if (timestamp != null) {
        timestampedFiles.add(MapEntry(file, timestamp));
      } else {
        // If no timestamp found, Move image file to the unsorted directory
        await backgroundMoveImageToUnsorted(
          unsortedDir: Directory(path.join(dir.path, 'unsorted')),
          service: service,
          file: file,
        );
      }
    }
  }
  service.invoke('update', {'currentAction': 'Sorting...'});
  // Sort files by timestamp (oldest first)
  timestampedFiles.sort((a, b) => a.value.compareTo(b.value));
  return timestampedFiles;
}

Future<void> backgroundSortAndMoveImages({
  required Directory targetDir,
  required bool metadataSearching,
  required AndroidServiceInstance service, // Example parameter
}) async {
  final totalFiles = targetDir.listSync().whereType<File>().length;
  service.invoke('update', {'totalFiles': totalFiles});
  // Get sorted list of image files
  final sortedFiles = await backgroundFindOldestImages(
    dir: targetDir,
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
    service.setForegroundNotificationInfo(
      title: "Sorting",
      content:
          'Moving Processed Images: ${totalFiles - sortedFiles.length} / $totalFiles',
    );
  }
  backgroundHandleUnsortedFiles(
    unsortedDir: Directory(path.join(targetDir.path, 'unsorted')),
    service: service,
  );
}

Future<void> backgroundHandleUnsortedFiles({
  required Directory unsortedDir,
  required AndroidServiceInstance service, // Example parameter
}) async {
  if (await unsortedDir.exists()) {
    final files = unsortedDir.listSync().whereType<File>();
    if (files.isNotEmpty) {
      service.invoke('update', {'unsortedFiles': files.length});
    } else {
      service.invoke('update', {
        'currentAction': 'Deleting Unsorted Folder...',
      });
      unsortedDir.delete(); // Ensure service has permissions
    }
  }
}
