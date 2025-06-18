import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'homeNavPage.dart';
import 'CustomerOrderPage.dart';
import 'splashScreen.dart';

// Global plugin instance
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

// Android notification channel
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'This channel is used for important notifications.',
  importance: Importance.max,
);

// FCM Background handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
}

// Daily Reminder (one-time, 2 minutes from now)
Future<void> scheduleDailyReminder() async {
  final now = tz.TZDateTime.now(tz.local);
  final scheduledDate = now.add(Duration(minutes: 2));

  await flutterLocalNotificationsPlugin.zonedSchedule(
    0,
    'Test Reminder',
    'This is a test notification scheduled 2 minutes from now.',
    scheduledDate,
    NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    ),
    androidAllowWhileIdle: true,
    uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    matchDateTimeComponents: null,
  );

  print("✅ Test reminder scheduled for ${scheduledDate.hour}:${scheduledDate.minute}");
}

// Instant Local Notification
Future<void> showLocalNotification(String title, String body) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'request_channel_id',
    'Request Notifications',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
  );

  const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
    0,
    title,
    body,
    platformDetails,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env file
  await dotenv.load(fileName: "assets/.env");

  // Initialize Mobile Ads
  MobileAds.instance.initialize();

  // Initialize timezone
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Karachi'));

  // Firebase Initialization
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: dotenv.env['API_KEY'] ?? '',
        authDomain: dotenv.env['AUTH_DOMAIN'] ?? '',
        projectId: dotenv.env['PROJECT_ID'] ?? '',
        storageBucket: dotenv.env['STORAGE_BUCKET'] ?? '',
        messagingSenderId: dotenv.env['MESSAGING_SENDER_ID'] ?? '',
        appId: dotenv.env['APP_ID'] ?? '',
        measurementId: dotenv.env['MEASUREMENT_ID'] ?? '',
      ),
    );
  } else {
    await Firebase.initializeApp();

    // Initialize local notifications
    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initSettings = InitializationSettings(android: androidInit);
    await flutterLocalNotificationsPlugin.initialize(initSettings);

    // Create notification channel
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Firebase Messaging setup
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    String? token = await messaging.getToken();
    print('📲 FCM Token: $token');

    if (token != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
      print('✅ Token saved in SharedPreferences');
    }

    NotificationSettings settings = await messaging.requestPermission();
    print('🔔 Notification permission: ${settings.authorizationStatus}');

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // Schedule test reminder
  await scheduleDailyReminder();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Home Services App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: SplashScreen(),
    );
  }
}
