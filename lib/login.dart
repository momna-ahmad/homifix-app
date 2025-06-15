import 'package:flutter/material.dart';
import 'package:home_services_app/services/auth_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'signupScreen.dart';
import 'CustomerOrderPage.dart';
import 'homeNavPage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  String? _userRole;

  // Interstitial Ad
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;

  @override
  void initState() {
    super.initState();
    _loadInterstitialAd();
  }

  void _loadInterstitialAd() {
    print('Loading interstitial ad...');
    print('Ad Unit ID: ${dotenv.env['ADMOB_INTERSTITIAL_ID']}');

    InterstitialAd.load(
      adUnitId: dotenv.env['ADMOB_INTERSTITIAL_ID'] ?? 'ca-app-pub-9203166790299807/4944810074',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
          print('✅ Interstitial ad loaded successfully');
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('❌ Interstitial ad failed to load: $error');
          _isInterstitialAdReady = false;
        },
      ),
    );
  }
  void _showInterstitialAd() {
    if (_isInterstitialAdReady && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (InterstitialAd ad) {
          ad.dispose();
          _loadInterstitialAd(); // Load a new ad for next time
        },
        onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
          ad.dispose();
          _loadInterstitialAd(); // Load a new ad for next time
        },
      );
      _interstitialAd!.show();
      _isInterstitialAdReady = false;
    }
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    super.dispose();
  }

  void _loginUser() async {
    try {
      final uid = await _authService.loginWithEmailPassword(
        _emailController.text,
        _passwordController.text,
      );

      final role = await _authService.getUserRole(uid!);

      // Save FCM token to Firestore after login
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'fcmToken': fcmToken,
        });
        print('✅ FCM token updated in Firestore for user $uid');
      }


      // Store user data in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('uid', uid);
      await prefs.setString('role', role ?? '');

      setState(() {
        _userId = uid;
        _userRole = role;
        _errorMessage = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Login successful!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // Show interstitial ad before navigation
      _showInterstitialAd();

      // Navigate based on role (with slight delay to show ad first)
      Future.delayed(const Duration(milliseconds: 500), () {
        if (role?.toLowerCase() == 'professional') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => HomeNavPage(userId: uid, role: role!)),
          );
        } else if (role?.toLowerCase() == 'client') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => HomeNavPage(userId: uid, role: role!)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unknown role: $role'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _userId = null;
        _userRole = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color darkBlue = Color(0xFF0D47A1);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/loginImage.jpeg',
            fit: BoxFit.cover,
            height: double.infinity,
            width: double.infinity,
          ),
          Container(
            color: Colors.black.withOpacity(0.3),
          ),
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.translate(
                      offset: const Offset(0, -1),
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          image: const DecorationImage(
                            image: AssetImage('assets/loginImage.jpeg'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
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
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
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
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () {
                              // Forgot Password Navigation
                            },
                            child: Text(
                              'Forgot your password?',
                              style: TextStyle(color: darkBlue),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Don't have an account? "),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SignupScreen(),
                                    ),
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