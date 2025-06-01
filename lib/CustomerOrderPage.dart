import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'addOrderPage.dart';


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

              final applications =
              (data['applications'] as List<dynamic>? ?? [])
                  .cast<Map<String, dynamic>>();
              final selectedWorkerId = data['selectedWorkerId'] as String?;
              final orderIsAssigned = selectedWorkerId != null;

              return AnimatedContainer(
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
                      _buildEmojiInfoRow('📍', 'Location:', data['location']),
                      _buildEmojiInfoRow('💰', 'Offered Price:', '\$${data['priceOffer']}'),
                      _buildEmojiInfoRow('📅', 'Date:', data['serviceDate']),
                      _buildEmojiInfoRow('⏰', 'Time:', data['serviceTime']),
                      const Divider(height: 24, thickness: 1),

                      Text(
                        'Applications:',
                        style: theme.textTheme.titleSmall!.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (applications.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('No applications yet.'),
                        )
                      else
                        Column(
                          children: applications.map((app) {
                            final workerId = app['workerId'] as String? ?? 'Unknown';
                            final workerName = app['workerName'] as String? ?? 'Unknown';
                            final offerPrice = app['offerPrice']?.toString() ?? 'N/A';
                            final message = app['message'] as String? ?? '';
                            final timestampRaw = app['timestamp'];
                            DateTime? timestamp;
                            if (timestampRaw is Timestamp) {
                              timestamp = timestampRaw.toDate();
                            } else if (timestampRaw is String) {
                              timestamp = DateTime.tryParse(timestampRaw);
                            }
                            final formattedTime = timestamp != null
                                ? DateFormat('MMM dd, yyyy • HH:mm').format(timestamp)
                                : 'Unknown';

                            final isSelected = selectedWorkerId == workerId;

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              color: isSelected
                                  ? Colors.green.shade100
                                  : orderIsAssigned
                                  ? Colors.grey.shade200
                                  : theme.cardColor,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: theme.colorScheme.primaryContainer,
                                  child: const Icon(Icons.person, color: Colors.white),
                                ),
                                title: Text(
                                  workerName,
                                  style: theme.textTheme.bodyLarge!.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Offer: \$$offerPrice'),
                                    Text('Message: $message'),
                                    Text('Applied at: $formattedTime'),
                                    if (orderIsAssigned && !isSelected)
                                      Text(
                                        'Worker Booked',
                                        style: TextStyle(
                                          color: Colors.red.shade400,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: orderIsAssigned
                                    ? (isSelected
                                    ? const Icon(Icons.check_circle, color: Colors.green)
                                    : null)
                                    : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.check, color: Colors.green),
                                      tooltip: 'Accept',
                                      onPressed: () => _acceptWorker(
                                          context, order.id, workerId),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.red),
                                      tooltip: 'Reject',
                                      onPressed: () => _rejectWorker(
                                          context, order.id, workerId),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                    ],
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
