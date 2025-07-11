import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login.dart';
import 'homeNavPage.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(seconds: 2)); // Splash delay

    final user = FirebaseAuth.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role');

    if (user != null && role != null) {
      // User is logged in — go to home page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeNavPage(userId: user.uid, role: role),
        ),
      );
    } else {
      // Not logged in — go to login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Icon Image
            Image.asset(
              'assets/app_icon.jpg',
              width: 120,
              height: 120,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16),
            Text(
              'Helping Hands for Your Home',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 30),
            CircularProgressIndicator(
              color: Colors.blue.shade800,
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}