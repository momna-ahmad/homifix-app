import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'landingPage.dart';
import 'splashScreen.dart';
import 'login.dart';

void main() async {
  // Firebase setup
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: "assets/.env");

  if (kIsWeb) {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: dotenv.env['API_KEY']!,
        authDomain: dotenv.env['AUTH_DOMAIN']!,
        projectId: dotenv.env['PROJECT_ID']!,
        storageBucket: dotenv.env['STORAGE_BUCKET']!,
        messagingSenderId: dotenv.env['MESSAGING_SENDER_ID']!,
        appId: dotenv.env['APP_ID']!,
        measurementId: dotenv.env['MEASUREMENT_ID'],
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HomiFix',
      theme: ThemeData(
        primaryColor: const Color(0xFF4A90E2),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        fontFamily: 'Roboto',
      ),
      debugShowCheckedModeBanner: false,
      home: const LandingPage(),
    );
  }
}
