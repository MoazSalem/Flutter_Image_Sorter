import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_sorter/core/sizes.dart';
import 'package:image_sorter/core/strings.dart';
import 'package:path/path.dart' as path;

class ActionButtons extends StatelessWidget {
  final Directory? selectedDirectory;
  final bool isProcessing;
  final VoidCallback onSelectFolder;
  final VoidCallback onStartProcessing;

  const ActionButtons({
    super.key,
    required this.selectedDirectory,
    required this.isProcessing,
    required this.onSelectFolder,
    required this.onStartProcessing,
  });

  @override
  Widget build(BuildContext context) {
    final bool canStartProcessing = selectedDirectory != null && !isProcessing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.all(AppSizes.padding),
          ),
          onPressed: isProcessing ? null : onSelectFolder,
          child: Text(
            selectedDirectory == null
                ? AppStrings.selectFolder
                : '${AppStrings.selected} ${path.basename(selectedDirectory!.path)}',
            overflow: TextOverflow.ellipsis, // Prevent long path overflow
          ),
        ),
        SizedBox(height: AppSizes.sizedBox),
        FilledButton.tonal(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.all(AppSizes.padding),
          ),
          // More explicit condition for onPressed
          onPressed: canStartProcessing ? onStartProcessing : null,
          child: const Text(AppStrings.startProcessing),
        ),
      ],
    );
  }
}
