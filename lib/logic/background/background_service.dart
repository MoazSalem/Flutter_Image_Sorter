import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'background_logic.dart';

// Unique ids for notification
const notificationChannelId = 'image_sorter_foreground';
const notificationId = 453;
final service = FlutterBackgroundService();

Future<FlutterBackgroundService> initializeBackgroundService() async {
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    notificationChannelId, // id
    'IMAGE SORTER SERVICE', // title
    description:
        'This channel is used for image sorter updates.', // description
    importance: Importance.low, // importance must be at low or higher level
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart, // Function to run when service starts
      isForegroundMode: true,
      autoStart: true,
      notificationChannelId: notificationChannelId,
      initialNotificationTitle: 'Image Sorter',
      initialNotificationContent: 'Initializing',
      foregroundServiceNotificationId: notificationId,
    ),
    iosConfiguration: IosConfiguration(),
  );
  return service;
}
