import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../profilePage.dart';

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

  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

    _bannerAd = BannerAd(
      adUnitId: dotenv.env['ADMOB_BANNER_ID'] ?? '', // Replace with real Ad Unit ID in production
      size: AdSize.banner,
      request: AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isBannerAdReady = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Ad failed to load: $error');
        },
      ),
    )..load();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Welcome to Home Services",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
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
                        final serviceName = (service['service'] ?? '').toString().toLowerCase();
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
                          final serviceName = service['service'] ?? '';

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              leading: const Icon(Icons.home_repair_service),
                              title: highlightText(serviceName, searchQuery),
                              subtitle: Text("Timing: ${service['timing']}"),
                              onTap: () {
                                final userId = service['userId'];
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ProfilePage(userId: userId),
                                  ),
                                );
                              },
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

          // Banner Ad at Bottom
          if (_isBannerAdReady)
            Container(
              height: _bannerAd!.size.height.toDouble(),
              width: _bannerAd!.size.width.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
        ],
      ),
    );
  }
}
