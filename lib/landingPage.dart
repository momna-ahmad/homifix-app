import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/serviceVideoPlayer.dart';
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

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
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
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          "Explore Services",
           style: TextStyle(color: Colors.black), // dark text
        ),
        iconTheme: const IconThemeData(color: Colors.black87), // for any icons (if added later)
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar and label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
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
                if (!snapshot.hasData) return const SizedBox(); // or return a placeholder Text("Loading...")


                final docs = snapshot.data!.docs;
                final categories = docs.map((doc) => doc['category']).toSet().toList();

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(categories.length, (index) {
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
                    }),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Services List
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

                final filtered = services.where((service) {
                  final serviceName = (service['service'] ?? '').toString().toLowerCase();
                  return serviceName.contains(searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  if (searchQuery.isNotEmpty) {
                    return const Center(child: Text("No results found."));
                  } else if (selectedCategory != null) {
                    return const Center(child: Text("No services found in this category."));
                  } else {
                    return const Center(child: Text("No services available."));
                  }
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final service = filtered[index];
                    final data = service.data() as Map<String, dynamic>;
                    final serviceName = data['service'] ?? '';
                    final imageUrls = List<String>.from(data['imageUrls'] ?? []);
                    final videoUrl = data['videoUrl'] ?? '';
                    final category = data['category'] ?? '';


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
                              "$category",
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
    );
  }
}