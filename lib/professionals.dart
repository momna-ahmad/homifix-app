import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfessionalsPage extends StatefulWidget {
  const ProfessionalsPage({super.key});

  @override
  State<ProfessionalsPage> createState() => _ProfessionalsPageState();
}

class _ProfessionalsPageState extends State<ProfessionalsPage> {
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
      appBar: AppBar(
        title: const Text('All Professionals'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by professional name',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Results List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', whereIn: ['Professional', 'professional']) // Handle case variations
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No professionals found.'),
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
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];

                    // Try different ways to access the data
                    Map<String, dynamic> userData;
                    try {
                      userData = user.data() as Map<String, dynamic>;
                    } catch (e) {
                      print('Error accessing user data: $e');
                      userData = {};
                    }

                    // Debug: Print user data to console
                    print('User ID: ${user.id}');
                    print('User Data Keys: ${userData.keys.toList()}');
                    print('Full User Data: $userData');

                    // Safely extract fields with multiple fallback approaches
                    final name = userData['name']?.toString() ??
                        userData['Name']?.toString() ??
                        userData['userName']?.toString() ?? 'No Name';

                    final email = userData['email']?.toString() ??
                        userData['Email']?.toString() ??
                        userData['emailAddress']?.toString() ?? 'N/A';

                    final role = userData['role']?.toString() ??
                        userData['Role']?.toString() ??
                        userData['userRole']?.toString() ?? 'No Role';

                    // ✅ Fixed: Consistent isReported check (prioritize 'isReported' field)
                    final isReported = userData['isReported'] == true ||
                        userData['reported'] == true ||
                        userData['Reported'] == true;

                    // ✅ Fixed: Consistent isDisabled check (prioritize 'isDisabled' field)  
                    final isDisabled = userData['isDisabled'] == true ||
                        userData['disabled'] == true ||
                        userData['Disabled'] == true;

                    final userId = user.id;

                    return FutureBuilder<List<dynamic>>(
                      future: Future.wait([
                        _calculateRating(userId),
                        _getServiceCategories(userId),
                      ]),
                      builder: (context, futureSnapshot) {
                        final rating = futureSnapshot.hasData
                            ? (futureSnapshot.data![0] as double).toStringAsFixed(1)
                            : '0.0';
                        final categories = futureSnapshot.hasData
                            ? futureSnapshot.data![1] as List<String>
                            : ['Loading...'];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8.0),
                          elevation: 2.0,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    if (isDisabled)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0,
                                          vertical: 4.0,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          'Disabled',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    if (isReported && !isDisabled)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0,
                                          vertical: 4.0,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          'Reported',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Categories: ${categories.join(', ')}",
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Role: $role",
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Email: $email",
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Rating: $rating",
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // ✅ Show disable button only if worker is reported and not already disabled
                                    if (isReported && !isDisabled)
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: () => _disableUser(userId, context),
                                          icon: const Icon(Icons.block, size: 16),
                                          label: const Text('Disable'),
                                        ),
                                      ),
                                    // ✅ Show disabled button if worker is already disabled
                                    if (isDisabled)
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.grey,
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: null, // Disabled button
                                          icon: const Icon(Icons.block, size: 16),
                                          label: const Text('Disabled'),
                                        ),
                                      ),
                                    // ✅ Show nothing if not reported and not disabled
                                    if (!isReported && !isDisabled)
                                      Expanded(
                                        child: Center(
                                          child: Text(
                                            'No actions available',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
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

  // ✅ Fixed: Updated to use 'isDisabled' instead of 'disabled' for consistency
  void _disableUser(String userId, BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Disable User'),
          content: const Text('Are you sure you want to disable this user? They will not be able to work until enabled again.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .update({
                    'isDisabled': true,  // ✅ Using consistent field name
                    'disabledAt': FieldValue.serverTimestamp(),
                  });

                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('User has been disabled')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error disabling user: $e')),
                    );
                  }
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Disable'),
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
