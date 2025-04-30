import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_sorter/core/sizes.dart';
import 'package:image_sorter/core/strings.dart';
import 'package:image_sorter/logic/cubit/sort_cubit.dart';
import 'package:image_sorter/presentation/widgets/action_buttons.dart';
import 'package:image_sorter/presentation/widgets/get_started_section.dart';
import 'package:image_sorter/presentation/widgets/how_it_works_section.dart';
import 'package:image_sorter/presentation/widgets/progress_indicator_section.dart';
import 'package:image_sorter/presentation/widgets/results_section.dart';

class MainScreenView extends StatelessWidget {
  const MainScreenView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SortCubit>().state;
    final cubit = context.read<SortCubit>();
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.only(
            top: AppSizes.appBarPadding,
            left: AppSizes.tinyPadding,
            right: AppSizes.tinyPadding,
          ),
          child: Text(
            AppStrings.appName,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: AppSizes.appTitle,
            ),
          ),
        ),
        toolbarHeight: screenHeight * 0.14,
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSizes.padding),
        child: SizedBox(
          height: screenHeight * 0.16,
          child: ActionButtons(
            selectedDirectory: state.selectedDirectory,
            isProcessing: state.isProcessing,
            onSelectFolder: cubit.selectFolder,
            onStartProcessing: () {
              final dir = state.selectedDirectory;
              if (dir == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(AppStrings.selectDirectory),
                    duration: Duration(seconds: 2),
                  ),
                );
              } else {
                cubit.startSortingProcess(selectedDirectory: dir);
              }
            },
          ),
        ),
      ),

      body: Padding(
        // Use const for EdgeInsets
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.padding),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const HowItWorksSection(),
              GetStartedSection(
                selectedDirectory: state.selectedDirectory,
                isProcessing: state.isProcessing,
                currentAction: state.currentAction,
              ),
              SizedBox(height: AppSizes.sizedBox),
              BlocBuilder<SortCubit, SortState>(
                builder: (context, state) {
                  if (state.isProcessing || state.currentAction.isNotEmpty) {
                    return Column(
                      children: [
                        ProgressIndicatorSection(
                          currentAction: state.currentAction,
                          processedFiles: state.processedFiles,
                          totalFiles: state.totalFiles,
                        ),
                        SizedBox(height: AppSizes.sizedBox),
                        ResultsSection(
                          sortedFiles: state.sortedFiles,
                          unsortedFiles: state.unsortedFiles,
                        ),
                      ],
                    );
                  } else {
                    // Use SizedBox.shrink() for empty content
                    return const SizedBox.shrink();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
