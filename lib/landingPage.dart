import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../services/serviceVideoPlayer.dart';
import '../profilePage.dart';
import 'sendOrderCustomer.dart';
import './adminDashboard.dart';

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

  // Banner Ad variables
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;
  bool _isAdInitialized = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _initializeAds();
  }

  // Initialize AdMob and then load banner ad
  Future<void> _initializeAds() async {
    try {
      print('🔄 Initializing Google Mobile Ads...');

      // Initialize AdMob
      await MobileAds.instance.initialize();

      // Wait a bit for initialization to complete
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
      // Try loading ad anyway
      if (mounted) {
        _loadBannerAd();
      }
    }
  }

  // Load Banner Ad with enhanced debugging
  void _loadBannerAd() {
    print('🚀 Starting to load banner ad...');

    // Force test ad ID for debugging
    String adUnitId;
    if (kDebugMode) {
      // Always use test ad in debug mode
      adUnitId = 'ca-app-pub-3940256099942544/6300978111';
      print('🧪 Using TEST ad unit ID: $adUnitId');
    } else {
      // Use production ad or fallback to test
      adUnitId = dotenv.env['ADMOB_BANNER_ID'] ?? 'ca-app-pub-3940256099942544/6300978111';
      print('💰 Using ad unit ID: $adUnitId');
    }

    // Dispose previous ad if exists
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
          print('❌ Failed to load banner ad:');
          print('   Error Code: ${error.code}');
          print('   Error Message: ${error.message}');
          print('   Error Domain: ${error.domain}');
          print('   Response Info: ${error.responseInfo}');

          if (mounted) {
            setState(() {
              _isBannerAdReady = false;
            });
          }
          ad.dispose();

          // Retry after 5 seconds
          Timer(const Duration(seconds: 5), () {
            if (mounted) {
              print('🔄 Retrying banner ad load...');
              _loadBannerAd();
            }
          });
        },
        onAdOpened: (ad) {
          print('📱 Banner ad opened');
        },
        onAdClosed: (ad) {
          print('📱 Banner ad closed');
        },
        onAdImpression: (ad) {
          print('👁 Banner ad impression recorded');
        },
        onAdClicked: (ad) {
          print('👆 Banner ad clicked');
        },
      ),
    );

    print('⏳ Loading banner ad...');
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

  // Enhanced widget for banner ad display with debug info and proper null checks
  Widget _buildBannerAdWidget() {
    // Show loading indicator if ads are still initializing
    if (!_isAdInitialized) {
      return Container(
        height: 60,
        margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
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
              Text('Initializing ads...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    // Show debug info in debug mode
    if (kDebugMode && !_isBannerAdReady) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange[300]!, width: 1),
        ),
        child: Column(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(height: 8),
            const Text(
              'Banner Ad Not Loading',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Check debug console for error details',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                print('🔄 Manual retry requested');
                _loadBannerAd();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Return empty space if ad is not ready and not in debug mode
    if (!_isBannerAdReady || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    // Show the actual ad with proper null checks
    return Container(
      alignment: Alignment.center,
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 8.0, bottom: 4.0),
            child: Text(
              'Advertisement',
              style: TextStyle(
                fontSize: 11,
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
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          "Explore Services",
          style: TextStyle(color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings_outlined),
            tooltip: 'Admin Dashboard',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminDashboard()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search bar and label
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      const Expanded(
                        flex: 2,
                        child: Text(
                          "Browse Services by Category",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                            hintText: "Search services...",
                            prefixIcon: const Icon(Icons.search),
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
                              borderRadius: BorderRadius.circular(8),
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Categories horizontal list
                SizedBox(
                  height: 50,
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('services').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                      final docs = snapshot.data!.docs;
                      final categories = docs.map((doc) => doc['category']).toSet().toList();

                      return ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: ElevatedButton(
                              onPressed: () {
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
                              style: ElevatedButton.styleFrom(
                                backgroundColor: selectedCategory == category ? Colors.blue : Colors.grey[300],
                                foregroundColor: selectedCategory == category ? Colors.white : Colors.black,
                              ),
                              child: Text(category),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Banner Ad - Enhanced with debugging
                _buildBannerAdWidget(),

                // Services List
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: selectedCategory != null
                        ? FirebaseFirestore.instance
                        .collection('services')
                        .where('category', isEqualTo: selectedCategory)
                        .snapshots()
                        : FirebaseFirestore.instance.collection('services').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final services = snapshot.data!.docs;

                      final filteredServices = services.where((service) {
                        final data = service.data() as Map<String, dynamic>;
                        final serviceName = (data['service'] ?? '').toString().toLowerCase();
                        return serviceName.contains(searchQuery);
                      }).toList();

                      if (filteredServices.isEmpty) {
                        if (searchQuery.isNotEmpty) {
                          return const Center(child: Text("No results found."));
                        } else if (selectedCategory != null) {
                          return const Center(child: Text("No services found in this category."));
                        } else {
                          return const Center(child: Text("No services available."));
                        }
                      }

                      return ListView.builder(
                        itemCount: filteredServices.length,
                        itemBuilder: (context, index) {
                          final service = filteredServices[index];
                          final data = service.data() as Map<String, dynamic>;
                          final serviceName = data['service'] ?? '';
                          final imageUrls = List<String>.from(data['imageUrls'] ?? []);
                          final videoUrl = data['videoUrl'] ?? '';
                          final category = data['category'] ?? '';
                          final timing = data['timing'] ?? '';

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            elevation: 5,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    category,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: selectedCategory == category ? Colors.blue : Colors.black,
                                    ),
                                  ),
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.home_repair_service, color: Colors.blue),
                                    title: highlightText(serviceName, searchQuery),
                                    subtitle: Text("Timing: $timing"),
                                    onTap: () {
                                      final userId = data['userId'];
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ProfilePage(userId: userId),
                                        ),
                                      );
                                    },
                                  ),

                                  const SizedBox(height: 8),

                                  // Images
                                  if (imageUrls.isNotEmpty)
                                    SizedBox(
                                      height: 200,
                                      child: PageView.builder(
                                        itemCount: imageUrls.length,
                                        itemBuilder: (_, i) => ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Image.network(
                                            imageUrls[i],
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            errorBuilder: (context, error, stackTrace) => Container(
                                              color: Colors.grey[300],
                                              child: const Icon(Icons.error),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Video
                                  if (videoUrl.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 12.0),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: SizedBox(
                                          height: 200,
                                          width: double.infinity,
                                          child: ServiceVideoPlayer(videoUrl: videoUrl),
                                        ),
                                      ),
                                    ),

                                  const SizedBox(height: 12),

                                  // Send Order Button
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.send),
                                      label: const Text("Send Order"),
                                      onPressed: () {
                                        final userId = data['userId'];
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
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}