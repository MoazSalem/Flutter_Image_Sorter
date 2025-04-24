import 'dart:io';

import 'package:flutter/material.dart';

// Finds the oldest timestamp among modification, access, change, and potentially
Future<DateTime?> findOldestFileTimestamp(File file) async {
  try {
    final FileStat stats = await file.stat();

    // Collect all available timestamps into a list
    final List<DateTime> timestamps = [];

    timestamps.add(stats.modified);
    timestamps.add(stats.accessed);
    timestamps.add(stats.changed);

    if (timestamps.isEmpty) {
      debugPrint("Warning: No valid timestamps retrieved for ${file.path}");
      return null;
    }
    DateTime oldest = timestamps[0];
    for (int i = 1; i < timestamps.length; i++) {
      if (timestamps[i].isBefore(oldest)) {
        oldest = timestamps[i];
      }
    }
    debugPrint("Oldest timestamp for ${file.path}: $oldest");
    return oldest;
  } catch (e) {
    // Catch any other unexpected errors
    debugPrint("Unexpected error getting stats for ${file.path}: $e");
    return null;
  }
}
