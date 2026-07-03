import 'logger.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart';

const String dailyQuoteTopic = 'daily-quote';
const String announcementsTopic = 'announcements';

final FirebaseMessaging messaging = FirebaseMessaging.instance;

Future<void> initializeNotifications() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final settings = await messaging.requestPermission();
  log.info("Notification permission: ${settings.authorizationStatus}");

  // Show pushes as banners even while the app is open (iOS).
  await messaging.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  // Everyone gets announcements; the daily quote is opt-in via the checkbox.
  await messaging.subscribeToTopic(announcementsTopic);

  await _cancelLegacyLocalNotifications();
}

// Older app versions pre-scheduled up to 50 days of local notifications on
// this device; clear any still pending so users don't get those on top of
// the new pushes.
Future<void> _cancelLegacyLocalNotifications() async {
  try {
    final notifier = FlutterLocalNotificationsPlugin();
    await notifier.initialize(
      const InitializationSettings(
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    await notifier.cancelAll();
    log.info("Cancelled legacy scheduled local notifications");
  } catch (e) {
    log.warning("Failed to cancel legacy local notifications: $e");
  }
}

Future<void> subscribeToDailyQuote() async {
  await messaging.subscribeToTopic(dailyQuoteTopic);
  log.info("Subscribed to daily quote notifications");
}

Future<void> unsubscribeFromDailyQuote() async {
  await messaging.unsubscribeFromTopic(dailyQuoteTopic);
  log.info("Unsubscribed from daily quote notifications");
}
