import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';

Future<bool> sendBatchRequest(BuildContext context, String userId) async {
  try {
    final batchRef = FirebaseFirestore.instance.collection('batch_requests');

    // Check if there's already a pending request
    final existing = await batchRef
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (existing.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('You already have a pending badge request.'),
          backgroundColor: const Color(0xFF2196F3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return false;
    }

    await batchRef.add({
      'userId': userId,
      'status': 'pending',
      'requestedAt': Timestamp.now(),
    });

    return true;
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error sending batch request: $e'),
        backgroundColor: const Color(0xFFEF5350),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    return false;
  }
}

class ProfessionalProfile extends StatelessWidget {
  final String userId;

  const ProfessionalProfile({super.key, required this.userId});

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

  // Define a primary blue color for accents
  Color get _accentBlue => const Color(0xFF1976D2); // Darker blue for accents
  Color get _lightBlueBackground => const Color(0xFFF3F8FF); // Very light blue for background
  Color get _cardBackground => Colors.white; // White for card backgrounds
  Color get _shadowColor => const Color(0xFFE0E0E0); // Lighter shadow color

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightBlueBackground, // Use light blue for overall background
      appBar: AppBar(
        title: Text(
          'Professional Profile',
          style: TextStyle(
            color: _accentBlue, // App bar title in accent blue
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: _cardBackground, // White app bar background
        elevation: 1, // Slightly raised app bar
        iconTheme: IconThemeData(color: _accentBlue), // Icons in accent blue
        centerTitle: true,
        actions: [
          // Badge request button only for the logged-in user's own profile
          if (FirebaseAuth.instance.currentUser?.uid == userId)
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();

                final data = snapshot.data!.data() as Map<String, dynamic>;
                final badgeStatus = (data['badgeStatus'] ?? 'none').toString().toLowerCase();

                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: badgeStatus == 'assigned' ? const Color(0xFF4CAF50) : _accentBlue, // Green for assigned, accent blue otherwise
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    icon: Icon(
                      badgeStatus == 'assigned' ? Icons.verified : Icons.verified_outlined,
                      color: Colors.white,
                    ),
                    tooltip: badgeStatus == 'assigned' ? 'Verified Professional' : 'Request for Badge',
                    onPressed: () async {
                      if (badgeStatus == 'none') {
                        await FirebaseFirestore.instance.collection('users').doc(userId).update({
                          'badgeStatus': 'Pending',
                        });

                        final success = await sendBatchRequest(context, userId);

                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('✅ Badge request sent.'),
                              backgroundColor: const Color(0xFF4CAF50),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        }
                      } else if (badgeStatus == 'pending') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('⚠️ Badge request already sent and is under review.'),
                            backgroundColor: const Color(0xFFFF9800),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      } else if (badgeStatus == 'assigned') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('✅ You are already a verified professional.'),
                            backgroundColor: const Color(0xFF4CAF50),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      }
                    },
                  ),
                );
              },
            ),

          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: _accentBlue, // Edit button in accent blue
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              tooltip: 'Edit Profile',
              onPressed: () {},
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFEF5350), // Logout button remains red
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              tooltip: 'Logout',
              onPressed: () => logoutUser(context),
            ),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Text(
                'User profile not found.',
                style: TextStyle(
                  fontSize: 18,
                  color: _accentBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }

          final userData = snapshot.data!.data()! as Map<String, dynamic>;
          return _buildProfessionalProfile(context, userData, userId);
        },
      ),
    );
  }

  Widget _buildProfessionalProfile(BuildContext context, Map<String, dynamic> userData, String userId) {
    final cnic = userData['cnic'] ?? 'Not Provided';
    final createdAt = userData['createdAt'] != null
        ? (userData['createdAt'] as Timestamp).toDate().toLocal().toString().split(' ')[0]
        : 'N/A';
    final profileImage = userData['profileImage'];

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('services').where('userId', isEqualTo: userId).snapshots(),
      builder: (context, servicesSnapshot) {
        final services = servicesSnapshot.data?.docs ?? [];

        return SingleChildScrollView(
          // ADDED PADDING HERE
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), // Added bottom padding of 80 to account for the navbar
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Profile Header Card - White background with blue text
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _cardBackground, // White background for the card
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _shadowColor, // Lighter shadow
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (profileImage != null && profileImage.toString().isNotEmpty) {
                          showDialog(
                            context: context,
                            builder: (_) => Dialog(
                              backgroundColor: Colors.transparent,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: PhotoView(
                                  imageProvider: NetworkImage(profileImage),
                                  backgroundDecoration: const BoxDecoration(color: Colors.transparent),
                                ),
                              ),
                            ),
                          );
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _accentBlue.withOpacity(0.3), width: 3), // Blue border
                        ),
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: _accentBlue.withOpacity(0.1), // Light blue background for avatar placeholder
                          backgroundImage: (profileImage?.toString().isNotEmpty ?? false)
                              ? NetworkImage(profileImage)
                              : null,
                          child: (profileImage == null || profileImage.toString().isEmpty)
                              ? Icon(Icons.person, size: 40, color: _accentBlue) // Blue icon
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      userData['name'] ?? 'No Name',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: _accentBlue, // Text in accent blue
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _accentBlue.withOpacity(0.1), // Light blue background
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Professional',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _accentBlue, // Text in accent blue
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'CNIC: $cnic',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700], // Darker grey for secondary text
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Member Since Card - White background with blue accent
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _cardBackground, // White background
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _shadowColor,
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _accentBlue.withOpacity(0.1), // Light blue accent for icon background
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.calendar_today,
                        color: _accentBlue, // Accent blue icon
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Member Since: $createdAt',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _accentBlue, // Accent blue text
                      ),
                    ),
                  ],
                ),
              ),

              if (services.isNotEmpty) ...[
                const SizedBox(height: 16),

                // Services Header - White background with blue text
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _cardBackground, // White background
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: _shadowColor,
                        spreadRadius: 2,
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'Services Providing',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _accentBlue, // Accent blue text
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 12),

                // Services List - White background with blue accents
                ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: services.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final service = services[index].data() as Map<String, dynamic>;
                    final serviceName = service['service'] ?? 'Unnamed';
                    final serviceCategory = service['category'] ?? 'N/A';
                    final serviceCreatedAt = service['createdAt'] != null
                        ? (service['createdAt'] as Timestamp).toDate().toLocal().toString().split('.')[0]
                        : 'N/A';

                    return Container(
                      decoration: BoxDecoration(
                        color: _cardBackground, // White background
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: _shadowColor,
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: _accentBlue.withOpacity(0.1), // Light blue accent
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    serviceCategory,
                                    style: TextStyle(
                                      color: _accentBlue, // Accent blue text
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  serviceName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey[800], // Dark grey for service name
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Added on: $serviceCreatedAt',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600], // Medium grey for date
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: _accentBlue.withOpacity(0.1), // Light blue accent
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _accentBlue.withOpacity(0.3), // Blue border
                                    width: 1,
                                  ),
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: Icon(Icons.edit, color: _accentBlue, size: 16), // Accent blue icon
                                  onPressed: () {
                                    // Edit logic placeholder
                                  },
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1), // Light red accent
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.red.withOpacity(0.3), // Red border
                                    width: 1,
                                  ),
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 16), // Red icon
                                  onPressed: () {
                                    // Delete logic placeholder
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Reviews Section
                StreamBuilder<QuerySnapshot>(
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

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (reviewDocs.isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: _cardBackground, // White background
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: _shadowColor,
                                  spreadRadius: 2,
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.1), // Light amber for icon background
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.star, color: Colors.amber, size: 20), // Amber star
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Average Rating: ${averageRating.toStringAsFixed(1)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: _accentBlue, // Accent blue text
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
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
                                      width: 220,
                                      margin: const EdgeInsets.only(right: 10),
                                      decoration: BoxDecoration(
                                        color: _cardBackground, // White background
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _shadowColor,
                                            spreadRadius: 1,
                                            blurRadius: 5,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            reviewerName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: _accentBlue, // Accent blue text
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: List.generate(
                                              rating.floor(),
                                                  (_) => const Icon(Icons.star, size: 16, color: Colors.amber), // Amber stars
                                            ) +
                                                (rating - rating.floor() >= 0.5
                                                    ? [const Icon(Icons.star_half, size: 16, color: Colors.amber)] // Amber half star
                                                    : []),
                                          ),
                                          const SizedBox(height: 8),
                                          Expanded(
                                            child: Text(
                                              text,
                                              maxLines: 4,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[700], // Dark grey for review text
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ] else
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: _cardBackground, // White background
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: _shadowColor,
                                  spreadRadius: 2,
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'No reviews yet.',
                              style: TextStyle(
                                color: Colors.grey[700], // Dark grey text
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}