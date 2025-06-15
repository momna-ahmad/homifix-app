import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'homeNavPage.dart';
import 'CustomerOrderPage.dart';
import 'splashScreen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Global plugin instance
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

// Android notification channel
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'This channel is used for important notifications.',
  importance: Importance.max,
);

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
}

Future<void> scheduleDailyReminder() async {
  //final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // Schedule for 2 minutes from now
  final now = tz.TZDateTime.now(tz.local);
  final scheduledDate = now.add(Duration(minutes: 2));

  await flutterLocalNotificationsPlugin.zonedSchedule(
    0, // Notification ID
    'Test Reminder', // Title
    'This is a test notification scheduled 2 minutes from now.', // Body
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
    uiLocalNotificationDateInterpretation:
    UILocalNotificationDateInterpretation.absoluteTime,
    matchDateTimeComponents: null, // 🔁 No repeat — one-time only
  );

  print("✅ Test reminder scheduled for ${scheduledDate.hour}:${scheduledDate.minute}");
}

Future<void> showLocalNotification(String title, String body) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
  AndroidNotificationDetails(
    'request_channel_id', // Channel ID
    'Request Notifications', // Channel name
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
  );

  const NotificationDetails platformChannelSpecifics =
  NotificationDetails(android: androidPlatformChannelSpecifics);

  await flutterLocalNotificationsPlugin.show(
    0,
    title,
    body,
    platformChannelSpecifics,
  );
}



void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone database
  tz.initializeTimeZones();

  // Optionally set local timezone to device time zone
  tz.initializeTimeZones();
  // Get device timezone and set local location for tz package
  tz.setLocalLocation(tz.getLocation('Asia/Karachi'));

  await dotenv.load(fileName: "assets/.env");
  MobileAds.instance.initialize();

  String? token;

  if (kIsWeb) {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: dotenv.env['API_KEY'] ?? '',
        authDomain: dotenv.env['AUTH_DOMAIN'] ?? '',
        projectId: dotenv.env['PROJECT_ID'] ?? '',
        storageBucket: dotenv.env['STORAGE_BUCKET'] ?? '',
        messagingSenderId: dotenv.env['MESSAGING_SENDER_ID'] ?? '',
        appId: dotenv.env['APP_ID'] ?? '',
        measurementId: dotenv.env['MEASUREMENT_ID'],
      ),
    );

  } else {
    await Firebase.initializeApp();

    // 🔔 Initialize local notifications
    const AndroidInitializationSettings androidInitSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initSettings =
    InitializationSettings(android: androidInitSettings);
    await flutterLocalNotificationsPlugin.initialize(initSettings);

    // 🔔 Create notification channel
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    FirebaseMessaging messaging = FirebaseMessaging.instance;

    token = await FirebaseMessaging.instance.getToken();
    print('FCM Token: $token');

  }

  NotificationSettings settings =
  await FirebaseMessaging.instance.requestPermission();
  print('User granted permission: ${settings.authorizationStatus}');

  if (token != null) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
    print('✅ FCM Token saved to SharedPreferences');
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
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
      home: SplashScreen(), // 💡 Always start at SplashScreen
    );
  }
}
