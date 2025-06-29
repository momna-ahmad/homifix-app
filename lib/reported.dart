import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:home_services_app/professionalForCustomer.dart';
import 'professional_orders_page.dart';
import 'reports_detail_page.dart';

class ReportsPage extends StatefulWidget {
  final String userId;

  const ReportsPage({super.key, required this.userId});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  // Updated stream to fetch users based on reportCount > 0
  Stream<QuerySnapshot> _reportedUsersStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('reportCount', isGreaterThan: 0)
        .snapshots();
  }

  Future<double> _calculateRating(String userId) async {
    try {
      final reviewsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reviews')
          .get();

      if (reviewsSnap.docs.isEmpty) return 0.0;

      double total = 0.0;
      int validRatings = 0;

      for (var doc in reviewsSnap.docs) {
        final rating = doc.data()['rating'];
        if (rating != null) {
          total += (rating is int) ? rating.toDouble() : (rating as double? ?? 0.0);
          validRatings++;
        }
      }

      return validRatings > 0 ? total / validRatings : 0.0;
    } catch (e) {
      print('Error calculating rating: $e');
      return 0.0;
    }
  }

  Future<List<String>> _getServiceCategories(String userId) async {
    try {
      final servicesSnap = await FirebaseFirestore.instance
          .collection('services')
          .where('userId', isEqualTo: userId)
          .get();

      if (servicesSnap.docs.isNotEmpty) {
        List<String> categories = [];
        for (var doc in servicesSnap.docs) {
          final serviceData = doc.data();
          final category = serviceData['category']?.toString();
          if (category != null && category.isNotEmpty) {
            categories.add(category);
          }
        }
        return categories.isNotEmpty ? categories : ['No Categories Found'];
      }

      return ['No Services Found'];
    } catch (e) {
      print('Error fetching service categories: $e');
      return ['Error Loading Categories'];
    }
  }

  Future<int> _getOrderCount(String professionalId) async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(professionalId)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        final orders = data['orders'] as List<dynamic>?;

        if (orders == null) return 0;

        final filtered = orders.where((order) {
          final status = (order['completionStatus'] ?? '').toString().toLowerCase();
          return status == 'assigned' || status == 'completed' || status == 'pending';
        }).toList();

        return filtered.length;
      } else {
        return 0;
      }
    } catch (e) {
      print('Error fetching order count: $e');
      return 0;
    }
  }

  // Get report count directly from user document data (no need for separate fetch)
  int _getReportCount(Map<String, dynamic> userData) {
    final reportCount = userData['reportCount'] as int?;
    return reportCount ?? 0;
  }

  // Get warning count from user document
  int _getWarningCount(Map<String, dynamic> userData) {
    final warnings = userData['warnings'] as List<dynamic>?;
    return warnings?.length ?? 0;
  }

  // Badge Management Card
  Widget _buildBadgeManagementCard() {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF22D3EE), Color(0xFF0EA5E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF22D3EE).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reports Management',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage your Professionals',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.verified_user,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCountBadge(int orderCount, String professionalId, String professionalName) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfessionalOrdersPage(
              professionalId: professionalId,
              professionalName: professionalName,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF22D3EE), Color(0xFF0EA5E9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF22D3EE).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          '$orderCount',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildYellowStarBadge() {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFFFBBF24),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFBBF24).withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: const Icon(
        Icons.star,
        color: Colors.white,
        size: 14,
      ),
    );
  }

  Widget _buildDefaultAvatar(String name) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF22D3EE), Color(0xFF0EA5E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // Bottom sheet with options
  void _showOptionsBottomSheet(BuildContext context, String userId, String name) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A202C),
                ),
              ),

              const SizedBox(height: 20),

              // View Profile Option
              ListTile(
                leading: const Icon(
                  Icons.person_outline,
                  color: Color(0xFF22D3EE),
                ),
                title: const Text(
                  'View Profile',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfessionalForCustomer(userId: userId),
                    ),
                  );
                },
              ),

              // View Reports Option
              ListTile(
                leading: const Icon(
                  Icons.report_outlined,
                  color: Color(0xFFDC2626),
                ),
                title: const Text(
                  'View Reports',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReportsDetailPage(
                        userId: userId,
                        professionalName: name,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _disableUser(String userId, BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Disable User',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A202C),
            ),
          ),
          content: const Text(
            'Are you sure you want to disable this user? They will not be able to work until enabled again.',
            style: TextStyle(
              color: Color(0xFF4A5568),
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFF718096),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .update({
                    'isDisabled': true,
                    'disabledAt': FieldValue.serverTimestamp(),
                  });

                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('User has been disabled'),
                        backgroundColor: const Color(0xFF059669),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error disabling user: $e'),
                        backgroundColor: const Color(0xFFDC2626),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'Disable',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        title: const Text(
          'Reported Users',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: Color(0xFF1A202C),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A202C)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: const Color(0xFFE2E8F0),
          ),
        ),
      ),
      body: Column(
        children: [
          // Badge Management Card
          _buildBadgeManagementCard(),

          // Results List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _reportedUsersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF22D3EE)),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.report_gmailerrorred, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text(
                          'No reported users found',
                          style: TextStyle(fontSize: 16, color: Color(0xFF718096)),
                        ),
                      ],
                    ),
                  );
                }

                final reportedUsers = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: reportedUsers.length,
                  itemBuilder: (context, index) {
                    final user = reportedUsers[index];
                    final userData = user.data() as Map<String, dynamic>;

                    final name = userData['name']?.toString() ??
                        userData['Name']?.toString() ??
                        userData['userName']?.toString() ?? 'No Name';

                    final profileImageUrl = userData['profileImageUrl']?.toString() ??
                        userData['profileImage']?.toString() ??
                        userData['imageUrl']?.toString();

                    final isDisabled = userData['isDisabled'] == true ||
                        userData['disabled'] == true ||
                        userData['Disabled'] == true;

                    final badgeStatus = userData['badgeStatus']?.toString().toLowerCase();
                    final showStar = badgeStatus == 'assigned';

                    final userId = user.id;
                    final reportCount = _getReportCount(userData);

                    return FutureBuilder<List<dynamic>>(
                      future: Future.wait([
                        _calculateRating(userId),
                        _getServiceCategories(userId),
                        _getOrderCount(userId),
                      ]),
                      builder: (context, futureSnapshot) {
                        final rating = futureSnapshot.hasData
                            ? (futureSnapshot.data![0] as double)
                            : 0.0;
                        final categories = futureSnapshot.hasData
                            ? futureSnapshot.data![1] as List<String>
                            : ['Loading...'];
                        final orderCount = futureSnapshot.hasData
                            ? (futureSnapshot.data![2] as int)
                            : 0;

                        return GestureDetector(
                          onTap: () => _showOptionsBottomSheet(context, userId, name),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16.0),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16.0),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Profile Picture
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12.0),
                                      color: const Color(0xFFF7FAFC),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                        width: 1,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12.0),
                                      child: profileImageUrl != null && profileImageUrl.isNotEmpty
                                          ? Image.network(
                                        profileImageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return _buildDefaultAvatar(name);
                                        },
                                      )
                                          : _buildDefaultAvatar(name),
                                    ),
                                  ),

                                  const SizedBox(width: 16),

                                  // Content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Name and Order Count Row with Star
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 18,
                                                  color: Color(0xFF1A202C),
                                                ),
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                if (showStar) ...[
                                                  _buildYellowStarBadge(),
                                                  const SizedBox(width: 8),
                                                ],
                                                _buildOrderCountBadge(orderCount, userId, name),
                                              ],
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 8),

                                        // Role/Category
                                        Text(
                                          'Professional',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF22D3EE),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 8),

                                        // Categories
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: categories.map((category) {
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFECFDF5),
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(color: const Color(0xFF67E8F9)),
                                              ),
                                              child: Text(
                                                category,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF22D3EE),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),

                                        const SizedBox(height: 8),

                                        // Rating
                                        Row(
                                          children: [
                                            ...List.generate(5, (starIndex) {
                                              return Icon(
                                                starIndex < rating.floor()
                                                    ? Icons.star
                                                    : starIndex < rating
                                                    ? Icons.star_half
                                                    : Icons.star_border,
                                                color: const Color(0xFFFBBF24),
                                                size: 16,
                                              );
                                            }),
                                            const SizedBox(width: 8),
                                            Text(
                                              rating.toStringAsFixed(1),
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Color(0xFF718096),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),

                                        // Status Chips - Shows report count
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            if (isDisabled)
                                              _buildStatusChip('Disabled', const Color(0xFFDC2626))
                                            else
                                              _buildStatusChip('Reports ($reportCount)', const Color(0xFFD97706)),
                                          ],
                                        ),

                                        const SizedBox(height: 16),

                                        // Action Button (only Disable)
                                        if (!isDisabled) ...[
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFFDC2626),
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                              onPressed: () => _disableUser(userId, context),
                                              child: const Text(
                                                'Disable User',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ] else ...[
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF7FAFC),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFFE2E8F0)),
                                            ),
                                            child: const Text(
                                              'User Disabled',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Color(0xFF718096),
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
