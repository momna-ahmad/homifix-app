import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:home_services_app/professionalProfile.dart';
import 'package:home_services_app/profilePage.dart';
import 'professionalOrderPage.dart' ;

// 1. Change to StatefulWidget to manage the Firestore stream
class OrderApplications extends StatefulWidget {
  final String orderId;
  const OrderApplications({super.key, required this.orderId});

  @override
  State<OrderApplications> createState() => _OrderApplicationsState();
}

class _OrderApplicationsState extends State<OrderApplications> {
  // Declare a Stream to listen for real-time updates on the order document
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _orderStream;

  @override
  void initState() {
    super.initState();
    // Initialize the stream: .snapshots() provides a stream of document changes
    _orderStream = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId) // Use widget.orderId as it's in a State now
        .snapshots();
  }

  // Good practice: Dispose of the stream when the widget is removed
  @override
  void dispose() {
    // No need to explicitly close the stream returned by Firestore .snapshots() as Firebase manages it
    super.dispose();
  }

  // Your _acceptApplication logic (slightly refined for robustness and consistency)
  void _acceptApplication(int index, String professionalId) async {
    final orderDocRef = FirebaseFirestore.instance.collection('orders').doc(widget.orderId);

    try {
      // Use a Firestore Transaction for atomic updates. This is crucial for data consistency
      // when multiple fields in different documents (order and user) are updated together.
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Re-fetch the order document within the transaction to ensure it's up-to-date
        DocumentSnapshot<Map<String, dynamic>> currentOrderSnapshot = await transaction.get(orderDocRef);

        if (!currentOrderSnapshot.exists) {
          throw Exception('Order document disappeared during transaction!');
        }

        Map<String, dynamic> orderData = Map.from(currentOrderSnapshot.data()!);
        List<dynamic> applications = List.from(orderData['applications'] ?? []);

        // Safety check for valid application index
        if (index < 0 || index >= applications.length) {
          throw Exception('Invalid application index: $index');
        }

        // Optional: Prevent accepting if the order is already assigned or completed
        if (orderData['status'] == 'assigned' || orderData['status'] == 'completed') {
          print('Order is already assigned or completed. Cannot accept new application.');
          if (mounted) { // Check if the widget is still in the tree before showing SnackBar
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Order already assigned or completed!'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return; // Exit transaction if already assigned/completed
        }

        // 2. Update the status of the selected application to 'accepted'
        Map<String, dynamic> updatedApplication = Map.from(applications[index]);
        updatedApplication['status'] = 'accepted';
        applications[index] = updatedApplication;

        // 3. Reject all other pending applications for this order (good practice)
        for (int i = 0; i < applications.length; i++) {
          if (i != index) {
            Map<String, dynamic> otherApplication = Map.from(applications[i]);
            if (otherApplication['status'] == 'pending') { // Only reject if still pending
              otherApplication['status'] = 'rejected';
              applications[i] = otherApplication;
            }
          }
        }

        // 4. Update the main order document: applications array, order status, and selected worker ID
        Map<String, dynamic> updateFields = {
          'applications': applications,
          'status': 'assigned', // Order status changes to 'assigned'
          'selectedWorkerId': professionalId, // Set the selected worker ID
        };

        transaction.update(orderDocRef, updateFields);

        // 5. Copy essential order data to the professional's 'orders' array (within the same transaction)
        final professionalDocRef = FirebaseFirestore.instance.collection('users').doc(professionalId);

        Map<String, dynamic> orderDataForProfessional = {
          'location': orderData['location'],
          'date': orderData['serviceDate'],
          'time': orderData['serviceTime'],
          'price': applications[index]['price'], // Use the price from the accepted application
          'service': orderData['service'],
          'completionStatus': 'pending', // Initial status for professional's view
          'orderId': widget.orderId, // Include the order ID for reference
        };

        // Use FieldValue.arrayUnion within the transaction to add the order to the professional's list
        transaction.update(professionalDocRef, {
          'orders': FieldValue.arrayUnion([orderDataForProfessional])
        });
      }); // End of runTransaction

      print('Accepted application, updated order status, set selectedWorkerId, and updated professional orders.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application accepted and order assigned!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error accepting application: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept application: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Applications'),
        centerTitle: true,
      ),
      // 2. Use StreamBuilder to listen for real-time changes
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _orderStream, // Provide the stream here
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Show a loading indicator while data is being fetched initially
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Order not found.'));
          }

          final data = snapshot.data!.data();
          final applications = (data?['applications'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();

          // Get the current order status and selected worker ID for UI logic
          final String orderStatus = data?['status'] as String? ?? 'pending';
          final String? selectedWorkerId = data?['selectedWorkerId'] as String?;

          if (applications.isEmpty) {
            return const Center(
              child: Text('No applications yet.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: applications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final application = applications[index];
              final professionalId = application['professionalId'] as String;

              // Determine if this specific application is the accepted one
              final bool isAcceptedApplication = application['status'] == 'accepted';
              // Determine if the order is already assigned to a different worker
              final bool isOrderAlreadyAssignedToOther =
                  orderStatus == 'assigned' && selectedWorkerId != professionalId;


              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: FirebaseFirestore.instance.collection('users').doc(professionalId).get(),
                  builder: (context, professionalSnapshot) {
                    if (professionalSnapshot.connectionState == ConnectionState.waiting) {
                      return ListTile(
                        leading: const Icon(Icons.person, color: Colors.blueAccent),
                        title: const Text('Loading professional info...'),
                      );
                    }
                    if (professionalSnapshot.hasError || !professionalSnapshot.hasData || !professionalSnapshot.data!.exists) {
                      return ListTile(
                        leading: const Icon(Icons.person, color: Colors.blueAccent),
                        title: const Text('Professional info not found'),
                      );
                    }

                    final professionalData = professionalSnapshot.data!.data()!;
                    final professionalName = professionalData['name'] ?? 'No Name';

                    return ListTile(
                      leading: const Icon(Icons.person, color: Colors.blueAccent),
                      title: Text('Professional: $professionalName'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('💬 Message: ${application['message'] ?? 'No message'}'),
                          Text('💰 Price: Rs. ${application['price'] ?? 'N/A'}'),
                          const SizedBox(height: 4,),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // View Profile button
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => ProfilePage(
                                        userId: application['professionalId'], // Pass the professional's ID
                                      ),
                                    ),
                                  );
                                },

                                child: const Text('View Profile'),
                              ),
                              const SizedBox(width: 8), // Spacing between buttons

                              // Conditional button/text based on application and order status
                              if (application['status'] == 'pending' && !isOrderAlreadyAssignedToOther && orderStatus != 'completed')
                              // Show Accept Application button only if pending and order not already assigned/completed
                                ElevatedButton(
                                  onPressed: () {
                                    _acceptApplication(index, professionalId);
                                  },
                                  child: const Text('Accept Application'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor: theme.colorScheme.onPrimary,
                                  ),
                                )
                              else if (application['status'] == 'accepted')
                              // Display 'Accepted' if this specific application is accepted
                                Chip(
                                  label: const Text('Accepted'),
                                  backgroundColor: Colors.green.shade100,
                                  avatar: const Icon(Icons.check_circle, color: Colors.green),
                                )
                              else if (application['status'] == 'rejected')
                                // Display 'Rejected' if this specific application is rejected
                                  Chip(
                                    label: const Text('Rejected'),
                                    backgroundColor: Colors.red.shade100,
                                    avatar: const Icon(Icons.cancel, color: Colors.red),
                                  )
                                else if (isOrderAlreadyAssignedToOther)
                                  // If order is assigned to someone else, this application cannot be accepted
                                    Chip(
                                      label: const Text('Order Assigned'),
                                      backgroundColor: Colors.grey.shade200,
                                      avatar: const Icon(Icons.info_outline, color: Colors.grey),
                                    ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}