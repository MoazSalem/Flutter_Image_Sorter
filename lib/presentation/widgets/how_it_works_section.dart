import 'package:flutter/material.dart';
import 'package:image_sorter/core/sizes.dart';
import 'package:image_sorter/core/strings.dart';

class HowItWorksSection extends StatelessWidget {
  const HowItWorksSection({super.key});

  // Define const TextStyles for reuse
  static const TextStyle _titleStyle = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: AppSizes.fontSize1,
  );
  static const EdgeInsets _tilePadding = EdgeInsets.symmetric(
    vertical: AppSizes.tinyPadding,
    horizontal: AppSizes.largePadding,
  );
  static const EdgeInsets _childrenPadding = EdgeInsets.only(
    left: AppSizes.largePadding,
    right: AppSizes.largePadding,
    bottom: AppSizes.largePadding,
  );

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(AppStrings.howItWorks, style: _titleStyle),
        dense: true,
        tilePadding: _tilePadding,
        childrenPadding: _childrenPadding,
        visualDensity: VisualDensity.compact,
        shape: Border(),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(AppSizes.tinyPadding),
            child: Text(AppStrings.firstStep),
          ),
          Padding(
            padding: EdgeInsets.all(AppSizes.tinyPadding),
            child: Text(AppStrings.secondStep),
          ),
          Padding(
            padding: EdgeInsets.all(AppSizes.tinyPadding),
            child: Text(AppStrings.thirdStep),
          ),
        ],
      ),
    );
  }
}
