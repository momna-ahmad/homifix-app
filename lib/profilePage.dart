import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  final String userId;
  const ProfilePage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Professional Profile'),
        backgroundColor: Colors.blue,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return const Center(child: Text('User profile not found.'));
          }

          final userData = userSnapshot.data!.data()! as Map<String, dynamic>;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('services')
                .where('userId', isEqualTo: userId)
                .snapshots(),
            builder: (context, servicesSnapshot) {
              if (servicesSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!servicesSnapshot.hasData) {
                return const Center(child: Text('Services data not available.'));
              }

              final services = servicesSnapshot.data!.docs;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        userData['name'] != null && userData['name'].isNotEmpty
                            ? userData['name'][0].toUpperCase()
                            : '?',
                        style: theme.headlineLarge?.copyWith(color: Colors.blue),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      userData['name'] ?? 'No Name',
                      style: theme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      userData['email'] ?? 'No Email',
                      style: theme.bodyMedium?.copyWith(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Role: ${userData['role'] ?? 'N/A'}',
                      style: theme.bodySmall?.copyWith(color: Colors.grey[700]),
                    ),
                    const Divider(height: 32, thickness: 1.5),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Services Provided:',
                        style: theme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (services.isEmpty)
                      const Text('No services added by this professional.')
                    else
                      ListView.separated(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: services.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final service = services[index].data() as Map<String, dynamic>;
                          return Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    service['service'] ?? 'Unknown Service',
                                    style: theme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue.shade800,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Category: ${service['category'] ?? 'N/A'}',
                                    style: theme.bodySmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Timing: ${service['timing'] ?? 'N/A'}',
                                    style: theme.bodySmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Added on: ${service['createdAt'] != null ? (service['createdAt'] as Timestamp).toDate().toLocal().toString().split('.')[0] : 'N/A'}',
                                    style: theme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
