import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

// Enhanced Customer Profile Image Carousel Widget
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

  @override
  void initState() {
    super.initState();
  }

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
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.customerId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[200],
              border: widget.showBorder
                  ? Border.all(color: Colors.blue.shade200, width: 2)
                  : null,
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildDefaultAvatar('?');
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final customerName = userData['name'] ?? 'Customer';

        // Get profile images - handle both single image and multiple images
        List<String> profileImages = [];

        if (userData['profileImage'] != null) {
          if (userData['profileImage'] is String && userData['profileImage'].isNotEmpty) {
            profileImages.add(userData['profileImage']);
          }
        }

        // Check for additional profile images (if user has multiple photos)
        if (userData['profileImages'] != null && userData['profileImages'] is List) {
          final additionalImages = List<String>.from(userData['profileImages'])
              .where((url) => url.isNotEmpty)
              .toList();
          profileImages.addAll(additionalImages);
        }

        // Remove duplicates
        profileImages = profileImages.toSet().toList();

        if (profileImages.isEmpty) {
          return _buildDefaultAvatar(customerName.isNotEmpty ? customerName[0].toUpperCase() : 'C');
        }

        if (profileImages.length == 1) {
          return _buildSingleImage(profileImages[0], customerName);
        }

        // Multiple images - use carousel
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
        border: widget.showBorder
            ? Border.all(color: Colors.blue.shade200, width: 2)
            : null,
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
        border: widget.showBorder
            ? Border.all(color: Colors.blue.shade200, width: 2)
            : null,
      ),
      child: ClipOval(
        child: Image.network(
          imageUrl,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(
              customerName.isNotEmpty ? customerName[0].toUpperCase() : 'C'
          ),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[200],
              ),
              child: Center(
                child: SizedBox(
                  width: widget.size * 0.3,
                  height: widget.size * 0.3,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              ),
            );
          },
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
        border: widget.showBorder
            ? Border.all(color: Colors.blue.shade200, width: 2)
            : null,
      ),
      child: Stack(
        children: [
          ClipOval(
            child: PageView.builder(
              controller: _pageController,
              itemCount: images.length,
              onPageChanged: (index) {
                if (mounted) {
                  setState(() {
                    _currentIndex = index;
                  });
                }
              },
              itemBuilder: (context, index) {
                return Image.network(
                  images[index],
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(
                      customerName.isNotEmpty ? customerName[0].toUpperCase() : 'C'
                  ),
                );
              },
            ),
          ),
          // Image indicators for multiple images
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
                      color: _currentIndex == index
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ),
          // Multiple images indicator
          if (images.length > 1)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade600,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Separate widget for service image carousel to prevent shivering
class ServiceImageCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final String serviceId;

  const ServiceImageCarousel({
    Key? key,
    required this.imageUrls,
    required this.serviceId,
  }) : super(key: key);

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
    if (widget.imageUrls.isEmpty) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.blue.shade100,
        ),
        child: Icon(
          Icons.work,
          color: Colors.blue.shade700,
          size: 24,
        ),
      );
    }

    if (widget.imageUrls.length == 1) {
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
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
              child: Icon(
                Icons.work,
                color: Colors.blue.shade700,
                size: 24,
              ),
            ),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: 60,
                height: 60,
                color: Colors.blue.shade100,
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                        : null,
                    strokeWidth: 2,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.imageUrls.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return Image.network(
                  widget.imageUrls[index],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.blue.shade100,
                    child: Icon(
                      Icons.work,
                      color: Colors.blue.shade700,
                      size: 24,
                    ),
                  ),
                );
              },
            ),
          ),
          // Image indicators for multiple images
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
                      color: _currentIndex == index
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
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

// ENHANCED Review carousel with CustomerProfileCarousel integration
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

  void _showCustomerProfileDialog(BuildContext context, String customerId) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Customer Profile',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              CustomerProfileCarousel(
                customerId: customerId,
                size: 120.0,
                showBorder: true,
              ),
              const SizedBox(height: 16),
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(customerId)
                    .get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }

                  final userData = snapshot.data!.data() as Map<String, dynamic>?;
                  final customerName = userData?['name'] ?? 'Anonymous';

                  return Text(
                    customerName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    if (widget.reviews.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                Icons.rate_review_outlined,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                'No reviews available yet.',
                style: theme.bodyLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 240, // Fixed height to prevent layout shifts
      child: Column(
        children: [
          // Review PageView - COMPLETELY ISOLATED
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              // Use ClampingScrollPhysics to prevent interference
              physics: const ClampingScrollPhysics(),
              onPageChanged: (index) {
                if (mounted) {
                  setState(() {
                    _currentIndex = index;
                  });
                }
              },
              itemCount: widget.reviews.length,
              itemBuilder: (context, index) {
                final review = widget.reviews[index].data() as Map<String, dynamic>;
                final customerId = review['customerId'] ?? '';

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.lightBlue.shade50,
                            Colors.white,
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // ✅ ENHANCED: Use CustomerProfileCarousel instead of simple CircleAvatar
                              GestureDetector(
                                onTap: () {
                                  // Show customer profile dialog with all images
                                  _showCustomerProfileDialog(context, customerId);
                                },
                                child: CustomerProfileCarousel(
                                  customerId: customerId,
                                  size: 40.0,
                                  showBorder: true,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FutureBuilder<DocumentSnapshot>(
                                  future: FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(customerId)
                                      .get(),
                                  builder: (context, customerSnapshot) {
                                    String customerName = 'Anonymous';

                                    if (customerSnapshot.hasData && customerSnapshot.data!.exists) {
                                      final customerData = customerSnapshot.data!.data() as Map<String, dynamic>;
                                      customerName = customerData['name'] ?? 'Anonymous';
                                    }

                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          customerName,
                                          style: theme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: List.generate(5, (starIndex) {
                                            final rating = review['rating'] ?? 0;
                                            return Icon(
                                              starIndex < rating
                                                  ? Icons.star
                                                  : Icons.star_border,
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
                              child: Text(
                                review['reviewText'] ?? 'No review text provided.',
                                style: theme.bodySmall?.copyWith(fontSize: 14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            review['timestamp'] != null
                                ? _formatTimestamp(review['timestamp'])
                                : 'Recent',
                            style: theme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Review indicators - Fixed position
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
                    color: _currentIndex == index
                        ? Colors.blue.shade600
                        : Colors.grey.shade300,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ProfessionalForCustomer extends StatefulWidget {
  final String userId;
  const ProfessionalForCustomer({super.key, required this.userId});

  @override
  State<ProfessionalForCustomer> createState() => _ProfessionalForCustomerState();
}

class _ProfessionalForCustomerState extends State<ProfessionalForCustomer> {
  @override
  void dispose() {
    super.dispose();
  }

  // Calculate average rating
  double _calculateAverageRating(List<dynamic> reviews) {
    if (reviews.isEmpty) return 0.0;
    double total = 0.0;
    for (var review in reviews) {
      final data = review.data() as Map<String, dynamic>;
      total += (data['rating'] ?? 0.0).toDouble();
    }
    return total / reviews.length;
  }

  // Show report dialog
  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Professional'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Why are you reporting this professional?'),
            const SizedBox(height: 16),
            ...['Inappropriate behavior', 'Fake profile', 'Poor service', 'Spam', 'Other'].map(
                  (reason) => ListTile(
                title: Text(reason),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Report submitted successfully'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // Launch phone dialer
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    await launchUrl(launchUri);
  }

  // Launch WhatsApp
  Future<void> _launchWhatsApp(String phoneNumber) async {
    final Uri launchUri = Uri.parse('https://wa.me/$phoneNumber');
    await launchUrl(launchUri);
  }

  // Launch email
  Future<void> _sendEmail(String email) async {
    final Uri launchUri = Uri(
      scheme: 'mailto',
      path: email,
    );
    await launchUrl(launchUri);
  }

  // Format service timestamp
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

  // Enhanced service image widget using ServiceImageCarousel
  Widget _buildServiceImage(int serviceIndex, Map<String, dynamic> service) {
    // 🔧 FIXED: Changed from 'imageUrl' to 'imageUrls' to match Firestore field name
    final imageUrls = service['imageUrls'];

    print('Service $serviceIndex imageUrls: $imageUrls'); // Debug print

    List<String> images = [];

    // Handle different types of imageUrls field
    if (imageUrls is String && imageUrls.isNotEmpty) {
      images = [imageUrls];
    } else if (imageUrls is List) {
      images = imageUrls.cast<String>().where((url) => url.isNotEmpty).toList();
    }

    // Use the ServiceImageCarousel widget
    return ServiceImageCarousel(
      imageUrls: images,
      serviceId: service['serviceId'] ?? 'service_$serviceIndex',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.lightBlue.shade50,
      appBar: AppBar(
        title: const Text(
          'Professional Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
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
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            );
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
                      Text(
                        'Professional profile not found.',
                        style: theme.titleMedium?.copyWith(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final userData = userSnapshot.data!.data()! as Map<String, dynamic>;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('services')
                .where('userId', isEqualTo: widget.userId)
                .snapshots(),
            builder: (context, servicesSnapshot) {
              final services = servicesSnapshot.hasData ? servicesSnapshot.data!.docs : <QueryDocumentSnapshot>[];

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(widget.userId)
                    .collection('reviews')
                    .snapshots(),
                builder: (context, reviewsSnapshot) {
                  final reviews = reviewsSnapshot.hasData ? reviewsSnapshot.data!.docs : <QueryDocumentSnapshot>[];
                  final averageRating = _calculateAverageRating(reviews);

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Profile Card with Badge and WhatsApp info
                        Card(
                          elevation: 6,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.lightBlue.shade100,
                                  Colors.white,
                                ],
                              ),
                            ),
                            child: Column(
                              children: [
                                Stack(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        if (userData['profileImage'] != null &&
                                            userData['profileImage'].toString().isNotEmpty) {
                                          showDialog(
                                            context: context,
                                            builder: (_) => Dialog(
                                              backgroundColor: Colors.transparent,
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(12),
                                                child: PhotoView(
                                                  imageProvider: NetworkImage(userData['profileImage']),
                                                  backgroundDecoration: const BoxDecoration(
                                                      color: Colors.transparent
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.blue.shade300,
                                            width: 3,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.blue.shade200,
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: CircleAvatar(
                                          radius: 50,
                                          backgroundColor: Colors.lightBlue.shade100,
                                          backgroundImage: (userData['profileImage'] != null &&
                                              userData['profileImage'].toString().isNotEmpty)
                                              ? NetworkImage(userData['profileImage']) as ImageProvider
                                              : null,
                                          child: (userData['profileImage'] == null ||
                                              userData['profileImage'].toString().isEmpty)
                                              ? Icon(Icons.person, size: 50, color: Colors.blue.shade600)
                                              : null,
                                        ),
                                      ),
                                    ),
                                    // Badge indicator
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
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.blue.shade300,
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.star,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  userData['name'] ?? 'Professional',
                                  style: theme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),

                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade600,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    userData['role'] ?? 'Professional',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),

                                // WhatsApp info in profile card
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
                                        Icon(
                                          Icons.chat,
                                          color: Colors.blue.shade600,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          userData['whatsapp'],
                                          style: TextStyle(
                                            color: Colors.blue.shade800,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        GestureDetector(
                                          onTap: () => _makePhoneCall(userData['whatsapp']),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade600,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Icon(
                                              Icons.call,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () => _launchWhatsApp(userData['whatsapp']),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade600,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Icon(
                                              Icons.chat,
                                              color: Colors.white,
                                              size: 16,
                                            ),
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

                        // Services Section with Enhanced ServiceImageCarousel
                        if ((userData['role'] ?? '').toLowerCase() == 'professional') ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade600,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.shade300,
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              'Services Offered',
                              style: theme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 16),

                          if (services.isEmpty)
                            Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.work_off,
                                      size: 48,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No services available at the moment.',
                                      style: theme.bodyLarge?.copyWith(
                                        color: Colors.grey.shade600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
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
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 4,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.white,
                                          Colors.lightBlue.shade50,
                                        ],
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              // Use enhanced ServiceImageCarousel
                                              _buildServiceImage(index, service),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  service['service'] ?? 'Service',
                                                  style: theme.titleMedium?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blue.shade800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          _buildServiceDetail(
                                            Icons.category,
                                            'Category',
                                            service['category'] ?? 'N/A',
                                            theme,
                                          ),
                                          const SizedBox(height: 8),
                                          _buildServiceDetail(
                                            Icons.calendar_today,
                                            'Added on',
                                            _formatServiceTimestamp(service['timestamp'] ?? service['createdAt']),
                                            theme,
                                          ),
                                          if (service['price'] != null) ...[
                                            const SizedBox(height: 8),
                                            _buildServiceDetail(
                                              Icons.attach_money,
                                              'Price',
                                              '₹${service['price']}',
                                              theme,
                                            ),
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

                        // Reviews Section - USING ENHANCED REVIEW CAROUSEL WITH CUSTOMER PROFILE IMAGES
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade600,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.shade300,
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            'Customer Reviews',
                            style: theme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ✅ Use the ENHANCED ReviewCarousel with CustomerProfileCarousel
                        ReviewCarousel(reviews: reviews),

                        const SizedBox(height: 24),

                        // Badge Status Section
                        if (userData['badgeStatus'] == 'assigned') ...[
                          Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.blue.shade50,
                                    Colors.white,
                                  ],
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.verified,
                                    color: Colors.blue.shade600,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Verified Professional',
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
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
        Icon(
          icon,
          size: 16,
          color: Colors.blue.shade600,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: theme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.bodyMedium?.copyWith(
              color: Colors.grey.shade800,
            ),
          ),
        ),
      ],
    );
  }
}