import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:photo_view/photo_view.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

// ✅ Import the main.dart file to use existing notification setup
import 'main.dart';

// ✅ FIXED: Updated to use your correct IP address
const String notificationApiUrl = 'http://192.168.43.84:5000/send-notification';

// ✅ IMPROVED: Push notification function with better error handling
Future<void> sendPushNotification({
  required String adminFcmToken,
  required String title,
  required String body,
}) async {
  print('🔄 Starting push notification process...');
  print('📱 Admin FCM Token: ${adminFcmToken.substring(0, 20)}...');
  print('📋 Title: $title');
  print('📋 Body: $body');
  print('🌐 API URL: $notificationApiUrl');

  try {
    final response = await http.post(
      Uri.parse(notificationApiUrl),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'adminFcmToken': adminFcmToken,
        'title': title,
        'body': body,
      }),
    ).timeout(const Duration(seconds: 15));

    print('📤 Server Response Status: ${response.statusCode}');
    print('📤 Server Response Body: ${response.body}');

    if (response.statusCode == 200) {
      print('✅ Push notification sent successfully to admin');
    } else {
      print('❌ Failed to send notification to admin');
      print('❌ Status: ${response.statusCode}');
      print('❌ Response: ${response.body}');
    }
  } catch (e) {
    print('🚨 DETAILED ERROR sending notification to admin:');
    print('🚨 Error Type: ${e.runtimeType}');
    print('🚨 Error Message: $e');

    if (e.toString().contains('Connection timed out')) {
      print('⏰ SERVER TIMEOUT - Check if server is running at: $notificationApiUrl');
      print('🔍 Try: curl -X POST $notificationApiUrl');
    }
  }
}

class CustomerProfileCarousel extends StatefulWidget {
  final String customerId;
  final double size;
  final bool showBorder;

  const CustomerProfileCarousel({
    Key? key,
    required this.customerId,
    this.size = 60.0,
    this.showBorder = true,
  }) : super(key: key);

  @override
  State<CustomerProfileCarousel> createState() => _CustomerProfileCarouselState();
}

class _CustomerProfileCarouselState extends State<CustomerProfileCarousel> {
  PageController? _pageController;
  Timer? _autoScrollTimer;
  int _currentIndex = 0;

  void _startAutoScroll(List<String> images) {
    if (images.length <= 1) return;
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && _pageController != null && _pageController!.hasClients) {
        final nextIndex = (_currentIndex + 1) % images.length;
        _pageController!.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(widget.customerId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[200],
              border: widget.showBorder ? Border.all(color: Colors.blue.shade200, width: 2) : null,
            ),
            child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildDefaultAvatar('?');
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final customerName = userData['name'] ?? 'Customer';
        List<String> profileImages = [];

        if (userData['profileImage'] != null && userData['profileImage'].toString().isNotEmpty) {
          profileImages.add(userData['profileImage']);
        }

        if (userData['profileImages'] != null && userData['profileImages'] is List) {
          final additionalImages = List<String>.from(userData['profileImages']).where((url) => url.isNotEmpty).toList();
          profileImages.addAll(additionalImages);
        }

        profileImages = profileImages.toSet().toList();

        if (profileImages.isEmpty) {
          return _buildDefaultAvatar(customerName.isNotEmpty ? customerName[0].toUpperCase() : 'C');
        }

        if (profileImages.length == 1) {
          return _buildSingleImage(profileImages[0], customerName);
        }

        return _buildImageCarousel(profileImages, customerName);
      },
    );
  }

  Widget _buildDefaultAvatar(String letter) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.blue.shade100,
        border: widget.showBorder ? Border.all(color: Colors.blue.shade200, width: 2) : null,
      ),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            fontSize: widget.size * 0.4,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade800,
          ),
        ),
      ),
    );
  }

  Widget _buildSingleImage(String imageUrl, String customerName) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: widget.showBorder ? Border.all(color: Colors.blue.shade200, width: 2) : null,
      ),
      child: ClipOval(
        child: Image.network(
          imageUrl,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(
              customerName.isNotEmpty ? customerName[0].toUpperCase() : 'C'),
        ),
      ),
    );
  }

  Widget _buildImageCarousel(List<String> images, String customerName) {
    if (_pageController == null) {
      _pageController = PageController();
      _startAutoScroll(images);
    }

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: widget.showBorder ? Border.all(color: Colors.blue.shade200, width: 2) : null,
      ),
      child: Stack(
        children: [
          ClipOval(
            child: PageView.builder(
              controller: _pageController,
              itemCount: images.length,
              onPageChanged: (index) {
                if (mounted) setState(() => _currentIndex = index);
              },
              itemBuilder: (context, index) {
                return Image.network(
                  images[index],
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(
                      customerName.isNotEmpty ? customerName[0].toUpperCase() : 'C'),
                );
              },
            ),
          ),
          if (images.length > 1)
            Positioned(
              bottom: 4,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  images.length,
                      (index) => Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentIndex == index ? Colors.white : Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ),
          if (images.length > 1)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: Colors.blue.shade600, shape: BoxShape.circle),
                child: Text('${images.length}', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }
}

// ✅ Service Image Carousel Widget (UNCHANGED)
class ServiceImageCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final String serviceId;

  const ServiceImageCarousel({Key? key, required this.imageUrls, required this.serviceId}) : super(key: key);

  @override
  State<ServiceImageCarousel> createState() => _ServiceImageCarouselState();
}

class _ServiceImageCarouselState extends State<ServiceImageCarousel> {
  PageController? _pageController;
  Timer? _autoScrollTimer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.imageUrls.length > 1) {
      _pageController = PageController();
      _startAutoScroll();
    }
  }

  void _startAutoScroll() {
    if (widget.imageUrls.length <= 1) return;
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted && _pageController != null && _pageController!.hasClients) {
        final nextIndex = (_currentIndex + 1) % widget.imageUrls.length;
        _pageController!.animateToPage(nextIndex, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      }
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.blue.shade100),
        child: Icon(Icons.work, color: Colors.blue.shade700, size: 24),
      );
    }

    if (widget.imageUrls.length == 1) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            widget.imageUrls[0],
            fit: BoxFit.cover,
            width: 60,
            height: 60,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 60,
              height: 60,
              color: Colors.blue.shade100,
              child: Icon(Icons.work, color: Colors.blue.shade700, size: 24),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.imageUrls.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                return Image.network(
                  widget.imageUrls[index],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.blue.shade100,
                    child: Icon(Icons.work, color: Colors.blue.shade700, size: 24),
                  ),
                );
              },
            ),
          ),
          if (widget.imageUrls.length > 1)
            Positioned(
              bottom: 4,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.imageUrls.length,
                      (index) => Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentIndex == index ? Colors.white : Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ✅ Review Carousel (UNCHANGED)
class ReviewCarousel extends StatefulWidget {
  final List<QueryDocumentSnapshot> reviews;

  const ReviewCarousel({Key? key, required this.reviews}) : super(key: key);

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    if (widget.reviews.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.rate_review_outlined, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text('No reviews available yet.', style: theme.bodyLarge?.copyWith(color: Colors.grey.shade600), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 240,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const ClampingScrollPhysics(),
              onPageChanged: (index) {
                if (mounted) setState(() => _currentIndex = index);
              },
              itemCount: widget.reviews.length,
              itemBuilder: (context, index) {
                final review = widget.reviews[index].data() as Map<String, dynamic>;
                final customerId = review['customerId'] ?? '';

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.lightBlue.shade50, Colors.white],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CustomerProfileCarousel(customerId: customerId, size: 40.0, showBorder: true),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FutureBuilder<DocumentSnapshot>(
                                  future: FirebaseFirestore.instance.collection('users').doc(customerId).get(),
                                  builder: (context, customerSnapshot) {
                                    String customerName = 'Anonymous';
                                    if (customerSnapshot.hasData && customerSnapshot.data!.exists) {
                                      final customerData = customerSnapshot.data!.data() as Map<String, dynamic>;
                                      customerName = customerData['name'] ?? 'Anonymous';
                                    }

                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(customerName, style: theme.titleSmall?.copyWith(fontWeight: FontWeight.bold, fontSize: 15)),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: List.generate(5, (starIndex) {
                                            final rating = review['rating'] ?? 0;
                                            return Icon(
                                              starIndex < rating ? Icons.star : Icons.star_border,
                                              color: Colors.blue,
                                              size: 16,
                                            );
                                          }),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const ClampingScrollPhysics(),
                              child: Text(review['reviewText'] ?? 'No review text provided.', style: theme.bodySmall?.copyWith(fontSize: 14)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            review['timestamp'] != null ? _formatTimestamp(review['timestamp']) : 'Recent',
                            style: theme.bodySmall?.copyWith(color: Colors.grey.shade600, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          if (widget.reviews.length > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.reviews.length,
                    (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentIndex == index ? 12 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: _currentIndex == index ? Colors.blue.shade600 : Colors.grey.shade300,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ✅ CRASH-SAFE: Report Service with enhanced context safety
class ReportService {
  static Future<void> submitReport({
    required BuildContext context,
    required String reportedProfessionalId,
    required String reportedProfessionalName,
    required String reportReason,
    required String customerId,
    required String customerName,
  }) async {
    // ✅ SAFETY: Check context validity before proceeding
    if (!context.mounted) {
      print('⚠️ Context not mounted, aborting report submission');
      return;
    }

    if (reportedProfessionalId.isEmpty || customerId.isEmpty) {
      _safeShowSnackBar(context,
          const Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 12),
              Text('Invalid user information. Please try again.'),
            ],
          ),
          const Color(0xFFF59E0B)
      );
      return;
    }

    try {
      // 1. Create report document
      await FirebaseFirestore.instance.collection('reports').add({
        'reportedProfessionalId': reportedProfessionalId,
        'reportedProfessionalName': reportedProfessionalName,
        'reportReason': reportReason,
        'customerId': customerId,
        'customerName': customerName,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
      });

      // 2. Update professional's report count
      final professionalRef = FirebaseFirestore.instance.collection('users').doc(reportedProfessionalId);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final professionalDoc = await transaction.get(professionalRef);
        if (professionalDoc.exists) {
          final currentData = professionalDoc.data() as Map<String, dynamic>;
          final currentReportCount = currentData['reportCount'] ?? 0;
          transaction.update(professionalRef, {
            'reportCount': currentReportCount + 1,
            'lastReportedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      // 3. ✅ SAFETY: Check context again before showing success message
      if (context.mounted) {
        _safeShowSnackBar(context,
            const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Report submitted successfully'),
              ],
            ),
            const Color(0xFF10B981)
        );
      }

      // 4. Handle notifications asynchronously (no context dependency)
      unawaited(_handleNotificationsAsync(reportedProfessionalId, customerId, reportReason));

    } catch (e) {
      print('Error submitting report: $e');

      // ✅ SAFETY: Check context before showing error
      if (context.mounted) {
        _safeShowSnackBar(context,
            Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error submitting report: $e')),
              ],
            ),
            const Color(0xFFEF4444)
        );
      }
      rethrow;
    }
  }

  // ✅ CRASH-SAFE: Safe SnackBar helper
  static void _safeShowSnackBar(BuildContext context, Widget content, Color backgroundColor) {
    if (!context.mounted) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: content,
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      print('Error showing snackbar: $e');
    }
  }

  // ✅ CRASH-SAFE: Async notification handling (no context dependency)
  static Future<void> _handleNotificationsAsync(
      String professionalId,
      String customerId,
      String reportReason
      ) async {
    print('🔄 Starting notification handling process...');

    try {
      // 1. Send local notification using existing function from main.dart
      print('📱 Sending local notification to customer...');
      await showLocalNotification(
        'Report Submitted',
        'Your report has been submitted successfully. We will review it shortly.',
      );
      print('✅ Local notification sent to customer');

      // 2. Get professional and customer names for notification context
      print('📋 Fetching professional data...');
      final professionalDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(professionalId)
          .get();
      final professionalData = professionalDoc.data() as Map<String, dynamic>?;
      final professionalName = professionalData?['name'] ?? 'Unknown Professional';
      print('👨‍💼 Professional Name: $professionalName');

      print('📋 Fetching customer data...');
      final customerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(customerId)
          .get();
      final customerData = customerDoc.data() as Map<String, dynamic>?;
      final customerName = customerData?['name'] ?? 'Unknown Customer';
      print('👤 Customer Name: $customerName');

      // 3. Get the admin's FCM token from users collection
      print('🔍 Searching for admin user...');
      final adminQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'Admin')
          .limit(1)
          .get();

      print('📊 Admin query results: ${adminQuery.docs.length} admins found');

      if (adminQuery.docs.isEmpty) {
        print('⚠️ NO ADMIN FOUND IN THE SYSTEM');
        return;
      }

      final adminData = adminQuery.docs.first.data();
      final adminFcmToken = adminData['fcmToken'];

      print('👨‍💼 Admin found: ${adminData['name']}');
      print('📱 Admin FCM Token exists: ${adminFcmToken != null}');

      if (adminFcmToken != null) {
        print('📱 Admin FCM Token length: ${adminFcmToken.toString().length}');
        print('📱 Admin FCM Token preview: ${adminFcmToken.toString().substring(0, 20)}...');
      }

      // 4. Send push notification to admin
      if (adminFcmToken != null && adminFcmToken.toString().trim().isNotEmpty) {
        print('🚀 Sending push notification to admin...');
        await sendPushNotification(
          adminFcmToken: adminFcmToken.toString().trim(),
          title: "New Professional Report",
          body: "$customerName reported $professionalName for: $reportReason",
        );
        print('✅ Push notification process completed');
      } else {
        print('❌ ADMIN FCM TOKEN IS NULL OR EMPTY');
        print('🔍 Admin data: $adminData');
      }

    } catch (e) {
      print('❌ DETAILED ERROR in notification handling:');
      print('❌ Error Type: ${e.runtimeType}');
      print('❌ Error Message: $e');
      // Don't rethrow - this is background processing
    }
  }
}

// ✅ Helper function for fire-and-forget async operations
void unawaited(Future<void> future) {
  // Explicitly ignore the future to avoid unawaited_futures lint
}

// ✅ CRASH-SAFE: ProfessionalForCustomer with enhanced context safety
class ProfessionalForCustomer extends StatefulWidget {
  final String userId;
  const ProfessionalForCustomer({super.key, required this.userId});

  @override
  State<ProfessionalForCustomer> createState() => _ProfessionalForCustomerState();
}

class _ProfessionalForCustomerState extends State<ProfessionalForCustomer> {
  // ✅ CRASH-SAFE: Track loading dialog state
  bool _isLoadingDialogShown = false;

  double _calculateAverageRating(List<dynamic> reviews) {
    if (reviews.isEmpty) return 0.0;
    double total = 0.0;
    for (var review in reviews) {
      final data = review.data() as Map<String, dynamic>;
      total += (data['rating'] ?? 0.0).toDouble();
    }
    return total / reviews.length;
  }

  String _getCurrentUserId() {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid ?? '';
  }

  Future<String> _getCurrentUserName() async {
    try {
      final currentUserId = _getCurrentUserId();
      if (currentUserId.isEmpty) return 'Anonymous User';

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        final userName = userData?['name']?.toString().trim() ?? 'Anonymous User';
        return userName.isNotEmpty ? userName : 'Anonymous User';
      }
      return 'Anonymous User';
    } catch (e) {
      return 'Anonymous User';
    }
  }

  Future<bool> _hasUserAlreadyReported(String professionalId, String reporterId) async {
    try {
      if (professionalId.isEmpty || reporterId.isEmpty) return false;

      final existingReports = await FirebaseFirestore.instance
          .collection('reports')
          .where('reportedProfessionalId', isEqualTo: professionalId)
          .where('customerId', isEqualTo: reporterId)
          .limit(1)
          .get();

      return existingReports.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  void _showReportDialog(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid.isEmpty) {
      _showLoginRequiredDialog(context);
      return;
    }

    String reporterId = currentUser.uid;
    if (reporterId == widget.userId) {
      _showErrorDialog(context, 'You cannot report yourself.');
      return;
    }

    try {
      final hasAlreadyReported = await _hasUserAlreadyReported(widget.userId, reporterId);
      if (hasAlreadyReported) {
        _showAlreadyReportedDialog(context);
        return;
      }

      String reporterName = await _getCurrentUserName();
      final professionalDoc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();

      if (!professionalDoc.exists) {
        _showErrorDialog(context, 'Professional profile not found.');
        return;
      }

      final professionalData = professionalDoc.data() as Map<String, dynamic>?;
      final professionalName = professionalData?['name']?.toString().trim() ?? 'Unknown Professional';

      if (mounted) {
        _showReportReasonsDialog(context, reporterId, reporterName, professionalName);
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(context, 'Failed to load report dialog. Please try again.');
      }
    }
  }

  void _showLoginRequiredDialog(BuildContext context) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.login, color: Colors.blue.shade600),
            const SizedBox(width: 8),
            const Text('Login Required'),
          ],
        ),
        content: const Text('You need to be logged in to report a professional. Please log in and try again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showAlreadyReportedDialog(BuildContext context) {
    if (!mounted) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('You have already reported this professional.', style: TextStyle(color: Colors.white))),
            ],
          ),
          backgroundColor: Colors.orange.shade600,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      print('Error showing already reported dialog: $e');
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    if (!mounted) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } catch (e) {
      print('Error showing error dialog: $e');
    }
  }

  void _showReportReasonsDialog(BuildContext context, String reporterId, String reporterName, String professionalName) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.report, color: Colors.red.shade600, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Report Professional',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: Text(
                          'Why are you reporting $professionalName?',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      const SizedBox(height: 20),
                      const Text(
                        'Select a reason:',
                        style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 12),

                      // Report reasons
                      ...['Inappropriate behavior', 'Fake profile', 'Poor service quality', 'Spam or fraud', 'Unprofessional conduct', 'Other'].map(
                            (reason) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          width: double.infinity,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () async {
                                Navigator.pop(context);
                                await _submitReport(context, reporterId, reporterName, professionalName, reason);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.report_problem_outlined,
                                      color: Colors.orange.shade600,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        reason,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey.shade600),
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
  }

  // ✅ CRASH-SAFE: Enhanced submit report with better dialog management
  Future<void> _submitReport(BuildContext context, String reporterId, String reporterName, String professionalName, String reason) async {
    if (!mounted) return;

    if (reporterId.isEmpty || reporterName.isEmpty || professionalName.isEmpty || reason.isEmpty) {
      if (mounted) {
        _showErrorDialog(context, 'Missing required information. Please try again.');
      }
      return;
    }

    // ✅ CRASH-SAFE: Show loading dialog with proper state tracking
    if (mounted && !_isLoadingDialogShown) {
      _isLoadingDialogShown = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => WillPopScope(
          onWillPop: () async => false, // Prevent back button
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Container(
              padding: const EdgeInsets.all(24),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  const Text(
                    'Submitting Report...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      'Please wait while we process your report',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    try {
      await ReportService.submitReport(
        context: context,
        reportedProfessionalId: widget.userId,
        reportedProfessionalName: professionalName,
        reportReason: reason,
        customerId: reporterId,
        customerName: reporterName,
      );

      // ✅ CRASH-SAFE: Close loading dialog safely
      _safeCloseLoadingDialog();

    } catch (e) {
      print('Error in _submitReport: $e');

      // ✅ CRASH-SAFE: Close loading dialog safely
      _safeCloseLoadingDialog();

      if (mounted) {
        _showErrorDialog(context, 'Failed to submit report. Please check your internet connection and try again.');
      }
    }
  }

  // ✅ CRASH-SAFE: Safe dialog closing
  void _safeCloseLoadingDialog() {
    if (_isLoadingDialogShown && mounted) {
      _isLoadingDialogShown = false;
      try {
        Navigator.of(context, rootNavigator: true).pop();
      } catch (e) {
        print('Error closing loading dialog: $e');
      }
    }
  }

  @override
  void dispose() {
    // ✅ CRASH-SAFE: Clean up any remaining dialogs
    if (_isLoadingDialogShown) {
      _isLoadingDialogShown = false;
    }
    super.dispose();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    await launchUrl(launchUri);
  }

  Future<void> _launchWhatsApp(String phoneNumber) async {
    final Uri launchUri = Uri.parse('https://wa.me/$phoneNumber');
    await launchUrl(launchUri);
  }

  String _formatServiceTimestamp(dynamic timestamp) {
    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return '${date.day}/${date.month}/${date.year}';
      } else if (timestamp is String) {
        final date = DateTime.parse(timestamp);
        return '${date.day}/${date.month}/${date.year}';
      }
      return 'Recently';
    } catch (e) {
      return 'Recently';
    }
  }

  Widget _buildServiceImage(int serviceIndex, Map<String, dynamic> service) {
    final imageUrls = service['imageUrls'];
    List<String> images = [];

    if (imageUrls is String && imageUrls.isNotEmpty) {
      images = [imageUrls];
    } else if (imageUrls is List) {
      images = imageUrls.cast<String>().where((url) => url.isNotEmpty).toList();
    }

    return ServiceImageCarousel(imageUrls: images, serviceId: service['serviceId'] ?? 'service_$serviceIndex');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.lightBlue.shade50,
      appBar: AppBar(
        title: const Text('Professional Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.report, color: Colors.white),
            onPressed: () => _showReportDialog(context),
            tooltip: 'Report Professional',
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.blue)));
          }
          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return Center(
              child: Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_off, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('Professional profile not found.', style: theme.titleMedium?.copyWith(color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ),
            );
          }

          final userData = userSnapshot.data!.data()! as Map<String, dynamic>;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('services').where('userId', isEqualTo: widget.userId).snapshots(),
            builder: (context, servicesSnapshot) {
              final services = servicesSnapshot.hasData ? servicesSnapshot.data!.docs : <QueryDocumentSnapshot>[];

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).collection('reviews').snapshots(),
                builder: (context, reviewsSnapshot) {
                  final reviews = reviewsSnapshot.hasData ? reviewsSnapshot.data!.docs : <QueryDocumentSnapshot>[];

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Profile Card
                        Card(
                          elevation: 6,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Colors.lightBlue.shade100, Colors.white],
                              ),
                            ),
                            child: Column(
                              children: [
                                Stack(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        if (userData['profileImage'] != null && userData['profileImage'].toString().isNotEmpty) {
                                          showDialog(
                                            context: context,
                                            builder: (_) => Dialog(
                                              backgroundColor: Colors.transparent,
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(12),
                                                child: PhotoView(
                                                  imageProvider: NetworkImage(userData['profileImage']),
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
                                          border: Border.all(color: Colors.blue.shade300, width: 3),
                                          boxShadow: [BoxShadow(color: Colors.blue.shade200, blurRadius: 10, offset: const Offset(0, 4))],
                                        ),
                                        child: CircleAvatar(
                                          radius: 50,
                                          backgroundColor: Colors.lightBlue.shade100,
                                          backgroundImage: (userData['profileImage'] != null && userData['profileImage'].toString().isNotEmpty)
                                              ? NetworkImage(userData['profileImage']) as ImageProvider
                                              : null,
                                          child: (userData['profileImage'] == null || userData['profileImage'].toString().isEmpty)
                                              ? Icon(Icons.person, size: 50, color: Colors.blue.shade600)
                                              : null,
                                        ),
                                      ),
                                    ),
                                    if (userData['badgeStatus'] == 'assigned')
                                      Positioned(
                                        bottom: 5,
                                        right: 5,
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.blue,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2),
                                            boxShadow: [BoxShadow(color: Colors.blue.shade300, blurRadius: 4, offset: const Offset(0, 2))],
                                          ),
                                          child: const Icon(Icons.star, color: Colors.white, size: 16),
                                        ),
                                      )
                                    else
                                      Positioned(
                                        bottom: 5,
                                        right: 5,
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2),
                                            boxShadow: [BoxShadow(color: Colors.red.shade300, blurRadius: 4, offset: const Offset(0, 2))],
                                          ),
                                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  userData['name'] ?? 'Professional',
                                  style: theme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  decoration: BoxDecoration(color: Colors.blue.shade600, borderRadius: BorderRadius.circular(20)),
                                  child: Text(
                                    userData['role'] ?? 'Professional',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                ),

                                // WhatsApp info
                                if (userData['whatsapp'] != null && userData['whatsapp'].toString().isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.blue.shade200),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.chat, color: Colors.blue.shade600, size: 20),
                                        const SizedBox(width: 8),
                                        Text(userData['whatsapp'], style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.w600)),
                                        const SizedBox(width: 12),
                                        GestureDetector(
                                          onTap: () => _makePhoneCall(userData['whatsapp']),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(color: Colors.blue.shade600, borderRadius: BorderRadius.circular(6)),
                                            child: const Icon(Icons.call, color: Colors.white, size: 16),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () => _launchWhatsApp(userData['whatsapp']),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(color: Colors.blue.shade600, borderRadius: BorderRadius.circular(6)),
                                            child: const Icon(Icons.chat, color: Colors.white, size: 16),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Services Section
                        if ((userData['role'] ?? '') == 'Professional') ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade600,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(color: Colors.blue.shade300, blurRadius: 8, offset: const Offset(0, 2))],
                            ),
                            child: Text(
                              'Services Offered',
                              style: theme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 16),

                          if (services.isEmpty)
                            Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  children: [
                                    Icon(Icons.work_off, size: 48, color: Colors.grey.shade400),
                                    const SizedBox(height: 12),
                                    Text('No services available at the moment.', style: theme.bodyLarge?.copyWith(color: Colors.grey.shade600), textAlign: TextAlign.center),
                                  ],
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              itemCount: services.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final service = services[index].data() as Map<String, dynamic>;
                                return Card(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 4,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [Colors.white, Colors.lightBlue.shade50],
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              _buildServiceImage(index, service),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  service['service'] ?? 'Service',
                                                  style: theme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          _buildServiceDetail(Icons.category, 'Category', service['category'] ?? 'N/A', theme),
                                          const SizedBox(height: 8),
                                          _buildServiceDetail(Icons.calendar_today, 'Added on', _formatServiceTimestamp(service['timestamp'] ?? service['createdAt']), theme),
                                          if (service['price'] != null) ...[
                                            const SizedBox(height: 8),
                                            _buildServiceDetail(Icons.attach_money, 'Price', '₹${service['price']}', theme),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          const SizedBox(height: 24),
                        ],

                        // Reviews Section
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade600,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: Colors.blue.shade300, blurRadius: 8, offset: const Offset(0, 2))],
                          ),
                          child: Text('Customer Reviews', style: theme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
                        ),
                        const SizedBox(height: 16),
                        ReviewCarousel(reviews: reviews),
                        const SizedBox(height: 24),

                        // Badge Status Section
                        if (userData['badgeStatus'] == 'assigned') ...[
                          Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.blue.shade50, Colors.white]),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.verified, color: Colors.blue.shade600, size: 24),
                                  const SizedBox(width: 8),
                                  Text('Verified Professional', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildServiceDetail(IconData icon, String label, String value, TextTheme theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.blue.shade600),
        const SizedBox(width: 8),
        Text('$label: ', style: theme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
        Expanded(child: Text(value, style: theme.bodyMedium?.copyWith(color: Colors.grey.shade800))),
      ],
    );
  }
}
