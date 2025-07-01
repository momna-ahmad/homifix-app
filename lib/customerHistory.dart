import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CustomerHistoryPage extends StatefulWidget {
  final String userId;
  const CustomerHistoryPage({super.key, required this.userId});

  @override
  State<CustomerHistoryPage> createState() => _CustomerHistoryPageState();
}

class _CustomerHistoryPageState extends State<CustomerHistoryPage> {
  // --- Standardized Color & Style Definitions (from ProfessionalProfile) ---
  // Primary accent blue color
  Color get _primaryBlue => const Color(0xFF0EA5E9);
  // Secondary blue for gradients
  Color get _secondaryBlue => const Color(0xFF22D3EE);
  // Darker text color
  Color get _darkTextColor => const Color(0xFF1E293B);
  // Secondary text color/grey
  Color get _secondaryTextColor => const Color(0xFF64748B);
  // Very light blue for overall background
  Color get _lightBlueBackground => const Color(0xFFF0F9FF);
  // White for card backgrounds
  Color get _cardBackground => Colors.white;
  // Consistent shadow style for cards
  BoxShadow get _cardShadow => BoxShadow(
    color: Colors.black.withOpacity(0.05),
    spreadRadius: 0,
    blurRadius: 10,
    offset: const Offset(0, 4),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightBlueBackground,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream:
              FirebaseFirestore.instance
                  .collection('orders')
                  .where('customerId', isEqualTo: widget.userId)
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _primaryBlue,
                  ), // ✅ Use primary blue
                ),
              );
            }

            if (snapshot.hasError) {
              print('Firestore Error: ${snapshot.error}');
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: TextStyle(
                    color: _secondaryTextColor, // ✅ Use secondary text color
                    fontSize: 14,
                  ),
                ),
              );
            }

            final allOrders = snapshot.data?.docs ?? [];

            // Filter orders with dates before today on the client side
            final DateTime today = DateTime.now();
            final DateTime todayMidnight = DateTime(
              today.year,
              today.month,
              today.day,
            );

            final orders = allOrders.where((doc) {
              final order = doc.data() as Map<String, dynamic>;

              // First check: customerId must match the logged-in user
              final orderCustomerId = order['customerId']?.toString() ?? '';
              if (orderCustomerId != widget.userId) {
                return false;
              }

              // Get order status
              final status = order['status']?.toString().toLowerCase() ?? '';

              // Condition 1: If status is completed, include regardless of date
              if (status == 'completed') {
                return true;
              }

              // Condition 2: For any status, check if service date has passed
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

              // Check if order date is before today (past date)
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

              return (dateB ?? DateTime.now()).compareTo(
                dateA ?? DateTime.now(),
              );
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
              print('Location: ${_getLocationAddress(order['location'])}');
              print('Price: ${_getOrderPrice(order)}');
              print('Applications: ${order['applications']?.length ?? 0}');
              print('');
            }

            if (orders.isEmpty) {
              return Column(
                children: [
                  // ✅ Header moved to very top with back button
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_primaryBlue, _secondaryBlue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [_cardShadow],
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: const Text(
                      'My Order History',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // Empty state
                  Expanded(child: _buildEmptyState()),
                ],
              );
            }

            return Column(
              children: [
                // ✅ Header moved to very top with back button
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_primaryBlue, _secondaryBlue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [_cardShadow],
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: const Text(
                    'My Order History',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                // Orders List
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final order =
                          orders[index].data() as Map<String, dynamic>;
                      return _buildOrderCard(order);
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ✅ Helper method to safely get location address
  String _getLocationAddress(dynamic location) {
    try {
      if (location == null) return 'N/A';

      if (location is Map<String, dynamic>) {
        return location['address']?.toString() ?? 'N/A';
      }

      if (location is String) {
        return location;
      }

      return 'N/A';
    } catch (e) {
      print('Error getting location address: $e');
      return 'N/A';
    }
  }

  // ✅ Helper method to safely get order price
  String _getOrderPrice(Map<String, dynamic> order) {
    try {
      // First try to get from applications
      if (order['applications'] != null && order['applications'] is List) {
        final applications = order['applications'] as List;
        if (applications.isNotEmpty) {
          final firstApp = applications[0];
          if (firstApp is Map<String, dynamic> && firstApp['price'] != null) {
            return firstApp['price'].toString();
          }
        }
      }

      // Fallback to priceOffer or price from order
      if (order['priceOffer'] != null) {
        return order['priceOffer'].toString();
      }

      if (order['price'] != null) {
        return order['price'].toString();
      }

      return 'N/A';
    } catch (e) {
      print('Error getting order price: $e');
      return 'N/A';
    }
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
      case 'assigned':
        statusColor = _primaryBlue; // ✅ Use primary blue
        statusIcon = Icons.assignment;
        break;
      default:
        statusColor = _secondaryTextColor; // ✅ Use secondary text color
        statusIcon = Icons.pending;
    }

    return Container(
      decoration: BoxDecoration(
        color: _cardBackground, // ✅ Use white card background
        borderRadius: BorderRadius.circular(16),
        boxShadow: [_cardShadow], // ✅ Use consistent shadow
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _darkTextColor, // ✅ Use dark text color
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
                      Icon(statusIcon, color: Colors.white, size: 16),
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

            // ✅ Location with safe access
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on,
                  color: _primaryBlue, // ✅ Use primary blue
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getLocationAddress(order['location']),
                    style: TextStyle(
                      fontSize: 14,
                      color: _secondaryTextColor, // ✅ Use secondary text color
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
                    Icon(
                      Icons.calendar_today,
                      color: _primaryBlue, // ✅ Use primary blue
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatDate(order['serviceDate']),
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            _secondaryTextColor, // ✅ Use secondary text color
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      color: _primaryBlue, // ✅ Use primary blue
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      order['serviceTime']?.toString() ?? 'N/A',
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            _secondaryTextColor, // ✅ Use secondary text color
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
                  Icon(
                    Icons.category,
                    color: _primaryBlue, // ✅ Use primary blue
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Type: ${order['orderType']}',
                    style: TextStyle(
                      fontSize: 14,
                      color: _secondaryTextColor, // ✅ Use secondary text color
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Category
            Row(
              children: [
                Icon(
                  Icons.build,
                  color: _primaryBlue, // ✅ Use primary blue
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  order['category']?.toString() ?? 'N/A',
                  style: TextStyle(
                    fontSize: 14,
                    color: _secondaryTextColor, // ✅ Use secondary text color
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ✅ Price with safe access
            Row(
              children: [
                Icon(
                  Icons.attach_money,
                  color: _primaryBlue, // ✅ Use primary blue
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  'Rs. ${_getOrderPrice(order)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _darkTextColor, // ✅ Use dark text color
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Applications count
            Row(
              children: [
                Icon(
                  Icons.people,
                  color: _primaryBlue, // ✅ Use primary blue
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  'Applications: ${order['applications']?.length ?? 0}',
                  style: TextStyle(
                    fontSize: 14,
                    color: _secondaryTextColor, // ✅ Use secondary text color
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
              color: _primaryBlue.withOpacity(
                0.1,
              ), // ✅ Use primary blue with opacity
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.history,
              size: 48,
              color: _primaryBlue, // ✅ Use primary blue
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Past Orders',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _darkTextColor, // ✅ Use dark text color
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You don\'t have any orders from previous dates.\nYour completed orders will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: _secondaryTextColor, // ✅ Use secondary text color
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
