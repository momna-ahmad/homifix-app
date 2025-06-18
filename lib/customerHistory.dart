import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CustomerHistoryPage extends StatelessWidget {
  final String userId;
  const CustomerHistoryPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order History'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('customerId', isEqualTo: userId)
            .where('status', isEqualTo: 'completed')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final orders = snapshot.data?.docs ?? [];

          if (orders.isEmpty) {
            return const Center(
              child: Text('No completed orders yet.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final order = orders[index].data() as Map<String, dynamic>;

              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Service title
                      Row(
                        children: [
                          const Icon(Icons.build, color: Colors.blueAccent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${order['category']?.toString().toUpperCase() ?? 'SERVICE'} - ${order['service'] ?? 'Unknown'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Location
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 20),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              order['location']?['address'] ?? 'N/A',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),

                      // Date & Time
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 18),
                          const SizedBox(width: 6),
                          Text(order['serviceDate'] ?? ''),
                          const SizedBox(width: 12),
                          const Icon(Icons.access_time, size: 18),
                          const SizedBox(width: 6),
                          Text(order['serviceTime'] ?? ''),
                        ],
                      ),

                      // Price
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.attach_money, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            'Rs. ${(order['applications'] != null && order['applications'].isNotEmpty) ? order['applications'][0]['price'] ?? 'N/A' : 'N/A'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),

                      // Status
                      const SizedBox(height: 10),
                      Row(
                        children: const [
                          Icon(Icons.check_circle, color: Colors.green, size: 20),
                          SizedBox(width: 6),
                          Text(
                            'Status: Completed',
                            style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
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
