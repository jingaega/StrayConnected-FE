import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  static bool _enabled = true;
  static StreamSubscription<RemoteMessage>? _onMessageSub;
  static const _prefKeyEnabled = 'notifications_enabled';

  static Future<void> initialize() async {
    if (_initialized) return;
    await _initLocal();
    await _restorePreference();
    if (_enabled) {
      await _initMessaging();
    }
    _initialized = true;
  }

  static Future<void> _restorePreference() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_prefKeyEnabled) ?? true;
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
    final perms =
        await messaging.requestPermission(alert: true, badge: true, sound: true);
    if (perms.authorizationStatus == AuthorizationStatus.denied ||
        perms.authorizationStatus == AuthorizationStatus.notDetermined) {
      await setEnabled(false);
      return;
    }
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    await _saveDeviceToken();
    _onMessageSub?.cancel();
    _onMessageSub = FirebaseMessaging.onMessage.listen(showNotification);
  }

  static Future<void> showNotification(RemoteMessage message) async {
    final notification = message.notification;
    final senderRaw = message.data['sender_name'] ?? message.data['sender'] ?? '';
    final sender = senderRaw.toString().trim();
    final messageBody =
        notification?.body ?? message.data['body'] ?? 'You have a new message';
    final title = sender.isNotEmpty ? 'New message from $sender' : 'New chat message';
    final body =
        sender.isNotEmpty && messageBody == 'You have a new message'
            ? 'Message from $sender'
            : messageBody;

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

  static Future<void> showLocalMessage({
    required String title,
    required String body,
  }) async {
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
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
    );
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKeyEnabled) ?? true;
  }

  static Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyEnabled, enabled);
    if (enabled) {
      await _initMessaging();
    } else {
      // Stop listening and revoke the token so no pushes arrive.
      _onMessageSub?.cancel();
      _onMessageSub = null;
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );
      await FirebaseMessaging.instance.deleteToken();
      await _localNotifications.cancelAll();
    }
  }

  /// Store the current device's FCM token in Supabase user profile.
  static Future<void> _saveDeviceToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    await Supabase.instance.client.from('user').update({
      'device_token': token,
      'device_token_updated_at': DateTime.now().toIso8601String(),
    }).eq('id', user.id);
  }

  /// Exposed helper to manually refresh and upload the device token.
  static Future<void> saveDeviceToken() => _saveDeviceToken();

  /// Listen to Supabase realtime for new messages for the current user and
  /// surface a local notification while the app is in the foreground/background.
  /// This keeps a lightweight listener similar to WhatsApp/Telegram behavior
  /// while the app is running. Fully background pushes still require server-side
  /// FCM triggers.
  static RealtimeChannel? _messageChannel;
  static String? _listeningForUser;

  static Future<void> startRealtimeListener() async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null || !_enabled) return;
    if (_listeningForUser == uid && _messageChannel != null) return;

    await _messageChannel?.unsubscribe();
    _listeningForUser = uid;
    _messageChannel = client
        .channel('public:inquiry')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'inquiry',
        callback: (payload) async {
          // Debug log of new inquiry row.
          // ignore: avoid_print
          print('NEW MESSAGE: $payload');

          final newRecord = payload.newRecord;
          final receiver = newRecord['receiver_id'] as String?;
          final sender = newRecord['sender_id'] as String?;
          if (receiver != uid || sender == uid) return; // Only incoming
          final text = (newRecord['message'] as String?) ?? 'New message';

          // Try to resolve sender name for local notification title
          String senderName = (newRecord['sender_name'] as String?) ??
              (newRecord['sender'] as String?) ??
              '';
          if (senderName.isEmpty && sender != null) {
            try {
              final profile = await client
                  .from('user')
                  .select('name')
                  .eq('id', sender)
                  .maybeSingle() as Map<String, dynamic>?;
              senderName = (profile?['name'] as String?) ?? '';
            } catch (_) {
              senderName = '';
            }
          }

          final title = senderName.isNotEmpty
              ? 'New chat from: $senderName'
              : 'New chat message';
          showLocalMessage(title: title, body: text);
        },
      )
      ..subscribe();
  }

  static Future<void> stopRealtimeListener() async {
    await _messageChannel?.unsubscribe();
    _messageChannel = null;
    _listeningForUser = null;
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await PushNotifications.initialize();
  await PushNotifications.showNotification(message);
}
