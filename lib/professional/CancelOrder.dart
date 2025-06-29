import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> onCancel(String orderId) async {
  final prefs = await SharedPreferences.getInstance();
  final uid = prefs.getString('uid');

  if (uid == null) {
    throw Exception("UID not found in SharedPreferences");
  }

  final userDocRef = FirebaseFirestore.instance.collection('users').doc(uid);
  final orderDocRef = FirebaseFirestore.instance.collection('orders').doc(orderId);

  try {
    final userSnapshot = await userDocRef.get();
    if (!userSnapshot.exists) {
      throw Exception("User document does not exist.");
    }

    final userData = userSnapshot.data()!;
    List<dynamic> orders = userData['orders'] ?? [];
    List<dynamic> requests = userData['requests'] ?? [];

    // Step 1: Remove the matching order from 'orders'
    final matchingOrder = orders.firstWhere(
          (order) => order['orderId'] == orderId,
      orElse: () => null,
    );

    if (matchingOrder != null) {
      await userDocRef.update({
        'orders': FieldValue.arrayRemove([matchingOrder]),
      });
    }

    // Step 2: Remove orderId from 'requests'
    if (requests.contains(orderId)) {
      await userDocRef.update({
        'requests': FieldValue.arrayRemove([orderId]),
      });
    }

    // Step 3: Set order status to 'cancelled'
    await orderDocRef.update({
      'status': 'cancelled',
    });

    // Step 4: Fetch order data
    final orderSnapshot = await orderDocRef.get();
    final order = orderSnapshot.data()!;
    List<dynamic> applications = order['applications'] ?? [];
    final String customerId = order['customerId'];
    final String service = order['service'];

    // Step 5: Update professional's application status
    final updatedApplications = applications.map((application) {
      if (application['professionalId'] == uid) {
        return {
          ...application,
          'status': 'cancelled',
        };
      }
      return application;
    }).toList();

    await orderDocRef.update({
      'applications': updatedApplications,
    });

    // Step 6: Add a notification for the customer
    final customerDocRef = FirebaseFirestore.instance.collection('users').doc(customerId);
    final notification = {
      'message': 'Your order for $service was cancelled',
      'orderId': orderId,
    };

    final customerSnapshot = await customerDocRef.get();
    if (customerSnapshot.exists) {
      final customerData = customerSnapshot.data();
      if (customerData != null && customerData.containsKey('notifications')) {
        // notifications exists → append
        await customerDocRef.update({
          'notifications': FieldValue.arrayUnion([notification]),
        });
      } else {
        // notifications doesn't exist → create
        await customerDocRef.set({
          'notifications': [notification],
        }, SetOptions(merge: true));
      }
    }


  } catch (e) {
    print("❌ Error while cancelling order: $e");
    rethrow;
  }
}




void cancelOrder({
  required BuildContext context,
  required String orderId,
  required VoidCallback onOrderCancelled,
}) {
  bool isLoading = false;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: isLoading
                      ? SizedBox(
                    height: 100,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text("Cancelling order..."),
                        ],
                      ),
                    ),
                  )
                      : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 20),
                      const Text(
                        'Are you sure you want to cancel this order?',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('No'),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              setState(() {
                                isLoading = true;
                              });

                              try {
                                await onCancel(orderId);
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                                onOrderCancelled(); // Callback if you want to update UI
                              } catch (e) {
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error cancelling order. Please try again.')),
                                  );
                                }
                              }
                            },
                            child: const Text('Yes, Cancel'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Close (X) button (only show when not loading)
                if (!isLoading)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.close, size: 20),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    },
  );
}
