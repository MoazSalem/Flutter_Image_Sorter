import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_sorter/logic/cubit/sort_cubit.dart';
import 'package:path/path.dart' as path;

class MainScreenView extends StatefulWidget {
  const MainScreenView({super.key});

  @override
  State<MainScreenView> createState() => _PhotoSorterHomeState();
}

class _PhotoSorterHomeState extends State<MainScreenView> {
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SortCubit>();
    final isProcessing = context.select<SortCubit, bool>(
      (cubit) => cubit.state.isProcessing,
    );
    final selectedDirectory = context.select<SortCubit, Directory?>(
      (cubit) => cubit.state.selectedDirectory,
    );
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
                  initiallyExpanded: true,
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
                    Text(
                      '1.You Select a folder containing images and start Processing.',
                    ),
                    Text(
                      '2. Get Images timestamp from file name or files stats and sort them in order of oldest to newest.',
                    ),
                    Text('3. Set files dates to the oldest timestamp found.'),
                    Text(
                      '4. Images with no timestamp will be moved to unsorted folder.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      isProcessing
                          ? null
                          : context.read<SortCubit>().selectFolder,
                  child: Text(
                    selectedDirectory == null
                        ? 'Select Image Folder'
                        : 'Selected: ${path.basename(selectedDirectory.path)}',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed:
                      selectedDirectory == null
                          ? () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please select a directory'),
                            ),
                          )
                          : isProcessing
                          ? null
                          : () => BlocProvider.of<SortCubit>(
                            context,
                          ).startSortingProcess(
                            selectedDirectory: selectedDirectory,
                          ),
                  child: const Text('Start Processing'),
                ),
              ),
              const SizedBox(height: 20),
              BlocBuilder<SortCubit, SortState>(
                builder: (context, state) {
                  if (isProcessing || cubit.state.currentAction.isNotEmpty) {
                    return Column(
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Center(
                                  child: Text(
                                    cubit.state.currentAction,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (cubit.state.totalFiles > 0)
                                  Column(
                                    children: [
                                      const SizedBox(height: 10),
                                      LinearProgressIndicator(
                                        value:
                                            cubit.state.totalFiles > 0
                                                ? cubit.state.processedFiles /
                                                    cubit.state.totalFiles
                                                : 0,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        '${cubit.state.processedFiles} / ${cubit.state.totalFiles} files',
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (cubit.state.sortedFiles > 0 ||
                            cubit.state.unsortedFiles > 0)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  Text('Sorted: ${cubit.state.sortedFiles}'),
                                  Text(
                                    'Unsorted: ${cubit.state.unsortedFiles}',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),
                      ],
                    );
                  } else {
                    return Container();
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
