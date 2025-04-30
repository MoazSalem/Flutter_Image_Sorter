import 'package:flutter/material.dart';
import 'package:image_sorter/core/sizes.dart';
import 'package:image_sorter/core/strings.dart';

class ProgressIndicatorSection extends StatelessWidget {
  final String currentAction;
  final int processedFiles;
  final int totalFiles;

  const ProgressIndicatorSection({
    super.key,
    required this.currentAction,
    required this.processedFiles,
    required this.totalFiles,
  });

  static const TextStyle _actionStyle = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: AppSizes.fontSize1,
  );
  static const EdgeInsets _cardPadding = EdgeInsets.all(AppSizes.padding);

  @override
  Widget build(BuildContext context) {
    // Avoid building this section if there's no action text
    if (currentAction.isEmpty) return const SizedBox.shrink();

    final double progressValue =
        totalFiles > 0 ? processedFiles / totalFiles : 0;

    return Card(
      child: Padding(
        padding: _cardPadding,
        child: Column(
          children: [
            Center(child: Text(currentAction, style: _actionStyle)),
            // Only show progress bar and text if there are total files calculated
            if (totalFiles > 0) ...[
              SizedBox(height: AppSizes.sizedBox),
              LinearProgressIndicator(value: progressValue),
              SizedBox(height: AppSizes.sizedBox),
              Text('$processedFiles / $totalFiles ${AppStrings.files}'),
            ],
          ],
        ),
      ),
    );
  }
}
