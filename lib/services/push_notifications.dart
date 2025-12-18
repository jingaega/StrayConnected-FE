import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel _chatChannel = AndroidNotificationChannel(
  'chat_messages',
  'Chat Messages',
  description: 'Notifications for incoming chat messages.',
  importance: Importance.max,
);

class PushNotifications {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    await _initLocal();
    await _initMessaging();
    _initialized = true;
  }

  static Future<void> _initLocal() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOS = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: android, iOS: iOS),
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_chatChannel);
  }

  static Future<void> _initMessaging() async {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    FirebaseMessaging.onMessage.listen(showNotification);
  }

  static Future<void> showNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? 'New message';
    final body =
        notification?.body ?? message.data['body'] ?? 'You have a new message';

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _chatChannel.id,
        _chatChannel.name,
        channelDescription: _chatChannel.description,
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      notification.hashCode,
      title,
      body,
      details,
      payload: message.data['payload'] as String?,
    );
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await PushNotifications.initialize();
  await PushNotifications.showNotification(message);
}
