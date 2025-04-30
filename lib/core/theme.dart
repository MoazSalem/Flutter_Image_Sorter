import 'package:flutter/material.dart';

class AppTheme {
  static final darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Colors.white,
    onPrimary: Colors.black,
    secondary: Colors.white12,
    onSecondary: Colors.white,
    error: Colors.red,
    onError: Colors.black,
    surface: Colors.black,
    onSurface: Colors.white,
    surfaceContainerLow: Colors.white12,
  );

  static final lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Colors.black,
    onPrimary: Colors.white,
    secondary: Colors.grey.shade200,
    onSecondary: Colors.black,
    error: Colors.red,
    onError: Colors.white,
    surface: Colors.white,
    onSurface: Colors.black,
    surfaceContainerLow: Colors.grey.shade200,
  );
}
