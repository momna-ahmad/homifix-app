import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';
import 'editProfile.dart' ;

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

  // --- Standardized Color & Style Definitions ---
  // Primary accent blue color (from ProfessionalOrdersPage)
  Color get _primaryBlue => const Color(0xFF0EA5E9);
  // Secondary blue for gradients (from ProfessionalOrdersPage)
  Color get _secondaryBlue => const Color(0xFF22D3EE);
  // Darker text color (from ProfessionalOrdersPage)
  Color get _darkTextColor => const Color(0xFF1E293B);
  // Secondary text color/grey (from ProfessionalOrdersPage)
  Color get _secondaryTextColor => const Color(0xFF64748B);
  // Very light blue for overall background (from ProfessionalOrdersPage)
  Color get _lightBlueBackground => const Color(0xFFF0F9FF);
  // White for card backgrounds
  Color get _cardBackground => Colors.white;
  // Consistent shadow style for cards
  BoxShadow get _cardShadow => BoxShadow(
    color: Colors.black.withOpacity(0.05),
    spreadRadius: 0,
    blurRadius: 10,
    offset: const Offset(0, 4),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightBlueBackground, // Use light blue for overall background
      appBar: AppBar(
        title: Text(
          'My Profile', // Changed AppBar title to "My Profile"
          style: TextStyle(
            color: _darkTextColor, // App bar title in dark text color
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: _cardBackground, // White app bar background
        elevation: 1, // Slightly raised app bar
        iconTheme: IconThemeData(color: _darkTextColor), // Icons in dark text color
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
                  width: 40, // Reduced button size
                  height: 40, // Reduced button size
                  decoration: BoxDecoration(
                    // Conditional gradient for badge button
                    gradient: badgeStatus == 'assigned'
                        ? LinearGradient(colors: [const Color(0xFF4CAF50), const Color(0xFF81C784)]) // Green gradient for assigned
                        : badgeStatus == 'pending'
                        ? LinearGradient(colors: [const Color(0xFFFF9800), const Color(0xFFFFCC80)]) // Orange gradient for pending
                        : LinearGradient(colors: [_primaryBlue, _secondaryBlue]), // Blue gradient for 'none'
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero, // Remove default padding
                    icon: Icon(
                      badgeStatus == 'assigned' ? Icons.verified : Icons.verified_outlined,
                      color: Colors.white,
                      size: 20, // Reduced icon size
                    ),
                    tooltip: badgeStatus == 'assigned'
                        ? 'Verified Professional'
                        : badgeStatus == 'pending'
                        ? 'Badge request is pending review'
                        : 'Request for Badge',
                    onPressed: () async {
                      if (badgeStatus == 'none') {
                        await FirebaseFirestore.instance.collection('users').doc(userId).update({
                          'badgeStatus': 'pending',
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
                        } else {
                          await FirebaseFirestore.instance.collection('users').doc(userId).update({
                            'badgeStatus': 'none',
                          });
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
            width: 40, // Reduced button size
            height: 40, // Reduced button size
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_primaryBlue, _secondaryBlue]), // Gradient for Edit button
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              padding: EdgeInsets.zero, // Remove default padding
              icon: const Icon(Icons.edit, color: Colors.white, size: 20), // Reduced icon size
              tooltip: 'Edit Profile',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return EditProfileDialog(userId: userId);
                  },
                );
              },
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            width: 40, // Reduced button size
            height: 40, // Reduced button size
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [const Color(0xFFEF5350), const Color(0xFFFFCDD2)]), // Gradient for Logout button
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              padding: EdgeInsets.zero, // Remove default padding
              icon: const Icon(Icons.logout, color: Colors.white, size: 20), // Reduced icon size
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
                  color: _darkTextColor,
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
    final badgeStatus = (userData['badgeStatus'] ?? 'none').toString().toLowerCase(); // Get badgeStatus

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('services').where('userId', isEqualTo: userId).snapshots(),
      builder: (context, servicesSnapshot) {
        final services = servicesSnapshot.data?.docs ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Profile Header Card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF22D3EE), Color(0xFF0EA5E9)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [_cardShadow],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20), // Increased vertical padding
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
                          border: Border.all(color: Colors.white.withOpacity(0.5), width: 3), // White border for contrast
                        ),
                        child: CircleAvatar(
                          radius: 40, // Slightly increased avatar size
                          backgroundColor: Colors.white.withOpacity(0.2), // More translucent background
                          backgroundImage: (profileImage?.toString().isNotEmpty ?? false)
                              ? NetworkImage(profileImage)
                              : null,
                          child: (profileImage == null || profileImage.toString().isEmpty)
                              ? Icon(Icons.person, size: 40, color: Colors.white)
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      userData['name'] ?? 'No Name',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // "Professional" text with conditional star badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            spreadRadius: 0,
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min, // Keep the row size to its content
                        children: [
                          Text(
                            'Professional',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _secondaryBlue, // Use secondary blue for the text
                            ),
                          ),
                          if (badgeStatus == 'assigned') ...[
                            const SizedBox(width: 6), // Spacing between text and badge
                            const Icon(
                              Icons.verified, // Star badge icon
                              color: Color(0xFF4CAF50), // Green color for verified badge
                              size: 18.0,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'CNIC: $cnic',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.8), // Lighter text color for CNIC
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Member Since Card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [_cardShadow],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), // Standardized padding
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.calendar_today,
                        color: _primaryBlue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Member Since: $createdAt',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _darkTextColor,
                      ),
                    ),
                  ],
                ),
              ),

              if (services.isNotEmpty) ...[
                const SizedBox(height: 16),

                // Services Header - WITH GRADIENT
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_primaryBlue, _secondaryBlue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [_cardShadow],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Services Providing',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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
                        color: _cardBackground,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [_cardShadow],
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
                                    color: _primaryBlue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    serviceCategory,
                                    style: TextStyle(
                                      color: _primaryBlue,
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
                                    color: _darkTextColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Added on: $serviceCreatedAt',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
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
                          // Average Rating Card - WITH GRADIENT
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.amber.shade600, Colors.amber.shade400],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [_cardShadow],
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.star, color: Colors.white, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Average Rating: ${averageRating.toStringAsFixed(1)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Use ReviewCarousel for reviews
                          ReviewCarousel(reviews: reviewDocs),
                        ] else
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: _cardBackground,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [_cardShadow],
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'No reviews yet.',
                              style: TextStyle(
                                color: _secondaryTextColor,
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

class ReviewCarousel extends StatefulWidget {
  final List<QueryDocumentSnapshot> reviews;

  const ReviewCarousel({
    Key? key,
    required this.reviews,
  }) : super(key: key);

  @override
  State<ReviewCarousel> createState() => _ReviewCarouselState();
}

class _ReviewCarouselState extends State<ReviewCarousel> {
  PageController? _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.reviews.isNotEmpty) {
      _pageController = PageController();
      _pageController!.addListener(() {
        setState(() {
          _currentIndex = _pageController!.page!.round();
        });
      });
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  String _formatTimestamp(dynamic timestamp) {
    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return '${date.day}/${date.month}/${date.year}';
      } else if (timestamp is String) {
        final date = DateTime.parse(timestamp);
        return '${date.day}/${date.month}/${date.year}';
      }
      return 'Recent';
    } catch (e) {
      return 'Recent';
    }
  }

  // Consistent shadow style for cards (copied from ProfessionalProfile)
  BoxShadow get _cardShadow => BoxShadow(
    color: Colors.black.withOpacity(0.05),
    spreadRadius: 0,
    blurRadius: 10,
    offset: const Offset(0, 4),
  );

  // White for card backgrounds (copied from ProfessionalProfile)
  Color get _cardBackground => Colors.white;

  // Darker text color (copied from ProfessionalProfile)
  Color get _darkTextColor => const Color(0xFF1E293B);

  // Secondary text color/grey (copied from ProfessionalProfile)
  Color get _secondaryTextColor => const Color(0xFF64748B);


  @override
  Widget build(BuildContext context) {
    if (widget.reviews.isEmpty) {
      return const SizedBox.shrink(); // Don't show carousel if no reviews
    }

    return Column(
      children: [
        SizedBox(
          height: 160, // Increased height to accommodate more text
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.reviews.length,
            itemBuilder: (context, index) {
              final data = widget.reviews[index].data() as Map<String, dynamic>;
              final rating = (data['rating'] ?? 0).toDouble();
              final text = data['reviewText'] ?? '';
              final customerId = data['customerId'] ?? '';
              final timestamp = data['timestamp'];
              final formattedDate = _formatTimestamp(timestamp);

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(customerId).get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final reviewerData = snapshot.data!.data() as Map<String, dynamic>;
                  final reviewerName = reviewerData['name'] ?? 'Anonymous';


                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 5), // Added horizontal margin
                    decoration: BoxDecoration(
                      color: _cardBackground,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [_cardShadow],
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              reviewerName,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: _darkTextColor,
                              ),
                            ),
                            Text(
                              formattedDate,
                              style: TextStyle(
                                fontSize: 11,
                                color: _secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: List.generate(
                            rating.floor(),
                                (_) => const Icon(Icons.star, size: 16, color: Colors.amber),
                          ) +
                              (rating - rating.floor() >= 0.5
                                  ? [const Icon(Icons.star_half, size: 16, color: Colors.amber)]
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
                              color: _secondaryTextColor,
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
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.reviews.length, (index) {
            return Container(
              width: 8.0,
              height: 8.0,
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentIndex == index ? Colors.blueAccent : Colors.grey.withOpacity(0.5),
              ),
            );
          }),
        ),
      ],
    );
  }
}