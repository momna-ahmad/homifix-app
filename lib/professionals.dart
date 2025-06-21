import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:home_services_app/profilePage.dart';
import 'professional_orders_page.dart';

class ProfessionalsPageWithOrders extends StatefulWidget {
  final String userId;

  const ProfessionalsPageWithOrders({super.key, required this.userId});

  @override
  State<ProfessionalsPageWithOrders> createState() => _ProfessionalsPageWithOrdersState();
}

class _ProfessionalsPageWithOrdersState extends State<ProfessionalsPageWithOrders> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
      final ordersSnap = await FirebaseFirestore.instance
          .collection('orders')
          .where('professionalId', isEqualTo: professionalId)
          .get();

      return ordersSnap.docs.length;
    } catch (e) {
      print('Error fetching order count: $e');
      return 0;
    }
  }

  List<QueryDocumentSnapshot> _filterUsers(List<QueryDocumentSnapshot> users) {
    return users.where((user) {
      final userData = user.data() as Map<String, dynamic>? ?? {};
      final name = (userData['name'] ?? '').toString().toLowerCase();
      final matchesSearch = _searchQuery.isEmpty ||
          name.contains(_searchQuery.toLowerCase());

      return matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'All Professionals',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: Color(0xFF2D3748),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2D3748)),
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
          // Search Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAFC),
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by professional name',
                  hintStyle: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 16,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: const Color(0xFF4299E1),
                    size: 22,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 16.0,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF2D3748),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
          ),

          // Results List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', whereIn: ['Professional', 'professional'])
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4299E1)),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF718096),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No professionals found.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF718096),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final allUsers = snapshot.data!.docs;
                final filteredUsers = _filterUsers(allUsers);

                if (filteredUsers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No professionals found matching "$_searchQuery"'
                              : 'No professionals found',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF718096),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];

                    Map<String, dynamic> userData;
                    try {
                      userData = user.data() as Map<String, dynamic>;
                    } catch (e) {
                      print('Error accessing user data: $e');
                      userData = {};
                    }

                    final name = userData['name']?.toString() ??
                        userData['Name']?.toString() ??
                        userData['userName']?.toString() ?? 'No Name';

                    final email = userData['email']?.toString() ??
                        userData['Email']?.toString() ??
                        userData['emailAddress']?.toString() ?? 'N/A';

                    final profileImageUrl = userData['profileImageUrl']?.toString() ??
                        userData['profileImage']?.toString() ??
                        userData['imageUrl']?.toString();

                    final isReported = userData['isReported'] == true ||
                        userData['reported'] == true ||
                        userData['Reported'] == true;

                    final isDisabled = userData['isDisabled'] == true ||
                        userData['disabled'] == true ||
                        userData['Disabled'] == true;

                    final userId = user.id;

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
                          onTap: () {
                            // Show bottom sheet with options
                            _showOptionsBottomSheet(context, userId, name, orderCount);
                          },
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
                                        // Name and Status Row
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 18,
                                                  color: Color(0xFF2D3748),
                                                ),
                                              ),
                                            ),
                                            if (isDisabled)
                                              _buildStatusChip('Disabled', Colors.red),
                                            if (isReported && !isDisabled)
                                              _buildStatusChip('Reported', Colors.orange),
                                          ],
                                        ),

                                        const SizedBox(height: 8),

                                        // Order Count Badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEDF2F7),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: const Color(0xFF4A5568)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.receipt_long,
                                                size: 14,
                                                color: Color(0xFF4A5568),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '$orderCount Orders',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF4A5568),
                                                ),
                                              ),
                                            ],
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
                                                color: const Color(0xFFEBF8FF),
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(color: const Color(0xFF4299E1)),
                                              ),
                                              child: Text(
                                                category,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF2B6CB0),
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

                                        const SizedBox(height: 16),

                                        // Action Buttons
                                        if (isReported && !isDisabled)
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFFE53E3E),
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                              onPressed: () => _disableUser(userId, context),
                                              child: const Text(
                                                'Disable',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ),

                                        if (isDisabled)
                                          SizedBox(
                                            width: double.infinity,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF7FAFC),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                              ),
                                              child: const Text(
                                                'Disabled',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: Color(0xFF718096),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ),
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

  void _showOptionsBottomSheet(BuildContext context, String userId, String name, int orderCount) {
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
                  color: Color(0xFF2D3748),
                ),
              ),

              const SizedBox(height: 20),

              // View Profile Option
              ListTile(
                leading: const Icon(
                  Icons.person_outline,
                  color: Color(0xFF4299E1),
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
                      builder: (_) => ProfilePage(
                        userId: userId,
                        isAdmin: true,
                      ),
                    ),
                  );
                },
              ),

              // View Orders Option
              ListTile(
                leading: const Icon(
                  Icons.receipt_long_outlined,
                  color: Color(0xFF38A169),
                ),
                title: Text(
                  'View Orders ($orderCount)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfessionalOrdersPage(
                        professionalId: userId,
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

  Widget _buildDefaultAvatar(String name) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF4299E1),
            const Color(0xFF3182CE),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
              color: Color(0xFF2D3748),
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
                backgroundColor: const Color(0xFFE53E3E),
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
                        backgroundColor: const Color(0xFF38A169),
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
                        backgroundColor: const Color(0xFFE53E3E),
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
