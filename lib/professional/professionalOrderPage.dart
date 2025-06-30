import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'sendServiceRequest.dart' ; // Ensure this path is correct
import '../ordersNearMe.dart';
import 'package:geolocator/geolocator.dart'; // Add this import

// Enum to represent the different job listing filters
enum JobFilter { all, nearMe, searchLocation }

// --- Utility functions (moved from ordersNearMe.dart for reusability) ---
double calculateDistanceKm(gmaps.LatLng start, gmaps.LatLng end) {
  const R = 6371; // Earth radius in KM
  final dLat = (end.latitude - start.latitude) * (pi / 180); // Corrected to use Dart's 'pi'
  final dLng = (end.longitude - start.longitude) * (pi / 180);
  final a =
      (sin(dLat / 2) * sin(dLat / 2)) +
          cos(start.latitude * (pi / 180)) *
              cos(end.latitude * (pi / 180)) *
              sin(dLng / 2) * sin(dLng / 2);

  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}

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

Future<List<Place>> _searchWithLocationIQ(String input) async {
  // Use current time to avoid caching issues with LocationIQ if any
  // Ensure your API key is secure and not hardcoded in production apps.
  const apiKey = 'pk.c6205b1882bfb7c832c4fea13d2fc5b4'; // Replace with your actual key
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
    throw Exception('LocationIQ error: ${response.statusCode}, Body: ${response.body}');
  }
}

// --- Location Autocomplete Field Widget ---
class LocationAutocompleteField extends StatefulWidget {
  final void Function(gmaps.LatLng, String) onPlaceSelected;
  final TextEditingController controller; // Pass controller from parent

  const LocationAutocompleteField({required this.onPlaceSelected, required this.controller, super.key});

  @override
  _LocationAutocompleteFieldState createState() => _LocationAutocompleteFieldState();
}

class _LocationAutocompleteFieldState extends State<LocationAutocompleteField> {
  List<Place> _suggestions = [];
  bool _isLoading = false;
  Timer? _debounce;

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
        print('LocationIQ search error: $e');
        // Optionally show an error message to the user
      } finally {
        setState(() => _isLoading = false);
      }
    });
  }

  void _onSuggestionTap(Place place) {
    final latLng = gmaps.LatLng(place.latitude, place.longitude);

    widget.controller.text = place.displayName ?? ''; // Update text field

    setState(() {
      _suggestions = []; // Clear suggestions
    });

    widget.onPlaceSelected(latLng, place.displayName ?? ''); // Notify parent
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField( // Changed to TextFormField for better integration with forms if needed
          controller: widget.controller,
          keyboardType: TextInputType.text,
          onChanged: _onTextChanged,
          decoration: InputDecoration(
            hintText: 'Search by location (e.g., Lahore, Pakistan)',
            prefixIcon: const Icon(Icons.location_on, color: Color(0xFF64748B)),
            suffixIcon: _isLoading
                ? const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : (widget.controller.text.isNotEmpty
                ? IconButton(
              icon: const Icon(Icons.clear, color: Color(0xFF64748B)),
              onPressed: () {
                widget.controller.clear();
                _suggestions = []; // Clear suggestions on clear
                setState(() {}); // Rebuild to clear suggestions
                widget.onPlaceSelected(const gmaps.LatLng(0, 0), ''); // Notify parent of clear
              },
            )
                : null),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          ),
        ),
        if (_suggestions.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
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

// --- Professional Orders Page ---
class ProfessionalOrdersPage extends StatefulWidget {
  final String professionalId;

  const ProfessionalOrdersPage({super.key, required this.professionalId});

  @override
  State<ProfessionalOrdersPage> createState() => _ProfessionalOrdersPageState();
}

class _ProfessionalOrdersPageState extends State<ProfessionalOrdersPage> {
  late Future<List<String>> _categoryFuture;
  late Future<List<String>> _requestsSentFuture;
  String? _loadingOrderId; // This controls the loading state of a specific button
  JobFilter _selectedFilter = JobFilter.all; // Default filter for main content

  final TextEditingController _searchLocationController = TextEditingController();
  gmaps.LatLng? _selectedSearchLatLng; // Store selected location from search bar
  String? _selectedSearchAddress; // Store selected address from search bar

  gmaps.LatLng? _currentUserLocation; // To store current device location for "Near Me"
  bool _isGettingLocation = false; // To show loading for location
  String? _locationError; // To store location-related errors

  @override
  void initState() {
    super.initState();
    _categoryFuture = _fetchProfessionalCategories();
    _requestsSentFuture = _fetchRequestsSent();
  }

  @override
  void dispose() {
    _searchLocationController.dispose();
    super.dispose();
  }

  Future<List<String>> _fetchProfessionalCategories() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('services')
          .where('userId', isEqualTo: widget.professionalId)
          .get();

      return snapshot.docs.map((doc) => doc['category'] as String).toSet().toList();
    } catch (e) {
      print('Error fetching professional categories: $e');
      return [];
    }
  }

  Future<List<String>> _fetchRequestsSent() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.professionalId)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null && data.containsKey('requestsSent')) {
          return List<String>.from(data['requestsSent'] ?? []);
        }
      }
      return [];
    } catch (e) {
      print('Error fetching requestsSent: $e');
      return [];
    }
  }

  Future<void> _getCurrentLocationAndFilter() async {
    setState(() {
      _isGettingLocation = true;
      _locationError = null;
      _selectedFilter = JobFilter.nearMe;
      _searchLocationController.clear();
      _selectedSearchLatLng = null;
      _selectedSearchAddress = null;
    });

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _locationError = 'Location services are disabled. Please enable them from settings.';
        _isGettingLocation = false;
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _locationError = 'Location permissions are denied. Please grant them.';
          _isGettingLocation = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _locationError = 'Location permissions are permanently denied. We cannot request permissions without app settings.';
        _isGettingLocation = false;
      });
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      setState(() {
        _currentUserLocation = gmaps.LatLng(position.latitude, position.longitude);
        _isGettingLocation = false;
        _locationError = null;
      });
    } catch (e) {
      setState(() {
        _locationError = 'Failed to get current location: ${e.toString()}';
        _isGettingLocation = false;
      });
    }
  }

  Future<List<DocumentSnapshot>> _fetchFilteredOrders() async {
    final categories = await _categoryFuture;
    if (categories.isEmpty) {
      return [];
    }

    Query collectionRef = FirebaseFirestore.instance.collection('orders')
        .where('category', whereIn: categories)
        .where('status', isEqualTo: 'waiting');

    if (_selectedFilter == JobFilter.searchLocation && _selectedSearchLatLng != null) {
      final querySnapshot = await collectionRef.get();
      return querySnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final loc = data['location'];
        if (loc == null || loc['lat'] == null || loc['lng'] == null) return false;

        final orderLatLng = gmaps.LatLng(loc['lat'], loc['lng']);
        final distance = calculateDistanceKm(_selectedSearchLatLng!, orderLatLng);
        return distance <= 150;
      }).toList();
    } else if (_selectedFilter == JobFilter.nearMe && _currentUserLocation != null) {
      final querySnapshot = await collectionRef.get();
      return querySnapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final loc = data['location'];
        if (loc == null || loc['lat'] == null || loc['lng'] == null) return false;

        final orderLatLng = gmaps.LatLng(loc['lat'], loc['lng']);
        final distance = calculateDistanceKm(_currentUserLocation!, orderLatLng);
        return distance <= 150;
      }).toList();
    } else if (_selectedFilter == JobFilter.all) {
      final querySnapshot = await collectionRef.get();
      return querySnapshot.docs;
    }
    return [];
  }

  void _showRequestDialog(String orderId) async {
    // Set loading state for this specific order
    setState(() {
      _loadingOrderId = orderId;
    });

    try {
      // Wait for the dialog to return a result
      final bool? result = await showDialog<bool>(
        context: context,
        builder: (_) => SendRequestDialog(
          orderId: orderId,
          professionalId: widget.professionalId,
          onRequestSent: () {
            // This callback will be called when request is successfully sent
            // Re-fetch the list of sent requests to update the UI
            _requestsSentFuture = _fetchRequestsSent();

            // Update the state to reflect the change
            setState(() {
              // The UI will rebuild and show 'Requested' button
            });
          },
        ),
      );

      // Only proceed with success actions if result is explicitly true
      if (result == true) {
        // Show a success snackbar ONLY if the request was sent
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Request sent successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // If result is false or null (dialog dismissed/cancelled/failed within dialog),
        // we don't show a success snackbar, and the button remains 'Send Request'
        // unless there was an error in the process outside the dialog's control.
        if (mounted && result == false) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Request sending failed or cancelled.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('Error showing request dialog or sending request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Always clear the loading state, regardless of success or failure within the dialog
      // This will revert the button to its original state if the request wasn't successful,
      // or to 'Requested' if _requestsSentFuture update happened.
      setState(() {
        _loadingOrderId = null;
      });
    }
  }

  void _goToOrdersNearMe() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrdersNearMe(professionalId: widget.professionalId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F9FF),
      appBar: AppBar(
        title: const Text(
          'Job Posts',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF0EA5E9),
              child: IconButton(
                icon: const Icon(
                  Icons.location_on_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: null, // Keep this as null if it's just an icon for "Near Me"
                tooltip: "Near Me (Current Location)",
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF22D3EE), Color(0xFF0EA5E9)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF22D3EE).withOpacity(0.3),
                          spreadRadius: 0,
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Find Jobs',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const Text(
                                'Discover opportunities in your area',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Browse Jobs',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0EA5E9),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.work,
                          size: 60,
                          color: Colors.white30,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSquaredFilterButton(
                        context,
                        'All',
                        Icons.work_outline,
                        JobFilter.all,
                      ),
                      const SizedBox(width: 16),
                      _buildSquaredFilterButton(
                        context,
                        'Near Me',
                        Icons.location_on_outlined,
                        JobFilter.nearMe,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LocationAutocompleteField(
                    controller: _searchLocationController,
                    onPlaceSelected: (latLng, address) {
                      setState(() {
                        _selectedSearchLatLng = latLng;
                        _selectedSearchAddress = address;
                        _selectedFilter = JobFilter.searchLocation;
                        _currentUserLocation = null;
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Text(
                'Available Jobs',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),

            const SizedBox(height: 16),

            FutureBuilder<List<DocumentSnapshot>>(
              future: _fetchFilteredOrders(),
              builder: (context, ordersSnapshot) {
                if (ordersSnapshot.connectionState == ConnectionState.waiting || _isGettingLocation) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Column(
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0EA5E9)),
                          ),
                          SizedBox(height: 10),
                          Text('Getting location and loading orders...', textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  );
                }

                if (_locationError != null) {
                  return _buildEmptyState(
                    _locationError!,
                    Icons.error_outline,
                  );
                }

                if (ordersSnapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text('Error loading orders: ${ordersSnapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                }

                final orders = ordersSnapshot.data ?? [];

                if (orders.isEmpty) {
                  if (_selectedFilter == JobFilter.all) {
                    return _buildEmptyState(
                      "No job posts found for your services.",
                      Icons.search_off,
                    );
                  } else if (_selectedFilter == JobFilter.nearMe) {
                    return _buildEmptyState(
                      "No jobs found within 150km of your current location for your services.",
                      Icons.location_off,
                    );
                  } else if (_selectedFilter == JobFilter.searchLocation && _selectedSearchLatLng == null) {
                    return _buildEmptyState(
                      "Enter a location in the search bar above to find jobs.",
                      Icons.location_searching,
                    );
                  } else if (_selectedFilter == JobFilter.searchLocation && _selectedSearchLatLng != null && _searchLocationController.text.isNotEmpty) {
                    return _buildEmptyState(
                      "No jobs found within 150km of '${_selectedSearchAddress ?? 'the selected location'}' for your services.",
                      Icons.location_off,
                    );
                  }
                }

                return FutureBuilder<List<String>>(
                  future: _requestsSentFuture,
                  builder: (context, requestsSentSnapshot) {
                    if (requestsSentSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0EA5E9)),
                          ),
                        ),
                      );
                    }

                    final List<String> requestsSent = requestsSentSnapshot.data ?? [];

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: orders.length,
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        final data = order.data() as Map<String, dynamic>;
                        return _buildJobCard(context, order.id, data, requestsSent);
                      },
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildSquaredFilterButton(BuildContext context, String text, IconData icon, JobFilter filter) {
    final bool isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
          _searchLocationController.clear();
          _selectedSearchLatLng = null;
          _selectedSearchAddress = null;
          _currentUserLocation = null;
          _locationError = null;
        });
        if (filter == JobFilter.nearMe) {
          _getCurrentLocationAndFilter();
        }
      },
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0EA5E9) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.transparent : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              spreadRadius: 0,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 40,
              color: isSelected ? Colors.white : const Color(0xFF0EA5E9),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobCard(BuildContext context, String orderId, Map<String, dynamic> data, List<String> requestsSent) {
    final bool isLoading = _loadingOrderId == orderId;
    final bool hasRequested = requestsSent.contains(orderId);
    final bool hasDescription = data.containsKey('description') &&
        data['description'] != null &&
        data['description'].toString().trim().isNotEmpty;

    return StatefulBuilder(
      builder: (context, setState) {
        bool isExpanded = false; // Initial state

        return StatefulBuilder(
          builder: (context, localSetState) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    spreadRadius: 0,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0EA5E9).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.category,
                            color: Color(0xFF0EA5E9),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            data['category'] ?? 'Unknown Category',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        if (hasDescription)
                          InkWell(
                            onTap: () {
                              localSetState(() {
                                isExpanded = !isExpanded;
                              });
                            },
                            child: Row(
                              children: [
                                Text(
                                  isExpanded ? "Hide Details" : "Show Details",
                                  style: TextStyle(
                                    color: Colors.blue[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Icon(
                                  isExpanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: Colors.blue[600],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    _buildDetailRow(Icons.home_repair_service, 'Service', data['service'] ?? 'N/A'),
                    const SizedBox(height: 8),
                    _buildDetailRow(Icons.location_on, 'Location', data['location']['address'] ?? 'N/A'),
                    const SizedBox(height: 8),
                    _buildDetailRow(Icons.calendar_today, 'Date', data['serviceDate'] ?? 'N/A'),
                    const SizedBox(height: 8),
                    _buildDetailRow(Icons.access_time, 'Time', data['serviceTime'] ?? 'N/A'),
                    const SizedBox(height: 8),
                    _buildDetailRow(Icons.payments, 'Offer', data['priceOffer'] ?? 'Not specified'),

                    if (hasDescription && isExpanded) ...[
                      const SizedBox(height: 12),
                      const Divider(),
                      const Text(
                        'Description:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data['description'],
                        style: const TextStyle(
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: isLoading || hasRequested ? null : () => _showRequestDialog(orderId),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ).copyWith(
                          backgroundColor: MaterialStateProperty.resolveWith<Color>(
                                (Set<MaterialState> states) {
                              if (states.contains(MaterialState.disabled)) return Colors.grey;
                              return const Color(0xFF0EA5E9);
                            },
                          ),
                          foregroundColor: MaterialStateProperty.all(Colors.white),
                          elevation: MaterialStateProperty.resolveWith<double>(
                                (Set<MaterialState> states) {
                              if (states.contains(MaterialState.disabled)) return 0;
                              return 4;
                            },
                          ),
                        ),
                        icon: isLoading
                            ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                            : hasRequested
                            ? const Icon(Icons.check_circle_outline, size: 16)
                            : const Icon(Icons.send, size: 16),
                        label: Text(
                          isLoading ? 'Sending...' : (hasRequested ? 'Requested' : 'Send Request'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
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
    );
  }



  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF0EA5E9).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 14,
            color: const Color(0xFF0EA5E9),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              size: 48,
              color: const Color(0xFF0EA5E9),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Available job opportunities will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}