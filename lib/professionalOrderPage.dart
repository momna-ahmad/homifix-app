import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ordersNearMe.dart' ;
import 'sendServiceRequest.dart' ;

class ProfessionalOrdersPage extends StatefulWidget {
  final String professionalId;

  const ProfessionalOrdersPage({super.key, required this.professionalId});

  @override
  State<ProfessionalOrdersPage> createState() => _ProfessionalOrdersPageState();
}

class _ProfessionalOrdersPageState extends State<ProfessionalOrdersPage> {
  late Future<List<String>> _categoryFuture;

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

  void _showRequestDialog(String orderId) {
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
        builder: (_) => OrdersNearMe(professionalId: widget.professionalId), // You must define this widget
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Job Posts"),
        actions: [
          IconButton(
            icon: const Icon(Icons.location_on_outlined),
            tooltip: "Near Me",
            onPressed: _goToOrdersNearMe,
          ),
        ],
      ),
      body: FutureBuilder<List<String>>(
        future: _categoryFuture,
        builder: (context, categorySnapshot) {
          if (categorySnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final categories = categorySnapshot.data ?? [];

          if (categories.isEmpty) {
            return const Center(child: Text("You haven't added any services yet."));
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('category', whereIn: categories)
                .where('status', isEqualTo: 'waiting')
                .snapshots(),
            builder: (context, orderSnapshot) {
              if (!orderSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final orders = orderSnapshot.data!.docs;

              if (orders.isEmpty) {
                return const Center(child: Text("No matching job posts found."));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final data = order.data() as Map<String, dynamic>;

                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.work_outline, color: Colors.blueAccent),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  data['category'] ?? 'Unknown Category',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text("📍 service: ${data['service'] ?? 'N/A'}"),
                          Text("📍 Location: ${data['location']['address'] ?? 'N/A'}"),
                          Text("📅 Date: ${data['serviceDate'] ?? ''}"),
                          Text("⏰ Time: ${data['serviceTime'] ?? ''}"),
                          Text("💰 Offer: ${data['priceOffer'] ?? 'Not specified'}"),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.send),
                              label: const Text('Send Request'),
                              onPressed: () => _showRequestDialog(order.id),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}


