import 'package:flutter/material.dart';
import 'signupScreen.dart'; // Make sure this file exists


class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    Future.delayed(Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SignupScreen()),

      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA), // light grey-blue
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'HomiFix',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A90E2), // soft blue
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Helping Hands for Your Home',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 30),
            CircularProgressIndicator(
              color: Color(0xFF7ED6DF), // light teal
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}
