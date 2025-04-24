import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

// --- Configuration ---

typedef _PatternParser =
    DateTime? Function(
      String candidate, {
      String? preferredLocale,
      int? minYear,
      int? maxYear,
    });

// Define parsers and their priorities (lower number = higher priority)
// Note: Adjusted priorities based on commonality and specificity
final List<(int priority, _PatternParser parser)> _patternParsers = [
  (10, _parseIso8601), // Most specific standard
  (20, _parseYyyyMmDdHhMmSsCompact), // Common compact format
  (30, _parseYyyyMmDdHhMmSsSeparated), // Common separated format
  (
    40,
    _parseYyyyMmDdWithSeparators,
  ), // Common date format with optional time/ms
  (50, _parseYyyyMmDdCompact), // Common compact date
  (60, _parseMonthNameDate), // Handles various textual month formats
  (70, _parseUnixTimestamp), // Less common in filenames, higher ambiguity risk
];

// Default year range (can be overridden in the main function)
const int _defaultMinYearDelta = 100;
const int _defaultMaxYearDelta = 10; // Reduced default future range

// --- Main Extraction Function ---

/// Extracts the most likely DateTime from a filename by identifying candidate
/// strings and attempting prioritized parsing methods.
///
/// Args:
///   filename: The input filename string.
///   preferredLocale: Locale hint for parsing month names (e.g., 'en_US', 'de_DE').
///   minYear: The minimum acceptable year (inclusive). Defaults to current year - 100.
///   maxYear: The maximum acceptable year (inclusive). Defaults to current year + 10.
///
/// Returns the highest-priority valid DateTime found, or null.
DateTime? extractTimestampFromFilename(
  String filename, {
  String? preferredLocale,
  int? minYear,
  int? maxYear,
}) {
  final candidates = _extractCandidateTimestamps(filename);
  if (candidates.isEmpty) {
    return null;
  }

  final List<(int priority, DateTime dateTime)> successfulParses = [];

  // Sort parsers by priority
  _patternParsers.sort((a, b) => a.$1.compareTo(b.$1));

  for (final candidate in candidates) {
    for (final parserTuple in _patternParsers) {
      final parser = parserTuple.$2;
      final priority = parserTuple.$1;

      final DateTime? result = parser(
        candidate,
        preferredLocale: preferredLocale,
        minYear: minYear,
        maxYear: maxYear,
      );

      if (result != null) {
        successfulParses.add((priority, result));
        // Optimization: Once a candidate is successfully parsed by *a* parser,
        // we could potentially break the inner loop if we only want the
        // highest priority parse *for that candidate*. However, another
        // candidate might yield a higher priority parse overall.
        // Let's find all valid parses and sort at the end.
      }
    }
  }

  if (successfulParses.isEmpty) {
    return null;
  }

  // Sort successful parses by priority (lowest number first)
  successfulParses.sort((a, b) => a.$1.compareTo(b.$1));

  // Return the DateTime from the highest priority parse
  return successfulParses.first.$2;
}

// --- Candidate Extraction ---

/// Finds potential timestamp strings within a filename using broad regex patterns.
List<String> _extractCandidateTimestamps(String filename) {
  // Keep regexes broad here; validation happens in the parsers.
  final regexes = [
    // ISO 8601-like structures (Date mandatory, Time/Offset optional)
    RegExp(
      r'(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})?)',
    ),
    // YYYYMMDDHHMMSS (compact or with common separators) - Added T, allow optional ms
    RegExp(
      r'(\d{4}[\-_.]?\d{2}[\-_.]?\d{2}[\-_ T]?\d{2}[\-_.:]?\d{2}[\-_.:]?\d{2}(?:[.,]\d{1,3})?)',
    ),
    // YYYYMMDD (compact or with common separators)
    RegExp(r'(\d{4}[\-_./]?\d{2}[\-_./]?\d{2})'),
    // Date with Month Name (various orders) - Simplified, relies on parser validation
    RegExp(
      r'(\d{1,2}[-./\s]+[a-zA-Z]{3,9}[-./\s]+\d{4}|\d{4}[-./\s]+[a-zA-Z]{3,9}[-./\s]+\d{1,2}|[a-zA-Z]{3,9}[-./\s]+\d{1,2}[,.\s]+[-./\s]?\d{4})',
      caseSensitive: false,
    ),
    // Unix timestamps (seconds or milliseconds) - Use lookarounds
    RegExp(r'(?<!\d)(\d{10}|(?:\d{13}))(?!\d)'),
  ];

  final results = <String>{}; // Use a Set to store unique candidates
  for (final regex in regexes) {
    for (final match in regex.allMatches(filename)) {
      if (match.groupCount > 0 && match.group(1) != null) {
        // Extract the primary capture group if it exists
        results.add(match.group(1)!);
      } else if (match.group(0) != null) {
        // Otherwise, take the whole match (e.g., for month names)
        results.add(match.group(0)!);
      }
    }
  }
  // Consider adding the full filename as a candidate for month parsing?
  // results.add(filename);
  return results.toList();
}

// --- Individual Parser Implementations ---

// Helper for year validation
bool _yearInRange(int year, int? minYear, int? maxYear) {
  final currentYear = DateTime.now().year; // Use current year for defaults
  final effectiveMin = minYear ?? (currentYear - _defaultMinYearDelta);
  final effectiveMax = maxYear ?? (currentYear + _defaultMaxYearDelta);
  return year >= effectiveMin && year <= effectiveMax;
}

DateTime? _parseIso8601(
  String candidate, {
  String? preferredLocale,
  int? minYear,
  int? maxYear,
}) {
  try {
    // DateTime.parse handles ISO 8601 including Z/offsets correctly
    final dt = DateTime.parse(candidate);
    // Convert to local time if necessary for consistent comparison, though year check is often enough
    final dtLocal = dt.toLocal();
    if (_yearInRange(dtLocal.year, minYear, maxYear)) {
      return dtLocal; // Return consistent local time
    }
  } catch (_) {
    // Ignore parsing errors
  }
  return null;
}

DateTime? _parseUnixTimestamp(
  String candidate, {
  String? preferredLocale,
  int? minYear,
  int? maxYear,
}) {
  final unix = int.tryParse(candidate);
  if (unix == null) return null;

  DateTime? dt;
  const minReasonableMillis = 0; // Corresponds to 1970-01-01 UTC
  const maxReasonableMillis = 4102444800000; // Corresponds to 2100-01-01 UTC
  const minReasonableSecs = minReasonableMillis ~/ 1000;
  const maxReasonableSecs = maxReasonableMillis ~/ 1000;

  // Check if it looks like milliseconds (13 digits, or 11-12 digits > Sep 2001)
  if (candidate.length == 13 &&
      unix >= minReasonableMillis &&
      unix <= maxReasonableMillis) {
    dt = DateTime.fromMillisecondsSinceEpoch(
      unix,
      isUtc: false,
    ); // Assume local if not ISO
  }
  // Check if it looks like seconds (10 digits)
  else if (candidate.length == 10 &&
      unix >= minReasonableSecs &&
      unix <= maxReasonableSecs) {
    dt = DateTime.fromMillisecondsSinceEpoch(
      unix * 1000,
      isUtc: false,
    ); // Assume local
  }

  if (dt != null && _yearInRange(dt.year, minYear, maxYear)) {
    return dt;
  }
  return null;
}

DateTime? _parseYyyyMmDdHhMmSsCompact(
  String candidate, {
  String? preferredLocale,
  int? minYear,
  int? maxYear,
}) {
  // YYYYMMDDHHMMSS or YYYYMMDDTHHMMSS
  final match = RegExp(
    r'^(\d{4})(\d{2})(\d{2})T?(\d{2})(\d{2})(\d{2})(?:[.,](\d{1,3}))?\$',
  ).firstMatch(candidate);
  if (match != null) {
    try {
      final dt = DateTime(
        int.parse(match[1]!),
        int.parse(match[2]!),
        int.parse(match[3]!), // Date
        int.parse(match[4]!),
        int.parse(match[5]!),
        int.parse(match[6]!), // Time
        match[7] != null
            ? int.parse(match[7]!.padRight(3, '0'))
            : 0, // Optional MS
      );
      if (_yearInRange(dt.year, minYear, maxYear)) return dt;
    } catch (_) {}
  }
  return null;
}

DateTime? _parseYyyyMmDdHhMmSsSeparated(
  String candidate, {
  String? preferredLocale,
  int? minYear,
  int? maxYear,
}) {
  // YYYY-MM-DD_HH:MM:SS or similar, allows T separator, allows ms
  final match = RegExp(
    r'^(\d{4})([\-_./])(\d{2})\2(\d{2})' // YYYY<sep>MM<sep>DD
    r'[\-_ T]' // Separator between date and time
    r'(\d{2})([\-_.:])(\d{2})\6(\d{2})' // HH<sep>MM<sep>SS
    r'(?:[.,](\d{1,3}))?' // Optional milliseconds
    r'\$',
  ).firstMatch(candidate);

  if (match != null) {
    try {
      final dt = DateTime(
        int.parse(match[1]!), // Year
        int.parse(match[3]!), // Month
        int.parse(match[4]!), // Day
        int.parse(match[5]!), // Hour
        int.parse(match[7]!), // Minute
        int.parse(match[8]!), // Second
        match[9] != null
            ? int.parse(match[9]!.padRight(3, '0'))
            : 0, // Optional MS
      );
      if (_yearInRange(dt.year, minYear, maxYear)) return dt;
    } catch (_) {}
  }
  return null;
}

DateTime? _parseYyyyMmDdWithSeparators(
  String candidate, {
  String? preferredLocale,
  int? minYear,
  int? maxYear,
}) {
  // YYYY-MM-DD optionally followed by T HH:MM:SS.fff (flexible separators)
  final match = RegExp(
    r'^(\d{4})([-./])(\d{2})\2(\d{2})' // YYYY<sep>MM<sep>DD
    r'(?:' // Optional time part
    r'[ T\-_]' // Separator date/time
    r'(\d{1,2})([:.\-])(\d{2})(?:\6(\d{2}))?' // HH<sep>MM (<sep>SS optional)
    r'(?:[.,](\d{1,3}))?' // Optional MS
    r')?' // End optional time part
    r'\$',
  ).firstMatch(candidate);

  if (match != null) {
    try {
      final dt = DateTime(
        int.parse(match[1]!), // Year
        int.parse(match[3]!), // Month
        int.parse(match[4]!), // Day
        int.parse(match[5] ?? '0'), // Hour (default 0)
        int.parse(match[7] ?? '0'), // Minute (default 0)
        int.parse(match[8] ?? '0'), // Second (default 0)
        match[9] != null
            ? int.parse(match[9]!.padRight(3, '0'))
            : 0, // MS (default 0)
      );
      if (_yearInRange(dt.year, minYear, maxYear)) return dt;
    } catch (_) {}
  }
  return null;
}

DateTime? _parseYyyyMmDdCompact(
  String candidate, {
  String? preferredLocale,
  int? minYear,
  int? maxYear,
}) {
  // YYYYMMDD
  final match = RegExp(r'^(\d{4})(\d{2})(\d{2})\$').firstMatch(candidate);
  if (match != null) {
    try {
      final dt = DateTime(
        int.parse(match[1]!),
        int.parse(match[2]!),
        int.parse(match[3]!),
      );
      if (_yearInRange(dt.year, minYear, maxYear)) return dt;
    } catch (_) {}
  }
  return null;
}

DateTime? _parseMonthNameDate(
  String candidate, {
  String? preferredLocale,
  int? minYear,
  int? maxYear,
}) {
  // Add more formats as needed, including time components
  final formats = [
    // Common Date Formats
    'd MMM yyyy', 'd MMMM yyyy',
    'MMM d, yyyy', 'MMMM d, yyyy',
    'yyyy MMM d', 'yyyy MMMM d',
    'yyyy-MMM-d', 'yyyy-MMMM-d',
    'd-MMM-yyyy', 'd-MMMM-yyyy',
    // Common Date + Time Formats
    'd MMM yyyy HH:mm:ss', 'd MMMM yyyy HH:mm:ss',
    'MMM d, yyyy HH:mm:ss', 'MMMM d, yyyy HH:mm:ss',
    'yyyy MMM d HH:mm:ss', 'yyyy MMMM d HH:mm:ss',
    'd MMM yyyy hh:mm:ss a', // With AM/PM
    'MMM d, yyyy hh:mm:ss a',
    'yyyy-MM-dd HH:mm:ss', // Sometimes month names fail, try numeric fallback within this parser? Risky.
  ];

  // Normalize candidate slightly for better matching with some formats
  final normalizedCandidate =
      candidate
          .replaceAllMapped(
            RegExp(r'(\d)(st|nd|rd|th)'),
            (m) => m.group(1)!,
          ) // Remove st, nd, rd, th
          .trim();

  for (final format in formats) {
    try {
      // Use parseStrict to avoid overly lenient matching
      final dateFormat = intl.DateFormat(format, preferredLocale);
      final dt = dateFormat.parseStrict(normalizedCandidate);
      if (_yearInRange(dt.year, minYear, maxYear)) {
        return dt;
      }
    } catch (_) {
      // Ignore format mismatch errors and try the next format
    }
  }
  return null; // No format matched
}
