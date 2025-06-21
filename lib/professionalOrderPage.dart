import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ordersNearMe.dart';
import 'sendServiceRequest.dart';

class ProfessionalOrdersPage extends StatefulWidget {
  final String professionalId;

  const ProfessionalOrdersPage({super.key, required this.professionalId});

  @override
  State<ProfessionalOrdersPage> createState() => _ProfessionalOrdersPageState();
}

class _ProfessionalOrdersPageState extends State<ProfessionalOrdersPage> {
  late Future<List<String>> _categoryFuture;
  String? _loadingOrderId; // Track which button is loading

  @override
  void initState() {
    super.initState();
    _categoryFuture = _fetchProfessionalCategories();
  }

  Future<List<String>> _fetchProfessionalCategories() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('services')
          .where('userId', isEqualTo: widget.professionalId)
          .get();

      return snapshot.docs.map((doc) => doc['category'] as String).toSet().toList();
    } catch (e) {
      return [];
    }
  }

  void _showRequestDialog(String orderId) async {
    setState(() {
      _loadingOrderId = orderId;
    });

    // Small delay to show the loading state, then open modal and reset immediately
    await Future.delayed(const Duration(milliseconds: 100));

    // Reset loading state immediately when modal opens
    setState(() {
      _loadingOrderId = null;
    });

    showDialog(
      context: context,
      builder: (_) => SendRequestDialog(
        orderId: orderId,
        professionalId: widget.professionalId,
      ),
    );
  }

  void _goToOrdersNearMe() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrdersNearMe(professionalId: widget.professionalId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F9FF), // Light blue background
      appBar: AppBar(
        title: const Text(
          'Job Posts',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF0EA5E9),
              child: IconButton(
                icon: const Icon(
                  Icons.location_on_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: _goToOrdersNearMe,
                tooltip: "Near Me",
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section with Promo Card
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  // Promo Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF22D3EE), Color(0xFF0EA5E9)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF22D3EE).withOpacity(0.3),
                          spreadRadius: 0,
                          blurRadius: 20,
                          offset: const Offset(0, 8),
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
                                'Find Jobs',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const Text(
                                'Discover opportunities in your area',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Browse Jobs',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0EA5E9),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.work,
                          size: 60,
                          color: Colors.white30,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Job Posts Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Text(
                'Available Jobs',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Jobs List
            FutureBuilder<List<String>>(
              future: _categoryFuture,
              builder: (context, categorySnapshot) {
                if (categorySnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0EA5E9)),
                      ),
                    ),
                  );
                }

                final categories = categorySnapshot.data ?? [];

                if (categories.isEmpty) {
                  return _buildEmptyState(
                    "You haven't added any services yet.",
                    Icons.work_off,
                  );
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('orders')
                      .where('category', whereIn: categories)
                      .where('status', isEqualTo: 'waiting')
                      .snapshots(),
                  builder: (context, orderSnapshot) {
                    if (!orderSnapshot.hasData) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0EA5E9)),
                          ),
                        ),
                      );
                    }

                    final orders = orderSnapshot.data!.docs;

                    if (orders.isEmpty) {
                      return _buildEmptyState(
                        "No matching job posts found.",
                        Icons.search_off,
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: orders.length,
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        final data = order.data() as Map<String, dynamic>;
                        return _buildJobCard(context, order.id, data);
                      },
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 100), // Bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildJobCard(BuildContext context, String orderId, Map<String, dynamic> data) {
    final bool isLoading = _loadingOrderId == orderId;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            // Header with category
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.category,
                    color: Color(0xFF0EA5E9),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    data['category'] ?? 'Unknown Category',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Service details
            _buildDetailRow(Icons.home_repair_service, 'Service', data['service'] ?? 'N/A'),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.location_on, 'Location', data['location']['address'] ?? 'N/A'),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.calendar_today, 'Date', data['serviceDate'] ?? 'N/A'),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.access_time, 'Time', data['serviceTime'] ?? 'N/A'),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.payments, 'Offer', data['priceOffer'] ?? 'Not specified'),

            const SizedBox(height: 16),

            // Send Request Button
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0EA5E9).withOpacity(0.3),
                      spreadRadius: 0,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextButton.icon(
                  onPressed: isLoading ? null : () => _showRequestDialog(orderId),
                  icon: isLoading
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : const Icon(Icons.send, color: Colors.white, size: 16),
                  label: Text(
                    'Send Request',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF0EA5E9).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 14,
            color: const Color(0xFF0EA5E9),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              size: 48,
              color: const Color(0xFF0EA5E9),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Available job opportunities will appear here.',
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
}