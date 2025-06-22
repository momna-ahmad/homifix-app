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
          color: Colors.grey[100],
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
          color: Colors.grey[100],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            widget.imageUrls[0],
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.grey[300],
              child: const Icon(Icons.error),
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
        color: Colors.grey[100],
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
                    color: Colors.grey[300],
                    child: const Icon(Icons.error),
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

  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;
  bool _isAdInitialized = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _initializeAds();
    _loadUserName();
  }

  Future<double> _fetchUserRating(String userId) async {
    try {
      print('🔍 FETCHING RATING FROM FIRESTORE DATABASE');
      print('📍 Path: users/$userId/reviews');
      print('🎯 Looking for userId: $userId');

      final reviewsQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reviews')
          .get();

      print('📊 DATABASE QUERY RESULT: Found ${reviewsQuery.docs.length} reviews');

      if (reviewsQuery.docs.isEmpty) {
        print('❌ NO REVIEWS FOUND - Returning 0.0');
        return 0.0;
      }

      double totalRating = 0.0;
      int validReviews = 0;

      print('📋 PROCESSING EACH REVIEW FROM DATABASE:');
      for (var reviewDoc in reviewsQuery.docs) {
        final reviewData = reviewDoc.data();
        final rating = reviewData['rating'];

        print('   📄 Review ID: ${reviewDoc.id}');
        print('   ⭐ Rating field value: $rating');

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
        print('❌ NO VALID RATINGS FOUND - Returning 0.0');
        return 0.0;
      }

      double averageRating = totalRating / validReviews;
      print('🎯 FINAL CALCULATION:');
      print('   📊 Total Rating: $totalRating');
      print('   📈 Valid Reviews: $validReviews');
      print('   ⭐ Average Rating: $averageRating');
      print('✅ RETURNING RATING FROM DATABASE: $averageRating');

      return averageRating;

    } catch (e) {
      print('❌ ERROR FETCHING FROM DATABASE: $e');
      print('🔄 Returning 0.0 due to error');
      return 0.0;
    }
  }

  Future<void> _loadUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists && mounted) {
          setState(() {
            userName = userDoc.data()?['name'] ?? user.displayName ?? 'User';
          });
        }
      } catch (e) {
        print('Error loading user name: $e');
      }
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
      adUnitId = dotenv.env['ADMOB_BANNER_ID'] ?? 'ca-app-pub-3940256099942544/6300978111';
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
          text: TextSpan(text: source, style: const TextStyle(color: Colors.black)));
    }

    final sourceLower = source.toLowerCase();
    final queryLower = query.toLowerCase();

    List<TextSpan> spans = [];
    int start = 0;
    int index = sourceLower.indexOf(queryLower);

    while (index != -1) {
      if (index > start) {
        spans.add(TextSpan(text: source.substring(start, index), style: const TextStyle(color: Colors.black)));
      }
      spans.add(TextSpan(
          text: source.substring(index, index + query.length),
          style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)));
      start = index + query.length;
      index = sourceLower.indexOf(queryLower, start);
    }

    if (start < source.length) {
      spans.add(TextSpan(text: source.substring(start), style: const TextStyle(color: Colors.black)));
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
          border: Border.all(color: Colors.grey[300]!, width: 0.5),
        ),
        child: const Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('Loading ad...', style: TextStyle(color: Colors.grey, fontSize: 12)),
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
        border: Border.all(color: Colors.grey[300]!, width: 0.5),
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

  Widget _buildCategoryIcon(String category) {
    IconData iconData;
    Color backgroundColor;

    switch (category.toLowerCase()) {
      case 'cleaning':
        iconData = Icons.cleaning_services;
        backgroundColor = Colors.cyan[100]!;
        break;
      case 'repair':
        iconData = Icons.build;
        backgroundColor = Colors.purple[100]!;
        break;
      case 'painting':
        iconData = Icons.format_paint;
        backgroundColor = Colors.pink[100]!;
        break;
      case 'laundry':
        iconData = Icons.local_laundry_service;
        backgroundColor = Colors.green[100]!;
        break;
      case 'plumbing':
        iconData = Icons.plumbing;
        backgroundColor = Colors.blue[100]!;
        break;
      case 'electrical':
        iconData = Icons.electrical_services;
        backgroundColor = Colors.yellow[100]!;
        break;
      default:
        iconData = Icons.miscellaneous_services;
        backgroundColor = Colors.grey[100]!;
    }

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: selectedCategory == category ? Colors.cyan : backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        iconData,
        color: selectedCategory == category ? Colors.white : Colors.grey[700],
        size: 28,
      ),
    );
  }

  Widget _buildCategoryChip(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!, width: 0.5),
      ),
      child: Text(
        category.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: Colors.grey[700],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildRatingWidget(double rating) {
    return Row(
      children: [
        const Icon(
          Icons.star,
          color: Colors.amber,
          size: 16,
        ),
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
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ LIGHT BLUE BACKGROUND - MATCHES YOUR IMAGE PERFECTLY
      backgroundColor: const Color(0xFFE3F2FD), // Light blue background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          "Home",
          style: TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: Colors.cyan,
              child: Icon(Icons.person, color: Colors.white),
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

                        // Promotional Banner - MATCHES YOUR IMAGE
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
                                        foregroundColor: Colors.cyan,
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(25),
                                        ),
                                      ),
                                      child: const Text(
                                        "BOOK NOW",
                                        style: TextStyle(fontWeight: FontWeight.bold),
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

                  // Search bar
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        hintText: "Search services...",
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            FocusScope.of(context).unfocus();
                          },
                        )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.cyan),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Categories - MATCHES YOUR IMAGE LAYOUT
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
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('services').snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            final docs = snapshot.data!.docs;
                            final categories = docs.map((doc) => doc['category']).toSet().toList();

                            return SizedBox(
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
                                          if (selectedCategory == category) {
                                            selectedCategory = null;
                                          } else {
                                            selectedCategory = category;
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
                                            category,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: selectedCategory == category ? Colors.cyan : Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // Banner Ad
                  _buildBannerAdWidget(),

                  const SizedBox(height: 16),

                  // ✅ TOP SERVICES WITH WHITE CARDS - PERFECT MATCH TO YOUR IMAGE
                  Container(
                    color: Colors.white,
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
                              .where('category', isEqualTo: selectedCategory)
                              .snapshots()
                              : FirebaseFirestore.instance.collection('services').snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            final services = snapshot.data!.docs;

                            final filteredServices = services.where((service) {
                              final data = service.data() as Map<String, dynamic>;
                              final serviceName = (data['service'] ?? '').toString().toLowerCase();
                              return serviceName.contains(searchQuery);
                            }).toList();

                            if (filteredServices.isEmpty) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: Text(
                                    "No services found",
                                    style: TextStyle(color: Colors.grey, fontSize: 16),
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
                                final imageUrls = List<String>.from(data['imageUrls'] ?? []);
                                final category = data['category'] ?? '';
                                final userId = data['userId'] ?? '';
                                final providerName = data['providerName'] ?? 'Professional';

                                print('🏷️ Processing service: $serviceName with userId: $userId');

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  elevation: 3, // Increased elevation for better shadow
                                  // ✅ ENSURE WHITE BACKGROUND FOR CARDS - MATCHES YOUR IMAGE
                                  color: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Container(
                                    // ✅ ADDITIONAL WHITE BACKGROUND CONTAINER
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.15),
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
                                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                                Text(
                                                  "By $providerName",
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                                const SizedBox(height: 8),

                                                // Rating from database
                                                FutureBuilder<double>(
                                                  future: _fetchUserRating(userId),
                                                  builder: (context, ratingSnapshot) {
                                                    if (ratingSnapshot.connectionState == ConnectionState.waiting) {
                                                      return Row(
                                                        children: [
                                                          SizedBox(
                                                            width: 12,
                                                            height: 12,
                                                            child: CircularProgressIndicator(
                                                              strokeWidth: 1,
                                                              color: Colors.grey[400],
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

                                                    if (ratingSnapshot.hasError) {
                                                      print('❌ Error in rating FutureBuilder: ${ratingSnapshot.error}');
                                                      return _buildRatingWidget(0.0);
                                                    }

                                                    final rating = ratingSnapshot.data ?? 0.0;
                                                    print('🎯 DISPLAYING RATING: $rating for service: $serviceName');
                                                    return _buildRatingWidget(rating);
                                                  },
                                                ),

                                                const SizedBox(height: 12),

                                                // Send Request Button - MATCHES YOUR IMAGE STYLE
                                                SizedBox(
                                                  width: double.infinity,
                                                  child: ElevatedButton.icon(
                                                    onPressed: () {
                                                      final serviceId = service.id;
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) => SendOrderCustomer(
                                                            userId: userId,
                                                            serviceId: serviceId,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                    icon: const Icon(Icons.send, size: 16),
                                                    label: const Text("Send Request"),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.cyan,
                                                      foregroundColor: Colors.white,
                                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(8),
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

    )
    );
  }
}
