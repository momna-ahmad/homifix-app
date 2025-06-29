import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'login.dart';

// ✅ RIVERPOD PROVIDERS

// User Data Provider with real-time updates
final userDataProvider = StreamProvider.family<DocumentSnapshot<Map<String, dynamic>>?, String>((ref, userId) {
  print('🔄 RIVERPOD: Setting up user data stream for: $userId');

  return FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .snapshots()
      .map((snapshot) {
    print('📡 RIVERPOD: User data update received');
    return snapshot.exists ? snapshot : null;
  });
});
final notificationsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('orders')
      .where('customerId', isEqualTo: user.uid)
      .where('status', isEqualTo: 'cancelled')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => {
    'id': doc.id,
    ...doc.data() as Map<String, dynamic>
  }).toList());
});

// Profile Actions Provider
final profileActionsProvider = Provider<ProfileActions>((ref) {
  return ProfileActions(ref);
});

class ProfileActions {
  final Ref ref;
  ProfileActions(this.ref);

  // Cloudinary configuration
  static const String cloudinaryCloudName = 'dnpcloh3n';
  static const String cloudinaryUploadPreset = 'flutter_unsigned';

  // Upload image to Cloudinary
  Future<String?> uploadImageToCloudinary(File imageFile, String userId) async {
    try {
      print('🔄 RIVERPOD: Starting Cloudinary upload...');
      print('☁️ Cloud Name: $cloudinaryCloudName');
      print('📤 Upload Preset: $cloudinaryUploadPreset');
      print('📁 File path: ${imageFile.path}');

      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudinaryCloudName/image/upload');
      final request = http.MultipartRequest('POST', url);

      // Add required fields
      request.fields['upload_preset'] = cloudinaryUploadPreset;
      request.fields['folder'] = 'profile_images';
      request.fields['public_id'] = 'profile_${userId}_${DateTime.now().millisecondsSinceEpoch}';

      // Add the file
      final multipartFile = await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        filename: 'profile_$userId.jpg',
      );
      request.files.add(multipartFile);

      print('📤 RIVERPOD: Sending request to Cloudinary...');
      final response = await request.send();
      print('📊 RIVERPOD: Response status code: ${response.statusCode}');

      final responseData = await response.stream.toBytes();
      final responseString = String.fromCharCodes(responseData);

      if (response.statusCode == 200) {
        final jsonMap = json.decode(responseString);
        final secureUrl = jsonMap['secure_url'];
        print('✅ RIVERPOD: Upload successful! URL: $secureUrl');
        return secureUrl;
      } else {
        print('❌ RIVERPOD: Upload failed with status: ${response.statusCode}');
        final errorData = json.decode(responseString);
        throw Exception('Cloudinary upload failed: ${errorData['error']['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      print('❌ RIVERPOD: Upload error: $e');
      throw Exception('Error uploading image: $e');
    }
  }
  Future<void> receiveApplications(String orderId) async {
    try {
      final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);

      // Get the current order data first
      final orderSnapshot = await orderRef.get();
      if (!orderSnapshot.exists) {
        throw Exception('Order not found');
      }

      final orderData = orderSnapshot.data() as Map<String, dynamic>;
      final selectedWorkerId = orderData['selectedWorkerId'] as String?;

      // Get current applications array
      List<String> currentApplications = [];
      if (orderData['applications'] != null) {
        currentApplications = List<String>.from(orderData['applications']);
      }

      // Remove only the selected worker (who cancelled) from applications array
      if (selectedWorkerId != null && currentApplications.contains(selectedWorkerId)) {
        currentApplications.remove(selectedWorkerId);
      }

      // Update the order status and reset selectedWorkerId, keep other applications
      await orderRef.update({
        'selectedWorkerId': null,
        'status': 'pending',
        'applications': currentApplications, // Keep other applications, remove only cancelled worker
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Remove this order from the cancelled worker's appliedOrders
      if (selectedWorkerId != null) {
        final workerRef = FirebaseFirestore.instance.collection('workers').doc(selectedWorkerId);
        await workerRef.update({
          'appliedOrders': FieldValue.arrayRemove([orderId])
        });
      }

    } catch (e) {
      throw Exception('Failed to receive applications: $e');
    }
  }

  Future<void> markNotificationAsRead(String orderId) async {
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
        'notificationRead': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  // Update user profile
  Future<void> updateUserProfile(String userId, Map<String, dynamic> updates) async {
    try {
      print('🔄 RIVERPOD: Updating user profile: $userId');
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update(updates);
      print('✅ RIVERPOD: Profile updated successfully');
    } catch (e) {
      print('❌ RIVERPOD: Error updating profile: $e');
      rethrow;
    }
  }

  // Logout user
  Future<void> logoutUser() async {
    try {
      print('🔄 RIVERPOD: Logging out user...');
      await FirebaseAuth.instance.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      print('✅ RIVERPOD: User logged out successfully');
    } catch (e) {
      print('❌ RIVERPOD: Error logging out: $e');
      rethrow;
    }
  }
}

class CustomerProfile extends ConsumerStatefulWidget {
  final String userId;
  const CustomerProfile({super.key, required this.userId});

  @override
  ConsumerState<CustomerProfile> createState() => _CustomerProfileState();
}

class _CustomerProfileState extends ConsumerState<CustomerProfile>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  // Function to show image picker options
  void _showImagePickerOptions(Map<String, dynamic> userData) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF00BCD4), // ✅ Updated color
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Update Profile Picture',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00838F), // ✅ Updated color
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImagePickerOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUploadImage(ImageSource.camera);
                  },
                ),
                _buildImagePickerOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUploadImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }


  Widget _buildImagePickerOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFE3F2FD), // ✅ Updated color
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF00BCD4).withOpacity(0.3), // ✅ Updated color
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF00BCD4), // ✅ Updated color
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF00838F), // ✅ Updated color
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Function to pick and upload image using Riverpod
  void _pickAndUploadImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        // Show loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00BCD4)), // ✅ Updated color
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Uploading image...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF00838F), // ✅ Updated color
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        try {
          final profileActions = ref.read(profileActionsProvider);

          // Upload to Cloudinary
          final imageUrl = await profileActions.uploadImageToCloudinary(
            File(image.path),
            widget.userId,
          );

          if (imageUrl != null) {
            // Update Firestore using Riverpod
            await profileActions.updateUserProfile(widget.userId, {
              'profileImage': imageUrl,
            });

            // Close loading dialog
            if (mounted) Navigator.pop(context);

            // Show success message
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 12),
                      Text('Profile picture updated successfully!'),
                    ],
                  ),
                  backgroundColor: const Color(0xFF10B981),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            }
          }
        } catch (e) {
          // Close loading dialog
          if (mounted) Navigator.pop(context);

          // Show error message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error uploading image: ${e.toString()}'),
                backgroundColor: Colors.red.shade400,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting image: ${e.toString()}'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  // Edit profile dialog using Riverpod
  void _showEditProfileDialog(Map<String, dynamic> userData) {
    final TextEditingController nameController = TextEditingController(
      text: userData['name'] ?? '',
    );
    bool isUpdating = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00BCD4).withOpacity(0.1), // ✅ Updated shadow
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00BCD4).withOpacity(0.1), // ✅ Updated color
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.edit,
                          color: Color(0xFF00BCD4), // ✅ Updated color
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Edit Profile',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00838F), // ✅ Updated color
                          ),
                        ),
                      ),
                      if (!isUpdating)
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.close,
                            color: Color(0xFF636E72),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Current Profile Image Display (Read-only)
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF00BCD4).withOpacity(0.3), // ✅ Updated color
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00BCD4).withOpacity(0.2), // ✅ Updated shadow
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: const Color(0xFFE3F2FD), // ✅ Updated color
                      backgroundImage: (userData['profileImage'] != null &&
                          userData['profileImage'].toString().isNotEmpty)
                          ? NetworkImage(userData['profileImage'])
                          : null,
                      child: (userData['profileImage'] == null ||
                          userData['profileImage'].toString().isEmpty)
                          ? const Icon(
                        Icons.person,
                        size: 60,
                        color: Color(0xFF636E72),
                      )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Profile picture can be changed from main screen',
                    style: TextStyle(
                      fontSize: 14,
                      color: const Color(0xFF636E72).withOpacity(0.8),
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Name Field
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD), // ✅ Updated color
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF00BCD4).withOpacity(0.3), // ✅ Updated color
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: nameController,
                      enabled: !isUpdating,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF00838F), // ✅ Updated color
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        labelStyle: TextStyle(
                          color: const Color(0xFF636E72).withOpacity(0.8),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(20),
                        prefixIcon: Container(
                          margin: const EdgeInsets.all(12),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00BCD4).withOpacity(0.1), // ✅ Updated color
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.person_outline,
                            color: Color(0xFF00BCD4), // ✅ Updated color
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD), // ✅ Updated color
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF00BCD4).withOpacity(0.3), // ✅ Updated color
                              width: 1,
                            ),
                          ),
                          child: TextButton(
                            onPressed: isUpdating ? null : () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                color: Color(0xFF636E72),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00BCD4), Color(0xFF00ACC1)], // ✅ Updated colors
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00BCD4).withOpacity(0.3), // ✅ Updated shadow
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: isUpdating
                                ? null
                                : () async {
                              if (nameController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Name cannot be empty'),
                                    backgroundColor: Colors.red.shade400,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                );
                                return;
                              }

                              setDialogState(() {
                                isUpdating = true;
                              });

                              try {
                                final profileActions = ref.read(profileActionsProvider);
                                await profileActions.updateUserProfile(widget.userId, {
                                  'name': nameController.text.trim(),
                                });

                                if (mounted) {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Row(
                                        children: [
                                          Icon(Icons.check_circle, color: Colors.white),
                                          SizedBox(width: 12),
                                          Text('Profile updated successfully!'),
                                        ],
                                      ),
                                      backgroundColor: const Color(0xFF10B981),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                setDialogState(() {
                                  isUpdating = false;
                                });

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error updating profile: ${e.toString()}'),
                                      backgroundColor: Colors.red.shade400,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: isUpdating
                                ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                                : const Text(
                              'Save Changes',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void logoutUser(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00BCD4).withOpacity(0.1), // ✅ Updated shadow
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade400.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.logout,
                  color: Colors.red.shade400,
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Logout',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00838F), // ✅ Updated color
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to logout?',
                style: TextStyle(
                  fontSize: 16,
                  color: const Color(0xFF636E72).withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD), // ✅ Updated color
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF00BCD4).withOpacity(0.3), // ✅ Updated color
                          width: 1,
                        ),
                      ),
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Color(0xFF636E72),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.red.shade400,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.shade400.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Logout',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (shouldLogout == true) {
      try {
        final profileActions = ref.read(profileActionsProvider);
        await profileActions.logoutUser();

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error logging out: ${e.toString()}'),
              backgroundColor: Colors.red.shade400,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    }
  }

  void _showImageViewer(String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: PhotoView(
                imageProvider: NetworkImage(imageUrl),
                backgroundDecoration: const BoxDecoration(
                  color: Colors.transparent,
                ),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final notificationsAsync = ref.watch(notificationsProvider);

          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),

                Divider(height: 1),

                // Content
                Expanded(
                  child: notificationsAsync.when(
                    data: (notifications) {
                      if (notifications.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.notifications_off_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No notifications',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: notifications.length,
                        itemBuilder: (context, index) {
                          final notification = notifications[index];
                          final orderId = notification['id'];
                          final serviceName = notification['serviceName'] ?? 'Unknown Service';
                          final workerName = notification['workerName'] ?? 'Unknown Worker';
                          final cancelledAt = notification['cancelledAt'];

                          return Container(
                            margin: EdgeInsets.only(bottom: 12),
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.cancel_outlined,
                                      color: Colors.red[600],
                                      size: 24,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Order Cancelled',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.red[800],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                SizedBox(height: 8),

                                Text(
                                  'Service: $serviceName',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),

                                Text(
                                  'Worker: $workerName',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),

                                if (cancelledAt != null)
                                  Text(
                                    'Cancelled: ${_formatDate(cancelledAt)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),

                                SizedBox(height: 12),

                                // Action Buttons
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Order cancellation confirmed'),
                                              backgroundColor: Colors.red[600],
                                            ),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red[600],
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: Text(
                                          'Cancel Order',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ),

                                    SizedBox(width: 8),

                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          try {
                                            await ref.read(profileActionsProvider)
                                                .receiveApplications(orderId);

                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Order restored to pending status'),
                                                backgroundColor: Colors.green[600],
                                              ),
                                            );
                                          } catch (e) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Failed to restore order'),
                                                backgroundColor: Colors.red[600],
                                              ),
                                            );
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue[600],
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: Text(
                                          'Receive Applications',
                                          style: TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    loading: () => Center(
                      child: CircularProgressIndicator(
                        color: Colors.blue[600],
                      ),
                    ),
                    error: (error, stack) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Failed to load notifications',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.red[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

// Helper method for date formatting (add this too)
  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      return 'Unknown';
    }

    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
  @override
  Widget build(BuildContext context) {
    final userDataAsync = ref.watch(userDataProvider(widget.userId));

    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD), // ✅ Updated background color
      appBar: AppBar(
        title: const Text(
          'Customer Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color(0xFF00BCD4),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // 🔔 NEW NOTIFICATION BELL ICON
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Consumer(
              builder: (context, ref, child) {
                final notificationsAsync = ref.watch(notificationsProvider);

                return Stack(
                  children: [
                    IconButton(
                      onPressed: () => _showNotifications(),
                      icon: const Icon(Icons.notifications_outlined, size: 20),
                      tooltip: 'Notifications',
                    ),
                    // Notification badge
                    notificationsAsync.when(
                      data: (notificationsSnapshot) {
                        final count = notificationsSnapshot?.length ?? 0;
                        if (count == 0) return const SizedBox.shrink();

                        return Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red.shade400,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              count > 99 ? '99+' : count.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                );
              },
            ),
          ),

          // Existing edit button
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: userDataAsync.when(
              data: (userSnapshot) => IconButton(
                onPressed: userSnapshot != null
                    ? () => _showEditProfileDialog(userSnapshot.data()!)
                    : null,
                icon: const Icon(Icons.edit, size: 20),
                tooltip: 'Edit Profile',
              ),
              loading: () => const IconButton(
                onPressed: null,
                icon: Icon(Icons.edit, size: 20),
              ),
              error: (_, __) => const IconButton(
                onPressed: null,
                icon: Icon(Icons.edit, size: 20),
              ),
            ),
          ),

          // Existing logout button
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () => logoutUser(context),
              icon: const Icon(Icons.logout, size: 20),
              tooltip: 'Logout',
            ),
          ),
        ],
      ),
      body: userDataAsync.when(
        data: (userSnapshot) => _buildBody(userSnapshot),
        loading: () => _buildLoadingWidget(),
        error: (error, stack) {
          print('❌ RIVERPOD: User data error: $error');
          return _buildErrorWidget(error.toString());
        },
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00BCD4)), // ✅ Updated color
            strokeWidth: 3,
          ),
          SizedBox(height: 24),
          Text(
            'Loading customer profile...',
            style: TextStyle(
              color: Color(0xFF636E72),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00BCD4).withOpacity(0.05), // ✅ Updated shadow
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade400.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              error,
              style: const TextStyle(
                fontSize: 18,
                color: Color(0xFF00838F), // ✅ Updated color
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Trigger rebuild by invalidating provider
                  ref.invalidate(userDataProvider(widget.userId));
                },
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text(
                  'Try Again',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BCD4), // ✅ Updated color
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(DocumentSnapshot<Map<String, dynamic>>? userSnapshot) {
    if (userSnapshot == null || !userSnapshot.exists) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00BCD4).withOpacity(0.05), // ✅ Updated shadow
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF636E72).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_off,
                  size: 48,
                  color: Color(0xFF636E72),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Customer profile not found',
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF00838F), // ✅ Updated color
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final userData = userSnapshot.data()!;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(userDataProvider(widget.userId));
        },
        color: const Color(0xFF00BCD4), // ✅ Updated color
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Column(
                  children: [
                    _buildHeaderSection(userData),
                    _buildDetailsSection(userData),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeaderSection(Map<String, dynamic> userData) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF00BCD4), // ✅ Updated colors
            Color(0xFF00ACC1),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
          child: Column(
            children: [
              // Profile Image with Upload Option
              GestureDetector(
                onTap: () {
                  if (userData['profileImage'] != null &&
                      userData['profileImage'].toString().isNotEmpty) {
                    _showImageViewer(userData['profileImage']);
                  } else {
                    _showImagePickerOptions(userData);
                  }
                },
                child: Hero(
                  tag: 'profile_image_${widget.userId}',
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 64,
                          backgroundColor: Colors.white,
                          backgroundImage: (userData['profileImage'] != null &&
                              userData['profileImage'].toString().isNotEmpty)
                              ? NetworkImage(userData['profileImage'])
                          as ImageProvider
                              : null,
                          child: (userData['profileImage'] == null ||
                              userData['profileImage'].toString().isEmpty)
                              ? Icon(
                            Icons.person,
                            size: 64,
                            color: const Color(0xFF636E72).withOpacity(0.5),
                          )
                              : null,
                        ),
                      ),
                      // Camera icon overlay for upload
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _showImagePickerOptions(userData),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00BCD4), // ✅ Updated color
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00BCD4).withOpacity(0.3), // ✅ Updated shadow
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                userData['name'] ?? 'No Name Available',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Add upload hint text
              if (userData['profileImage'] == null || userData['profileImage'].toString().isEmpty)
                Text(
                  'Tap camera icon to add profile picture',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsSection(Map<String, dynamic> userData) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00BCD4).withOpacity(0.05), // ✅ Updated shadow
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BCD4).withOpacity(0.1), // ✅ Updated color
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.info_outline,
                    color: Color(0xFF00BCD4), // ✅ Updated color
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Customer Details',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00838F), // ✅ Updated color
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildDetailRow(
              icon: Icons.email_outlined,
              label: 'Email Address',
              value: userData['email'] ?? 'No email available',
            ),
            const SizedBox(height: 24),
            _buildDetailRow(
              icon: Icons.badge_outlined,
              label: 'Role',
              value: userData['role'] ?? 'No role specified',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD), // ✅ Updated color
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00BCD4).withOpacity(0.3), // ✅ Updated color
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF00BCD4).withOpacity(0.1), // ✅ Updated color
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 20,
              color: const Color(0xFF00BCD4), // ✅ Updated color
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF636E72).withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF00838F), // ✅ Updated color
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
