import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'editProfile.dart';
import 'package:photo_view/photo_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';

class ProfilePage extends StatelessWidget {
  final String userId;
  const ProfilePage({super.key, required this.userId});

  void logoutUser(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Text('Profile', style: TextStyle(color: Colors.black));
            }
            final data = snapshot.data!.data() as Map<String, dynamic>;
            final role = (data['role'] ?? '').toString().toLowerCase();
            return Text(
              role == 'professional' ? 'Professional Profile' : 'Customer Profile',
              style: const TextStyle(color: Colors.black),
            );
          },
        ),
        backgroundColor: Colors.white,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          if (FirebaseAuth.instance.currentUser?.uid == userId) ...[
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.black),
              tooltip: 'Edit Profile',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => EditProfileDialog(userId: userId),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.black),
              tooltip: 'Logout',
              onPressed: () => logoutUser(context),
            ),
          ],
        ],
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
          final role = (userData['role'] ?? '').toString().toLowerCase();

          return role == 'professional'
              ? _buildProfessionalProfile(context, userData, userId)
              : _buildCustomerProfile(context, userData);
        },
      ),
    );
  }

  Widget _buildProfessionalProfile(BuildContext context, Map<String, dynamic> userData, String userId) {
    final theme = Theme.of(context).textTheme;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('services')
          .where('userId', isEqualTo: userId)
          .snapshots(),
      builder: (context, servicesSnapshot) {
        if (!servicesSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final services = servicesSnapshot.data!.docs;

        return _buildProfileBase(context, userData, theme, children: [
          const Divider(height: 32, thickness: 1.5),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Services Providing:',
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
                        Text('Category: ${service['category'] ?? 'N/A'}'),
                        const SizedBox(height: 4),
                        Text('Timing: ${service['timing'] ?? 'N/A'}'),
                        const SizedBox(height: 4),
                        Text(
                          'Added on: ${service['createdAt'] != null ? (service['createdAt'] as Timestamp).toDate().toLocal().toString().split('.')[0] : 'N/A'}',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ]);
      },
    );
  }

  Widget _buildCustomerProfile(BuildContext context, Map<String, dynamic> userData) {
    final theme = Theme.of(context).textTheme;

    return _buildProfileBase(context, userData, theme, children: [
      const Divider(height: 32, thickness: 1.5),
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Customer Profile',
          style: theme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'This user is a customer and can browse or book services.',
        style: TextStyle(color: Colors.black54),
      ),
    ]);
  }

  Widget _buildProfileBase(
      BuildContext context,
      Map<String, dynamic> userData,
      TextTheme theme, {
        required List<Widget> children,
      }) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              final img = userData['profileImage'];
              if (img != null && img.toString().isNotEmpty) {
                showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    backgroundColor: Colors.transparent,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: PhotoView(
                        imageProvider: NetworkImage(img),
                        backgroundDecoration: const BoxDecoration(color: Colors.transparent),
                      ),
                    ),
                  ),
                );
              }
            },
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: (userData['profileImage']?.toString().isNotEmpty ?? false)
                  ? NetworkImage(userData['profileImage']) as ImageProvider
                  : null,
              child: (userData['profileImage'] == null || userData['profileImage'].toString().isEmpty)
                  ? const Icon(Icons.person, size: 40)
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            userData['name'] ?? 'No Name',
            style: theme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (currentUser?.uid == userData['uid'])
            Text(
              currentUser?.email ?? 'No Email',
              style: theme.bodyMedium?.copyWith(color: Colors.grey[700]),
            ),
          const SizedBox(height: 4),
          Text(
            'Role: ${userData['role'] ?? 'N/A'}',
            style: theme.bodySmall?.copyWith(color: Colors.grey[700]),
          ),
          ...children,
        ],
      ),
    );
  }
}
