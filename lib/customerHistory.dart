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
      backgroundColor: const Color(0xFFF0F9FF), // Light blue background from sample
      appBar: AppBar(
        title: const Text(
          'My Orders',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('customerId', isEqualTo: widget.userId)
            .snapshots(), // Removed status filter to get all orders
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF22D3EE)),
              ),
            );
          }

          if (snapshot.hasError) {
            print('Firestore Error: ${snapshot.error}');
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 14,
                ),
              ),
            );
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
          print('=== ALL ORDERS BEFORE TODAY ===');
          print('User ID: ${widget.userId}');
          print('Today: ${todayMidnight.toString()}');
          print('Found ${orders.length} orders');

          for (int i = 0; i < orders.length; i++) {
            final order = orders[i].data() as Map<String, dynamic>;
            print('--- Order ${i + 1} ---');
            print('Order ID: ${orders[i].id}');
            print('Customer ID: ${order['customerId']}');
            print('Status: ${order['status']}');
            print('Order Type: ${order['orderType']}');
            print('Service Date: ${order['serviceDate']}');
            print('Service: ${order['service']}');
            print('Category: ${order['category']}');
            print('Location: ${order['location']?['address']}');
            print('Price: ${order['applications']?[0]?['price']}');
            print('Applications: ${order['applications']?.length ?? 0}');
            print('');
          }

          if (orders.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final order = orders[index].data() as Map<String, dynamic>;
              return _buildOrderCard(order);
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    // Get status and determine color
    final status = order['status']?.toString().toLowerCase() ?? 'pending';
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'completed':
        statusColor = const Color(0xFF10B981); // Green
        statusIcon = Icons.check_circle;
        break;
      case 'cancelled':
        statusColor = const Color(0xFFEF4444); // Red
        statusIcon = Icons.cancel;
        break;
      case 'in_progress':
        statusColor = const Color(0xFFF59E0B); // Orange
        statusIcon = Icons.hourglass_empty;
        break;
      default:
        statusColor = const Color(0xFF64748B); // Gray
        statusIcon = Icons.pending;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 0,
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
            // Service title and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '${order['category']?.toString().toUpperCase() ?? 'SERVICE'} - ${order['service'] ?? 'Unknown'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        statusIcon,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        status.toUpperCase(),
                        style: const TextStyle(
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
                  color: Color(0xFF22D3EE),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order['location']?['address'] ?? 'N/A',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
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
                      color: Color(0xFF22D3EE),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatDate(order['serviceDate']),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      color: Color(0xFF22D3EE),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      order['serviceTime'] ?? 'N/A',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Order Type (if available)
            if (order['orderType'] != null) ...[
              Row(
                children: [
                  const Icon(
                    Icons.category,
                    color: Color(0xFF22D3EE),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Type: ${order['orderType']}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Category
            Row(
              children: [
                const Icon(
                  Icons.build,
                  color: Color(0xFF22D3EE),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  order['category'] ?? 'N/A',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
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
                  color: Color(0xFF22D3EE),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  'Rs. ${(order['applications'] != null && order['applications'].isNotEmpty) ? order['applications'][0]['price'] ?? 'N/A' : 'N/A'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Applications count
            Row(
              children: [
                const Icon(
                  Icons.people,
                  color: Color(0xFF22D3EE),
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  'Applications: ${order['applications']?.length ?? 0}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF22D3EE).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.history,
              size: 48,
              color: Color(0xFF22D3EE),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Past Orders',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'You don\'t have any orders from previous dates.\nYour completed orders will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';

    DateTime? dateTime;
    if (date is Timestamp) {
      dateTime = date.toDate();
    } else if (date is String) {
      try {
        dateTime = DateTime.parse(date);
      } catch (e) {
        return date;
      }
    }

    if (dateTime != null) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }

    return date.toString();
  }
}