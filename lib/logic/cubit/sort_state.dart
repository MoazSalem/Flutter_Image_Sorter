part of 'sort_cubit.dart';

class SortState extends Equatable {
  final Directory? selectedDirectory;
  final bool isProcessing;
  final int totalFiles;
  final int processedFiles;
  final int sortedFiles;
  final int unsortedFiles;
  final String currentAction;
  const SortState({
    required this.selectedDirectory,
    required this.isProcessing,
    required this.totalFiles,
    required this.processedFiles,
    required this.sortedFiles,
    required this.unsortedFiles,
    required this.currentAction,
  });

  SortState copyWith({
    Directory? selectedDirectory,
    bool? isProcessing,
    int? totalFiles,
    int? processedFiles,
    int? sortedFiles,
    int? unsortedFiles,
    String? currentAction,
  }) {
    return SortState(
      selectedDirectory: selectedDirectory ?? this.selectedDirectory,
      isProcessing: isProcessing ?? this.isProcessing,
      totalFiles: totalFiles ?? this.totalFiles,
      processedFiles: processedFiles ?? this.processedFiles,
      sortedFiles: sortedFiles ?? this.sortedFiles,
      unsortedFiles: unsortedFiles ?? this.unsortedFiles,
      currentAction: currentAction ?? this.currentAction,
    );
  }

  @override
  List<Object?> get props => [
    selectedDirectory,
    isProcessing,
    totalFiles,
    processedFiles,
    sortedFiles,
    unsortedFiles,
    currentAction,
  ];
}
