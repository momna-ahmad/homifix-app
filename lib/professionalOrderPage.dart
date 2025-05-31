import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfessionalOrdersPage extends StatefulWidget {
  final String professionalId;

  const ProfessionalOrdersPage({super.key, required this.professionalId});

  @override
  State<ProfessionalOrdersPage> createState() => _ProfessionalOrdersPageState();
}

class _ProfessionalOrdersPageState extends State<ProfessionalOrdersPage> {
  late Future<Map<String, dynamic>?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _getProfessionalProfile();
  }

  Future<Map<String, dynamic>?> _getProfessionalProfile() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.professionalId)
          .get();
      if (doc.exists) {
        return doc.data();
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  void _sendApplication({
    required String orderId,
    required String offerPrice,
    required String message,
  }) async {
    if (offerPrice.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter all fields')),
      );
      return;
    }

    try {
      final profileDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.professionalId)
          .get();
      final name = profileDoc.data()?['name'] ?? 'Unknown';

      final application = {
        'workerId': widget.professionalId,
        'workerName': name,
        'offerPrice': offerPrice,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);
      await orderRef.update({
        'applications': FieldValue.arrayUnion([application]),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Application sent to customer.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  void _updateOrderStatus(String orderId, String status) async {
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({'status': status});
    } catch (e) {
      // handle error
    }
  }

  void _showApplicationDialog(String orderId) {
    final offerController = TextEditingController();
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Send Application'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: offerController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Offer Price',
                prefixIcon: Icon(Icons.attach_money),
              ),
            ),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                labelText: 'Message',
                prefixIcon: Icon(Icons.message),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _sendApplication(
                orderId: orderId,
                offerPrice: offerController.text.trim(),
                message: messageController.text.trim(),
              );
              Navigator.pop(context);
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final profile = snapshot.data!;
        if (profile['role'] != 'Professional') {
          return const Center(
            child: Text('Only professionals can view this page.'),
          );
        }

        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('services')
              .where('userId', isEqualTo: widget.professionalId)
              .get(),
          builder: (context, serviceSnapshot) {
            if (!serviceSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final services = serviceSnapshot.data!.docs;
            final serviceNames = services.map((doc) => doc['service'] as String).toList();

            if (serviceNames.isEmpty) {
              return const Center(child: Text('You have not added any services.'));
            }

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('service', whereIn: serviceNames)
                  .snapshots(),
              builder: (context, orderSnapshot) {
                if (!orderSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final orders = orderSnapshot.data!.docs;

                if (orders.isEmpty) {
                  return const Center(child: Text('No matching orders found.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final doc = orders[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final orderId = doc.id;
                    final status = data['status'] ?? 'waiting';
                    final selectedWorkerId = data['selectedWorkerId'];
                    final isSelected = selectedWorkerId == widget.professionalId;
                    final hasApplied = (data['applications'] as List<dynamic>?)
                        ?.any((app) => app['workerId'] == widget.professionalId) ??
                        false;

                    Color statusColor = Colors.grey;
                    if (status == 'waiting') statusColor = Colors.orange;
                    if (status == 'confirmed') statusColor = Colors.blue;
                    if (status == 'in_progress') statusColor = Colors.purple;
                    if (status == 'completed') statusColor = Colors.green;

                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 6,
                      color: Colors.white,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.build, color: Colors.blueAccent),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    data['service'] ?? '',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('📂 Category: ${data['category']}'),
                            Text('📍 Location: ${data['location']}'),
                            Text('📅 Date: ${data['serviceDate']}'),
                            Text('⏰ Time: ${data['serviceTime']}'),
                            Text('💰 Offered Price: ${data['priceOffer'] ?? 'Not set'}'),
                            const SizedBox(height: 12),

                            // Status badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            if (!isSelected && status == 'waiting')
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.send),
                                  label: Text(hasApplied ? 'Counteroffer' : 'Apply Now'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                  onPressed: () => _showApplicationDialog(orderId),
                                ),
                              ),

                            if (isSelected && status == 'confirmed')
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton(
                                  onPressed: () => _updateOrderStatus(orderId, 'in_progress'),
                                  child: const Text('Start Service'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purple,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),

                            if (isSelected && status == 'in_progress')
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton(
                                  onPressed: () => _updateOrderStatus(orderId, 'completed'),
                                  child: const Text('Complete Service'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),

                            if (isSelected && status == 'completed')
                              const Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'Service Completed!',
                                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
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
        );
      },
    );
  }
}
