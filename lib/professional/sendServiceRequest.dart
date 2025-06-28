import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';
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
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'customerFcmToken': customerFcmToken,
        'title': title,
        'body': body,
      }),
    );

    if (response.statusCode == 200) {
      print('✅ Push notification sent successfully');
    } else {
      print('❌ Failed to send notification: ${response.body}');
    }
  } catch (e) {
    print('🚨 Error sending notification: $e');
  }
}

class RequestService {
  static Future<void> sendRequest({
    required BuildContext context,
    required String professionalId,
    required String orderId,
    required String price,
    required String message,
  }) async {
    if (price.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 12),
              Text("All fields are required"),
            ],
          ),
          backgroundColor: const Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    try {
      // Check if request already sent
      final professionalUserRef = FirebaseFirestore.instance.collection('users').doc(professionalId);
      final professionalSnapshot = await professionalUserRef.get();

      if (professionalSnapshot.exists) {
        final professionalData = professionalSnapshot.data();
        final List<dynamic> requestsSent = professionalData?['requestsSent'] ?? [];

        if (requestsSent.contains(orderId)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.info, color: Colors.white),
                  SizedBox(width: 12),
                  Text('You have already sent a request for this order.'),
                ],
              ),
              backgroundColor: const Color(0xFFF59E0B),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
          return;
        }
      }

      // Send the request
      final request = {
        'professionalId': professionalId,
        'price': price,
        'message': message,
        'status': 'pending',
        'timestamp': DateTime.now().toIso8601String(),
      };

      final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);

      // Perform Firestore operations
      await orderRef.update({
        'applications': FieldValue.arrayUnion([request]),
      });

      await professionalUserRef.update({
        'requestsSent': FieldValue.arrayUnion([orderId]),
      });

      // Show success SnackBar immediately after Firestore operations complete
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Request sent successfully'),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );

      // Handle notifications asynchronously in the background
      _handleNotificationsAsync(orderId, orderRef);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Error sending request: $e')),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      print('Error sending request: $e');
      rethrow; // Re-throw to handle in the dialog
    }
  }

  // Handle notifications asynchronously to avoid blocking the UI
  static void _handleNotificationsAsync(String orderId, DocumentReference orderRef) async {
    try {
      // Send local notification
      await showLocalNotification(
        'Request Sent',
        'Your request has been sent successfully!',
      );

      // Send push notification to customer
      final orderSnapshot = await orderRef.get();
      final orderData = orderSnapshot.data() as Map<String, dynamic>?;
      final customerId = orderData?['customerId'];
      if (customerId != null) {
        final customerDoc = await FirebaseFirestore.instance.collection('users').doc(customerId).get();
        final customerData = customerDoc.data() as Map<String, dynamic>?;
        final customerFcmToken = customerData?['fcmToken'];
        if (customerFcmToken != null && customerFcmToken is String) {
          await sendPushNotification(
            customerFcmToken: customerFcmToken,
            title: "New Request Received",
            body: "A professional has applied to your order. Check it out!",
          );
        }
      }
    } catch (e) {
      print('Error sending notifications: $e');
      // Don't show error to user since the main operation (sending request) was successful
    }
  }
}

class SendRequestDialog extends StatefulWidget {
  final String orderId;
  final String professionalId;
  final VoidCallback? onRequestSent; // Add callback

  const SendRequestDialog({
    super.key,
    required this.orderId,
    required this.professionalId,
    this.onRequestSent, // Add callback parameter
  });

  @override
  State<SendRequestDialog> createState() => _SendRequestDialogState();
}

class _SendRequestDialogState extends State<SendRequestDialog> {
  final TextEditingController priceController = TextEditingController();
  final TextEditingController messageController = TextEditingController();
  bool _loading = false;

  void _submitRequest() async {
    final price = priceController.text.trim();
    final message = messageController.text.trim();

    setState(() => _loading = true);

    try {
      await RequestService.sendRequest(
        context: context,
        professionalId: widget.professionalId,
        orderId: widget.orderId,
        price: price,
        message: message,
      );

      // Call the callback to notify parent widget
      if (widget.onRequestSent != null) {
        widget.onRequestSent!();
      }

      // Close modal and return true to indicate success
      if (mounted) {
        Navigator.pop(context, true); // Return true for success
      }
    } catch (e) {
      // Only reset loading state if there was an error
      if (mounted) {
        setState(() => _loading = false);
        // Optionally return false to indicate failure
        // Navigator.pop(context, false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 0,
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.send,
                      color: Color(0xFF0EA5E9),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Send Request',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Price Input
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Your Price Offer',
                    labelStyle: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 14,
                    ),
                    prefixIcon: Container(
                      padding: const EdgeInsets.all(12),
                      child: const Icon(
                        Icons.attach_money,
                        color: Color(0xFF0EA5E9),
                        size: 20,
                      ),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Message Input
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: messageController,
                  maxLines: 3,
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Message to Customer',
                    labelStyle: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 14,
                    ),
                    prefixIcon: Container(
                      padding: const EdgeInsets.all(12),
                      child: const Icon(
                        Icons.message,
                        color: Color(0xFF0EA5E9),
                        size: 20,
                      ),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextButton(
                        onPressed: _loading ? null : () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF22D3EE), Color(0xFF0EA5E9)],
                        ),
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x300EA5E9),
                            spreadRadius: 0,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextButton(
                        onPressed: _loading ? null : _submitRequest,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                            : const Text(
                          'Send Request',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    priceController.dispose();
    messageController.dispose();
    super.dispose();
  }
}