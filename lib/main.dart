import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_sorter/presentation/main_screen.dart';
import 'logic/background/background_service.dart';
import 'logic/cubit/sort_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeBackgroundService();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Sorter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: MediaQuery.of(context).platformBrightness,
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: BlocProvider<SortCubit>(
        create: (BuildContext context) => SortCubit(),
        child: const MainScreenView(),
      ),
    );
  }
}
