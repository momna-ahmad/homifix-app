import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:home_services_app/profilePage.dart';
import 'professionalForCustomer.dart';

// ✅ RIVERPOD PROVIDERS

// Order Applications Provider
final orderApplicationsProvider = StreamProvider.family<DocumentSnapshot<Map<String, dynamic>>?, String>((ref, orderId) {
  print('🔄 RIVERPOD: Setting up order applications stream for order: $orderId');

  return FirebaseFirestore.instance
      .collection('orders')
      .doc(orderId)
      .snapshots()
      .map((snapshot) {
    print('📡 RIVERPOD: Order applications update received');
    return snapshot.exists ? snapshot : null;
  });
});

// Previous Locations Provider for Customer
final previousLocationsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, customerId) {
  print('🔄 RIVERPOD: Setting up previous locations stream for customer: $customerId');

  return FirebaseFirestore.instance
      .collection('orders')
      .where('customerId', isEqualTo: customerId)
      .snapshots()
      .map((snapshot) {
    print('📡 RIVERPOD: Previous locations update - ${snapshot.docs.length} orders');

    Set<String> uniqueAddresses = {};
    List<Map<String, dynamic>> locations = [];

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['location'] != null && data['location'] is Map<String, dynamic>) {
        final location = data['location'] as Map<String, dynamic>;
        final address = location['address'] as String?;

        if (address != null && address.isNotEmpty && !uniqueAddresses.contains(address)) {
          uniqueAddresses.add(address);
          locations.add({
            'address': address,
            'lat': location['lat'],
            'lng': location['lng'],
          });
        }
      }
    }

    print('✅ RIVERPOD: Previous locations processed - ${locations.length} unique locations');
    return locations;
  });
});

// Location State Provider
final locationStateProvider = StateNotifierProvider<LocationStateNotifier, LocationState>((ref) {
  return LocationStateNotifier();
});

class LocationState {
  final String currentLocation;
  final double? currentLat;
  final double? currentLng;
  final Map<String, dynamic>? selectedPreviousLocation;
  final bool isGettingLocation;
  final bool isLoadingLocations;

  LocationState({
    this.currentLocation = '',
    this.currentLat,
    this.currentLng,
    this.selectedPreviousLocation,
    this.isGettingLocation = false,
    this.isLoadingLocations = false,
  });

  LocationState copyWith({
    String? currentLocation,
    double? currentLat,
    double? currentLng,
    Map<String, dynamic>? selectedPreviousLocation,
    bool? isGettingLocation,
    bool? isLoadingLocations,
    bool clearSelectedLocation = false,
  }) {
    return LocationState(
      currentLocation: currentLocation ?? this.currentLocation,
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
      selectedPreviousLocation: clearSelectedLocation ? null : (selectedPreviousLocation ?? this.selectedPreviousLocation),
      isGettingLocation: isGettingLocation ?? this.isGettingLocation,
      isLoadingLocations: isLoadingLocations ?? this.isLoadingLocations,
    );
  }
}

class LocationStateNotifier extends StateNotifier<LocationState> {
  LocationStateNotifier() : super(LocationState());

  // ✅ Get address from coordinates using LocationIQ API
  Future<String> _getAddressFromLatLng(double lat, double lng) async {
    const apiKey = 'pk.c6205b1882bfb7c832c4fea13d2fc5b4';
    final url = Uri.parse(
      'https://us1.locationiq.com/v1/reverse?key=$apiKey&lat=$lat&lon=$lng&format=json',
    );

    try {
      print('🌐 RIVERPOD: Making LocationIQ API request for coordinates: $lat, $lng');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['display_name'] ?? 'Unknown location';
        print('✅ RIVERPOD: LocationIQ API response: $address');
        return address;
      } else {
        print('❌ RIVERPOD: LocationIQ API error: ${response.statusCode}');
        throw Exception('Failed to get address: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ RIVERPOD: Error getting address from LocationIQ: $e');
      return 'Location: $lat, $lng';
    }
  }

  // ✅ Improved location acquisition with multiple fallback strategies
  Future<void> getCurrentLocation() async {
    try {
      print('🔄 RIVERPOD: Starting improved location acquisition process...');

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled. Please enable location services in your device settings.');
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied. Please allow location access.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permissions are permanently denied. Please enable them in device settings.',
        );
      }

      // Show loading indicator
      state = state.copyWith(isGettingLocation: true);

      Position? position;

      try {
        print('📍 RIVERPOD: Attempting high accuracy location...');
        // First attempt: High accuracy with shorter timeout
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (e) {
        print('⚠️ RIVERPOD: High accuracy failed, trying medium accuracy: $e');

        try {
          // Second attempt: Medium accuracy with longer timeout
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 15),
          );
        } catch (e) {
          print('⚠️ RIVERPOD: Medium accuracy failed, trying low accuracy: $e');

          try {
            // Third attempt: Low accuracy with even longer timeout
            position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.low,
              timeLimit: const Duration(seconds: 20),
            );
          } catch (e) {
            print('⚠️ RIVERPOD: Low accuracy failed, trying last known position: $e');

            // Final fallback: Get last known position
            position = await Geolocator.getLastKnownPosition();
            if (position == null) {
              throw Exception('Unable to get location. Please ensure GPS is enabled and try again in an open area.');
            }
            print('✅ RIVERPOD: Using last known position as fallback');
          }
        }
      }

      final lat = position.latitude;
      final lng = position.longitude;

      print('✅ RIVERPOD: Position obtained: $lat, $lng');
      print('🌐 RIVERPOD: Getting address from LocationIQ API...');

      // Get address using LocationIQ API with timeout
      String address;
      try {
        address = await _getAddressFromLatLng(lat, lng);
      } catch (e) {
        print('⚠️ RIVERPOD: Address lookup failed, using coordinates: $e');
        address = 'Location: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
      }

      state = state.copyWith(
        currentLat: lat,
        currentLng: lng,
        currentLocation: address,
        isGettingLocation: false,
        clearSelectedLocation: true, // Clear dropdown selection
      );

      print('✅ RIVERPOD: Current location obtained successfully: $address');
      print('📊 RIVERPOD: Location data - Lat: $lat, Lng: $lng');
    } catch (e) {
      state = state.copyWith(isGettingLocation: false);
      print('❌ RIVERPOD: Error getting location: $e');
      rethrow;
    }
  }

  // Handle previous location selection
  void selectPreviousLocation(Map<String, dynamic> location) {
    state = state.copyWith(
      selectedPreviousLocation: location,
      currentLocation: location['address'],
      currentLat: location['lat']?.toDouble(),
      currentLng: location['lng']?.toDouble(),
    );

    print('✅ RIVERPOD: Previous location selected: ${location['address']}');
  }

  void clearLocation() {
    state = LocationState();
  }
}

// Application Actions Provider
final applicationActionsProvider = Provider<ApplicationActions>((ref) {
  return ApplicationActions(ref);
});

class ApplicationActions {
  final Ref ref;
  ApplicationActions(this.ref);

  // Accept application with location sharing
  Future<void> acceptApplication(
      BuildContext context,
      String orderId,
      int applicationIndex,
      String professionalId,
      String customerId,
      ) async {
    final locationState = ref.read(locationStateProvider);

    // Validate location
    if (locationState.currentLocation.isEmpty ||
        locationState.currentLat == null ||
        locationState.currentLng == null) {
      _showSnackBar(context, 'Please select a location first', Colors.red);
      return;
    }

    try {
      print('🎯 RIVERPOD: Accepting application with location:');
      print('   🆔 Order ID: $orderId');
      print('   📋 Application Index: $applicationIndex');
      print('   👨‍💼 Professional ID: $professionalId');
      print('   👤 Customer ID: $customerId');
      print('   📍 Location: ${locationState.currentLocation}');
      print('   🌐 Coordinates: ${locationState.currentLat}, ${locationState.currentLng}');

      final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final currentOrderSnapshot = await transaction.get(orderRef);

        if (!currentOrderSnapshot.exists) {
          throw Exception('Order document disappeared during transaction!');
        }

        final orderData = currentOrderSnapshot.data()!;
        final applications = List.from(orderData['applications'] ?? []);

        if (applicationIndex < 0 || applicationIndex >= applications.length) {
          throw Exception('Invalid application index: $applicationIndex');
        }

        if (orderData['status'] == 'assigned' || orderData['status'] == 'completed') {
          throw Exception('Order already assigned or completed!');
        }

        // Update application status
        final updatedApplication = {...applications[applicationIndex], 'status': 'accepted'};
        applications[applicationIndex] = updatedApplication;

        // ✅ Update order with client location (customer's shared location)
        transaction.update(orderRef, {
          'applications': applications,
          'status': 'assigned',
          'selectedWorkerId': professionalId,
          'clientLocation': {
            'address': locationState.currentLocation,
            'lat': locationState.currentLat!,
            'lng': locationState.currentLng!,
          },
        });

        // ✅ Add to professional's orders array with location as Map format
        final professionalDocRef = FirebaseFirestore.instance.collection('users').doc(professionalId);
        transaction.update(professionalDocRef, {
          'orders': FieldValue.arrayUnion([
            {
              'location': {
                'address': locationState.currentLocation,
                'lat': locationState.currentLat!,
                'lng': locationState.currentLng!,
              },
              'date': orderData['serviceDate'],
              'time': orderData['serviceTime'],
              'price': applications[applicationIndex]['price'],
              'service': orderData['service'],
              'completionStatus': 'pending',
              'orderId': orderId,
            }
          ])
        });
      });

      // Clear location state
      ref.read(locationStateProvider.notifier).clearLocation();

      if (context.mounted) {
        _showSnackBar(context, 'Application accepted successfully!', Colors.green);
        Navigator.pop(context);
      }

      print('✅ RIVERPOD: Application accepted successfully');
    } catch (e) {
      print('❌ RIVERPOD: Error accepting application: $e');
      if (context.mounted) {
        _showSnackBar(context, 'Failed to accept application: $e', Colors.red);
      }
    }
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }
}

class OrderApplications extends ConsumerWidget {
  final String orderId;

  const OrderApplications({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderApplicationsProvider(orderId));

    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      appBar: _buildAppBar(),
      body: orderAsync.when(
        data: (orderSnapshot) {
          if (orderSnapshot == null || !orderSnapshot.exists) {
            return _buildErrorWidget('Order not found');
          }

          final orderData = orderSnapshot.data()! as Map<String, dynamic>;
          final applications = (orderData['applications'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          final orderStatus = orderData['status'] as String? ?? 'pending';
          final customerId = orderData['customerId'] as String? ?? '';

          if (applications.isEmpty) {
            return _buildEmptyWidget();
          }

          return _buildApplicationsList(applications, orderData, orderStatus, customerId);
        },
        loading: () => _buildLoadingWidget(),
        error: (error, stack) {
          print('❌ RIVERPOD: Order applications error: $error');
          return _buildErrorWidget('Error loading applications: $error');
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      title: const Text(
        "Order Applications",
        style: TextStyle(
          color: Colors.black,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      iconTheme: const IconThemeData(color: Colors.black),
    );
  }

  Widget _buildApplicationsList(
      List<Map<String, dynamic>> applications,
      Map<String, dynamic> orderData,
      String orderStatus,
      String customerId,
      ) {
    return Container(
      color: const Color(0xFFE3F2FD),
      child: Column(
        children: [
          // Order Info Header
          _buildOrderInfoHeader(orderData),

          // Applications List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: applications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final application = applications[index];
                final professionalId = application['professionalId'] as String;

                return _ApplicationCard(
                  key: ValueKey('${application['professionalId']}_$index'),
                  orderId: orderId,
                  application: application,
                  applicationIndex: index,
                  professionalId: professionalId,
                  orderStatus: orderStatus,
                  customerId: customerId,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfoHeader(Map<String, dynamic> orderData) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            orderData['service'] ?? orderData['serviceName'] ?? 'Service Request',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          if (orderData['category'] != null) ...[
            _buildInfoChip(orderData['category'], Icons.category),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              if (orderData['serviceDate'] != null)
                _buildInfoChip(orderData['serviceDate'], Icons.calendar_today),
              const SizedBox(width: 12),
              if (orderData['serviceTime'] != null)
                _buildInfoChip(orderData['serviceTime'], Icons.access_time),
            ],
          ),
          if (orderData['price'] != null || orderData['priceOffer'] != null) ...[
            const SizedBox(height: 8),
            _buildInfoChip(
              'Rs. ${orderData['priceOffer'] ?? orderData['price']}',
              Icons.payments,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF00BCD4), size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF00838F),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF00BCD4)),
          const SizedBox(height: 16),
          Text(
            'Loading applications...',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
          const SizedBox(height: 16),
          Text(error, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'No applications yet',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            'Applications will appear here when professionals apply',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Application Card Widget
class _ApplicationCard extends ConsumerStatefulWidget {
  final String orderId;
  final Map<String, dynamic> application;
  final int applicationIndex;
  final String professionalId;
  final String orderStatus;
  final String customerId;

  const _ApplicationCard({
    super.key,
    required this.orderId,
    required this.application,
    required this.applicationIndex,
    required this.professionalId,
    required this.orderStatus,
    required this.customerId,
  });

  @override
  ConsumerState<_ApplicationCard> createState() => _ApplicationCardState();
}

class _ApplicationCardState extends ConsumerState<_ApplicationCard> {
  String? _professionalName;
  String? _profileImageUrl;
  bool _isLoadingProfessional = false;

  @override
  void initState() {
    super.initState();
    _loadProfessionalData();
  }

  void _loadProfessionalData() async {
    if (_isLoadingProfessional) return;

    setState(() => _isLoadingProfessional = true);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.professionalId)
          .get();

      if (userDoc.exists && mounted) {
        final userData = userDoc.data()!;
        setState(() {
          _professionalName = userData['name'] ?? 'Professional';
          _profileImageUrl = userData['profileImage'] as String?;
          _isLoadingProfessional = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _professionalName = 'Professional';
          _isLoadingProfessional = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final applicationStatus = widget.application['status'] as String? ?? 'pending';

    return Card(
      elevation: 6,
      shadowColor: const Color(0xFF00BCD4).withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Main content row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Image
                Container(
                  width: 64,
                  height: 64,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF00BCD4), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00BCD4).withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                        ? Image.network(
                      _profileImageUrl!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: const Color(0xFFE3F2FD),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: const Color(0xFF00BCD4),
                              strokeWidth: 2,
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: const Color(0xFFE3F2FD),
                          child: const Icon(
                            Icons.person,
                            color: Color(0xFF00BCD4),
                            size: 32,
                          ),
                        );
                      },
                    )
                        : Container(
                      color: const Color(0xFFE3F2FD),
                      child: const Icon(
                        Icons.person,
                        color: Color(0xFF00BCD4),
                        size: 32,
                      ),
                    ),
                  ),
                ),

                // Professional Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _professionalName ?? (_isLoadingProfessional ? 'Loading...' : 'Professional'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.message_outlined,
                            color: const Color(0xFF00BCD4),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Message: ${widget.application['message'] ?? 'No message'}',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.currency_rupee,
                            color: const Color(0xFF00BCD4),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Price: Rs. ${widget.application['price'] ?? 'N/A'}',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Action Buttons Row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.person, size: 14),
                    label: const Text(
                      'View Profile',
                      style: TextStyle(fontSize: 12),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProfessionalForCustomer(userId: widget.professionalId),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00BCD4),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (applicationStatus == 'accepted')
                  Container(
                    height: 36,
                    child: Chip(
                      label: const Text(
                        'Accepted',
                        style: TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Colors.green.shade100,
                      avatar: const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 16,
                      ),
                    ),
                  )
                else if (applicationStatus == 'pending' &&
                    widget.orderStatus != 'assigned' &&
                    widget.orderStatus != 'completed')
                  SizedBox(
                    height: 36,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 14),
                      label: const Text(
                        'Accept',
                        style: TextStyle(fontSize: 12),
                      ),
                      onPressed: () => _showLocationDialog(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BCD4),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showLocationDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LocationSelectionDialog(
        orderId: widget.orderId,
        applicationIndex: widget.applicationIndex,
        professionalId: widget.professionalId,
        customerId: widget.customerId,
      ),
    );
  }
}

// Location Selection Dialog
class _LocationSelectionDialog extends ConsumerWidget {
  final String orderId;
  final int applicationIndex;
  final String professionalId;
  final String customerId;

  const _LocationSelectionDialog({
    required this.orderId,
    required this.applicationIndex,
    required this.professionalId,
    required this.customerId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationState = ref.watch(locationStateProvider);
    final previousLocationsAsync = ref.watch(previousLocationsProvider(customerId));
    final applicationActions = ref.watch(applicationActionsProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF00BCD4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title
          const Text(
            'Share Your Location',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF00838F),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Share your location to accept this application',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Previous Locations Dropdown
          previousLocationsAsync.when(
            data: (previousLocations) => _buildPreviousLocationsSection(
              context, ref, previousLocations, locationState,
            ),
            loading: () => _buildLoadingLocationsSection(),
            error: (error, stack) => _buildErrorLocationsSection(),
          ),

          const SizedBox(height: 16),

          // OR Divider
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey.shade300)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'OR',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey.shade300)),
            ],
          ),
          const SizedBox(height: 16),

          // Current Location Display
          if (locationState.currentLocation.isNotEmpty)
            _buildLocationDisplay(locationState),

          // ✅ Get Current Location Button with improved error handling
          ElevatedButton.icon(
            onPressed: locationState.isGettingLocation
                ? null
                : () => _getCurrentLocation(context, ref),
            icon: locationState.isGettingLocation
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Icon(Icons.my_location),
            label: Text(
              locationState.isGettingLocation
                  ? 'Getting Location...'
                  : 'Get Current Location',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ✅ Location Tips
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade600, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'For better location accuracy, ensure GPS is enabled and you\'re in an open area.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Accept Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (locationState.currentLocation.isNotEmpty &&
                  locationState.currentLat != null &&
                  locationState.currentLng != null)
                  ? () => applicationActions.acceptApplication(
                context,
                orderId,
                applicationIndex,
                professionalId,
                customerId,
              )
                  : null,
              icon: const Icon(Icons.send, size: 18),
              label: const Text('Accept Application'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BCD4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviousLocationsSection(
      BuildContext context,
      WidgetRef ref,
      List<Map<String, dynamic>> previousLocations,
      LocationState locationState,
      ) {
    if (previousLocations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey.shade600, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No previous locations found. Use current location instead.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.history, color: const Color(0xFF00BCD4), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Select from Previous Locations',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF00838F),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<Map<String, dynamic>>(
              value: locationState.selectedPreviousLocation,
              decoration: InputDecoration(
                hintText: 'Choose a previous location',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: const Color(0xFF00BCD4).withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFF00BCD4), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: previousLocations.map((location) {
                return DropdownMenuItem<Map<String, dynamic>>(
                  value: location,
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      location['address'] ?? 'Unknown location',
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (Map<String, dynamic>? selectedLocation) {
                if (selectedLocation != null) {
                  ref.read(locationStateProvider.notifier).selectPreviousLocation(selectedLocation);
                  _showSnackBar(context, 'Previous location selected!', const Color(0xFF00BCD4));
                }
              },
              isExpanded: true,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildLoadingLocationsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: const Color(0xFF00BCD4),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Loading previous locations...',
            style: TextStyle(color: const Color(0xFF00838F)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorLocationsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Error loading previous locations',
              style: TextStyle(color: Colors.red.shade700, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationDisplay(LocationState locationState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on, color: Colors.green.shade600, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selected Location:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  locationState.currentLocation,
                  style: TextStyle(fontSize: 13, color: Colors.green.shade800),
                ),
                if (locationState.currentLat != null && locationState.currentLng != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Coordinates: ${locationState.currentLat!.toStringAsFixed(6)}, ${locationState.currentLng!.toStringAsFixed(6)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green.shade600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
                if (locationState.selectedPreviousLocation != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Previous Location',
                      style: TextStyle(
                        fontSize: 10,
                        color: const Color(0xFF00838F),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _getCurrentLocation(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(locationStateProvider.notifier).getCurrentLocation();
      if (context.mounted) {
        _showSnackBar(context, 'Location obtained successfully!', Colors.green);
      }
    } catch (e) {
      if (context.mounted) {
        String errorMessage = 'Failed to get location: ';

        if (e.toString().contains('TimeoutException')) {
          errorMessage += 'Location request timed out. Please ensure GPS is enabled and try again in an open area.';
        } else if (e.toString().contains('Location services are disabled')) {
          errorMessage += 'Please enable location services in your device settings.';
        } else if (e.toString().contains('Location permissions')) {
          errorMessage += 'Please allow location access for this app.';
        } else {
          errorMessage += e.toString();
        }

        _showSnackBar(context, errorMessage, Colors.red);
      }
    }
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}