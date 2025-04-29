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
              BlocSelector<SortCubit, SortState, bool>(
                selector: (state) {
                  return state.metadataSearching;
                },
                builder: (context, state) {
                  return Card(
                    child: CheckboxListTile(
                      value: state,
                      onChanged: (v) => cubit.setMetadata(!state),
                      title: Text(
                        "Metadata Searching",
                        style: TextStyle(fontSize: 16),
                      ),
                      subtitle: Text(
                        "It's much slower, Most likely would only affect photos taken by camera, Although It's very accurate, but with milliseconds difference to normal sorting method, use if images has no date in name and taken by professional camera, used by default for photos that start with DSC_",
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: BlocSelector<SortCubit, SortState, Directory?>(
                  selector: (state) {
                    return state.selectedDirectory;
                  },
                  builder: (context, selectedDirectory) {
                    return FilledButton(
                      onPressed:
                          isProcessing
                              ? null
                              : context.read<SortCubit>().selectFolder,
                      child: Text(
                        selectedDirectory == null
                            ? 'Select Image Folder'
                            : 'Selected: ${path.basename(selectedDirectory.path)}',
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed:
                      () =>
                          cubit.state.selectedDirectory == null
                              ? ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please select a directory'),
                                ),
                              )
                              : isProcessing
                              ? null
                              : BlocProvider.of<SortCubit>(
                                context,
                              ).startSortProcess(
                                selectedDirectory:
                                    cubit.state.selectedDirectory!.path,
                                metadataSearching:
                                    cubit.state.metadataSearching,
                              ),
                  child: const Text('Start Processing'),
                ),
              ),
              const SizedBox(height: 20),
              if (isProcessing || cubit.state.currentAction.isNotEmpty)
                BlocBuilder<SortCubit, SortState>(
                  buildWhen: (previous, current) => isProcessing,
                  builder: (context, state) {
                    return Column(
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Text(
                                  cubit.state.currentAction,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
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
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
