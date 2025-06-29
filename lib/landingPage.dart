import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/serviceVideoPlayer.dart';
import '../profilePage.dart';
import 'sendOrderCustomer.dart';
import './adminDashboard.dart';

// Separate widget for image carousel to prevent shivering
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
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFFE3F2FD),
        ),
        child: const Center(
          child: Text(
            'No Image',
            style: TextStyle(color: Colors.grey, fontSize: 10),
          ),
        ),
      );
    }

    if (widget.imageUrls.length == 1) {
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFFE3F2FD),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            widget.imageUrls[0],
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: const Color(0xFFE3F2FD),
              child: const Icon(Icons.error, color: Color(0xFF00BCD4)),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFE3F2FD),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
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
                    color: const Color(0xFFE3F2FD),
                    child: const Icon(Icons.error, color: Color(0xFF00BCD4)),
                  ),
                );
              },
            ),
          ),
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

// Rating widget using onSnapshot for real-time updates
class ServiceRatingWidget extends StatefulWidget {
  final String providerUserId;
  final String serviceName;

  const ServiceRatingWidget({
    Key? key,
    required this.providerUserId,
    required this.serviceName,
  }) : super(key: key);

  @override
  State<ServiceRatingWidget> createState() => _ServiceRatingWidgetState();
}

class _ServiceRatingWidgetState extends State<ServiceRatingWidget> {
  StreamSubscription<QuerySnapshot>? _reviewsSubscription;
  double _currentRating = 0.0;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _setupRealtimeRatingListener();
  }

  void _setupRealtimeRatingListener() {
    print('🔄 SETTING UP REAL-TIME RATING LISTENER');
    print('📍 Path: users/${widget.providerUserId}/reviews');
    print('🎯 Service: ${widget.serviceName}');

    _reviewsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.providerUserId)
        .collection('reviews')
        .snapshots()
        .listen(
          (QuerySnapshot reviewsSnapshot) {
        print('📡 REAL-TIME UPDATE RECEIVED for ${widget.serviceName}');
        print('📊 Reviews count: ${reviewsSnapshot.docs.length}');

        if (reviewsSnapshot.docs.isEmpty) {
          print('❌ NO REVIEWS FOUND - Setting rating to 0.0');
          if (mounted) {
            setState(() {
              _currentRating = 0.0;
              _isLoading = false;
              _hasError = false;
            });
          }
          return;
        }

        double totalRating = 0.0;
        int validReviews = 0;

        print('📋 PROCESSING REAL-TIME REVIEWS:');
        for (var reviewDoc in reviewsSnapshot.docs) {
          final reviewData = reviewDoc.data() as Map<String, dynamic>;
          final rating = reviewData['rating'];

          print('   📄 Review ID: ${reviewDoc.id}');
          print('   ⭐ Rating value: $rating');

          if (rating != null) {
            double ratingValue = 0.0;
            if (rating is int) {
              ratingValue = rating.toDouble();
            } else if (rating is double) {
              ratingValue = rating;
            } else if (rating is String) {
              ratingValue = double.tryParse(rating) ?? 0.0;
            }

            totalRating += ratingValue;
            validReviews++;
            print('   ✅ Added rating: $ratingValue');
          }
        }

        if (validReviews == 0) {
          print('❌ NO VALID RATINGS - Setting to 0.0');
          if (mounted) {
            setState(() {
              _currentRating = 0.0;
              _isLoading = false;
              _hasError = false;
            });
          }
          return;
        }

        double averageRating = totalRating / validReviews;
        print('🎯 REAL-TIME CALCULATION:');
        print('   📊 Total Rating: $totalRating');
        print('   📈 Valid Reviews: $validReviews');
        print('   ⭐ Average Rating: $averageRating');
        print('✅ REAL-TIME UPDATE: ${widget.serviceName} = $averageRating');

        if (mounted) {
          setState(() {
            _currentRating = averageRating;
            _isLoading = false;
            _hasError = false;
          });
        }
      },
      onError: (error) {
        print('❌ REAL-TIME RATING ERROR: $error');
        if (mounted) {
          setState(() {
            _currentRating = 0.0;
            _isLoading = false;
            _hasError = true;
          });
        }
      },
    );
  }

  Widget _buildRatingWidget(double rating) {
    return Row(
      children: [
        const Icon(Icons.star, color: Colors.amber, size: 16),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    print('🔄 DISPOSING REAL-TIME RATING LISTENER for ${widget.serviceName}');
    _reviewsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1,
              color: const Color(0xFF00BCD4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "Loading rating...",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      );
    }

    if (_hasError) {
      print('❌ Error in ServiceRatingWidget for service: ${widget.serviceName}');
      return Row(
        children: [
          _buildRatingWidget(0.0),
          const SizedBox(width: 4),
          Icon(
            Icons.error_outline,
            size: 12,
            color: Colors.red[400],
          ),
        ],
      );
    }

    print('🎯 DISPLAYING REAL-TIME RATING: $_currentRating for service: ${widget.serviceName}');
    return _buildRatingWidget(_currentRating);
  }
}

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  String? selectedCategory;
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';
  Timer? _debounce;
  String userName = 'Guest';
  int _selectedIndex = 0;
  String? _currentUserId;
  String? _currentUserRole;

  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;
  bool _isAdInitialized = false;

  // Hardcoded categories with their icons and colors
  final List<Map<String, dynamic>> categories = [
    {
      'name': 'Cleaning',
      'icon': Icons.cleaning_services,
      'color': const Color(0xFF00BCD4),
    },
    {
      'name': 'Repair',
      'icon': Icons.build,
      'color': const Color(0xFF0288D1),
    },
    {
      'name': 'Painting',
      'icon': Icons.format_paint,
      'color': const Color(0xFF00ACC1),
    },
    {
      'name': 'Laundry',
      'icon': Icons.local_laundry_service,
      'color': const Color(0xFF0097A7),
    },
    {
      'name': 'Plumbing',
      'icon': Icons.plumbing,
      'color': const Color(0xFF00838F),
    },
    {
      'name': 'Electrical',
      'icon': Icons.electrical_services,
      'color': const Color(0xFF006064),
    },
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _initializeAds();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _currentUserId = user.uid;
      });

      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists && mounted) {
          final userData = userDoc.data()!;
          setState(() {
            userName = userData['name'] ?? user.displayName ?? 'User';
            _currentUserRole = userData['role'] ?? 'customer';
          });

          print('✅ User data loaded:');
          print('   👤 User ID: ${user.uid}');
          print('   📛 User Name: $userName');
          print('   🎭 User Role: $_currentUserRole');
        }
      } catch (e) {
        print('❌ Error loading user data: $e');
        setState(() {
          _currentUserRole = 'customer';
        });
      }
    } else {
      print('❌ No user logged in');
    }
  }

  Future<void> _initializeAds() async {
    try {
      print('🔄 Initializing Google Mobile Ads...');
      await MobileAds.instance.initialize();
      await Future.delayed(const Duration(milliseconds: 500));
      print('✅ Google Mobile Ads initialized successfully');

      if (mounted) {
        setState(() {
          _isAdInitialized = true;
        });
        _loadBannerAd();
      }
    } catch (e) {
      print('❌ Error initializing ads: $e');
      if (mounted) {
        _loadBannerAd();
      }
    }
  }

  void _loadBannerAd() {
    print('🚀 Starting to load banner ad...');

    String adUnitId;
    if (kDebugMode) {
      adUnitId = 'ca-app-pub-3940256099942544/6300978111';
      print('🧪 Using TEST ad unit ID: $adUnitId');
    } else {
      adUnitId = dotenv.env['ADMOB_BANNER_ID'] ??
          'ca-app-pub-3940256099942544/6300978111';
      print('💰 Using ad unit ID: $adUnitId');
    }

    _bannerAd?.dispose();

    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          print('✅ Banner ad loaded successfully!');
          if (mounted) {
            setState(() {
              _isBannerAdReady = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          print('❌ Failed to load banner ad: ${error.message}');
          if (mounted) {
            setState(() {
              _isBannerAdReady = false;
            });
          }
          ad.dispose();
          Timer(const Duration(seconds: 5), () {
            if (mounted) {
              print('🔄 Retrying banner ad load...');
              _loadBannerAd();
            }
          });
        },
      ),
    );

    _bannerAd?.load();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        break;
      case 1:
        break;
      case 2:
        break;
      case 3:
        break;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  RichText highlightText(String source, String query) {
    if (query.isEmpty) {
      return RichText(
        text: TextSpan(
          text: source,
          style: const TextStyle(color: Colors.black),
        ),
      );
    }

    final sourceLower = source.toLowerCase();
    final queryLower = query.toLowerCase();

    List<TextSpan> spans = [];
    int start = 0;
    int index = sourceLower.indexOf(queryLower);

    while (index != -1) {
      if (index > start) {
        spans.add(
          TextSpan(
            text: source.substring(start, index),
            style: const TextStyle(color: Colors.black),
          ),
        );
      }
      spans.add(
        TextSpan(
          text: source.substring(index, index + query.length),
          style: const TextStyle(
            color: Color(0xFF00BCD4),
            fontWeight: FontWeight.bold,
          ),
        ),
      );
      start = index + query.length;
      index = sourceLower.indexOf(queryLower, start);
    }

    if (start < source.length) {
      spans.add(
        TextSpan(
          text: source.substring(start),
          style: const TextStyle(color: Colors.black),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildBannerAdWidget() {
    if (!_isAdInitialized) {
      return Container(
        height: 60,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE3F2FD), width: 0.5),
        ),
        child: const Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF00BCD4),
                ),
              ),
              SizedBox(width: 8),
              Text(
                'Loading ad...',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isBannerAdReady || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      alignment: Alignment.center,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE3F2FD), width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4.0, bottom: 2.0),
            child: Text(
              'Advertisement',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Container(
            width: AdSize.banner.width.toDouble(),
            height: AdSize.banner.height.toDouble(),
            child: AdWidget(ad: _bannerAd!),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildCategoryIcon(Map<String, dynamic> category) {
    final isSelected = selectedCategory == category['name'];

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: isSelected ? category['color'] : const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? category['color'] : const Color(0xFF00BCD4).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Icon(
        category['icon'],
        color: isSelected ? Colors.white : category['color'],
        size: 28,
      ),
    );
  }

  Widget _buildCategoryChip(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        category.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: Color(0xFF00838F),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          "Home",
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: const Color(0xFF00BCD4),
              child: const Icon(Icons.person, color: Colors.white),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Section
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Welcome, $userName 👋",
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Find the best cleaning services in your city",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Promotional Banner with updated colors
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00BCD4), Color(0xFF00ACC1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "25% OFF",
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const Text(
                                      "On home services",
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ElevatedButton(
                                      onPressed: () {},
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: const Color(0xFF00BCD4),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(25),
                                        ),
                                      ),
                                      child: const Text(
                                        "BOOK NOW",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.cleaning_services,
                                size: 60,
                                color: Colors.white24,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Search bar with updated colors
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        hintText: "Search services...",
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xFF00BCD4),
                        ),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                          icon: const Icon(Icons.clear, color: Color(0xFF00BCD4)),
                          onPressed: () {
                            _searchController.clear();
                            FocusScope.of(context).unfocus();
                          },
                        )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE3F2FD)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE3F2FD)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF00BCD4)),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FDFF),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Categories with hardcoded data
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Categories",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: categories.length,
                            itemBuilder: (context, index) {
                              final category = categories[index];
                              return Padding(
                                padding: const EdgeInsets.only(right: 16),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (selectedCategory == category['name']) {
                                        selectedCategory = null;
                                      } else {
                                        selectedCategory = category['name'];
                                      }
                                      _searchController.clear();
                                      searchQuery = '';
                                    });
                                  },
                                  child: Column(
                                    children: [
                                      _buildCategoryIcon(category),
                                      const SizedBox(height: 8),
                                      Text(
                                        category['name'],
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: selectedCategory == category['name']
                                              ? const Color(0xFF00BCD4)
                                              : Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Banner Ad
                  _buildBannerAdWidget(),

                  const SizedBox(height: 16),

                  // Top Services
                  Container(
                    color: const Color(0xFFE3F2FD),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Top Services",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),
                        StreamBuilder<QuerySnapshot>(
                          stream: selectedCategory != null
                              ? FirebaseFirestore.instance
                              .collection('services')
                              .where(
                            'category',
                            isEqualTo: selectedCategory,
                          )
                              .snapshots()
                              : FirebaseFirestore.instance
                              .collection('services')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF00BCD4),
                                ),
                              );
                            }
                            final services = snapshot.data!.docs;

                            final filteredServices = services.where((service) {
                              final data = service.data() as Map<String, dynamic>;
                              final serviceName = (data['service'] ?? '')
                                  .toString()
                                  .toLowerCase();
                              return serviceName.contains(searchQuery);
                            }).toList();

                            if (filteredServices.isEmpty) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: Text(
                                    "No services found",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              );
                            }

                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filteredServices.length,
                              itemBuilder: (context, index) {
                                final service = filteredServices[index];
                                final data = service.data() as Map<String, dynamic>;
                                final serviceName = data['service'] ?? '';
                                final price = data['price'] ?? '';
                                final imageUrls = List<String>.from(
                                  data['imageUrls'] ?? [],
                                );
                                final category = data['category'] ?? '';
                                final providerUserId = data['userId'] ?? '';
                                final providerName =
                                    data['providerName'] ?? 'Professional';

                                print('🏷️ Processing service: $serviceName');
                                print('👤 Service Provider ID: $providerUserId');
                                print('🔑 Current Customer ID: $_currentUserId');
                                print('🎭 Current User Role: $_currentUserRole');

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  elevation: 3,
                                  color: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF00BCD4).withOpacity(0.1),
                                          spreadRadius: 1,
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          // Service Image
                                          ServiceImageCarousel(
                                            imageUrls: imageUrls,
                                            serviceId: service.id,
                                          ),

                                          const SizedBox(width: 16),

                                          // Service Details
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  serviceName,
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),

                                                // Category chip
                                                _buildCategoryChip(category),

                                                const SizedBox(height: 6),

                                                // Service description/details
                                                if (data['description'] != null &&
                                                    data['description']
                                                        .toString()
                                                        .isNotEmpty)
                                                  Column(
                                                    crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        data['description'],
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color: Colors.grey[700],
                                                          height: 1.3,
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      const SizedBox(height: 6),
                                                    ],
                                                  ),

                                                Text(
                                                  "By $providerName",
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                                const SizedBox(height: 8),

                                                // Price
                                                Text(
                                                  "PKR $price",
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black,
                                                  ),
                                                ),

                                                // Rating with onSnapshot
                                                ServiceRatingWidget(
                                                  providerUserId: providerUserId,
                                                  serviceName: serviceName,
                                                ),

                                                const SizedBox(height: 12),

                                                // Send Request Button
                                                SizedBox(
                                                  width: double.infinity,
                                                  child: ElevatedButton.icon(
                                                    onPressed: () {
                                                      if (_currentUserId == null) {
                                                        ScaffoldMessenger.of(context)
                                                            .showSnackBar(
                                                          const SnackBar(
                                                            content: Text(
                                                              'Please log in to send a request',
                                                            ),
                                                            backgroundColor: Colors.red,
                                                          ),
                                                        );
                                                        return;
                                                      }

                                                      if (_currentUserRole == null) {
                                                        ScaffoldMessenger.of(context)
                                                            .showSnackBar(
                                                          const SnackBar(
                                                            content: Text(
                                                              'Loading user data, please wait...',
                                                            ),
                                                            backgroundColor: Colors.orange,
                                                          ),
                                                        );
                                                        return;
                                                      }

                                                      final serviceId = service.id;

                                                      print(
                                                        '🚀 NAVIGATING TO SendOrderCustomer:',
                                                      );
                                                      print(
                                                        '   👤 Customer ID (logged-in user): $_currentUserId',
                                                      );
                                                      print(
                                                        '   🏷️ Service ID: $serviceId',
                                                      );
                                                      print(
                                                        '   👨‍💼 Provider ID (from service): $providerUserId',
                                                      );
                                                      print(
                                                        '   🎭 User Role: $_currentUserRole',
                                                      );

                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              SendOrderCustomer(
                                                                customerId: _currentUserId!,
                                                                serviceId: serviceId,
                                                                providerId: providerUserId,
                                                                role: _currentUserRole!,
                                                              ),
                                                        ),
                                                      );
                                                    },
                                                    icon: const Icon(
                                                      Icons.send,
                                                      size: 16,
                                                    ),
                                                    label: const Text("Send Request"),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: const Color(0xFF00BCD4),
                                                      foregroundColor: Colors.white,
                                                      padding: const EdgeInsets.symmetric(
                                                        vertical: 8,
                                                      ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                        BorderRadius.circular(8),
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
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 100), // Space for bottom navigation
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
