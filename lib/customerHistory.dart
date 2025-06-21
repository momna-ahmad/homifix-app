import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CustomerHistoryPage extends StatefulWidget {
  final String userId;
  const CustomerHistoryPage({super.key, required this.userId});

  @override
  State<CustomerHistoryPage> createState() => _CustomerHistoryPageState();
}

class _CustomerHistoryPageState extends State<CustomerHistoryPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      appBar: AppBar(
        title: const Text(
          'My Orders',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF42A5F5),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('customerId', isEqualTo: widget.userId)
            .where('status', isEqualTo: 'completed')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            print('Firestore Error: ${snapshot.error}');
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final allOrders = snapshot.data?.docs ?? [];

          // Filter orders with dates before today on the client side
          final DateTime today = DateTime.now();
          final DateTime todayMidnight = DateTime(today.year, today.month, today.day);

          final orders = allOrders.where((doc) {
            final order = doc.data() as Map<String, dynamic>;

            // Handle different date formats
            var serviceDate = order['serviceDate'];
            DateTime? orderDate;

            if (serviceDate is Timestamp) {
              orderDate = serviceDate.toDate();
            } else if (serviceDate is String) {
              // Try to parse string date (adjust format as needed)
              try {
                orderDate = DateTime.parse(serviceDate);
              } catch (e) {
                print('Error parsing date: $serviceDate');
                return false;
              }
            }

            // Check if order date is before today
            if (orderDate != null) {
              return orderDate.isBefore(todayMidnight);
            }

            return false;
          }).toList();

          // Sort by date (most recent first)
          orders.sort((a, b) {
            final orderA = a.data() as Map<String, dynamic>;
            final orderB = b.data() as Map<String, dynamic>;

            DateTime? dateA, dateB;

            if (orderA['serviceDate'] is Timestamp) {
              dateA = (orderA['serviceDate'] as Timestamp).toDate();
            } else if (orderA['serviceDate'] is String) {
              try {
                dateA = DateTime.parse(orderA['serviceDate']);
              } catch (e) {
                dateA = DateTime.now();
              }
            }

            if (orderB['serviceDate'] is Timestamp) {
              dateB = (orderB['serviceDate'] as Timestamp).toDate();
            } else if (orderB['serviceDate'] is String) {
              try {
                dateB = DateTime.parse(orderB['serviceDate']);
              } catch (e) {
                dateB = DateTime.now();
              }
            }

            return (dateB ?? DateTime.now()).compareTo(dateA ?? DateTime.now());
          });

          // Print orders to console for debugging
          print('=== COMPLETED ORDERS BEFORE TODAY ===');
          print('User ID: ${widget.userId}');
          print('Today: ${todayMidnight.toString()}');
          print('Found ${orders.length} orders');

          for (int i = 0; i < orders.length; i++) {
            final order = orders[i].data() as Map<String, dynamic>;
            print('--- Order ${i + 1} ---');
            print('Order ID: ${orders[i].id}');
            print('Customer ID: ${order['customerId']}');
            print('Status: ${order['status']}');
            print('Service Date: ${order['serviceDate']}');
            print('Service: ${order['service']}');
            print('Category: ${order['category']}');
            print('Location: ${order['location']?['address']}');
            print('Price: ${order['applications']?[0]?['price']}');
            print('Applications: ${order['applications']?.length ?? 0}');
            print('');
          }

          if (orders.isEmpty) {
            return const Center(
              child: Text('No completed orders from previous dates.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final order = orders[index].data() as Map<String, dynamic>;

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Service title and status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              '${order['category']?.toString().toUpperCase() ?? 'SERVICE'} - ${order['service'] ?? 'Unknown'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'COMPLETED',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Location
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Color(0xFF42A5F5),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              order['location']?['address'] ?? 'N/A',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Date and Time
                      Row(
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                color: Color(0xFF42A5F5),
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                order['serviceDate']?.toString() ?? '',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 20),
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                color: Color(0xFF42A5F5),
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                order['serviceTime'] ?? '',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Category
                      Row(
                        children: [
                          const Icon(
                            Icons.build,
                            color: Color(0xFF42A5F5),
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            order['category'] ?? 'N/A',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Price
                      Row(
                        children: [
                          const Icon(
                            Icons.attach_money,
                            color: Color(0xFF42A5F5),
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Rs. ${(order['applications'] != null && order['applications'].isNotEmpty) ? order['applications'][0]['price'] ?? 'N/A' : 'N/A'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Applications count
                      Text(
                        'Applications: ${order['applications']?.length ?? 0}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
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