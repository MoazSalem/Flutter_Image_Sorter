import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'background/background_service.dart';

void changeNotification({
  required String title,
  required String body,
  int? progress,
  required bool onGoing,
}) async {
  flutterLocalNotificationsPlugin.show(
    notificationId,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        progress: progress ?? 0,
        maxProgress: 100,
        showProgress: progress != null,
        onlyAlertOnce: true, // Don't alert for every update
        notificationChannelId,
        'IMAGE SORTER BACKGROUND SERVICE',
        icon: 'ic_bg_service_small',
        ongoing: onGoing,
      ),
    ),
  );
}
