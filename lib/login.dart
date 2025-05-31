import 'package:flutter/material.dart';
import 'package:home_services_app/services/auth_service.dart';
import 'signupScreen.dart'; // Add your correct path
import 'addServicesPage.dart';
import 'addOrderPage.dart';
import 'professionalOrderPage.dart';
import 'CustomerOrderPage.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  String? _errorMessage;
  String? _userId;

  void _loginUser() async {
    try {
      final uid = await _authService.loginWithEmailPassword(
        _emailController.text,
        _passwordController.text,
      );
      setState(() {
        _userId = uid;
        _errorMessage = null;
      });

      // Show success snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Login successful!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      Navigator.pushReplacement(
        context,
         MaterialPageRoute(builder: (_) => AddServicesPage(userId: uid!)),
        //MaterialPageRoute(builder: (_) => AddOrderPage(userId: uid!)),
        //MaterialPageRoute(builder: (_) => ProfessionalOrdersPage(professionalId: uid!)),
         // MaterialPageRoute(builder: (_) => CustomerOrdersPage(userId: uid!)),



      );

    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _userId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color darkBlue = Color(0xFF0D47A1); // Changed to dark blue

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          Image.asset(
            'assets/loginImage.jpeg',
            fit: BoxFit.cover,
            height: double.infinity,
            width: double.infinity,
          ),
          // Overlay
          Container(
            color: Colors.black.withOpacity(0.3),
          ),
          // Login Form
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Image
                    Transform.translate(
                      offset: const Offset(0, -1), // move up by 20 pixels
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 24),  // keep bottom margin
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          image: const DecorationImage(
                            image: AssetImage('assets/loginImage.jpeg'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    // Login Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            offset: Offset(0, 4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Welcome Back!',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: darkBlue,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Login to your account',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Email Field
                          TextField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              hintText: 'johndoe@gmail.com',
                              prefixIcon: Icon(Icons.email, color: darkBlue),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: darkBlue, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Password Field
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: '********',
                              prefixIcon: Icon(Icons.lock, color: darkBlue),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: darkBlue, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Login Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _loginUser,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: darkBlue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white, // Add this line
                                ),
                              ),

                            ),
                          ),
                          const SizedBox(height: 12),
                          // Forgot Password
                          TextButton(
                            onPressed: () {
                              // Add navigation to Forgot Password screen here
                            },
                            child: Text(
                              'Forgot your password?',
                              style: TextStyle(color: darkBlue),
                            ),
                          ),
                          // Sign Up Link
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Don't have an account? "),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => SignupScreen()),

                                  );
                                },
                                child: Text(
                                  'Sign Up',
                                  style: TextStyle(
                                    color: darkBlue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Error or Success Message
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12.0),
                              child: Text(
                                'Error: $_errorMessage',
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          if (_userId != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12.0),
                              child: Text(
                                'Logged in! UID: $_userId',
                                style: const TextStyle(color: Colors.green),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
