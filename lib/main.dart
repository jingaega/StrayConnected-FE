import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:strayconnected/firebase_options.dart';
import 'package:strayconnected/services/push_notifications.dart';
import 'package:strayconnected/strayconnected.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase for FCM chat notifications
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Hardcoded Supabase keys (use only for local dev)
  await Supabase.initialize(
    url: 'ISI SENDIRI',
    anonKey:
        'ISI SENDIRI',
  );

  await PushNotifications.initialize();
  await PushNotifications.startRealtimeListener();

  runApp(const StrayConnectedApp());
}

final supabase = Supabase.instance.client;
