import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:home_services_app/professionalProfile.dart';
import 'professionalOrderPage.dart' ;

class OrderApplications extends StatelessWidget{
  final String orderId;
  const OrderApplications({super.key, required this.orderId});
  Future<DocumentSnapshot<Map<String,dynamic>>> _fetchOrder(){
    return FirebaseFirestore.instance.collection('orders').doc(orderId).get() ;
  }

  void _acceptApplication(int index, String professionalId) async {
    final orderDocRef = FirebaseFirestore.instance.collection('orders').doc(orderId);

    // Step 1: Fetch the order document
    DocumentSnapshot<Map<String, dynamic>> orderSnapshot = await orderDocRef.get();
    if (!orderSnapshot.exists) return;

    Map<String, dynamic> orderData = Map.from(orderSnapshot.data()!);
    List<dynamic> applications = List.from(orderData['applications'] ?? []);

    // Safety check
    if (index < 0 || index >= applications.length) return;

    // Step 2: Update application status
    Map<String, dynamic> updatedApplication = Map.from(applications[index]);
    updatedApplication['status'] = 'accepted';
    applications[index] = updatedApplication;
    orderData['status'] = 'assigned';

    // Step 3: Update the 'applications' field in the order document
    await orderDocRef.update({
      'applications': applications,
      'status': orderData['status']
    });

    // Step 4: Copy order data to the professional's 'orders' array
    final professionalDocRef = FirebaseFirestore.instance.collection('users').doc(professionalId);

    // Optional: Remove large or unnecessary fields before storing in the user's document
    Map<String, dynamic> orderDataForProfessional = {
      'location' : orderData['location'] ,
      'date' : orderData['serviceDate'] ,
      'time' : orderData['serviceTime'] ,
      'price' : applications[index]['price'] ,
      'service' : orderData['service'] ,
      'completionStatus' : 'pending'
    };
    orderDataForProfessional['orderId'] = orderId; // include the order ID for reference

    await professionalDocRef.update({
      'orders': FieldValue.arrayUnion([orderDataForProfessional])
    });

    print('Accepted application and updated professional orders.');
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
                        const SizedBox(height: 4,),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            //view profile button 
                            TextButton(onPressed: (){ // This is the VoidCallback expected by onPressed
                      Navigator.of(context).push(
                      MaterialPageRoute(
                      builder: (context) => ProfessionalProfilePage(
                      professionalId: application['professionalId'],
                      ),
                      ),
                      );
                      },
                                child: Text('View Profile')),
                            application['status'] == 'pending' ?
                            TextButton(onPressed: () {
                              _acceptApplication(index, application['professionalId']) ;
                            },
                                child: Text('Accept Application'))
                                :
                            TextButton(onPressed: () {
                              application['status'] = 'completed' ;
                            },
                                child: Text('Completed'))
                          ],
                        ),
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