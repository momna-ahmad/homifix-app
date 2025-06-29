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
  String _currentLocation = '';
  double? _currentLat;
  double? _currentLng;

  // Location dropdown variables
  List<Map<String, dynamic>> _previousLocations = [];
  Map<String, dynamic>? _selectedPreviousLocation;
  bool _isLoadingLocations = false;

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
    _setupRealtimePreviousLocationsListener(); // ✅ Use onSnapshot for orders

    print('🔧 SendOrderCustomer initialized:');
    print('   👤 Customer ID: ${widget.customerId}');
    print('   🏷️ Service ID: ${widget.serviceId}');
    print('   👨‍💼 Provider ID: ${widget.providerId}');
    print('   🎭 Role: ${widget.role}');
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  // ✅ REAL-TIME: Setup service data listener using onSnapshot
  void _setupRealtimeServiceListener() {
    print('🔄 SETTING UP REAL-TIME SERVICE LISTENER');

    _serviceSubscription = FirebaseFirestore.instance
        .collection('services')
        .doc(widget.serviceId)
        .snapshots()
        .listen(
          (DocumentSnapshot serviceSnap) {
        print('📡 REAL-TIME SERVICE UPDATE RECEIVED');

        if (serviceSnap.exists) {
          final data = serviceSnap.data() as Map<String, dynamic>;

          // Setup provider listener
          _setupRealtimeProviderListener();

          if (mounted) {
            setState(() {
              _serviceData = data;
              _category = data['category'];
              _serviceName = data['service'];
              _servicePrice = data['price']?.toString() ?? 'Not specified';
            });
          }

          print('✅ REAL-TIME Service data updated:');
          print('   📂 Category: $_category');
          print('   🏷️ Service: $_serviceName');
          print('   💰 Price: $_servicePrice');
        } else {
          _showErrorAndExit("Service not found");
        }
      },
      onError: (error) {
        print('❌ REAL-TIME SERVICE ERROR: $error');
        _showErrorAndExit("Error loading service data: $error");
      },
    );
  }

  // ✅ REAL-TIME: Setup provider data listener using onSnapshot
  void _setupRealtimeProviderListener() {
    print('🔄 SETTING UP REAL-TIME PROVIDER LISTENER');

    _providerSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.providerId)
        .snapshots()
        .listen(
          (DocumentSnapshot providerSnap) {
        print('📡 REAL-TIME PROVIDER UPDATE RECEIVED');

        if (providerSnap.exists && mounted) {
          final providerData = providerSnap.data() as Map<String, dynamic>;
          setState(() {
            _providerName = providerData['name'] ?? 'Unknown Provider';
          });

          print('✅ REAL-TIME Provider data updated:');
          print('   👨‍💼 Provider: $_providerName');
        }
      },
      onError: (error) {
        print('❌ REAL-TIME PROVIDER ERROR: $error');
      },
    );
  }

  // ✅ REAL-TIME: Load previous locations using onSnapshot
  void _setupRealtimePreviousLocationsListener() {
    setState(() => _isLoadingLocations = true);

    print('🔄 SETTING UP REAL-TIME PREVIOUS LOCATIONS LISTENER');

    _ordersSubscription = FirebaseFirestore.instance
        .collection('orders')
        .where('customerId', isEqualTo: widget.customerId)
        .snapshots()
        .listen(
          (QuerySnapshot ordersSnapshot) {
        print('📡 REAL-TIME ORDERS UPDATE RECEIVED');
        print('📊 Orders count: ${ordersSnapshot.docs.length}');

        Set<String> uniqueAddresses = {};
        List<Map<String, dynamic>> locations = [];

        for (var doc in ordersSnapshot.docs) {
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

        if (mounted) {
          setState(() {
            _previousLocations = locations;
            _isLoadingLocations = false;
          });
        }

        print('✅ REAL-TIME Previous locations updated: ${locations.length} locations');
      },
      onError: (error) {
        print('❌ REAL-TIME ORDERS ERROR: $error');
        if (mounted) {
          setState(() => _isLoadingLocations = false);
        }
      },
    );
  }

  void _showErrorAndExit(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
    Navigator.pop(context);
  }

  // Get address from coordinates using LocationIQ API
  Future<String> _getAddressFromLatLng(double lat, double lng) async {
    const apiKey = 'pk.c6205b1882bfb7c832c4fea13d2fc5b4';
    final url = Uri.parse(
      'https://us1.locationiq.com/v1/reverse?key=$apiKey&lat=$lat&lon=$lng&format=json',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['display_name'] ?? 'Unknown location';
      } else {
        throw Exception('Failed to get address: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting address: $e');
      return 'Location: $lat, $lng';
    }
  }

  // Get current location
  Future<void> _getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled. Please enable them.');
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permissions are permanently denied. Please enable them in settings.',
        );
      }

      // Show loading indicator for location only
      setState(() => _isGettingLocation = true);

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final lat = position.latitude;
      final lng = position.longitude;
      final address = await _getAddressFromLatLng(lat, lng);

      setState(() {
        _currentLat = lat;
        _currentLng = lng;
        _currentLocation = address;
        _selectedPreviousLocation = null; // Clear dropdown selection
        _isGettingLocation = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location obtained successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isGettingLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to get location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Handle previous location selection
  void _selectPreviousLocation(Map<String, dynamic> location) {
    setState(() {
      _selectedPreviousLocation = location;
      _currentLocation = location['address'];
      _currentLat = location['lat']?.toDouble();
      _currentLng = location['lng']?.toDouble();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Previous location selected!'),
        backgroundColor: Color(0xFF00BCD4),
      ),
    );
  }

  // Validate form data
  bool _validateForm() {
    if (_category == null || _serviceName == null) {
      _showSnackBar('Service data not loaded properly', Colors.red);
      return false;
    }

    if (_priceController.text.trim().isEmpty) {
      _showSnackBar('Please enter your price offer', Colors.red);
      return false;
    }

    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price <= 0) {
      _showSnackBar('Please enter a valid price', Colors.red);
      return false;
    }

    if (_selectedDate == null) {
      _showSnackBar('Please select a service date', Colors.red);
      return false;
    }

    if (_selectedTime == null) {
      _showSnackBar('Please select a service time', Colors.red);
      return false;
    }

    if (_currentLocation.isEmpty || _currentLat == null || _currentLng == null) {
      _showSnackBar(
        'Please select a location or get your current location',
        Colors.red,
      );
      return false;
    }

    // Check if selected date is not in the past
    final selectedDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    if (selectedDateTime.isBefore(DateTime.now())) {
      _showSnackBar('Please select a future date and time', Colors.red);
      return false;
    }

    return true;
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  // ✅ Submit order and add to professional's orders array
  Future<void> _submitOrder() async {
    if (!_validateForm()) return;

    setState(() => _isSubmitting = true);

    try {
      final customerId = widget.customerId;
      final serviceId = widget.serviceId;
      final providerId = widget.providerId;
      final orderId = FirebaseFirestore.instance.collection('orders').doc().id;

      // Format date and time
      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      final formattedTime = _selectedTime!.format(context);
      final formattedDateTime = DateFormat('yyyy-MM-dd HH:mm').format(
        DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        ),
      );

      // Create order data
      final orderData = {
        'orderId': orderId,
        'customerId': customerId,
        'serviceId': serviceId,
        'providerId': providerId,
        'selectedWorkerId': providerId,
        'category': _category!,
        'service': _serviceName!,
        'price': _servicePrice!,
        'providerName': _providerName ?? 'Unknown Provider',
        'priceOffer': _priceController.text.trim(),
        'serviceDate': formattedDate,
        'serviceTime': formattedTime,
        'serviceDateTime': formattedDateTime,
        'location': {
          'lat': _currentLat!,
          'lng': _currentLng!,
          'address': _currentLocation,
        },
        'description': _descriptionController.text.trim(),
        'status': 'assigned',
        'orderType': 'customer_application',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // ✅ Professional's order data for orders array
      final professionalOrderData = {
        'completionStatus': 'pending', // 1. completionStatus
        'date': formattedDate, // 2. date
        'location': [ // 3. location as array
          _currentLocation, // address
          _currentLat!, // lat
          _currentLng!, // lng
        ],
        'orderId': orderId, // 4. orderId
        'price': _priceController.text.trim(), // 5. price (customer's offer)
        'service': _serviceName!, // 6. service
        'time': formattedTime, // 7. time
      };

      // Use batch write for atomic operations
      final batch = FirebaseFirestore.instance.batch();

      // 1. Add order to orders collection
      final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);
      batch.set(orderRef, orderData);

      // 2. Add order to professional's orders array
      final professionalRef = FirebaseFirestore.instance.collection('users').doc(providerId);
      batch.update(professionalRef, {
        'orders': FieldValue.arrayUnion([professionalOrderData])
      });

      // Execute batch
      await batch.commit();

      print('✅ Order created and added to professional successfully!');
      print('📋 Order Details:');
      print('   🆔 Order ID: $orderId');
      print('   👤 Customer ID: $customerId');
      print('   👨‍💼 Provider ID: $providerId');
      print('   🏷️ Service ID: $serviceId');
      print('   📊 Status: assigned');
      print('   📝 Order Type: customer_application');
      print('   💰 Service Price: $_servicePrice');
      print('   💰 Price Offer: ${_priceController.text.trim()}');
      print('   📅 Service Date: $formattedDate');
      print('   ⏰ Service Time: $formattedTime');
      print('   📍 Location: $_currentLocation');
      print('   📝 Description: ${_descriptionController.text.trim()}');
      print('');
      print('✅ Professional Order Data Added:');
      print('   📊 Completion Status: pending');
      print('   📅 Date: $formattedDate');
      print('   📍 Location Array: [$_currentLocation, $_currentLat, $_currentLng]');
      print('   🆔 Order ID: $orderId');
      print('   💰 Price: ${_priceController.text.trim()}');
      print('   🏷️ Service: $_serviceName');
      print('   ⏰ Time: $formattedTime');

      // Show success message
      if (mounted) {
        _showSnackBar('Order submitted successfully!', Colors.green);

        // Navigate to HomeNavPage
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeNavPage(userId: widget.customerId, role: widget.role),
          ),
        );
      }
    } catch (e) {
      print('❌ Error submitting order: $e');
      if (mounted) {
        _showSnackBar('Failed to submit order: $e', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // Date picker
  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 1),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF00BCD4)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  // Time picker
  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF00BCD4)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  // UI Helper Methods
  Widget _buildInfoTile(String title, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF00BCD4), size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontSize: 16, color: Colors.black),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller,
      String label,
      IconData icon,
      Color iconColor, {
        TextInputType keyboardType = TextInputType.text,
        String? prefix,
        int maxLines = 1,
      }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefix,
        prefixStyle: TextStyle(
          color: iconColor,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
        prefixIcon: Icon(icon, color: iconColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: iconColor, width: 2),
        ),
        filled: true,
        fillColor: const Color(0xFFE3F2FD).withOpacity(0.6),
      ),
    );
  }

  Widget _buildDateTimeTile(
      String title,
      String subtitle,
      IconData icon,
      Color iconColor,
      VoidCallback onTap,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00BCD4).withOpacity(0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [iconColor.withOpacity(0.7), iconColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: iconColor.withOpacity(0.4),
                blurRadius: 5,
                offset: const Offset(1, 2),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
        ),
        trailing: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: iconColor,
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
          child: const Text("Select"),
        ),
      ),
    );
  }

  // Previous locations dropdown
  Widget _buildPreviousLocationsDropdown() {
    if (_isLoadingLocations) {
      return Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 16),
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

    if (_previousLocations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 16),
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
      margin: const EdgeInsets.only(bottom: 16),
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
              value: _selectedPreviousLocation,
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
              items: _previousLocations.map((location) {
                return DropdownMenuItem<Map<String, dynamic>>(
                  value: location,
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      location['address'],
                      style: const TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  _selectPreviousLocation(value);
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

  Widget _buildLocationDisplay() {
    if (_currentLocation.isEmpty) {
      return const SizedBox.shrink();
    }

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
                  'Selected Service Location:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentLocation,
                  style: TextStyle(fontSize: 13, color: Colors.green.shade800),
                ),
                if (_currentLat != null && _currentLng != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Coordinates: ${_currentLat!.toStringAsFixed(6)}, ${_currentLng!.toStringAsFixed(6)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green.shade600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
                if (_selectedPreviousLocation != null) ...[
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

  @override
  void dispose() {
    _priceController.dispose();
    _descriptionController.dispose();
    _animationController.dispose();

    // ✅ Dispose real-time listeners
    _serviceSubscription?.cancel();
    _providerSubscription?.cancel();
    _ordersSubscription?.cancel();

    print('🔄 DISPOSING ALL REAL-TIME LISTENERS');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Show loading while service data is being loaded
    if (_category == null || _serviceName == null || _servicePrice == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFE3F2FD),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: const Color(0xFF00BCD4),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading service details...',
                style: TextStyle(
                  color: const Color(0xFF00838F),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        // Background blur effect
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(color: Colors.black.withOpacity(0.5)),
        ),

        // Main content
        SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: DraggableScrollableSheet(
                initialChildSize: 0.85,
                minChildSize: 0.7,
                maxChildSize: 0.95,
                builder: (_, controller) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00BCD4).withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: ListView(
                    controller: controller,
                    physics: const BouncingScrollPhysics(),
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
                      Text(
                        "Apply for Service",
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF00838F),
                          letterSpacing: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // Service Information
                      _buildInfoTile(
                        "Category",
                        _category!,
                        Icons.category,
                      ),
                      _buildInfoTile(
                        "Service",
                        _serviceName!,
                        Icons.home_repair_service,
                      ),
                      _buildInfoTile(
                        "Service Price",
                        "Rs. $_servicePrice",
                        Icons.monetization_on,
                      ),
                      if (_providerName != null)
                        _buildInfoTile(
                          "Provider",
                          _providerName!,
                          Icons.person,
                        ),

                      const SizedBox(height: 20),

                      // Price Offer
                      _buildTextField(
                        _priceController,
                        'Your Price Offer',
                        Icons.currency_rupee,
                        Colors.amber.shade700,
                        keyboardType: TextInputType.number,
                        prefix: 'Rs. ',
                      ),
                      const SizedBox(height: 20),

                      // Description
                      _buildTextField(
                        _descriptionController,
                        'Description',
                        Icons.description,
                        Colors.grey.shade600,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 20),

                      // Date Selection
                      _buildDateTimeTile(
                        'Service Date',
                        _selectedDate == null
                            ? 'No date selected'
                            : DateFormat('EEE, MMM d, yyyy').format(_selectedDate!),
                        Icons.calendar_today,
                        const Color(0xFF00BCD4),
                            () => _pickDate(context),
                      ),

                      // Time Selection
                      _buildDateTimeTile(
                        'Service Time',
                        _selectedTime == null
                            ? 'No time selected'
                            : _selectedTime!.format(context),
                        Icons.access_time,
                        const Color(0xFF00BCD4),
                            () => _pickTime(context),
                      ),

                      // Previous Locations Dropdown
                      _buildPreviousLocationsDropdown(),

                      // OR Divider
                      if (_previousLocations.isNotEmpty) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Divider(color: Colors.grey.shade300),
                            ),
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
                            Expanded(
                              child: Divider(color: Colors.grey.shade300),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Location Display
                      _buildLocationDisplay(),

                      // Get Location Button
                      ElevatedButton.icon(
                        onPressed: (_isGettingLocation || _isSubmitting)
                            ? null
                            : _getCurrentLocation,
                        icon: _isGettingLocation
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
                          _isGettingLocation
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
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: _isSubmitting
                              ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : const Icon(Icons.send),
                          label: Text(
                            _isSubmitting
                                ? 'Submitting Order...'
                                : 'Submit Order',
                          ),
                          onPressed: (_isSubmitting || _isGettingLocation)
                              ? null
                              : _submitOrder,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00BCD4),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            elevation: 10,
                            shadowColor: const Color(0xFF00BCD4).withOpacity(0.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
