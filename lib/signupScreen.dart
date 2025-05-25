import 'package:flutter/material.dart';

class SignupScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA), // Same light background as splash
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // TODO: Add sign-up logic here (e.g., Firebase Auth)
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Sign Up button pressed')),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF4A90E2), // HomiFix primary color
            padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            'Sign Up',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}

