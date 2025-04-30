import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_sorter/core/sizes.dart';
import 'package:image_sorter/core/strings.dart';

class GetStartedSection extends StatelessWidget {
  final Directory? selectedDirectory;
  final bool isProcessing;
  final String currentAction;
  const GetStartedSection({
    super.key,
    required this.selectedDirectory,
    required this.isProcessing,
    required this.currentAction,
  });

  static const EdgeInsets _cardPadding = EdgeInsets.all(AppSizes.padding);
  static const TextStyle _titleStyle = TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 14,
  );

  @override
  Widget build(BuildContext context) {
    if (selectedDirectory != null && isProcessing || currentAction.isNotEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: _cardPadding,
        child: Center(
          child: Text(
            selectedDirectory == null
                ? AppStrings.getStarted1
                : AppStrings.getStarted2,
            style: _titleStyle,
          ),
        ),
      ),
    );
  }
}
