import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'addOrderPage.dart';
import 'orderApplications.dart';

class CustomerOrdersPage extends StatelessWidget {
  final String userId;
  const CustomerOrdersPage({required this.userId, super.key});

  // Function to show the add order modal
  void _showAddOrderModal(BuildContext context, String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OrderForm(userId: userId),
    );
  }

  // Function to mark an order as complete
  Future<void> _markOrderComplete(BuildContext context, String orderId, String customerId) async {
    try {
      final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);

      // Get the order data to retrieve the selectedWorkerId
      // This is done BEFORE the transaction, as the transaction is for modifying,
      // and we need to read the data to pass the workerId for the review form.
      final orderSnapshot = await orderRef.get();
      if (!orderSnapshot.exists) {
        throw Exception('Order does not exist for marking complete!');
      }

      final orderData = orderSnapshot.data()! as Map<String, dynamic>;
      final String? selectedWorkerId = orderData['selectedWorkerId'] as String?;

      if (selectedWorkerId == null) {
        throw Exception('No worker was selected for this order. Cannot submit review.');
      }

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(orderRef);
        if (!snapshot.exists) throw Exception('Order does not exist!');

        // Update the order status to 'completed'
        transaction.update(orderRef, {'status': 'completed'});
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order marked as completed'),
          backgroundColor: Colors.green,
        ),
      );

      // After marking complete, show the review form, passing the selectedWorkerId
      // Pass the obtained selectedWorkerId here
      _showReviewForm(context, orderId, customerId, selectedWorkerId);
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error marking order complete: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Function to show the review form (UPDATED to accept workerId)
  void _showReviewForm(BuildContext context, String orderId, String customerId, String workerId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // Pass workerId to the _ReviewForm
      builder: (_) => _ReviewForm(orderId: orderId, customerId: customerId, workerId: workerId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ordersRef = FirebaseFirestore.instance
        .collection('orders')
        .where('customerId', isEqualTo: userId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        backgroundColor: Colors.lightBlue.shade700,
        centerTitle: true,
        elevation: 4,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: ordersRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = snapshot.data!.docs;

          if (orders.isEmpty) {
            return const Center(
              child: Text(
                'No orders found.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final data = order.data()! as Map<String, dynamic>;

              final int applicationCount = (data['applications'] as List<dynamic>? ?? []).length;
              final String? selectedWorkerId = data['selectedWorkerId'] as String?;
              final String orderStatus = data['status'] as String? ?? 'pending'; // Get current order status

              // Determine if the order is assigned and its status is pending (ready for completion)
              final bool showMarkCompleteButton =
                  selectedWorkerId != null && orderStatus == 'assigned';

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrderApplications(orderId: order.id),
                    ),
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row with category and status chip
                        Row(
                          children: [
                            Icon(Icons.category, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              data['service'] ?? 'N/A',
                              style: theme.textTheme.titleMedium!.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(), // Added Spacer here
                            // Display status based on orderStatus field
                            Chip(
                              label: Text(orderStatus.toUpperCase()),
                              backgroundColor: orderStatus == 'assigned'
                                  ? Colors.blue.shade100 // Changed to blue for assigned
                                  : orderStatus == 'completed'
                                  ? Colors.green.shade100 // Green for completed
                                  : Colors.orange.shade100, // Orange for pending/waiting
                              avatar: Icon(
                                orderStatus == 'assigned'
                                    ? Icons.person_add // Icon for assigned
                                    : orderStatus == 'completed'
                                    ? Icons.task_alt // Icon for completed
                                    : Icons.hourglass_top, // Icon for pending/waiting
                                color: orderStatus == 'assigned'
                                    ? Colors.blue
                                    : orderStatus == 'completed'
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Order details with colorful emojis
                        _buildEmojiInfoRow('📂', 'Category:', data['category']),
                        _buildEmojiInfoRow(
                          '📍',
                          'Location:',
                          (data['location'] != null && data['location'] is Map<String, dynamic>)
                              ? data['location']['address'] ?? 'N/A'
                              : 'N/A',
                        ),
                        _buildEmojiInfoRow('💰', 'Offered Price:', '\$${data['priceOffer']}'),
                        _buildEmojiInfoRow('📅', 'Date:', data['serviceDate']),
                        _buildEmojiInfoRow('⏰', 'Time:', (data['serviceTime'] as String?) ?? 'N/A'),

                        // Mark Complete Button - Moved here, above the Divider
                        if (showMarkCompleteButton)
                          Align( // Use Align to position to the right
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8.0, bottom: 8.0), // Add some padding
                              child: ElevatedButton.icon(
                                onPressed: () => _markOrderComplete(context, order.id, userId),
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('Mark Complete'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.secondary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ),

                        const Divider(height: 24, thickness: 1), // The black line

                        // Applications display part
                        Text(
                          'Applications: $applicationCount',
                          style: theme.textTheme.titleSmall!.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12), // Added spacing
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.lightBlue.shade700,
        onPressed: () => _showAddOrderModal(context, userId),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  // Helper widget to build info rows with emojis
  Widget _buildEmojiInfoRow(String emoji, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: const TextStyle(fontWeight: FontWeight.normal),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Existing accept worker function (modified)
  Future<void> _acceptWorker(BuildContext context, String orderId, String workerId) async {
    try {
      final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(orderRef);
        if (!snapshot.exists) throw Exception('Order does not exist!');
        final data = snapshot.data()!;
        if (data['selectedWorkerId'] != null) {
          throw Exception('Order already assigned!');
        }

        transaction.update(orderRef, {
          'selectedWorkerId': workerId,
          'visibleToWorkerIds': [workerId],
          'status': 'assigned', // Status set to 'assigned' when worker is accepted/assigned
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Worker accepted'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Existing reject worker function (unchanged)
  Future<void> _rejectWorker(BuildContext context, String orderId, String workerId) async {
    try {
      final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(orderRef);
        if (!snapshot.exists) throw Exception('Order does not exist!');

        final applications = (snapshot.data()!['applications'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        final updatedApps = applications.where((app) => app['workerId'] != workerId).toList();

        transaction.update(orderRef, {'applications': updatedApps});
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Worker rejected'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

// New StatefulWidget for the Review Form
class _ReviewForm extends StatefulWidget {
  final String orderId;
  final String customerId;
  final String workerId; // Add workerId to the constructor

  const _ReviewForm({
    required this.orderId,
    required this.customerId,
    required this.workerId, // Make it required
  });

  @override
  _ReviewFormState createState() => _ReviewFormState();
}

class _ReviewFormState extends State<_ReviewForm> {
  double _rating = 3.0; // Default rating
  final TextEditingController _reviewTextController = TextEditingController();
  bool _isSubmitting = false; // To prevent multiple submissions

  // Function to submit the review to Firestore
  Future<void> _submitReview() async {
    if (_reviewTextController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your review text.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Change Firestore path to save review under the worker's user document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.workerId) // <-- Now targets the worker's user ID
          .collection('reviews')
          .add({
        'orderId': widget.orderId,
        'customerId': widget.customerId,
        'workerId': widget.workerId, // Also add workerId to the review data
        'rating': _rating,
        'reviewText': _reviewTextController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(), // Timestamp for when the review was submitted
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted successfully!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context); // Dismiss the review form
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting review: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  void dispose() {
    _reviewTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          // Review Form background color uses theme's canvasColor
          color: theme.canvasColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Rate Your Service',
              style: theme.textTheme.headlineSmall!.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            // Star Rating System
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _rating.floor() ? Icons.star : Icons.star_border,
                    color: Colors.amber, // Star color
                    size: 36.0,
                  ),
                  onPressed: () {
                    setState(() {
                      _rating = (index + 1).toDouble(); // Set rating based on tapped star
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _reviewTextController,
              decoration: InputDecoration(
                labelText: 'Your Review',
                hintText: 'Share your experience...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.inputDecorationTheme.fillColor,
              ),
              maxLines: 4,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitReview,
              icon: _isSubmitting
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                ),
              )
                  : const Icon(Icons.send),
              label: Text(_isSubmitting ? 'Submitting...' : 'Submit Review'),
              style: ElevatedButton.styleFrom(
                // Submit button background color: sky blue
                backgroundColor: Colors.lightBlue.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}