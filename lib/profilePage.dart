import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'editProfile.dart';
import 'package:photo_view/photo_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';
import 'package:url_launcher/url_launcher.dart';


class ProfilePage extends StatelessWidget {
  final String userId;
  final bool isAdmin;

  const ProfilePage({super.key, required this.userId, this.isAdmin = false});


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




  void _showReportDialog(BuildContext context, String professionalId) {
    final TextEditingController reasonController = TextEditingController();
    String selectedReason = 'Inappropriate Behavior';

    final List<String> reportReasons = [
      'Inappropriate Behavior',
      'Fraud/Scam',
      'Poor Service Quality',
      'Unprofessional Conduct',
      'False Information',
      'Harassment',
      'Other'
    ];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.report, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Report Professional'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Please select a reason for reporting this professional:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedReason,
                      decoration: const InputDecoration(
                        labelText: 'Reason',
                        border: OutlineInputBorder(),
                      ),
                      items: reportReasons.map((String reason) {
                        return DropdownMenuItem<String>(
                          value: reason,
                          child: Text(reason),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            selectedReason = newValue;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: reasonController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Additional Details (Optional)',
                        hintText: 'Please provide more details about your report...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Note: False reports may result in account restrictions.',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    reasonController.dispose();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _submitReport(context, professionalId, selectedReason,
                        reasonController.text.trim());
                    reasonController.dispose();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Submit Report'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitReport(BuildContext context, String professionalId,
      String reason, String details) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to report.')),
        );
        return;
      }

      // Add report to reports collection
      await FirebaseFirestore.instance.collection('reports').add({
        'reportedUserId': professionalId,
        'reportedBy': currentUser.uid,
        'reason': reason,
        'details': details,
        'timestamp': Timestamp.now(),
        'status': 'pending', // pending, reviewed, resolved
      });

      // Update the professional's isReported field to true
      await FirebaseFirestore.instance.collection('users')
          .doc(professionalId)
          .update({
        'isReported': true,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              '✅ Report submitted successfully. Thank you for your feedback.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error submitting report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users')
              .doc(userId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Text(
                  'Profile', style: TextStyle(color: Colors.black));
            }
            final data = snapshot.data!.data() as Map<String, dynamic>;
            final role = (data['role'] ?? '').toString().toLowerCase();
            return Text(
              role == 'professional'
                  ? 'Professional Profile'
                  : 'Customer Profile',
              style: const TextStyle(color: Colors.black),
            );
          },
        ),
        backgroundColor: Colors.white,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users')
                .doc(userId)
                .get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();

              final data = snapshot.data!.data() as Map<String, dynamic>;
              final isCurrentUser = FirebaseAuth.instance.currentUser?.uid ==
                  userId;
              final role = data['role']?.toString().toLowerCase();
              final badgeStatus = data['badgeStatus'] ?? 'None';

              return Row(
                children: [
                  // Report button - only show for customers viewing professional profiles
                  if (!isCurrentUser && role == 'professional')
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users')
                          .doc(FirebaseAuth.instance.currentUser?.uid)
                          .get(),
                      builder: (context, currentUserSnapshot) {
                        if (!currentUserSnapshot.hasData)
                          return const SizedBox();

                        final currentUserData = currentUserSnapshot.data!
                            .data() as Map<String, dynamic>?;
                        final currentUserRole = currentUserData?['role']
                            ?.toString()
                            .toLowerCase();

                        // Only show report button if current user is a customer
                        if (currentUserRole == 'customer') {
                          return IconButton(
                            icon: const Icon(Icons.report, color: Colors.red),
                            tooltip: 'Report Professional',
                            onPressed: () => _showReportDialog(context, userId),
                          );
                        }

                        return const SizedBox();
                      },
                    ),

                  if (isCurrentUser)
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.black),
                      tooltip: 'Edit Profile',
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) =>
                              EditProfileDialog(userId: userId),
                        );
                      },
                    ),
                  if (isCurrentUser)
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.black),
                      tooltip: 'Logout',
                      onPressed: () => logoutUser(context),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users')
            .doc(userId)
            .snapshots(),
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


  Widget _buildCustomerProfile(BuildContext context,
      Map<String, dynamic> userData) {

    final theme = Theme
        .of(context)
        .textTheme;

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


  Widget _buildProfessionalProfile(
      BuildContext context,
      Map<String, dynamic> userData,
      String userId,
      ) {
    final theme = Theme.of(context).textTheme;
    final cnic = userData['cnic'] ?? 'Not Provided';
    final whatsapp = userData['whatsapp'] ?? '';
    final createdAt = userData['createdAt'] != null
        ? (userData['createdAt'] as Timestamp).toDate().toLocal().toString().split(' ')[0]
        : 'N/A';

    final isOwnProfile = FirebaseAuth.instance.currentUser?.uid == userId;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('services')
          .where('userId', isEqualTo: userId)
          .snapshots(),
      builder: (context, servicesSnapshot) {
        final services = servicesSnapshot.data?.docs ?? [];

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('reviews')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, reviewSnapshot) {
            final reviewDocs = reviewSnapshot.data?.docs ?? [];

            final averageRating = reviewDocs.isNotEmpty
                ? reviewDocs.map((doc) => (doc['rating'] ?? 0) as num).reduce((a, b) => a + b) / reviewDocs.length
                : 0.0;

            return _buildProfileBase(
              context,
              userData,
              theme,
              children: [
                const Divider(height: 32, thickness: 1.5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.blueAccent),
                    const SizedBox(width: 10),
                    Text('Member Since: $createdAt', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),
                Text('CNIC: $cnic', style: theme.bodyMedium),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: whatsapp.isNotEmpty
                      ? () async {
                    final uri = Uri.parse('https://wa.me/$whatsapp');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not open WhatsApp')),
                      );
                    }
                  }
                      : null,
                  icon: const Icon(Icons.message_rounded),
                  label: Text(whatsapp.isNotEmpty ? 'Contact on WhatsApp' : 'WhatsApp Not Provided'),
                ),

                // Services Section
                if (!isOwnProfile && services.isNotEmpty) ...[
                  const Divider(height: 32, thickness: 1.5),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Services Providing:', style: theme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 12),
                  ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: services.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final service = services[index].data() as Map<String, dynamic>;
                      final serviceName = service['service'] ?? 'Unnamed';
                      final serviceCategory = service['category'] ?? 'N/A';
                      final serviceCreatedAt = service['createdAt'] != null
                          ? (service['createdAt'] as Timestamp).toDate().toLocal().toString().split('.')[0]
                          : 'N/A';

                      return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left Side (Category + Service Name)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(serviceCategory,
                                        style: TextStyle(
                                            color: Colors.blueGrey[700],
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    Text(serviceName,
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue[800])),
                                    const SizedBox(height: 4),
                                    Text('Added on: $serviceCreatedAt', style: theme.bodySmall),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Right Side (Buttons)
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      // Placeholder for edit logic
                                    },
                                    icon: const Icon(Icons.edit, color: Colors.blueAccent),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      // Placeholder for delete logic
                                    },
                                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],

                // Reviews
                const Divider(height: 32, thickness: 1.5),
                if (reviewDocs.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.orange),
                      const SizedBox(width: 6),
                      Text('Average Rating: ${averageRating.toStringAsFixed(1)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 140,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: reviewDocs.length,
                      itemBuilder: (context, index) {
                        final data = reviewDocs[index].data() as Map<String, dynamic>;
                        final rating = (data['rating'] ?? 0).toDouble();
                        final text = data['reviewText'] ?? '';
                        final customerId = data['customerId'] ?? '';

                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(customerId).get(),
                          builder: (context, snapshot) {
                            final reviewerName = (snapshot.data?.data() as Map<String, dynamic>?)?['name'] ?? 'Anonymous';

                            return Container(
                              width: 250,
                              margin: const EdgeInsets.only(right: 12),
                              child: Card(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 3,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(reviewerName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: List.generate(
                                          rating.floor(),
                                              (_) => const Icon(Icons.star, size: 16, color: Colors.orange),
                                        ) +
                                            (rating - rating.floor() >= 0.5
                                                ? [const Icon(Icons.star_half, size: 16, color: Colors.orange)]
                                                : []),
                                      ),
                                      const SizedBox(height: 8),
                                      Expanded(
                                        child: Text(text,
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 13, color: Colors.black54)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ] else
                  const Text('No reviews yet.', style: TextStyle(color: Colors.grey)),
              ],
            );
          },
        );
      },
    );
  }




  Widget _buildProfileBase(BuildContext context,
        Map<String, dynamic> userData,
        TextTheme theme, {
          required List<Widget> children,
        }) {
      final currentUser = FirebaseAuth.instance.currentUser;
      final profileImage = userData['profileImage'];
      final role = userData['role']?.toString().toLowerCase();
      final badgeStatus = userData['badgeStatus']?.toString().toLowerCase();

      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () {
                if (profileImage != null && profileImage
                    .toString()
                    .isNotEmpty) {
                  showDialog(
                    context: context,
                    builder: (_) =>
                        Dialog(
                          backgroundColor: Colors.transparent,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: PhotoView(
                              imageProvider: NetworkImage(profileImage),
                              backgroundDecoration: const BoxDecoration(
                                  color: Colors.transparent),
                            ),
                          ),
                        ),
                  );
                }
              },
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: (profileImage
                        ?.toString()
                        .isNotEmpty ?? false)
                        ? NetworkImage(profileImage) as ImageProvider
                        : null,
                    child: (profileImage == null || profileImage
                        .toString()
                        .isEmpty)
                        ? const Icon(Icons.person, size: 40)
                        : null,
                  ),
                  // ⭐ Verified star badge
                  if (role == 'professional' && badgeStatus == 'assigned')
                    const Positioned(
                      right: 0,
                      bottom: 0,
                      child: CircleAvatar(
                        backgroundColor: Colors.white,
                        radius: 12,
                        child: Icon(Icons.star, color: Colors.amber, size: 20),
                      ),
                    ),
                ],
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