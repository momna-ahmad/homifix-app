import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'addOrderPage.dart';
import 'orderApplications.dart';


class CustomerOrdersPage extends StatelessWidget {
  final String userId;
  const CustomerOrdersPage({required this.userId, super.key});
  void _showAddOrderModal(BuildContext context, String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OrderForm(userId: userId),
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
        backgroundColor: theme.colorScheme.primary,
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
              final selectedWorkerId = data['selectedWorkerId'] as String?;
              final orderIsAssigned = selectedWorkerId != null;

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
                          const Spacer(),
                          if (orderIsAssigned)
                            Chip(
                              label: const Text('Assigned'),
                              backgroundColor: Colors.green.shade100,
                              avatar: const Icon(Icons.check_circle, color: Colors.green),
                            )
                          else
                            Chip(
                              label: const Text('Pending'),
                              backgroundColor: Colors.orange.shade100,
                              avatar: const Icon(Icons.hourglass_top, color: Colors.orange),
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
                      _buildEmojiInfoRow('⏰', 'Time:', data['serviceTime']),
                      const Divider(height: 24, thickness: 1),

                      Text(
                        'Applications: $applicationCount',
                        style: theme.textTheme.titleSmall!.copyWith(fontWeight: FontWeight.bold),
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
        backgroundColor: Colors.lightBlue.shade700,
        onPressed: () => _showAddOrderModal(context, userId),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

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
          'status': 'accepted',
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Worker accepted'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

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
        SnackBar(
          content: const Text('Worker rejected'),
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
