import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'addOrderPage.dart';
import 'orderApplications.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

// Global analytics instance
final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

// Optimized analytics logging
void logOrderCompleted(String orderId) {
  _analytics.logEvent(
    name: 'order_completed',
    parameters: {'order_id': orderId},
  );
}

class CustomerOrderPage extends StatefulWidget {
  final String userId;
  const CustomerOrderPage({required this.userId, super.key});

  @override
  State<CustomerOrderPage> createState() => _CustomerOrderPageState();
}

class _CustomerOrderPageState extends State<CustomerOrderPage>
    with AutomaticKeepAliveClientMixin {

  // State variables
  int _selectedTab = 0;

  // Cache for provider names to avoid repeated Firestore calls
  final Map<String, String> _providerNameCache = {};

  @override
  bool get wantKeepAlive => true; // Keep state alive for better performance

  // Optimized provider name fetching with caching
  Future<String> _getProviderName(String? providerId, String? selectedWorkerId) async {
    final String workerId = selectedWorkerId ?? providerId ?? '';
    if (workerId.isEmpty) return 'Unknown Provider';

    // Check cache first
    if (_providerNameCache.containsKey(workerId)) {
      return _providerNameCache[workerId]!;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(workerId)
          .get();

      String providerName = 'Provider';
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        providerName = userData['name'] as String? ??
            userData['fullName'] as String? ??
            userData['displayName'] as String? ??
            'Provider';
      }

      // Cache the result
      _providerNameCache[workerId] = providerName;
      return providerName;
    } catch (e) {
      print('Error fetching provider name: $e');
      _providerNameCache[workerId] = 'Provider';
      return 'Provider';
    }
  }
  // Helper method to check if service date has passed
  bool _hasServiceDatePassed(Map<String, dynamic> data) {
    final String? serviceDateStr = data['serviceDate'] as String?;
    if (serviceDateStr == null || serviceDateStr.isEmpty) {
      return false; // If no date specified, don't filter out
    }

    try {
      // Parse the service date (assuming format is DD/MM/YYYY or similar)
      final DateTime serviceDate = DateFormat('dd/MM/yyyy').parse(serviceDateStr);
      final DateTime today = DateTime.now();

      // Check if service date is before today (ignoring time)
      return serviceDate.isBefore(DateTime(today.year, today.month, today.day));
    } catch (e) {
      print('Error parsing service date: $serviceDateStr, Error: $e');
      return false; // If parsing fails, don't filter out
    }
  }

  // Optimized modal showing
  void _showAddOrderModal(BuildContext context, String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OrderForm(userId: userId),
    );
  }

  // ✅ ENHANCED: Mark order complete with user orders array update
  Future<void> _markOrderComplete(
      BuildContext context,
      String orderId,
      String customerId,
      String orderType,
      ) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);
      final orderSnapshot = await orderRef.get();

      if (!orderSnapshot.exists) {
        throw Exception('Order does not exist for marking complete!');
      }

      final orderData = orderSnapshot.data()!;
      final String workerId = orderData['selectedWorkerId'] as String? ??
          orderData['providerId'] as String? ??
          orderData['workerId'] as String? ??
          '';

      if (workerId.isEmpty) {
        throw Exception('No provider found for this order. Cannot submit review.');
      }

      // ✅ NEW: Update completionStatus in user's orders array
      await _updateUserOrderCompletionStatus(workerId, orderId);

      // Use batch write for better performance
      final batch = FirebaseFirestore.instance.batch();
      batch.update(orderRef, {
        'status': 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();

      logOrderCompleted(orderId);

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order marked as completed'),
            backgroundColor: Colors.green,
          ),
        );
        _showReviewForm(context, orderId, customerId, workerId);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error marking order complete: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ✅ NEW: Update completionStatus in user's orders array
  Future<void> _updateUserOrderCompletionStatus(String workerId, String orderId) async {
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(workerId);
      final userSnapshot = await userRef.get();

      if (!userSnapshot.exists) {
        print('❌ User document does not exist: $workerId');
        return;
      }

      final userData = userSnapshot.data()!;
      final List<dynamic> orders = userData['orders'] as List<dynamic>? ?? [];

      print('🔍 Looking for orderId: $orderId in user: $workerId');
      print('📋 User has ${orders.length} orders');

      // Find and update the specific order in the array
      bool orderFound = false;
      for (int i = 0; i < orders.length; i++) {
        final order = orders[i] as Map<String, dynamic>;
        final String currentOrderId = order['orderId'] as String? ?? '';

        print('🔍 Checking order at index $i: $currentOrderId');

        if (currentOrderId == orderId) {
          print('✅ Found matching order! Updating completionStatus from ${order['completionStatus']} to completed');

          // Update the completionStatus to "completed"
          orders[i] = {
            ...order,
            'completionStatus': 'completed',
          };
          orderFound = true;
          break;
        }
      }

      if (orderFound) {
        // Update the user document with the modified orders array
        await userRef.update({
          'orders': orders,
        });
        print('✅ Successfully updated completionStatus to completed for orderId: $orderId');
      } else {
        print('❌ Order not found in user orders array: $orderId');
      }

    } catch (e) {
      print('❌ Error updating user order completion status: $e');
      // Don't throw error to prevent blocking the main completion flow
    }
  }

  void _showReviewForm(BuildContext context, String orderId, String customerId, String workerId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviewForm(
        orderId: orderId,
        customerId: customerId,
        workerId: workerId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF), // Light blue background
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Container(
              color: const Color(0xFFE6F3FF), // Light blue background between cards
              child: _selectedTab == 0 ? _buildAppliedOrders() : _buildPostedOrders(),
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedTab == 1 ? _buildFAB() : null,
    );
  }

  // AppBar with white background
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      title: const Text(
        "My Orders",
        style: TextStyle(
          color: Colors.black,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      iconTheme: const IconThemeData(color: Colors.black),
    );
  }

  // Header with WHITE background as shown in image
  Widget _buildHeader() {
    return Container(
      color: Colors.white, // WHITE background as shown in image
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStayOrganizedCard(),
          const SizedBox(height: 24),
          _buildTabButtons(),
        ],
      ),
    );
  }

  // Stay Organized Card matching the image design
  Widget _buildStayOrganizedCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00BFFF), Color(0xFF00ACC1)], // ✅ Updated color
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Stay Organized',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Manage your orders efficiently',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF00ACC1), // ✅ Updated color
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'View Orders',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_today_outlined,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  // Tab Buttons matching the image design
  Widget _buildTabButtons() {
    return Row(
      children: [
        Expanded(child: _buildTabButton(0, 'Applied')),
        const SizedBox(width: 16),
        Expanded(child: _buildTabButton(1, 'Posted')),
      ],
    );
  }

  Widget _buildTabButton(int index, String title) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedTab = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00ACC1) : const Color(0xFFE5E7EB), // ✅ Updated color
          borderRadius: BorderRadius.circular(25),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF6B7280),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  // Extracted FAB
  Widget _buildFAB() {
    return FloatingActionButton(
      backgroundColor: const Color(0xFF00ACC1), // ✅ Updated color
      onPressed: () => _showAddOrderModal(context, widget.userId),
      tooltip: 'Create New Job Post',
      child: const Icon(Icons.add, size: 28, color: Colors.white),
    );
  }

  // Applied Orders with light blue background
  Widget _buildAppliedOrders() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorWidget('Applied Orders Error: ${snapshot.error}');
        }

        if (!snapshot.hasData) {
          return _buildLoadingWidget('Loading your applications...');
        }

        // Filter and sort applied orders on client side
// Filter and sort applied orders on client side
        final appliedOrders = snapshot.data!.docs.where((order) {
          final data = order.data() as Map<String, dynamic>;
          final orderType = data['orderType'] as String? ?? '';
          final providerId = data['providerId'] as String?;
          final status = data['status'] as String? ?? '';

          // Filter out cancelled orders
          if (status.toLowerCase() == 'cancelled') {
            return false;
          }

          // Filter out orders with passed dates
          if (_hasServiceDatePassed(data)) {
            return false;
          }

          return orderType == 'customer_application' ||
              (orderType != 'customer_post' && providerId != null && providerId.isNotEmpty);
        }).toList();

        // Sort by createdAt on client side
        appliedOrders.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aCreated = aData['createdAt'] as Timestamp?;
          final bCreated = bData['createdAt'] as Timestamp?;

          if (aCreated == null && bCreated == null) return 0;
          if (aCreated == null) return 1;
          if (bCreated == null) return -1;

          return bCreated.compareTo(aCreated);
        });

        if (appliedOrders.isEmpty) {
          return _buildEmptyWidget(
            Icons.assignment_outlined,
            'No applications found.',
            'Apply to service providers to see them here.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: appliedOrders.length,
          itemBuilder: (context, index) {
            final order = appliedOrders[index];
            final data = order.data()! as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _ApplicationOrderCard(
                key: ValueKey(order.id),
                orderId: order.id,
                data: data,
                onMarkComplete: _markOrderComplete,
                getProviderName: _getProviderName,
                userId: widget.userId,
              ),
            );
          },
        );
      },
    );
  }

  // Posted Orders with light blue background
  Widget _buildPostedOrders() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: widget.userId)
          .where('orderType', isEqualTo: 'customer_post')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('Posted Orders Error: ${snapshot.error}');
          return _buildErrorWidget('Posted Orders Error: ${snapshot.error}');
        }

        if (!snapshot.hasData) {
          return _buildLoadingWidget('Loading your job posts...');
        }

        // Filter out cancelled orders and orders with passed dates
        final orders = snapshot.data!.docs.where((order) {
          final data = order.data() as Map<String, dynamic>;
          final status = data['status'] as String? ?? '';

          // Filter out cancelled orders
          if (status.toLowerCase() == 'cancelled') {
            return false;
          }

          // Filter out orders with passed dates
          if (_hasServiceDatePassed(data)) {
            return false;
          }

          return true;
        }).toList();

        // Sort by createdAt on client side to avoid index issues
        orders.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aCreated = aData['createdAt'] as Timestamp?;
          final bCreated = bData['createdAt'] as Timestamp?;

          if (aCreated == null && bCreated == null) return 0;
          if (aCreated == null) return 1;
          if (bCreated == null) return -1;

          return bCreated.compareTo(aCreated);
        });

        if (orders.isEmpty) {
          return _buildEmptyWidget(
            Icons.work_outline,
            'No job posts found.',
            'Create your first job post using the + button',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            final data = order.data()! as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _PostedOrderCard(
                key: ValueKey(order.id),
                orderId: order.id,
                data: data,
                onMarkComplete: _markOrderComplete,
                userId: widget.userId,
              ),
            );
          },
        );
      },
    );
  }

  // Helper widgets
  Widget _buildErrorWidget(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
          const SizedBox(height: 16),
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {}); // Trigger rebuild
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF00ACC1)), // ✅ Updated color
          const SizedBox(height: 16),
          Text(message),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Enhanced Application Order Card with better styling
class _ApplicationOrderCard extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> data;
  final Function(BuildContext, String, String, String) onMarkComplete;
  final Future<String> Function(String?, String?) getProviderName;
  final String userId;

  const _ApplicationOrderCard({
    super.key,
    required this.orderId,
    required this.data,
    required this.onMarkComplete,
    required this.getProviderName,
    required this.userId,
  });

  @override
  State<_ApplicationOrderCard> createState() => _ApplicationOrderCardState();
}

class _ApplicationOrderCardState extends State<_ApplicationOrderCard> {
  String? _cachedProviderName;
  bool _isLoadingProvider = false;

  @override
  void initState() {
    super.initState();
    _loadProviderName();
  }

  void _loadProviderName() async {
    if (_isLoadingProvider) return;

    setState(() => _isLoadingProvider = true);

    final providerId = widget.data['providerId'] as String?;
    final selectedWorkerId = widget.data['selectedWorkerId'] as String?;

    try {
      final name = await widget.getProviderName(providerId, selectedWorkerId);
      if (mounted) {
        setState(() {
          _cachedProviderName = name;
          _isLoadingProvider = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cachedProviderName = 'Provider';
          _isLoadingProvider = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String orderStatus = widget.data['status'] as String? ?? 'assigned';
    final String? providerId = widget.data['providerId'] as String?;
    final String? selectedWorkerId = widget.data['selectedWorkerId'] as String?;
    final String? serviceName = widget.data['service'] as String? ?? widget.data['serviceName'] as String?;
    final String? category = widget.data['category'] as String? ?? widget.data['serviceCategory'] as String?;

    final bool showMarkCompleteButton = (orderStatus == 'assigned' ||
        orderStatus == 'accepted' ||
        orderStatus == 'confirmed') &&
        (selectedWorkerId != null || providerId != null);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00ACC1).withOpacity(0.1), // ✅ Updated color
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    serviceName ?? 'Service Application',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusChip(orderStatus),
              ],
            ),
            const SizedBox(height: 16),

            // Category
            if (category != null && category.isNotEmpty) ...[
              _buildInfoRow(Icons.category, 'Category: $category'),
              const SizedBox(height: 12),
            ],

            // Provider info
            _buildInfoRow(
              Icons.person,
              'Provider: ${_cachedProviderName ?? (_isLoadingProvider ? 'Loading...' : 'Unknown')}',
            ),
            const SizedBox(height: 12),

            // Location
            _buildInfoRow(Icons.location_on, _getLocationText(widget.data)),
            const SizedBox(height: 12),

            // Date and time
            Row(
              children: [
                _buildDateTimeChip(Icons.calendar_today, widget.data['serviceDate'] ?? widget.data['date'] ?? 'N/A'),
                const SizedBox(width: 24),
                _buildDateTimeChip(Icons.access_time, widget.data['serviceTime'] ?? widget.data['time'] ?? 'N/A'),
              ],
            ),
            const SizedBox(height: 12),

            // Price
            _buildPriceRow(widget.data),

            if (showMarkCompleteButton) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () => widget.onMarkComplete(
                    context,
                    widget.orderId,
                    widget.userId,
                    'customer_application',
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Mark Complete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'assigned':
      case 'accepted':
      case 'confirmed':
        color = const Color(0xFF00ACC1); // ✅ Updated color
        break;
      case 'completed':
        color = const Color(0xFF10B981);
        break;
      case 'cancelled':
        color = const Color(0xFF6B7280);
        break;
      default:
        color = const Color(0xFFF59E0B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
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

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF00ACC1), size: 20), // ✅ Updated color
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimeChip(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF00ACC1), size: 16), // ✅ Updated color
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow(Map<String, dynamic> data) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF00ACC1).withOpacity(0.1), // ✅ Updated color
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.payments_outlined,
            color: const Color(0xFF00ACC1), // ✅ Updated color
            size: 18,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Rs. ${_getPriceText(data)}',
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _getLocationText(Map<String, dynamic> data) {
    if (data['location'] != null && data['location'] is Map<String, dynamic>) {
      return data['location']['address'] ?? 'N/A';
    }
    return data['address'] as String? ?? data['customerAddress'] as String? ?? 'N/A';
  }

  String _getPriceText(Map<String, dynamic> data) {
    return data['priceOffer']?.toString() ??
        data['price']?.toString() ??
        data['amount']?.toString() ??
        'N/A';
  }
}

// Enhanced Posted Order Card with themed styling
class _PostedOrderCard extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> data;
  final Function(BuildContext, String, String, String) onMarkComplete;
  final String userId;

  const _PostedOrderCard({
    super.key,
    required this.orderId,
    required this.data,
    required this.onMarkComplete,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final int applicationCount = (data['applications'] as List<dynamic>? ?? []).length;
    final String? selectedWorkerId = data['selectedWorkerId'] as String?;
    final String orderStatus = data['status'] as String? ?? 'waiting';
    final bool showMarkCompleteButton = selectedWorkerId != null &&
        (orderStatus == 'assigned' || orderStatus == 'accepted');

    // Get category information
    final String? category = data['category'] as String? ??
        data['serviceCategory'] as String? ??
        data['service'] as String?;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrderApplications(orderId: orderId),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00ACC1).withOpacity(0.1), // ✅ Updated color
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      data['service'] ?? data['serviceName'] ?? 'Job Post',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(orderStatus),
                ],
              ),
              const SizedBox(height: 16),

              // Category
              if (category != null && category.isNotEmpty) ...[
                _buildInfoRow(Icons.category, 'Category: $category', const Color(0xFF1E293B)),
                const SizedBox(height: 12),
              ],

              // Complete Location
              _buildCompleteLocationRow(data),
              const SizedBox(height: 12),

              // Date and time
              Row(
                children: [
                  _buildDateTimeChip(Icons.calendar_today, data['serviceDate'] ?? 'N/A'),
                  const SizedBox(width: 24),
                  _buildDateTimeChip(Icons.access_time, data['serviceTime'] ?? data['time'] ?? 'N/A'),
                ],
              ),
              const SizedBox(height: 12),

              // Price
              _buildPriceRow(data),

              if (showMarkCompleteButton) ...[
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () => onMarkComplete(
                      context,
                      orderId,
                      userId,
                      'customer_post',
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Mark Complete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Divider
              Container(height: 1, color: const Color(0xFFE2E8F0)),
              const SizedBox(height: 12),

              // Applications count
              Row(
                children: [
                  const Icon(Icons.people_outline, color: Color(0xFF64748B), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Applications: $applicationCount',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (applicationCount > 0) ...[
                    const Spacer(),
                    const Text(
                      'Tap to view →',
                      style: TextStyle(
                        color: Color(0xFF00ACC1), // ✅ Updated color
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Enhanced location display for Posted Orders
  Widget _buildCompleteLocationRow(Map<String, dynamic> data) {
    String locationText = _getCompleteLocationText(data);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.location_on, color: Color(0xFF00ACC1), size: 20), // ✅ Updated color
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Location:',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                locationText,
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'assigned':
      case 'accepted':
        color = const Color(0xFF00ACC1); // ✅ Updated color
        break;
      case 'completed':
        color = const Color(0xFF10B981);
        break;
      default:
        color = const Color(0xFFF59E0B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
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

  Widget _buildInfoRow(IconData icon, String text, Color textColor) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF00ACC1), size: 20), // ✅ Updated color
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimeChip(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF00ACC1), size: 16), // ✅ Updated color
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow(Map<String, dynamic> data) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF00ACC1).withOpacity(0.1), // ✅ Updated color
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.payments_outlined,
            color: const Color(0xFF00ACC1), // ✅ Updated color
            size: 18,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Rs. ${_getPriceText(data)}',
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _getCompleteLocationText(Map<String, dynamic> data) {
    if (data['location'] != null && data['location'] is Map<String, dynamic>) {
      final location = data['location'] as Map<String, dynamic>;

      List<String> addressParts = [];

      if (location['address'] != null && location['address'].toString().isNotEmpty) {
        addressParts.add(location['address'].toString());
      }

      if (location['city'] != null && location['city'].toString().isNotEmpty) {
        addressParts.add(location['city'].toString());
      }

      if (location['state'] != null && location['state'].toString().isNotEmpty) {
        addressParts.add(location['state'].toString());
      }

      if (location['country'] != null && location['country'].toString().isNotEmpty) {
        addressParts.add(location['country'].toString());
      }

      if (location['postalCode'] != null && location['postalCode'].toString().isNotEmpty) {
        addressParts.add(location['postalCode'].toString());
      }

      if (addressParts.isNotEmpty) {
        return addressParts.join(', ');
      }

      return location['address']?.toString() ?? 'Location not specified';
    }

    return data['address'] as String? ??
        data['customerAddress'] as String? ??
        data['serviceAddress'] as String? ??
        'Location not specified';
  }

  String _getPriceText(Map<String, dynamic> data) {
    return data['priceOffer']?.toString() ??
        data['price']?.toString() ??
        data['amount']?.toString() ??
        'N/A';
  }
}

// Review Form with themed styling
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
  State<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<_ReviewForm> {
  double _rating = 5.0;
  final TextEditingController _reviewTextController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reviewTextController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    final reviewText = _reviewTextController.text.trim();
    if (reviewText.isEmpty) {
      _showSnackBar('Please enter your review text.', Colors.orange);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      final reviewRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.workerId)
          .collection('reviews')
          .doc();

      batch.set(reviewRef, {
        'orderId': widget.orderId,
        'customerId': widget.customerId,
        'workerId': widget.workerId,
        'rating': _rating,
        'reviewText': reviewText,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (mounted) {
        _showSnackBar('Review submitted successfully!', Colors.green);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error submitting review: $e', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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

            // Star Rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _rating.floor() ? Icons.star : Icons.star_border,
                    color: const Color(0xFFF59E0B),
                    size: 36.0,
                  ),
                  onPressed: () => setState(() => _rating = (index + 1).toDouble()),
                );
              }),
            ),

            Text(
              '${_rating.toInt()} out of 5 stars',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
            const SizedBox(height: 20),

            // Review Text Field
            TextField(
              controller: _reviewTextController,
              decoration: InputDecoration(
                labelText: 'Your Review',
                hintText: 'Share your experience with this service...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00ACC1)), // ✅ Updated color
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
              ),
              maxLines: 4,
              maxLength: 500,
            ),
            const SizedBox(height: 20),

            // Submit Button
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
                backgroundColor: const Color(0xFF00ACC1), // ✅ Updated color
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}