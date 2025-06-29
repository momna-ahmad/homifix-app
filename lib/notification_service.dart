import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:flutter/material.dart';

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // Android notification channel
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'badge_channel',
    'Badge Notifications',
    description: 'Notifications for badge assignments and updates',
    importance: Importance.high,
  );

  // Initialize notification service (CLIENT-SIDE ONLY)
  static Future<void> initialize() async {
    print('🔔 Initializing NotificationService...');

    // Request permission for iOS and Android
    await _requestPermission();

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Create notification channel for Android
    await _createNotificationChannel();

    // Get and save FCM token
    await _getFCMToken();

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Handle notification when app is terminated
    _firebaseMessaging.getInitialMessage().then((message) {
      if (message != null) {
        _handleNotificationTap(message);
      }
    });

    print('✅ NotificationService initialized successfully');
  }

  // Request notification permissions
  static Future<void> _requestPermission() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    print('🔔 Notification permission status: ${settings.authorizationStatus}');
  }

  // Create notification channel for Android
  static Future<void> _createNotificationChannel() async {
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  // Initialize local notifications
  static Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
  }

  // Get FCM token and save to Firestore and SharedPreferences
  static Future<void> _getFCMToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        print('📱 FCM Token: $token');

        // Save to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', token);

        // Save to Firestore if user is logged in
        await _saveFCMTokenToFirestore(token);
      }
    } catch (e) {
      print('❌ Error getting FCM token: $e');
    }
  }

  // Save FCM token to user document in Firestore
  static Future<void> _saveFCMTokenToFirestore(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        print('✅ FCM token saved to Firestore for user: ${user.uid}');
      } else {
        print('⚠️ No user logged in, FCM token not saved to Firestore');
      }
    } catch (e) {
      print('❌ Error saving FCM token to Firestore: $e');
    }
  }

  // Handle foreground messages
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📱 Foreground message received: ${message.messageId}');
    print('📱 Title: ${message.notification?.title}');
    print('📱 Body: ${message.notification?.body}');
    print('📱 Data: ${message.data}');

    // Show local notification when app is in foreground
    await _showLocalNotification(message);
  }

  // Show local notification
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF22D3EE),
      playSound: true,
      enableVibration: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'New Notification',
      message.notification?.body ?? 'You have a new notification',
      notificationDetails,
      payload: message.data.toString(),
    );

    print('✅ Local notification shown');
  }

  // Handle notification tap when app is in background
  static void _handleNotificationTap(RemoteMessage message) {
    print('🔔 Notification tapped: ${message.data}');

    // Handle navigation based on notification data
    if (message.data.containsKey('type')) {
      String notificationType = message.data['type'];

      switch (notificationType) {
        case 'badge_assigned':
          print('Navigate to badge section');
          // Add navigation logic here
          break;
        case 'warning':
          print('Navigate to warnings section');
          // Add navigation logic here
          break;
        case 'order_update':
          print('Navigate to orders section');
          // Add navigation logic here
          break;
        default:
          print('Unknown notification type: $notificationType');
      }
    }
  }

  // Handle local notification tap
  static void _onNotificationTap(NotificationResponse response) {
    print('🔔 Local notification tapped: ${response.payload}');
    // Handle local notification tap
  }

  // Refresh FCM token (call this when user logs in)
  static Future<void> refreshFCMToken() async {
    print('🔄 Refreshing FCM token...');
    await _getFCMToken();
  }

  // Update FCM token for specific user
  static Future<void> updateFCMTokenForUser(String userId) async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        print('✅ FCM token updated for user: $userId');
      }
    } catch (e) {
      print('❌ Error updating FCM token for user: $e');
    }
  }

  // Show instant local notification (for testing)
  static Future<void> showInstantNotification(String title, String body) async {
    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF22D3EE),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      notificationDetails,
    );
  }
}
