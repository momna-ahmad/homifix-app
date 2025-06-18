import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'profilePage.dart';// Assuming you already have ProfilePage to view profile
import 'package:http/http.dart' as http;
import 'dart:convert';

const String notificationApiUrl = 'http://10.0.2.2:5000/send-notification';

Future<void> sendPushNotification({
  required String customerFcmToken,
  required String title,
  required String body,
}) async {
  try {
    final response = await http.post(
      Uri.parse(notificationApiUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'customerFcmToken': customerFcmToken,
        'title': title,
        'body': body,
      }),
    );

    if (response.statusCode == 200) {
      print('✅ Notification sent');
    } else {
      print('❌ Failed to send notification: ${response.body}');
    }
  } catch (e) {
    print('🚨 Error sending notification: $e');
  }
}

class BadgeRequestsPage extends StatelessWidget {
  const BadgeRequestsPage({super.key});

  Stream<QuerySnapshot> _pendingBadgeRequests() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'Professional')
        .where('badgeStatus', isEqualTo: 'Pending')
        .snapshots();
  }

  Future<void> _assignBadge(String userId, BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'badgeStatus': 'Approved',
      });

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: const Text('🎉 Badge has been assigned to the professional.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final fcmToken = doc.data()?['fcmToken'];

      if (fcmToken != null && fcmToken is String) {
        await sendPushNotification(
          customerFcmToken: fcmToken,
          title: '🎖️ Badge Approved',
          body: 'Congratulations! Your badge request has been approved.',
        );
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('❌ Error assigning badge: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Badge Requests'),
        backgroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _pendingBadgeRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No pending badge requests'));
          }

          final professionals = snapshot.data!.docs;

          return ListView.builder(
            itemCount: professionals.length,
            itemBuilder: (context, index) {
              final doc = professionals[index];
              final data = doc.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.badge),
                        title: Text(data['name'] ?? 'No Name'),
                        subtitle: const Text('Requested Badge'),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            child: const Text('Review Profile'),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ProfilePage(userId: doc.id, isAdmin: true),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Assign Badge'),
                            onPressed: () => _assignBadge(doc.id, context),
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
      ),
    );
  }
}
