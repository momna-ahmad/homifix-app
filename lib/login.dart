import 'package:flutter/material.dart';
import 'package:home_services_app/services/auth_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'signupScreen.dart';
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

  final TextEditingController _resetEmailController = TextEditingController();
  bool _showResetPassword = false;
  String? _resetMessage;
  bool _resetSuccess = false;
  bool _isResetLoading = false;

  String? _errorMessage;
  bool _isLoading = false;

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;

  static const Color primaryBlue = Color(0xFF00BCD4);
  static const Color lightBlue = Color(0xFF4DD0E1);
  // Changed to light blue background instead of gray
  static const Color backgroundColor = Color(0xFFE0F7FA); // Light cyan background
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF2C3E50);
  static const Color textSecondary = Color(0xFF7F8C8D);

  @override
  void initState() {
    super.initState();
    _loadInterstitialAd();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: dotenv.env['ADMOB_INTERSTITIAL_ID'] ?? 'ca-app-pub-9203166790299807/4944810074',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
        },
        onAdFailedToLoad: (LoadAdError error) {
          _isInterstitialAdReady = false;
        },
      ),
    );
  }

  void _showInterstitialAdAndNavigate(String uid, String? role) {
    if (role == 'Admin') {
      _navigateToRoleScreen(uid, role);
      return;
    }

    if (_isInterstitialAdReady && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (InterstitialAd ad) {
          ad.dispose();
          _loadInterstitialAd();
          _navigateToRoleScreen(uid, role);
        },
        onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
          ad.dispose();
          _loadInterstitialAd();
          _navigateToRoleScreen(uid, role);
        },
      );
      _interstitialAd!.show();
      _isInterstitialAdReady = false;
    } else {
      _navigateToRoleScreen(uid, role);
    }
  }

  void _navigateToRoleScreen(String uid, String? role) {
    if (role == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('User role is missing.'),
          backgroundColor: Colors.red[400],
        ),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeNavPage(userId: uid, role: role),
      ),
    );
  }

  void _loginUser() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = "Please fill in both fields.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uid = await _authService.loginWithEmailPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      final role = await _authService.getUserRole(uid!);

      if (role == null || role.isEmpty) {
        setState(() {
          _errorMessage = "User role is missing.";
        });
        return;
      }

      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'fcmToken': fcmToken,
        });
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('uid', uid);
      await prefs.setString('role', role);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Login successful!'),
          backgroundColor: primaryBlue,
        ),
      );

      _showInterstitialAdAndNavigate(uid, role);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _submitPasswordReset() async {
    final email = _resetEmailController.text.trim();

    if (email.isEmpty) {
      setState(() {
        _resetMessage = 'Please enter your email.';
        _resetSuccess = false;
      });
      return;
    }

    if (!_isValidEmail(email)) {
      setState(() {
        _resetMessage = 'Please enter a valid email.';
        _resetSuccess = false;
      });
      return;
    }

    setState(() {
      _isResetLoading = true;
      _resetMessage = null;
    });

    try {
      await _authService.sendPasswordResetEmail(email);
      setState(() {
        _resetMessage = 'Password reset email sent!';
        _resetSuccess = true;
      });
    } catch (e) {
      setState(() {
        _resetMessage = 'Error: ${e.toString()}';
        _resetSuccess = false;
      });
    } finally {
      setState(() {
        _isResetLoading = false;
      });
    }
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(email);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _resetEmailController.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword,
            enabled: enabled,
            keyboardType: isPassword ? TextInputType.text : TextInputType.emailAddress,
            style: const TextStyle(
              fontSize: 16,
              color: textPrimary,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: textSecondary.withOpacity(0.7),
                fontSize: 16,
              ),
              prefixIcon: Icon(
                icon,
                color: primaryBlue,
                size: 22,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: cardColor,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButton({
    required String text,
    required VoidCallback onPressed,
    bool isLoading = false,
    bool isPrimary = true,
  }) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: isPrimary
            ? LinearGradient(
          colors: [primaryBlue, lightBlue],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        )
            : null,
        color: isPrimary ? null : Colors.transparent,
        boxShadow: isPrimary
            ? [
          BoxShadow(
            color: primaryBlue.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ]
            : null,
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
            : Text(
          text,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isPrimary ? Colors.white : primaryBlue,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor, // Now using light blue background
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // App Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: primaryBlue.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: Image.asset(
                    'assets/app_icon.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Main Card with enhanced shadow for better contrast on light blue background
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12), // Slightly stronger shadow
                      blurRadius: 35,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: primaryBlue.withOpacity(0.08), // Added subtle blue shadow
                      blurRadius: 20,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: _showResetPassword ? _buildResetPasswordForm() : _buildLoginForm(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Center(
          child: Column(
            children: [
              Text(
                'Welcome Back!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to continue',
                style: TextStyle(
                  fontSize: 16,
                  color: textSecondary,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 40),

        // Email Field
        _buildInputField(
          controller: _emailController,
          label: 'Email',
          hint: 'Enter your email',
          icon: Icons.email_outlined,
          enabled: !_isLoading,
        ),

        const SizedBox(height: 24),

        // Password Field
        _buildInputField(
          controller: _passwordController,
          label: 'Password',
          hint: 'Enter your password',
          icon: Icons.lock_outline,
          isPassword: true,
          enabled: !_isLoading,
        ),

        const SizedBox(height: 16),

        // Forgot Password Link
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              setState(() {
                _showResetPassword = true;
                _resetMessage = null;
              });
            },
            child: Text(
              'Forgot Password?',
              style: TextStyle(
                color: primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Error Message
        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red[600], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red[600], fontSize: 14),
                  ),
                ),
              ],
            ),
          ),

        // Login Button
        _buildButton(
          text: 'Sign In',
          onPressed: _loginUser,
          isLoading: _isLoading,
        ),

        const SizedBox(height: 32),

        // Sign Up Link
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Don't have an account? ",
              style: TextStyle(color: textSecondary),
            ),
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
                  color: primaryBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResetPasswordForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with Back Button
        Row(
          children: [
            IconButton(
              onPressed: () {
                setState(() {
                  _showResetPassword = false;
                  _resetMessage = null;
                  _resetEmailController.clear();
                });
              },
              icon: const Icon(Icons.arrow_back_ios),
              color: primaryBlue,
            ),
            const Expanded(
              child: Text(
                'Reset Password',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 48), // Balance the back button
          ],
        ),

        const SizedBox(height: 16),

        Center(
          child: Text(
            'Enter your email to receive a password reset link',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: textSecondary,
            ),
          ),
        ),

        const SizedBox(height: 32),

        // Email Field
        _buildInputField(
          controller: _resetEmailController,
          label: 'Email',
          hint: 'Enter your email',
          icon: Icons.email_outlined,
        ),

        const SizedBox(height: 24),

        // Reset Message
        if (_resetMessage != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: _resetSuccess ? Colors.green[50] : Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _resetSuccess ? Colors.green[200]! : Colors.red[200]!,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _resetSuccess ? Icons.check_circle_outline : Icons.error_outline,
                  color: _resetSuccess ? Colors.green[600] : Colors.red[600],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _resetMessage!,
                    style: TextStyle(
                      color: _resetSuccess ? Colors.green[600] : Colors.red[600],
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Send Reset Email Button
        _buildButton(
          text: 'Send Reset Email',
          onPressed: _submitPasswordReset,
          isLoading: _isResetLoading,
        ),
      ],
    );
  }
}