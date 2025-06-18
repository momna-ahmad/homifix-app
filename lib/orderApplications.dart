import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:home_services_app/profilePage.dart';
import 'package:geolocator/geolocator.dart';

class OrderApplications extends StatefulWidget {
  final String orderId;
  const OrderApplications({super.key, required this.orderId});

  @override
  State<OrderApplications> createState() => _OrderApplicationsState();
}

class _OrderApplicationsState extends State<OrderApplications> {
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _orderStream;

  @override
  void initState() {
    super.initState();
    _orderStream = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .snapshots();
  }

  void _showLocationDialog(int index, String professionalId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Send Current Location'),
          content: const Text(
              'Do you want to send your current location when accepting this application?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _getCurrentLocationAndAccept(index, professionalId);
              },
              child: const Text('Send Location'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _getCurrentLocationAndAccept(int index, String professionalId) async {
    final orderRef = FirebaseFirestore.instance.collection('orders').doc(widget.orderId);
    final orderSnapshot = await orderRef.get();
    if (!orderSnapshot.exists) throw Exception('Order not found');
    final orderData = orderSnapshot.data()!;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services are disabled.');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Location permissions are denied.');
      }
      if (permission == LocationPermission.deniedForever) throw Exception('Location permissions are permanently denied.');

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      await orderRef.update({
        'clientLocation': {
          'address': orderData['location']['address'],
          'lat': position.latitude,
          'lng': position.longitude,
        }
      });

      _acceptApplication(index, professionalId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _acceptApplication(int index, String professionalId) async {
    final orderDocRef = FirebaseFirestore.instance.collection('orders').doc(widget.orderId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final currentOrderSnapshot = await transaction.get(orderDocRef);
        if (!currentOrderSnapshot.exists) throw Exception('Order document disappeared during transaction!');

        final orderData = currentOrderSnapshot.data()!;
        final applications = List.from(orderData['applications'] ?? []);

        if (index < 0 || index >= applications.length) throw Exception('Invalid application index: $index');
        if (orderData['status'] == 'assigned' || orderData['status'] == 'completed') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Order already assigned or completed!'), backgroundColor: Colors.orange),
            );
          }
          return;
        }

        final updatedApplication = {...applications[index], 'status': 'accepted'};
        applications[index] = updatedApplication;

        transaction.update(orderDocRef, {
          'applications': applications,
          'status': 'assigned',
          'selectedWorkerId': professionalId,
        });

        final professionalDocRef = FirebaseFirestore.instance.collection('users').doc(professionalId);
        transaction.update(professionalDocRef, {
          'orders': FieldValue.arrayUnion([
            {
              'location': orderData['clientLocation'],
              'date': orderData['serviceDate'],
              'time': orderData['serviceTime'],
              'price': applications[index]['price'],
              'service': orderData['service'],
              'completionStatus': 'pending',
              'orderId': widget.orderId,
            }
          ])
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application accepted and order assigned!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept application: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Order Applications'), centerTitle: true),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _orderStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: Text('Order not found.'));

          final data = snapshot.data!.data();
          final applications = (data?['applications'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          final orderStatus = data?['status'] as String? ?? 'pending';

          if (applications.isEmpty) return const Center(child: Text('No applications yet.'));

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: applications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final application = applications[index];
              final professionalId = application['professionalId'] as String;
              final applicationStatus = application['status'] as String? ?? 'pending';

              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    future: FirebaseFirestore.instance.collection('users').doc(professionalId).get(),
                    builder: (context, professionalSnapshot) {
                      if (professionalSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (professionalSnapshot.hasError || !professionalSnapshot.hasData || !professionalSnapshot.data!.exists) {
                        return const Text('Professional info not found');
                      }

                      final professionalData = professionalSnapshot.data!.data()!;
                      final professionalName = professionalData['name'] ?? 'No Name';

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(professionalName,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text('💬 Message: ${application['message'] ?? 'No message'}'),
                                const SizedBox(height: 4),
                                Text('💰 Price: Rs. ${application['price'] ?? 'N/A'}'),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              ElevatedButton.icon(
                                label: const Text('View Profile'),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ProfilePage(userId: professionalId),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                ),
                              ),

                              const SizedBox(height: 8),
                              if (applicationStatus == 'accepted')
                                Chip(
                                  label: const Text('Accepted'),
                                  backgroundColor: Colors.green.shade100,
                                  avatar: const Icon(Icons.check_circle, color: Colors.green),
                                )
                              else if (applicationStatus == 'pending' &&
                                  orderStatus != 'assigned' &&
                                  orderStatus != 'completed')
                                ElevatedButton(
                                  onPressed: () => _showLocationDialog(index, professionalId),
                                  child: const Text('Accept'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.primaryColor,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      );
                    },
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