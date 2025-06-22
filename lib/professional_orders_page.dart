import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ProfessionalOrdersPage extends StatefulWidget {
  final String professionalId;
  final String professionalName;

  const ProfessionalOrdersPage({
    super.key,
    required this.professionalId,
    required this.professionalName,
  });

  @override
  State<ProfessionalOrdersPage> createState() => _ProfessionalOrdersPageState();
}

class _ProfessionalOrdersPageState extends State<ProfessionalOrdersPage> {
  String _selectedStatus = 'All';
  final List<String> _statusOptions = ['All', 'Pending', 'Assigned', 'Completed'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        title: Text(
          '${widget.professionalName}\'s Orders',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: Color(0xFF1A202C),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A202C)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: const Color(0xFFE2E8F0),
          ),
        ),
      ),
      body: Column(
        children: [
          // Stay Organized Card
          Container(
            margin: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF22D3EE),
                  Color(0xFF0EA5E9),
                ],
              ),
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Order Management',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Track and manage professional orders',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.assignment,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Status Filter
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _statusOptions.map((status) {
                  final isSelected = _selectedStatus == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(status),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedStatus = status;
                        });
                      },
                      backgroundColor: Colors.white,
                      selectedColor: const Color(0xFF22D3EE),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF4A5568),
                        fontWeight: FontWeight.w500,
                      ),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF22D3EE) : const Color(0xFFE2E8F0),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Orders List
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _getOrdersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF22D3EE)),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red[300],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Error loading orders',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF718096),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final orders = snapshot.data ?? [];

                if (orders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No orders found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF718096),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final orderData = orders[index];
                    return _buildOrderCard(orderData, index.toString());
                  },
                );
              },
            )
          ),
        ],
      ),
    );
  }

  Stream<List<Map<String, dynamic>>> _getOrdersStream() async* {
    final docSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.professionalId)
        .get();

    if (docSnapshot.exists) {
      final data = docSnapshot.data();
      final orders = data?['orders'] as List<dynamic>?;

      if (orders != null) {
        List<Map<String, dynamic>> filteredOrders = orders
            .where((order) {
          final status = (order['completionStatus'] ?? '').toString().toLowerCase();
          return _selectedStatus == 'All' || status == _selectedStatus.toLowerCase();
        })
            .map((order) => order as Map<String, dynamic>)
            .toList();

        yield filteredOrders;
      } else {
        yield [];
      }
    } else {
      yield [];
    }
  }



  Widget _buildOrderCard(Map<String, dynamic> orderData, String orderId) {
    final serviceName = orderData['serviceName']?.toString() ??
        orderData['service']?.toString() ?? 'Unknown Service';
    final customerName = orderData['customerName']?.toString() ?? 'Unknown Customer';
    final status = orderData['status']?.toString() ?? 'pending';
    final amount = orderData['amount']?.toString() ??
        orderData['priceOffer']?.toString() ?? '0';
    final address = orderData['address']?.toString() ??
        ((orderData['location'] != null && orderData['location'] is Map<String, dynamic>)
            ? orderData['location']['address'] ?? 'No address provided'
            : 'No address provided');
    final phone = orderData['phone']?.toString() ?? 'No phone provided';

    // Handle different timestamp formats
    DateTime? createdAt;
    DateTime? scheduledDate;

    try {
      if (orderData['createdAt'] != null) {
        if (orderData['createdAt'] is Timestamp) {
          createdAt = (orderData['createdAt'] as Timestamp).toDate();
        } else if (orderData['createdAt'] is String) {
          createdAt = DateTime.parse(orderData['createdAt']);
        }
      }

      if (orderData['scheduledDate'] != null) {
        if (orderData['scheduledDate'] is Timestamp) {
          scheduledDate = (orderData['scheduledDate'] as Timestamp).toDate();
        } else if (orderData['scheduledDate'] is String) {
          scheduledDate = DateTime.parse(orderData['scheduledDate']);
        }
      } else if (orderData['serviceDate'] != null) {
        // Try to parse serviceDate as fallback
        try {
          if (orderData['serviceDate'] is String) {
            final dateStr = orderData['serviceDate'] as String;
            if (dateStr.contains('/')) {
              scheduledDate = DateFormat('MM/dd/yyyy').parse(dateStr);
            } else if (dateStr.contains('-')) {
              scheduledDate = DateFormat('yyyy-MM-dd').parse(dateStr);
            }
          }
        } catch (e) {
          print('Error parsing serviceDate: $e');
        }
      }
    } catch (e) {
      print('Error parsing dates: $e');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22D3EE).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.category,
                    color: Color(0xFF22D3EE),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    serviceName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      color: Color(0xFF1A202C),
                    ),
                  ),
                ),
                _buildStatusChip(status),
              ],
            ),

            const SizedBox(height: 16),

            // Customer Info
            _buildDetailItem(Icons.person_outline, 'Customer', customerName),
            const SizedBox(height: 8),

            // Phone
            if (phone != 'No phone provided')
              _buildDetailItem(Icons.phone_outlined, 'Phone', phone),
            if (phone != 'No phone provided') const SizedBox(height: 8),

            // Address
            _buildDetailItem(Icons.location_on_outlined, 'Address', address),
            const SizedBox(height: 8),

            // Amount
            _buildDetailItem(Icons.attach_money, 'Amount', '₹$amount'),

            const SizedBox(height: 16),

            // Time Information
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  if (createdAt != null)
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 16,
                          color: Color(0xFF718096),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Ordered: ${DateFormat('MMM dd, yyyy - hh:mm a').format(createdAt)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF4A5568),
                          ),
                        ),
                      ],
                    ),

                  if (scheduledDate != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 16,
                          color: Color(0xFF22D3EE),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Scheduled: ${DateFormat('MMM dd, yyyy').format(scheduledDate)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF4A5568),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String? value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: const Color(0xFF718096),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF718096),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value ?? 'N/A',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1A202C),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;

    switch (status.toLowerCase()) {
      case 'completed':
        backgroundColor = const Color(0xFF059669);
        break;
      case 'assigned':
        backgroundColor = const Color(0xFF22D3EE);
        break;
      case 'pending':
        backgroundColor = const Color(0xFFD97706);
        break;
      case 'cancelled':
        backgroundColor = const Color(0xFFDC2626);
        break;
      case 'inprogress':
        backgroundColor = const Color(0xFF7C3AED);
        break;
      default:
        backgroundColor = const Color(0xFF718096);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}