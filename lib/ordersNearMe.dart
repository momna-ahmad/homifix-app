import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import '../shared/categories.dart'; // Import the new category structure
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'sendServiceRequest.dart' ;


class Place {
  final double latitude;
  final double longitude;
  final String? displayName;

  Place({
    required this.latitude,
    required this.longitude,
    this.displayName,
  });
}

double calculateDistanceKm(gmaps.LatLng start, gmaps.LatLng end) {
  const R = 6371; // Earth radius in KM
  final dLat = (end.latitude - start.latitude) * (3.14159265359 / 180);
  final dLng = (end.longitude - start.longitude) * (3.14159265359 / 180);
  final a =
      (sin(dLat / 2) * sin(dLat / 2)) +
          cos(start.latitude * (3.14159265359 / 180)) *
              cos(end.latitude * (3.14159265359 / 180)) *
              sin(dLng / 2) * sin(dLng / 2);

  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}

Future<List<DocumentSnapshot>> _fetchNearbyOrders(gmaps.LatLng userLocation) async {
  final snapshot = await FirebaseFirestore.instance.collection('orders').get();

  final allOrders = snapshot.docs;

  final nearbyOrders = allOrders.where((doc) {
    final data = doc.data() as Map<String, dynamic>;
    final loc = data['location'];
    if (loc == null || loc['lat'] == null || loc['lng'] == null) return false;

    final orderLatLng = gmaps.LatLng(loc['lat'], loc['lng']);
    final distance = calculateDistanceKm(userLocation, orderLatLng);
    return distance <= 50;
  }).toList();

  return nearbyOrders;
}



Future<List<Place>> _searchWithLocationIQ(String input) async {
  const apiKey = 'pk.c6205b1882bfb7c832c4fea13d2fc5b4';
  final uri = Uri.parse('https://api.locationiq.com/v1/autocomplete?key=$apiKey&q=$input&limit=5&format=json');

  final response = await http.get(uri);

  if (response.statusCode == 200) {
    final List data = json.decode(response.body);
    return data.map((item) => Place(
      latitude: double.parse(item['lat']),
      longitude: double.parse(item['lon']),
      displayName: item['display_name'],
    )).toList();
  } else {
    throw Exception('LocationIQ error: ${response.statusCode}');
  }
}


Widget _buildColoredIconTextField(TextEditingController? controller, String label, IconData icon, Color iconColor, ValueChanged<String>? onChanged,  [TextInputType? type]) {
  return TextField(
    controller: controller,
    keyboardType: type ?? TextInputType.text,
    onChanged: onChanged,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Container(
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [iconColor.withOpacity(0.7), iconColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(color: iconColor.withOpacity(0.5), blurRadius: 5, offset: const Offset(1, 2)),
          ],
        ),
        child: Icon(icon, color: Colors.white),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      filled: true,
      fillColor: Colors.lightBlue.shade50.withOpacity(0.6),
      labelStyle: TextStyle(color: Colors.lightBlue.shade800, fontWeight: FontWeight.w600),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.lightBlue.shade700, width: 2),
      ),
    ),
  );
}

class LocationAutocompleteField extends StatefulWidget {
  final void Function(gmaps.LatLng, String) onPlaceSelected;
  const LocationAutocompleteField({required this.onPlaceSelected, super.key});

  @override
  _LocationAutocompleteFieldState createState() => _LocationAutocompleteFieldState();
}

class _LocationAutocompleteFieldState extends State<LocationAutocompleteField> {
  final TextEditingController _controller = TextEditingController();
  List<Place> _suggestions = [];
  bool _isLoading = false;
  Timer? _debounce;

  // Called when user types



  void _onTextChanged(String input) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (input.length < 3) {
        setState(() => _suggestions = []);
        return;
      }

      setState(() => _isLoading = true);

      try {
        final results = await _searchWithLocationIQ(input);
        setState(() => _suggestions = results);
      } catch (e) {
        print('location search error: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    });
  }

  void _onSuggestionTap(Place place) {
    final lat = place.latitude;
    final lon = place.longitude;
    final latLng = gmaps.LatLng(lat, lon);

    // Update text field
    _controller.text = place.displayName ?? '';

    // Clear suggestions
    setState(() {
      _suggestions = [];
    });

    // Notify parent widget of selection
    widget.onPlaceSelected(latLng, place.displayName ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildColoredIconTextField(
          _controller,
          'Location (e.g Wapda town, lahore, punjab, pakistan)',
          Icons.location_on,
          Colors.redAccent.shade400,
          _onTextChanged,
        ),
        if (_suggestions.isNotEmpty)
          Container(
            constraints: BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final place = _suggestions[index];
                return ListTile(
                  title: Text(place.displayName ?? 'Unknown'),
                  onTap: () => _onSuggestionTap(place),
                );
              },
            ),
          ),
      ],

    );
  }
}


class OrdersNearMe extends StatefulWidget {
  final String professionalId;
  const OrdersNearMe({super.key, required this.professionalId});

  @override
  State<OrdersNearMe> createState() => _OrdersNearMeState();
}

class _OrdersNearMeState extends State<OrdersNearMe> {
  gmaps.LatLng? _selectedLatLng;
  String _selectedAddress = '';
  List<DocumentSnapshot> _nearbyOrders = [];
  bool _loadingOrders = false;
  late Future<List<String>> _categoryFuture;

  void _showRequestDialog(String orderId) {
    showDialog(
      context: context,
      builder: (_) => SendRequestDialog(
        orderId: orderId,
        professionalId: widget.professionalId,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _categoryFuture = _fetchProfessionalCategories();
  }

  Future<List<String>> _fetchProfessionalCategories() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('services')
          .where('userId', isEqualTo: widget.professionalId)
          .get();

      return snapshot.docs.map((doc) => doc['category'] as String).toSet().toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _loadNearbyOrders(gmaps.LatLng location) async {
    setState(() => _loadingOrders = true);
    try {
      final orders = await _fetchNearbyOrders(location);
      setState(() => _nearbyOrders = orders);
    } catch (e) {
      print("Error loading nearby orders: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load nearby orders.")),
      );
    } finally {
      setState(() => _loadingOrders = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Orders Near Me')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            LocationAutocompleteField(
              onPlaceSelected: (latLng, address) {
                setState(() {
                  _selectedLatLng = latLng;
                  _selectedAddress = address;
                  _nearbyOrders.clear(); // Clear previous results
                });
                _loadNearbyOrders(latLng);
              },
            ),
            const SizedBox(height: 16),

            // Wait for categories before showing filtered orders
            FutureBuilder<List<String>>(
              future: _categoryFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }

                final categories = snapshot.data ?? [];

                if (_loadingOrders) {
                  return const CircularProgressIndicator();
                }

                if (_selectedLatLng != null && _nearbyOrders.isEmpty) {
                  return const Text("No nearby orders found.");
                }

                // ✅ Filter orders by professional's categories
                final filteredOrders = _nearbyOrders.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final category = data['category'];
                  return category != null && categories.contains(category);
                }).toList();

                if (filteredOrders.isEmpty) {
                  return const Text("No matching orders for your services.");
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Nearby Orders:",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredOrders.length,
                        itemBuilder: (context, index) {
                          final orderSnap = filteredOrders[index];
                          final data = orderSnap.data() as Map<String, dynamic>;

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 3,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(data['category'] ?? 'Category'),
                                    subtitle: Text(data['service'] ?? 'Service'),
                                    trailing: Text(
                                      data['status'] ?? 'Pending',
                                      style: const TextStyle(
                                        color: Colors.blueAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text("📅 Date: ${data['serviceDate'] ?? 'N/A'}"),
                                  Text("⏰ Time: ${data['serviceTime'] ?? 'N/A'}"),
                                  Text("💰 Price: ${data['priceOffer'] ?? 'Not specified'}"),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.send),
                                      label: const Text('Send Request'),
                                      onPressed: () => _showRequestDialog(orderSnap.id),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blueAccent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                    ),

                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
