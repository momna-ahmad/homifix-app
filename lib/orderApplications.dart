import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderApplications extends StatelessWidget{
  final String orderId;
  const OrderApplications({super.key, required this.orderId});
  Future<DocumentSnapshot<Map<String,dynamic>>> _fetchOrder(){
    return FirebaseFirestore.instance.collection('orders').doc(orderId).get() ;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context) ;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Applications'),
        centerTitle: true,
      ),
      body: FutureBuilder(future: _fetchOrder(), builder: (context,snapshot){
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('Order not found.'));
        }
        final data = snapshot.data!.data() ;
        final applications = (data?['applications'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        if (applications.isEmpty) {
          return const Center(
            child: Text('No applications yet.'),
          );
        }
        return ListView.separated(
          itemCount: applications.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final application = applications[index];
            final professionalId = application['professionalId'] as String;

            return Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance.collection('users').doc(professionalId).get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return ListTile(
                      leading: const Icon(Icons.person, color: Colors.blueAccent),
                      title: const Text('Loading professional info...'),
                    );
                  }
                  if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                    return ListTile(
                      leading: const Icon(Icons.person, color: Colors.blueAccent),
                      title: const Text('Professional info not found'),
                    );
                  }

                  final professionalData = snapshot.data!.data()!;
                  final professionalName = professionalData['name'] ?? 'No Name';

                  return ListTile(
                    leading: const Icon(Icons.person, color: Colors.blueAccent),
                    title: Text('Professional: $professionalName'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('💬 Message: ${application['message'] ?? 'No message'}'),
                        Text('💰 Price: Rs. ${application['price'] ?? 'N/A'}'),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      }),
    );
  }
}