import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'addOrderPage.dart';
import 'orderApplications.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

FirebaseAnalytics analytics = FirebaseAnalytics.instance;

void logOrderCompleted(String orderId) {
  analytics.logEvent(
    name: 'order_completed',
    parameters: {
      'order_id': orderId,
    },
  );
}

class CustomerOrdersPage extends StatefulWidget {
  final String userId;
  const CustomerOrdersPage({required this.userId, super.key});

  @override
  State<CustomerOrdersPage> createState() => _CustomerOrdersPageState();
}

class _CustomerOrdersPageState extends State<CustomerOrdersPage> {
  // Function to check if service date has passed
  bool _isServiceDatePassed(String? serviceDate) {
    if (serviceDate == null || serviceDate.isEmpty) {
      return false; // If no date, don't filter out
    }

    try {
      // Parse the service date - adjust the format based on how you store dates
      // Common formats: 'yyyy-MM-dd', 'MM/dd/yyyy', 'dd/MM/yyyy'
      DateTime parsedDate;

      // Try different date formats
      if (serviceDate.contains('/')) {
        // Assuming MM/dd/yyyy format
        parsedDate = DateFormat('MM/dd/yyyy').parse(serviceDate);
      } else if (serviceDate.contains('-')) {
        // Assuming yyyy-MM-dd format
        parsedDate = DateFormat('yyyy-MM-dd').parse(serviceDate);
      } else {
        // If it's in another format, add more conditions or use a default
        return false;
      }

      // Get current date without time
      DateTime today = DateTime.now();
      DateTime currentDateOnly = DateTime(today.year, today.month, today.day);
      DateTime serviceDateOnly = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);

      // Return true if service date is before today
      return serviceDateOnly.isBefore(currentDateOnly);
    } catch (e) {
      // If parsing fails, don't filter out the order
      print('Error parsing date: $serviceDate, Error: $e');
      return false;
    }
  }

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

      final orderData = orderSnapshot.data()!;
      final String? selectedWorkerId = orderData['selectedWorkerId'] as String?;

      if (selectedWorkerId == null) {
        throw Exception('No worker was selected for this order. Cannot submit review.');
      }

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(orderRef);
        if (!snapshot.exists) throw Exception('Order does not exist!');

        // Update the order status to 'completed'
        transaction.update(orderRef, {'status': 'completed'});

        logOrderCompleted(orderId);
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
    final ordersRef = FirebaseFirestore.instance
        .collection('orders')
        .where('customerId', isEqualTo: widget.userId);

    return Scaffold(
      backgroundColor: const Color(0xFFE0F2FE), // Light blue background
      appBar: AppBar(
        backgroundColor: const Color(0xFF38BDF8), // Full header background in blue
        elevation: 0,
        centerTitle: true, // Center the title
        title: const Text(
          "My Orders",
          style: TextStyle(
            color: Colors.white, // White text for better contrast
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white), // White icons
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
          final unfiltered_orders = snapshot.data!.docs;

          // Filter out orders with passed service dates
          final orders = unfiltered_orders.where((order) {
            final data = order.data()! as Map<String, dynamic>;
            final serviceDate = data['serviceDate'] as String?;
            return !_isServiceDatePassed(serviceDate);
          }).toList();

          if (orders.isEmpty) {
            return const Center(
              child: Text(
                'No orders found.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final data = order.data()! as Map<String, dynamic>;

              final int applicationCount = (data['applications'] as List<dynamic>? ?? []).length;
              final String? selectedWorkerId = data['selectedWorkerId'] as String?;
              final String orderStatus = data['status'] as String? ?? 'pending';

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
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header section with service name and status
                        Row(
                          children: [
                            // Service name in black text
                            Text(
                              data['service'] ?? 'N/A',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            // Status chip with orange color for pending
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: orderStatus == 'assigned'
                                    ? const Color(0xFF3B82F6) // Blue for assigned
                                    : orderStatus == 'completed'
                                    ? const Color(0xFF10B981) // Green for completed
                                    : const Color(0xFFF59E0B), // Orange for pending
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    orderStatus == 'assigned'
                                        ? Icons.person_add
                                        : orderStatus == 'completed'
                                        ? Icons.task_alt
                                        : Icons.schedule,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    orderStatus.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Location row with icon
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Color(0xFF38BDF8),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                (data['location'] != null && data['location'] is Map<String, dynamic>)
                                    ? data['location']['address'] ?? 'N/A'
                                    : 'N/A',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Date and time row
                        Row(
                          children: [
                            // Date
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  color: Color(0xFF38BDF8),
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  data['serviceDate'] ?? 'N/A',
                                  style: const TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 24),
                            // Time
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  color: Color(0xFF38BDF8),
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  (data['serviceTime'] as String?) ?? 'N/A',
                                  style: const TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Category row with light blur icon (no "Category:" text)
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF38BDF8).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.build_circle_outlined,
                                color: const Color(0xFF38BDF8).withOpacity(0.7),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                data['category'] ?? 'N/A',
                                style: const TextStyle(
                                  color: Color(0xFF1E293B),
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Price row with light blue blur icon (no "Price:" text, using Rs.)
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF38BDF8).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.payments_outlined,
                                color: const Color(0xFF38BDF8).withOpacity(0.7),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Rs. ${data['priceOffer']}',
                                style: const TextStyle(
                                  color: Color(0xFF1E293B),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Mark Complete Button
                        if (showMarkCompleteButton)
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: () => _markOrderComplete(context, order.id, widget.userId),
                              icon: const Icon(Icons.check_circle_outline, size: 18),
                              label: const Text('Mark Complete'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),

                        if (showMarkCompleteButton) const SizedBox(height: 12),

                        // Divider
                        Container(
                          height: 1,
                          color: const Color(0xFFE2E8F0),
                        ),
                        const SizedBox(height: 12),

                        // Applications count
                        Text(
                          'Applications: $applicationCount',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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
        backgroundColor: const Color(0xFF38BDF8), // Matching theme blue
        onPressed: () => _showAddOrderModal(context, widget.userId),
        child: const Icon(Icons.add, size: 28, color: Colors.white),
      ),
    );
  }

  // Helper widget to build detail rows
  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 14,
              ),
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
          'status': 'assigned',
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

// Review Form with updated theme
class _ReviewForm extends StatefulWidget {
  final String orderId;
  final String customerId;
  final String workerId;

  const _ReviewForm({
    required this.orderId,
    required this.customerId,
    required this.workerId,
  });

  @override
  _ReviewFormState createState() => _ReviewFormState();
}

class _ReviewFormState extends State<_ReviewForm> {
  double _rating = 3.0;
  final TextEditingController _reviewTextController = TextEditingController();
  bool _isSubmitting = false;

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
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.workerId)
          .collection('reviews')
          .add({
        'orderId': widget.orderId,
        'customerId': widget.customerId,
        'workerId': widget.workerId,
        'rating': _rating,
        'reviewText': _reviewTextController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted successfully!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
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
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
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
            const Text(
              'Rate Your Service',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
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
                    color: const Color(0xFFF59E0B),
                    size: 36.0,
                  ),
                  onPressed: () {
                    setState(() {
                      _rating = (index + 1).toDouble();
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
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
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
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}