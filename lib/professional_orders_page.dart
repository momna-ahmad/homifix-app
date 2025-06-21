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
  final List<String> _statusOptions = ['All', 'Pending', 'Accepted', 'In Progress', 'Completed', 'Cancelled'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Orders',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 20,
                color: Color(0xFF2D3748),
              ),
            ),
            Text(
              widget.professionalName,
              style: const TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 14,
                color: Color(0xFF718096),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2D3748)),
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
                      selectedColor: const Color(0xFF4299E1),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF4A5568),
                        fontWeight: FontWeight.w500,
                      ),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF4299E1) : const Color(0xFFE2E8F0),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Orders List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getOrdersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4299E1)),
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
                        Text(
                          'Error loading orders',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF718096),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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

                final orders = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    final orderData = order.data() as Map<String, dynamic>;

                    return _buildOrderCard(orderData, order.id);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getOrdersStream() {
    Query query = FirebaseFirestore.instance
        .collection('orders')
        .where('professionalId', isEqualTo: widget.professionalId)
        .orderBy('createdAt', descending: true);

    if (_selectedStatus != 'All') {
      query = query.where('status', isEqualTo: _selectedStatus.toLowerCase());
    }

    return query.snapshots();
  }

  Widget _buildOrderCard(Map<String, dynamic> orderData, String orderId) {
    final serviceName = orderData['serviceName']?.toString() ?? 'Unknown Service';
    final customerName = orderData['customerName']?.toString() ?? 'Unknown Customer';
    final status = orderData['status']?.toString() ?? 'pending';
    final amount = orderData['amount']?.toString() ?? '0';
    final address = orderData['address']?.toString() ?? 'No address provided';
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    serviceName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                ),
                _buildStatusChip(status),
              ],
            ),

            const SizedBox(height: 12),

            // Customer Info
            Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 16,
                  color: Color(0xFF718096),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    customerName,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF4A5568),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Phone
            if (phone != 'No phone provided')
              Row(
                children: [
                  const Icon(
                    Icons.phone_outlined,
                    size: 16,
                    color: Color(0xFF718096),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      phone,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF4A5568),
                      ),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 8),

            // Address
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: Color(0xFF718096),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    address,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF4A5568),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

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
                          color: Color(0xFF4299E1),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Scheduled: ${DateFormat('MMM dd, yyyy - hh:mm a').format(scheduledDate)}',
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

            const SizedBox(height: 12),

            // Amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Amount:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF718096),
                  ),
                ),
                Text(
                  '₹$amount',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF38A169),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor = Colors.white;

    switch (status.toLowerCase()) {
      case 'completed':
        backgroundColor = const Color(0xFF38A169);
        break;
      case 'in progress':
      case 'inprogress':
        backgroundColor = const Color(0xFF4299E1);
        break;
      case 'accepted':
        backgroundColor = const Color(0xFF805AD5);
        break;
      case 'pending':
        backgroundColor = const Color(0xFFF6AD55);
        break;
      case 'cancelled':
        backgroundColor = const Color(0xFFE53E3E);
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
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
