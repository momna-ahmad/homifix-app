import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:home_services_app/profilePage.dart';
import 'package:geolocator/geolocator.dart';
import 'professionalForCustomer.dart';

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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightBlue,
                foregroundColor: Colors.white,
              ),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Applications'),
        centerTitle: true,
        backgroundColor: Colors.lightBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.lightBlue.shade50,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _orderStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.lightBlue),
            );
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text(
                'Order not found.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final data = snapshot.data!.data();
          final applications = (data?['applications'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          final orderStatus = data?['status'] as String? ?? 'pending';

          if (applications.isEmpty) {
            return const Center(
              child: Text(
                'No applications yet.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.lightBlue.shade50,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: applications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final application = applications[index];
                final professionalId = application['professionalId'] as String;
                final applicationStatus = application['status'] as String? ?? 'pending';

                return Card(
                  elevation: 6,
                  shadowColor: Colors.lightBlue.withOpacity(0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      future: FirebaseFirestore.instance.collection('users').doc(professionalId).get(),
                      builder: (context, professionalSnapshot) {
                        if (professionalSnapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(color: Colors.lightBlue),
                            ),
                          );
                        }
                        if (professionalSnapshot.hasError ||
                            !professionalSnapshot.hasData ||
                            !professionalSnapshot.data!.exists) {
                          return const Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'Professional info not found',
                              style: TextStyle(color: Colors.red),
                            ),
                          );
                        }

                        final professionalData = professionalSnapshot.data!.data()!;
                        final professionalName = professionalData['name'] ?? 'No Name';
                        final profileImageUrl = professionalData['profileImage'] as String?;

                        return Column(
                          children: [
                            // Main content row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Profile Image
                                Container(
                                  width: 64,
                                  height: 64,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.lightBlue, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.lightBlue.withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: profileImageUrl != null && profileImageUrl.isNotEmpty
                                        ? Image.network(
                                      profileImageUrl,
                                      width: 64,
                                      height: 64,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return Container(
                                          color: Colors.lightBlue.shade50,
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              color: Colors.lightBlue,
                                              strokeWidth: 2,
                                              value: loadingProgress.expectedTotalBytes != null
                                                  ? loadingProgress.cumulativeBytesLoaded /
                                                  loadingProgress.expectedTotalBytes!
                                                  : null,
                                            ),
                                          ),
                                        );
                                      },
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          color: Colors.lightBlue.shade50,
                                          child: const Icon(
                                            Icons.person,
                                            color: Colors.lightBlue,
                                            size: 32,
                                          ),
                                        );
                                      },
                                    )
                                        : Container(
                                      color: Colors.lightBlue.shade50,
                                      child: const Icon(
                                        Icons.person,
                                        color: Colors.lightBlue,
                                        size: 32,
                                      ),
                                    ),
                                  ),
                                ),

                                // Professional Details - Takes up remaining space
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        professionalName,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.message_outlined,
                                            color: Colors.lightBlue,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'Message: ${application['message'] ?? 'No message'}',
                                              style: TextStyle(
                                                color: Colors.grey[700],
                                                fontSize: 14,
                                              ),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      // Added price icon back
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.currency_rupee,
                                            color: Colors.lightBlue,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Price: Rs. ${application['price'] ?? 'N/A'}',
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Action Buttons Row - Positioned at the bottom right
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                SizedBox(
                                  height: 36,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.person, size: 14),
                                    label: const Text(
                                      'View Profile',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => ProfessionalForCustomer(userId: professionalId),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.lightBlue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      elevation: 2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (applicationStatus == 'accepted')
                                  Container(
                                    height: 36,
                                    child: Chip(
                                      label: const Text(
                                        'Accepted',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      backgroundColor: Colors.green.shade100,
                                      avatar: const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 16,
                                      ),
                                    ),
                                  )
                                else if (applicationStatus == 'pending' &&
                                    orderStatus != 'assigned' &&
                                    orderStatus != 'completed')
                                  SizedBox(
                                    height: 36,
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.check, size: 14),
                                      label: const Text(
                                        'Accept',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      onPressed: () => _showLocationDialog(index, professionalId),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.lightBlue,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        elevation: 2,
                                      ),
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
            ),
          );
        },
      ),
    );
  }
}