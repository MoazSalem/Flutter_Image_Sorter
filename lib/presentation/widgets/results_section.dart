import 'package:flutter/material.dart';
import 'package:image_sorter/core/sizes.dart';
import 'package:image_sorter/core/strings.dart';

class ResultsSection extends StatelessWidget {
  final int sortedFiles;
  final int unsortedFiles;

  const ResultsSection({
    super.key,
    required this.sortedFiles,
    required this.unsortedFiles,
  });

  static const EdgeInsets _cardPadding = EdgeInsets.all(AppSizes.padding);

  @override
  Widget build(BuildContext context) {
    // Avoid building this section if both counts are zero
    if (sortedFiles <= 0 && unsortedFiles <= 0) {
      return const SizedBox.shrink();
    }
    final TextStyle resultStyle = DefaultTextStyle.of(
      context,
    ).style.copyWith(fontSize: AppSizes.fontSize2);

    return Card(
      child: Padding(
        padding: _cardPadding,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            RichText(
              text: TextSpan(
                style: resultStyle,
                children: [
                  TextSpan(
                    text: AppStrings.sorted,
                    style: resultStyle.copyWith(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: '$sortedFiles'),
                ],
              ),
            ),
            RichText(
              text: TextSpan(
                style: resultStyle,
                children: [
                  TextSpan(
                    text: AppStrings.unsorted,
                    style: resultStyle.copyWith(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: '$unsortedFiles'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
