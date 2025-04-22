import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Sorter',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurpleAccent),
        useMaterial3: true,
      ),
      home: const PhotoSorterHome(),
    );
  }
}

class PhotoSorterHome extends StatefulWidget {
  const PhotoSorterHome({super.key});

  @override
  State<PhotoSorterHome> createState() => _PhotoSorterHomeState();
}

class _PhotoSorterHomeState extends State<PhotoSorterHome> {
  String? selectedDirectory;
  bool isProcessing = false;
  int totalFiles = 0;
  int processedFiles = 0;
  int sortedFiles = 0;
  int unsortedFiles = 0;
  String currentAction = "";
  bool sortByName = true;

  Future<bool> requestAllStoragePermissions() async {
    bool granted = true;

    // For Android 13+ (API 33+): request specific media permissions
    if (Platform.isAndroid) {
      await Permission.storage.status;

      if (await Permission.photos.status.isDenied) {
        await Permission.photos.request();
      }

      // Android 13+ requires more granular permissions
      if (await Permission.videos.status.isDenied) {
        await Permission.videos.request();
      }

      if (await Permission.audio.status.isDenied) {
        await Permission.audio.request();
      }

      // Optional: Request access to manage external storage (Android 11+)
      if (await Permission.manageExternalStorage.isDenied) {
        final result = await Permission.manageExternalStorage.request();
        if (!result.isGranted) {
          granted = false;
          debugPrint('Storage management permission denied.');
        }
      }
    } else {
      // iOS or other platforms: request photos
      if (await Permission.photos.status.isDenied) {
        await Permission.photos.request();
      }
    }

    // Confirm if all permissions are granted
    final statuses =
        await [
          Permission.photos,
          Permission.videos,
          Permission.audio,
          Permission.manageExternalStorage,
        ].request();

    for (final permission in statuses.entries) {
      if (!permission.value.isGranted) {
        granted = false;
        debugPrint('${permission.key} permission denied.');
      }
    }

    return granted;
  }

  Future<void> selectFolder() async {
    String? selectedDir = await FilePicker.platform.getDirectoryPath();

    if (selectedDir != null) {
      setState(() {
        selectedDirectory = selectedDir;
      });
    }
  }

  Future<void> movePhotosToUnsorted(String imgPath) async {
    requestAllStoragePermissions();
    final sourceDir = Directory(imgPath);

    if (!await sourceDir.exists()) {
      return;
    }

    final unsortedDir = Directory(path.join(imgPath, 'unsorted'));

    if (!await unsortedDir.exists()) {
      await unsortedDir.create();
    }
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.heic', '.webp'];
    final files = sourceDir.listSync().whereType<File>();

    for (final file in files) {
      final ext = path.extension(file.path).toLowerCase();
      if (imageExtensions.contains(ext)) {
        final newPath = path.join(unsortedDir.path, path.basename(file.path));
        try {
          await file.rename(newPath);
          debugPrint('Moved: ${file.path} -> $newPath');
        } catch (e) {
          debugPrint('Failed to move ${file.path}: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Image Sorter')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Card(
                child: ExpansionTile(
                  title: Text(
                    'How it works:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  dense: true,
                  tilePadding: EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 20,
                  ),
                  childrenPadding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: 20,
                  ),
                  shape: Border(),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('1. Select a folder containing images'),
                    Text(
                      '2. All images will be moved to an "unsorted" subfolder',
                    ),
                    Text(
                      '3. Images will be sorted by date from filename or creation date',
                    ),
                    Text(
                      '4. Sorted images will be moved back to the original folder',
                    ),
                    Text(
                      '5. Unsortable images will remain in the "unsorted" folder',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Select Sort Method',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Column(
                        children: [
                          RadioListTile<bool>(
                            title: const Text('Sort by Filename'),
                            value: true,
                            groupValue: sortByName,
                            onChanged:
                                isProcessing
                                    ? null
                                    : (value) {
                                      setState(() {
                                        sortByName = value!;
                                      });
                                    },
                          ),
                          RadioListTile<bool>(
                            title: const Text('Sort by Creation Date'),
                            value: false,
                            groupValue: sortByName,
                            onChanged:
                                isProcessing
                                    ? null
                                    : (value) {
                                      setState(() {
                                        sortByName = value!;
                                      });
                                    },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: isProcessing ? null : selectFolder,
                child: Text(
                  selectedDirectory == null
                      ? 'Select Image Folder'
                      : 'Selected: ${path.basename(selectedDirectory!)}',
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.tonal(
                onPressed: () => movePhotosToUnsorted(selectedDirectory!),
                child: const Text('Start Processing'),
              ),
              const SizedBox(height: 20),
              if (isProcessing)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          currentAction,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value:
                              totalFiles > 0 ? processedFiles / totalFiles : 0,
                        ),
                        const SizedBox(height: 10),
                        Text('$processedFiles / $totalFiles files'),
                        if (sortedFiles > 0 || unsortedFiles > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Sorted: $sortedFiles, Unsorted: $unsortedFiles',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
