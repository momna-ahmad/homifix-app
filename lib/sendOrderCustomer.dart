import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'landingPage.dart';
import 'HomeNavPage.dart'; // Import for navigation
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart';

class SendOrderCustomer extends StatefulWidget {
  final String customerId;
  final String serviceId;
  final String providerId;
  final String role; // Add role for navigation

  const SendOrderCustomer({
    required this.customerId,
    required this.serviceId,
    required this.providerId,
    required this.role, // Add role parameter
    super.key,
  });

  @override
  State<SendOrderCustomer> createState() => _SendOrderCustomerState();
}

class _SendOrderCustomerState extends State<SendOrderCustomer>
    with SingleTickerProviderStateMixin {
  // Controllers and State Variables
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSubmitting = false;
  bool _isGettingLocation = false;

  // ✅ Location as Map
  Map<String, dynamic> _currentLocationMap = {};

  // Location dropdown variables
  List<Map<String, dynamic>> _previousLocations = [];
  Map<String, dynamic>? _selectedPreviousLocation;
  bool _isLoadingLocations = false;

  // ✅ NEW: Location selection mode
  String _locationSelectionMode = 'none'; // 'none', 'previous', 'current'

  // Animation Controllers
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  // Service Data
  String? _category;
  String? _serviceName;
  String? _providerName;
  String? _servicePrice;
  Map<String, dynamic>? _serviceData;

  // ✅ Real-time listeners
  StreamSubscription<DocumentSnapshot>? _serviceSubscription;
  StreamSubscription<DocumentSnapshot>? _providerSubscription;
  StreamSubscription<QuerySnapshot>? _ordersSubscription;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupRealtimeServiceListener(); // ✅ Use onSnapshot for service data
    _setupRealtimePreviousLocations(); // ✅ Use onSnapshot for previous locations
    _setupRealtimeProviderListener(); // ✅ Use onSnapshot for provider data
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));

    _animationController.forward();
  }

  // ✅ Robust date parsing utility
  DateTime? _parseServiceDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return null;
    }

    try {
      // Try yyyy-MM-dd format first (most common in your logs)
      if (dateString.contains('-') && dateString.length == 10) {
        return DateFormat('yyyy-MM-dd').parse(dateString);
      }

      // Try dd/MM/yyyy format
      if (dateString.contains('/')) {
        if (dateString.split('/')[2].length == 4) {
          return DateFormat('dd/MM/yyyy').parse(dateString);
        } else {
          return DateFormat('dd/MM/yy').parse(dateString);
        }
      }

      // Try MM/dd/yyyy format
      if (dateString.contains('/')) {
        return DateFormat('MM/dd/yyyy').parse(dateString);
      }

      // Try ISO format
      return DateTime.parse(dateString);

    } catch (e) {
      print('❌ Error parsing date "$dateString": $e');
      return null;
    }
  }

  // ✅ Real-time service listener
  void _setupRealtimeServiceListener() {
    print('🔄 Setting up real-time service listener for serviceId: ${widget.serviceId}');

    _serviceSubscription = FirebaseFirestore.instance
        .collection('services')
        .doc(widget.serviceId)
        .snapshots()
        .listen((snapshot) {
      print('📡 Service data update received');

      if (snapshot.exists && mounted) {
        final data = snapshot.data()!;
        setState(() {
          _serviceData = data;
          _category = data['category'];
          _serviceName = data['name'];
          _servicePrice = data['price']?.toString();
        });
        print('✅ Service data updated: $_serviceName, Category: $_category, Price: $_servicePrice');
      }
    }, onError: (error) {
      print('❌ Service listener error: $error');
    });
  }

  // ✅ Real-time provider listener
  void _setupRealtimeProviderListener() {
    print('🔄 Setting up real-time provider listener for providerId: ${widget.providerId}');

    _providerSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.providerId)
        .snapshots()
        .listen((snapshot) {
      print('📡 Provider data update received');

      if (snapshot.exists && mounted) {
        final data = snapshot.data()!;
        setState(() {
          _providerName = data['name'];
        });
        print('✅ Provider data updated: $_providerName');
      }
    }, onError: (error) {
      print('❌ Provider listener error: $error');
    });
  }

  // ✅ COMPLETELY REWRITTEN previous locations listener with bulletproof date parsing
  // ✅ CORRECTED previous locations listener
  void _setupRealtimePreviousLocations() {
    print('🔄 Setting up real-time previous locations listener for customerId: ${widget.customerId}');

    _ordersSubscription = FirebaseFirestore.instance
        .collection('orders')
        .where('customerId', isEqualTo: widget.customerId)
        .snapshots()
        .listen((snapshot) {
      print('📡 Previous locations update - ${snapshot.docs.length} orders');

      if (mounted) {
        Set<String> uniqueAddresses = {};
        List<Map<String, dynamic>> locations = [];

        // ✅ Get today's date for filtering
        final today = DateTime.now();
        final todayStart = DateTime(today.year, today.month, today.day);
        print('Today start: ${todayStart.toString()}');

        // ✅ Process all orders with robust date parsing
        List<Map<String, dynamic>> validOrdersBeforeToday = [];

        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final serviceDateString = data['serviceDate'] as String?;

          print('📋 Processing order ${doc.id}:');
          print('   📅 Service Date String: $serviceDateString');
          print('   📍 Location: ${data['location']}');
          print('   🏷️ Status: ${data['status']}');

          if (serviceDateString == null || serviceDateString.isEmpty) {
            print('⚠️ Order ${doc.id} has no service date');
            continue;
          }

          // ✅ Use the robust date parser
          final serviceDate = _parseServiceDate(serviceDateString);

          if (serviceDate == null) {
            print('❌ Could not parse date for order ${doc.id}: $serviceDateString');
            continue;
          }

          print('   📅 Parsed Date: ${serviceDate.toString()}');
          print('   📅 Is Before Today: ${serviceDate.isBefore(todayStart)}');

          // ✅ FIXED: Only check if customerId matches and has valid location
          if (data['location'] != null) {
            validOrdersBeforeToday.add({
              'id': doc.id,
              'data': data,
              'serviceDate': serviceDate,
              'serviceDateString': serviceDateString,
            });
            print('   ✅ Added to valid orders list');
          } else {
            print('   ❌ Order not included - No valid location data');
          }
        }

        print('=== FILTERED ORDERS SUMMARY ===');
        print('User ID: ${widget.customerId}');
        print('Today: ${todayStart.toString()}');
        print('Found ${validOrdersBeforeToday.length} valid orders');

        // ✅ Extract unique locations from valid orders
        for (int i = 0; i < validOrdersBeforeToday.length; i++) {
          final orderInfo = validOrdersBeforeToday[i];
          final data = orderInfo['data'] as Map<String, dynamic>;

          print('--- Order ${i + 1} ---');
          print('Order ID: ${orderInfo['id']}');
          print('Customer ID: ${data['customerId']}');
          print('Status: ${data['status']}');
          print('Service Date (parsed): ${orderInfo['serviceDate']}');

          // ✅ Extract location information
          if (data['location'] != null && data['location'] is Map<String, dynamic>) {
            final location = data['location'] as Map<String, dynamic>;
            final address = location['address'] as String?;

            print('Location: ${address ?? 'No address'}');

            if (address != null && address.isNotEmpty && !uniqueAddresses.contains(address)) {
              uniqueAddresses.add(address);
              locations.add({
                'address': address,
                'lat': location['lat'],
                'lng': location['lng'],
              });
              print('✅ Added unique location: $address');
            } else if (address != null && uniqueAddresses.contains(address)) {
              print('⚠️ Duplicate location skipped: $address');
            }
          } else {
            print('⚠️ No valid location data');
          }
          print(' ');
        }

        setState(() {
          _previousLocations = locations;
        });

        print('✅ Previous locations updated - ${locations.length} unique locations');
        for (var loc in locations) {
          print('   📍 ${loc['address']}');
        }
      }
    }, onError: (error) {
      print('❌ Previous locations listener error: $error');
    });
  }
  @override
  void dispose() {
    _animationController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();

    // ✅ Cancel all subscriptions
    _serviceSubscription?.cancel();
    _providerSubscription?.cancel();
    _ordersSubscription?.cancel();

    super.dispose();
  }

  // ✅ Improved location acquisition with multiple fallback strategies
  Future<void> _getCurrentLocation() async {
    if (_isGettingLocation) return;

    try {
      print('📍 Starting improved location acquisition...');

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

      setState(() {
        _isGettingLocation = true;
        _selectedPreviousLocation = null; // Clear dropdown selection
        _locationSelectionMode = 'current'; // ✅ Set mode to current
      });

      Position? position;

      try {
        print('📍 Attempting high accuracy location...');
        // First attempt: High accuracy with shorter timeout
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (e) {
        print('⚠️ High accuracy failed, trying medium accuracy: $e');

        try {
          // Second attempt: Medium accuracy with longer timeout
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 15),
          );
        } catch (e) {
          print('⚠️ Medium accuracy failed, trying low accuracy: $e');

          try {
            // Third attempt: Low accuracy with even longer timeout
            position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.low,
              timeLimit: const Duration(seconds: 20),
            );
          } catch (e) {
            print('⚠️ Low accuracy failed, trying last known position: $e');

            // Final fallback: Get last known position
            position = await Geolocator.getLastKnownPosition();
            if (position == null) {
              throw Exception('Unable to get location. Please ensure GPS is enabled and try again in an open area.');
            }
            print('✅ Using last known position as fallback');
          }
        }
      }

      final lat = position.latitude;
      final lng = position.longitude;

      print('✅ Position obtained: $lat, $lng');
      print('🌐 Getting address from LocationIQ API...');

      // Get address using LocationIQ API with timeout
      String address;
      try {
        address = await _getAddressFromLatLng(lat, lng);
      } catch (e) {
        print('⚠️ Address lookup failed, using coordinates: $e');
        address = 'Location: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
      }

      if (mounted) {
        setState(() {
          _currentLocationMap = {
            'address': address,
            'lat': lat,
            'lng': lng,
          };
          _isGettingLocation = false;
        });

        _showSnackBar('Current location obtained successfully!', Colors.green);
        print('✅ Current location obtained: $address');
        print('📊 Location data - Lat: $lat, Lng: $lng');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGettingLocation = false;
          _locationSelectionMode = 'none'; // ✅ Reset mode on error
        });

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

        _showSnackBar(errorMessage, Colors.red);
        print('❌ Error getting current location: $e');
      }
    }
  }

  // ✅ Get address from coordinates using LocationIQ API
  Future<String> _getAddressFromLatLng(double lat, double lng) async {
    const apiKey = 'pk.c6205b1882bfb7c832c4fea13d2fc5b4';
    final url = Uri.parse(
      'https://us1.locationiq.com/v1/reverse?key=$apiKey&lat=$lat&lon=$lng&format=json',
    );

    try {
      print('🌐 Making LocationIQ API request for coordinates: $lat, $lng');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['display_name'] ?? 'Unknown location';
        print('✅ LocationIQ API response: $address');
        return address;
      } else {
        print('❌ LocationIQ API error: ${response.statusCode}');
        throw Exception('Failed to get address: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error getting address from LocationIQ: $e');
      return 'Location: $lat, $lng';
    }
  }

  // ✅ NEW: Select previous location function
  void _selectPreviousLocation(Map<String, dynamic> location) {
    setState(() {
      _selectedPreviousLocation = location;
      _currentLocationMap = {
        'address': location['address'],
        'lat': location['lat'],
        'lng': location['lng'],
      };
      _locationSelectionMode = 'previous'; // ✅ Set mode to previous
    });

    _showSnackBar('Previous location selected!', const Color(0xFF0EA5E9));
    print('✅ Previous location selected: ${location['address']}');
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0EA5E9),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0EA5E9),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _sendCustomerOrder() async {
    // Enhanced price validation
    final priceText = _priceController.text.trim();
    if (priceText.isEmpty) {
      _showSnackBar('Please enter a price', Colors.red);
      return;
    }

    final price = double.tryParse(priceText);
    if (price == null) {
      _showSnackBar('Please enter a valid number', Colors.red);
      return;
    }

    if (price <= 0) {
      _showSnackBar('Price must be greater than 0', Colors.red);
      return;
    }

    if (price < 1) {
      _showSnackBar('Minimum price is Rs. 1', Colors.red);
      return;
    }

    if (_selectedDate == null) {
      _showSnackBar('Please select a date', Colors.red);
      return;
    }

    if (_selectedTime == null) {
      _showSnackBar('Please select a time', Colors.red);
      return;
    }

    if (_currentLocationMap.isEmpty) {
      _showSnackBar('Please select a location', Colors.red);
      return;
    }

    if (_descriptionController.text.isEmpty) {
      _showSnackBar('Please enter additional details', Colors.red);
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      print('📤 Sending customer order...');
      print('   🆔 Customer ID: ${widget.customerId}');
      print('   🔧 Service ID: ${widget.serviceId}');
      print('   👨‍💼 Provider ID: ${widget.providerId}');
      print('   💰 Price: ${_priceController.text}');
      print('   📅 Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate!)}');
      print('   ⏰ Time: ${_selectedTime!.format(context)}');
      print('   📍 Location: ${_currentLocationMap['address']}');
      print('   🌐 Coordinates: ${_currentLocationMap['lat']}, ${_currentLocationMap['lng']}');

      DocumentSnapshot serviceDoc = await FirebaseFirestore.instance
          .collection('services')
          .doc(widget.serviceId)
          .get();

      String serviceName = serviceDoc.exists ? serviceDoc['service'] : 'Unknown Service';

      // ✅ Create order document with location as Map
      final orderDocRef=await FirebaseFirestore.instance.collection('orders').add({
        'customerId': widget.customerId,
        'service': serviceName ?? 'Unknown Service',
        'category': _category ?? 'Unknown Category',
        'priceOffer': _priceController.text,
        'description': _descriptionController.text,
        'serviceDate': DateFormat('yyyy-MM-dd').format(_selectedDate!),
        'serviceTime': _selectedTime!.format(context),
        'location': _currentLocationMap,
        'status': 'assigned',
        'orderType': 'customer_request',
        'createdAt': FieldValue.serverTimestamp(),
        'applications': [],
        'selectedWorkerId': widget.providerId,
      });
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.providerId)
          .update({
        'orders': FieldValue.arrayUnion([
          {
            'completionStatus': 'pending',
            'date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
            'location': {
              'address': _currentLocationMap['address'],
              'lat': _currentLocationMap['lat'],
              'lng': _currentLocationMap['lng'],
            },
            'orderId': orderDocRef.id,
            'price': _priceController.text,
            'service': serviceName ?? 'Unknown Service',
            'time': _selectedTime!.format(context),
          }
        ])
      });

      print('✅ Order added to provider\'s orders array');

      if (mounted) {
        _showSnackBar('Order sent successfully!', Colors.green);

        // Navigate back to home
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => HomeNavPage(
              userId: widget.customerId,
              role: widget.role,
            ),
          ),
              (route) => false,
        );
      }

      print('✅ Order sent successfully');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        _showSnackBar('Failed to send order: $e', Colors.red);
      }
      print('❌ Error sending order: $e');
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: color == Colors.red ? 4 : 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F9FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        title: Text(
          'Send Order Request',
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildServiceInfoCard(),
                const SizedBox(height: 12),
                _buildPriceInput(),
                const SizedBox(height: 12),
                _buildDescriptionInput(),
                const SizedBox(height: 12),
                _buildDateTimeSelection(),
                const SizedBox(height: 12),
                _buildLocationSelection(), // ✅ This is where the new logic is placed
                const SizedBox(height: 20),
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceInfoCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF0EA5E9), const Color(0xFF22D3EE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Service Request',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          if (_serviceName != null) ...[
            _buildServiceInfoRow(Icons.build, 'Service', _serviceName!),
            const SizedBox(height: 6),
          ],
          if (_category != null) ...[
            _buildServiceInfoRow(Icons.category, 'Category', _category!),
            const SizedBox(height: 6),
          ],
          if (_providerName != null) ...[
            _buildServiceInfoRow(Icons.person, 'Provider', _providerName!),
            const SizedBox(height: 6),
          ],
          if (_servicePrice != null)
            _buildServiceInfoRow(Icons.attach_money, 'Base Price', 'Rs. $_servicePrice'),
        ],
      ),
    );
  }

  Widget _buildServiceInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceInput() {
    return Container(
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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Price Offer',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Enter your price offer (minimum Rs. 1)',
              prefixIcon: const Icon(Icons.currency_rupee, color: Color(0xFF0EA5E9)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: const Color(0xFF0EA5E9).withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 2),
              ),
              filled: true,
              fillColor: const Color(0xFFF0F9FF),
            ),
            onChanged: (value) {
              if (value.isNotEmpty) {
                final price = double.tryParse(value);
                if (price != null && price <= 0) {
                  _priceController.text = '';
                  _priceController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _priceController.text.length),
                  );
                  _showSnackBar('Price must be greater than 0', Colors.orange);
                }
              }
            },
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^[1-9]\d*\.?\d*$')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionInput() {
    return Container(
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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Additional Details',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Add any specific requirements or details...',
              prefixIcon: const Icon(Icons.description, color: Color(0xFF0EA5E9)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: const Color(0xFF0EA5E9).withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 2),
              ),
              filled: true,
              fillColor: const Color(0xFFF0F9FF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeSelection() {
    return Container(
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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Service Schedule',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _selectDate,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF0EA5E9).withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today, color: Color(0xFF0EA5E9), size: 18),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _selectedDate != null
                                ? DateFormat('MMM dd, yyyy').format(_selectedDate!)
                                : 'Select Date',
                            style: TextStyle(
                              color: _selectedDate != null ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: _selectTime,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF0EA5E9).withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time, color: Color(0xFF0EA5E9), size: 18),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _selectedTime != null
                                ? _selectedTime!.format(context)
                                : 'Select Time',
                            style: TextStyle(
                              color: _selectedTime != null ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ✅ COMPLETELY REWRITTEN _buildLocationSelection with proper logic
  Widget _buildLocationSelection() {
    return Container(
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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Service Location',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),

          // ✅ Show previous locations dropdown ONLY if there are previous locations
          if (_previousLocations.isNotEmpty) ...[
            Text(
              'Select from Previous Locations',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedPreviousLocation != null
                  ? _selectedPreviousLocation!['address']
                  : null,
              decoration: InputDecoration(
                hintText: 'Choose a previous location',
                prefixIcon: const Icon(Icons.history, color: Color(0xFF0EA5E9), size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: const Color(0xFF0EA5E9).withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 2),
                ),
                filled: true,
                fillColor: const Color(0xFFF0F9FF),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              items: _previousLocations.map((location) {
                return DropdownMenuItem<String>(
                  value: location['address'],
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      location['address'] ?? 'Unknown location',
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? selectedAddress) {
                if (selectedAddress != null) {
                  final selectedLocation = _previousLocations.firstWhere(
                        (location) => location['address'] == selectedAddress,
                  );
                  _selectPreviousLocation(selectedLocation);
                }
              },
              isExpanded: true,
              isDense: false,
            ),
            const SizedBox(height: 12),

            // ✅ OR divider
            Row(
              children: [
                Expanded(child: Divider(color: const Color(0xFF64748B).withOpacity(0.3))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: const Color(0xFF64748B).withOpacity(0.3))),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // ✅ Get Current Location Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isGettingLocation ? null : _getCurrentLocation,
              icon: _isGettingLocation
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.my_location, size: 18),
              label: Text(
                _isGettingLocation ? 'Getting Location...' : 'Get Current Location',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ✅ Selected Location Display (shows for BOTH previous and current)
          if (_currentLocationMap.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _locationSelectionMode == 'previous'
                    ? const Color(0xFF0EA5E9).withOpacity(0.1)
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _locationSelectionMode == 'previous'
                      ? const Color(0xFF0EA5E9).withOpacity(0.3)
                      : Colors.green.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _locationSelectionMode == 'previous' ? Icons.history : Icons.location_on,
                    color: _locationSelectionMode == 'previous'
                        ? const Color(0xFF0EA5E9)
                        : Colors.green.shade600,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _locationSelectionMode == 'previous'
                              ? 'Selected Previous Location:'
                              : 'Current Location:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _locationSelectionMode == 'previous'
                                ? const Color(0xFF0EA5E9)
                                : Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentLocationMap['address'] ?? 'Unknown location',
                          style: TextStyle(
                            fontSize: 13,
                            color: _locationSelectionMode == 'previous'
                                ? const Color(0xFF1E293B)
                                : Colors.green.shade800,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_currentLocationMap['lat'] != null && _currentLocationMap['lng'] != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Coordinates: ${_currentLocationMap['lat'].toStringAsFixed(6)}, ${_currentLocationMap['lng'].toStringAsFixed(6)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: _locationSelectionMode == 'previous'
                                  ? const Color(0xFF64748B)
                                  : Colors.green.shade600,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ✅ Info container
          Container(
            padding: const EdgeInsets.all(10),
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
                    _previousLocations.isNotEmpty
                        ? 'Choose from your previous locations or get your current location for better accuracy.'
                        : 'For better location accuracy, ensure GPS is enabled and you\'re in an open area.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _sendCustomerOrder,
        icon: _isSubmitting
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
            : const Icon(Icons.send, size: 20),
        label: Text(
          _isSubmitting ? 'Sending Order...' : 'Send Order Request',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0EA5E9),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
        ),
      ),
    );
  }
}
