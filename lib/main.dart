import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_sorter/core/strings.dart';
import 'package:image_sorter/presentation/main_screen.dart';
import 'core/theme.dart';
import 'logic/cubit/sort_cubit.dart';

void main() async {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: MediaQuery.of(context).platformBrightness,
        colorScheme:
            MediaQuery.of(context).platformBrightness == Brightness.dark
                ? AppTheme.darkColorScheme
                : AppTheme.lightColorScheme,
        useMaterial3: true,
        fontFamily: AppStrings.fontFamily,
      ),
      home: BlocProvider<SortCubit>(
        create: (BuildContext context) => SortCubit(),
        child: const MainScreenView(),
      ),
    );
  }
}
