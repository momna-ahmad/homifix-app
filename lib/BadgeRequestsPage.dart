import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:home_services_app/professionalForCustomer.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'notification_service.dart'; // Import the centralized notification service

// Dynamic API URL based on platform
String get notificationApiUrl {
  if (kIsWeb) {
    // For web (Chrome admin), use localhost
    return 'http://localhost:5000/send-notification';
  } else {
    // For mobile (Android emulator), use 10.0.2.2
    // For mobile (real device), use your computer's IP address
    return 'http://192.168.1.113:5000/send-notification';
    // If using real device, replace with your computer's IP:
    // return 'http://192.168.1.100:5000/send-notification'; // Replace with your actual IP
  }
}

Future<void> sendPushNotification({
  required String professionalFcmToken,
  required String title,
  required String body,
}) async {
  try {
    print('🚀 Sending notification to: ${notificationApiUrl}');
    print('🎯 FCM Token: ${professionalFcmToken.substring(0, 20)}...');

    final response = await http.post(
      Uri.parse(notificationApiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'customerFcmToken': professionalFcmToken, // Your server expects this parameter name
        'title': title,
        'body': body,
      }),
    );

    print('📡 Response Status: ${response.statusCode}');
    print('📡 Response Body: ${response.body}');

    if (response.statusCode == 200) {
      print('✅ Badge assignment notification sent to professional');
    } else {
      print('❌ Failed to send badge notification: ${response.body}');
    }
  } catch (e) {
    print('🚨 Error sending badge notification: $e');
  }
}

class BadgeRequestsPage extends StatefulWidget {
  const BadgeRequestsPage({super.key});

  @override
  _BadgeRequestsPageState createState() => _BadgeRequestsPageState();
}

class _BadgeRequestsPageState extends State<BadgeRequestsPage> {
  @override
  void initState() {
    super.initState();
    // Initialize the centralized notification service
    NotificationService.initialize();
  }

  Stream<QuerySnapshot> _pendingBadgeRequests() {
    return FirebaseFirestore.instance
        .collection('batch_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Future<void> _assignBadge(String requestId, String userId, BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      print('🎖️ Starting badge assignment for user: $userId');

      // First, get the professional's data before updating
      final professionalDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();

      if (!professionalDoc.exists) {
        throw Exception('Professional not found');
      }

      final professionalData = professionalDoc.data() as Map<String, dynamic>?;
      final professionalName = professionalData?['name'] ?? 'Professional';
      final professionalFcmToken = professionalData?['fcmToken'];

      print('👤 Professional Name: $professionalName');
      print('🔑 FCM Token exists: ${professionalFcmToken != null}');

      if (professionalFcmToken != null) {
        print('🔑 FCM Token: ${professionalFcmToken.toString().substring(0, 20)}...');
      }

      // Update professional's badge status
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'badgeStatus': 'assigned',
        'badgeAssignedAt': FieldValue.serverTimestamp(),
      });

      // Update badge request status
      await FirebaseFirestore.instance.collection('batch_requests').doc(requestId).update({
        'status': 'assigned',
        'assignedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Database updated successfully');

      // Show success message
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('🎉 Badge has been assigned to $professionalName'),
          backgroundColor: const Color(0xFF059669),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );

      // Send push notification to the professional using your Node.js server
      if (professionalFcmToken != null && professionalFcmToken is String && professionalFcmToken.isNotEmpty) {
        print('📤 Attempting to send notification...');

        await sendPushNotification(
          professionalFcmToken: professionalFcmToken,
          title: '🎖️ Badge Assigned!',
          body: 'Congratulations $professionalName! Your professional badge has been successfully assigned. You can now showcase your verified status to customers.',
        );

        print('✅ Badge notification sent to professional: $professionalName');
      } else {
        print('⚠️ No FCM token found for professional: $professionalName');
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Badge assigned but notification could not be sent to $professionalName - No FCM token'),
            backgroundColor: const Color(0xFFD97706),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Error assigning badge: $e');
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('❌ Error assigning badge: ${e.toString()}'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  Future<void> _rejectBadgeRequest(String requestId, String userId, String professionalName, BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Show confirmation dialog
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Reject Badge Request',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A202C),
            ),
          ),
          content: Text(
            'Are you sure you want to reject the badge request from $professionalName?',
            style: const TextStyle(
              color: Color(0xFF4A5568),
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFF718096),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Reject',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        // Get professional's FCM token before updating
        final professionalDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        final professionalData = professionalDoc.data() as Map<String, dynamic>?;
        final professionalFcmToken = professionalData?['fcmToken'];

        // Update badge request status to rejected
        await FirebaseFirestore.instance.collection('batch_requests').doc(requestId).update({
          'status': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
        });

        // Show success message
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Badge request from $professionalName has been rejected'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );

        // Send rejection notification to professional
        if (professionalFcmToken != null && professionalFcmToken is String && professionalFcmToken.isNotEmpty) {
          await sendPushNotification(
            professionalFcmToken: professionalFcmToken,
            title: '❌ Badge Request Update',
            body: 'Hello $professionalName, your badge request has been reviewed. Please ensure all requirements are met and try again.',
          );
        }
      } catch (e) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error rejecting badge request: ${e.toString()}'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        title: const Text(
          'Badge Requests',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: Color(0xFF1A202C),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A202C)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: const Color(0xFFE2E8F0),
          ),
        ),
      ),
      body: Column(
        children: [
          // Header Card with debug info
          Container(
            margin: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF22D3EE), Color(0xFF0EA5E9)],
              ),
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Badge Management',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Verify your Professionals',
                              style: TextStyle(fontSize: 16, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.badge, color: Colors.white, size: 30),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Badge Requests List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _pendingBadgeRequests(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF22D3EE)),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.badge_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text(
                          'No pending badge requests',
                          style: TextStyle(fontSize: 16, color: Color(0xFF718096)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final professionals = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: professionals.length,
                  itemBuilder: (context, index) {
                    final doc = professionals[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final userId = data['userId'] ?? '';

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                        final userName = userData['name'] ?? 'No Name';
                        final fcmToken = userData['fcmToken'];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16.0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF22D3EE).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.badge, color: Color(0xFF22D3EE), size: 24),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            userName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 18,
                                              color: Color(0xFF1A202C),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFD97706),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: const Text(
                                                  'Badge Request',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Mobile-optimized Action buttons
                                Column(
                                  children: [
                                    // First row - Review Profile button (full width)
                                    SizedBox(
                                      width: double.infinity,
                                      height: 36,
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.person_outline, size: 16),
                                        label: const Text(
                                          'Review Profile',
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                        ),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ProfessionalForCustomer(userId: userId),
                                            ),
                                          );
                                        },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFF22D3EE),
                                          side: const BorderSide(color: Color(0xFF22D3EE), width: 1.5),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Second row - Reject and Assign buttons
                                    Row(
                                      children: [
                                        // Reject Button
                                        Expanded(
                                          child: SizedBox(
                                            height: 36,
                                            child: ElevatedButton.icon(
                                              icon: const Icon(Icons.close, size: 16),
                                              label: const Text(
                                                'Reject',
                                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                              ),
                                              onPressed: () => _rejectBadgeRequest(doc.id, userId, userName, context),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFFDC2626),
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Assign Badge Button
                                        Expanded(
                                          child: SizedBox(
                                            height: 36,
                                            child: ElevatedButton.icon(
                                              icon: const Icon(Icons.check_circle, size: 16),
                                              label: const Text(
                                                'Assign',
                                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                              ),
                                              onPressed: () => _assignBadge(doc.id, userId, context),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF22D3EE),
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF718096)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF718096), fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 14, color: Color(0xFF1A202C), fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}