import 'package:flutter_local_notifications/flutter_local_notifications.dart';

late final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

Future<void> initializeNotificationService() async {
  flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}
