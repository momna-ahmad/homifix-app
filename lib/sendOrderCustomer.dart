import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'CustomerOrderPage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


class SendOrderCustomer extends StatefulWidget {
  final String userId;
  final String serviceId;

  const SendOrderCustomer({required this.userId, required this.serviceId, super.key});

  @override
  State<SendOrderCustomer> createState() => _SendOrderCustomerState();
}

class _SendOrderCustomerState extends State<SendOrderCustomer> with SingleTickerProviderStateMixin {
  final _priceController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSubmitting = false;

  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  String? _category;
  String? _serviceName;
  String? _providerId;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation =
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
            .animate(CurvedAnimation(
            parent: _animationController, curve: Curves.easeOut));
    _animationController.forward();

    _loadServiceData();
  }

  Future<String> _getAddressFromLatLng(double lat, double lng) async {
    const apiKey = 'pk.c6205b1882bfb7c832c4fea13d2fc5b4';
    final url = Uri.parse(
      'https://us1.locationiq.com/v1/reverse?key=$apiKey&lat=$lat&lon=$lng&format=json',
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['display_name'] ?? 'Unknown location';
    } else {
      throw Exception('Failed to reverse geocode location');
    }
  }


  Future<void> _sendCurrentLocationOnly() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services are disabled.');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final lat = position.latitude;
      final lng = position.longitude;
      final address = await _getAddressFromLatLng(lat, lng);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location captured:\n$address')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get location: $e')),
      );
    }
  }



  Future<void> _submitOrder() async {
    if (_category == null ||
        _serviceName == null ||
        _priceController.text.trim().isEmpty ||
        _selectedDate == null ||
        _selectedTime == null ||
        _providerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userId = widget.userId;
      final serviceId = widget.serviceId;

      // === 1. Get current location ===
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services are disabled.');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final lat = position.latitude;
      final lng = position.longitude;
      final address = await _getAddressFromLatLng(lat, lng);

      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      final formattedTime = _selectedTime!.format(context);

      // === 2. Create order object for array ===
      final orderForUserArray = {
        'orderId': '', // will be filled after doc is created
        'serviceId': serviceId,
        'price': _priceController.text.trim(),
        'selectedWorkerId': _providerId,
        'category': _category ?? '',
        'customerId': userId,
        'location': {
          'lat': lat,
          'lng': lng,
          'address': address,
        },
        'service': _serviceName ?? '',
        'date': formattedDate,
        'time': formattedTime,
      };

      // === 3. Create Firestore order doc ===
      final orderRef = FirebaseFirestore.instance.collection('orders').doc();
      final orderId = orderRef.id;

      await orderRef.set({
        ...orderForUserArray,
        'orderId': orderId,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'assigned',
      });

      // === 4. Push this order into user's "orders" array ===
      final userDocRef =
      FirebaseFirestore.instance.collection('users').doc(userId);

      await userDocRef.update({
        'orders': FieldValue.arrayUnion([
          {
            ...orderForUserArray,
            'orderId': orderId,
          }
        ])
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order submitted successfully')),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CustomerOrdersPage(userId: userId),
          ),
        );
      }
    } catch (e) {
      print('Error submitting order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }



  Future<void> _loadServiceData() async {
    final serviceSnap = await FirebaseFirestore.instance.collection('services')
        .doc(widget.serviceId)
        .get();
    if (serviceSnap.exists) {
      final data = serviceSnap.data()!;
      setState(() {
        _category = data['category'];
        _serviceName = data['service'];
        _providerId = data['userId'];
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Service not found")));
      Navigator.pop(context);
    }
  }

  Widget _buildInfoTile(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.info_outline, color: Colors.blue.shade600),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(fontSize: 15, color: Colors.black87),
        ),
      ),
    );
  }

  Widget _buildColoredTextField(TextEditingController controller,
      String label,
      IconData icon,
      Color iconColor,
      TextInputType keyboardType,) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: iconColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        filled: true,
        fillColor: Colors.lightBlue.shade50.withOpacity(0.6),
      ),
    );
  }


  Widget _buildDateTimeTile(String title, String subtitle, IconData icon,
      Color iconColor, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
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
            BoxShadow(color: iconColor.withOpacity(0.4),
                blurRadius: 5,
                offset: const Offset(1, 2)),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      subtitle: Text(subtitle,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
      trailing: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: iconColor,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
        child: const Text("Pick"),
      ),
    );
  }


  @override
  void dispose() {
    _priceController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_category == null || _serviceName == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Stack(
      children: [
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(color: Colors.black.withOpacity(0.5)),
        ),
        SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: DraggableScrollableSheet(
                initialChildSize: 0.8,
                minChildSize: 0.6,
                maxChildSize: 0.95,
                builder: (_, controller) =>
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.lightBlue.shade200.withOpacity(0.5),
                            blurRadius: 15,
                            offset: const Offset(0, -5),
                          ),
                        ],
                      ),
                      child: ListView(
                        controller: controller,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.lightBlue.shade300,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          Text(
                            "Send Order",
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.lightBlue.shade800,
                              letterSpacing: 1.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          _buildInfoTile("Category", _category!),
                          _buildInfoTile("Service", _serviceName!),
                          const SizedBox(height: 16),
                          _buildColoredTextField(
                              _priceController, 'Your Price Offer',
                              Icons.attach_money, Colors.amber.shade700,
                              TextInputType.number),
                          const SizedBox(height: 20),
                          _buildDateTimeTile(
                              'Service Date',
                              _selectedDate == null
                                  ? 'No date chosen'
                                  : DateFormat('EEE, MMM d, yyyy').format(
                                  _selectedDate!),
                              Icons.calendar_today,
                              Colors.lightBlue.shade600,
                                  () => _pickDate(context)),
                          const SizedBox(height: 10),
                          _buildDateTimeTile(
                              'Service Time',
                              _selectedTime == null
                                  ? 'No time chosen'
                                  : _selectedTime!.format(context),
                              Icons.access_time,
                              Colors.lightBlue.shade600,
                                  () => _pickTime(context)),
                          const SizedBox(height: 20),

                          /// === 🔘 Send Location Button ===
                          ElevatedButton.icon(
                            onPressed: _isSubmitting ? null : _sendCurrentLocationOnly,
                            icon: const Icon(Icons.my_location),
                            label: const Text('Send Current Location'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),

                          const SizedBox(height: 8),


                          const SizedBox(height: 30),

                          /// === ✅ Submit Order Button ===
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.check_circle_outline),
                              label: _isSubmitting
                                  ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                                  : const Text('Submit Order'),
                              onPressed: _isSubmitting ? null : _submitOrder,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.lightBlue.shade700,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 18),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                textStyle: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                                elevation: 10,
                                shadowColor: Colors.lightBlue.shade300,
                              ),
                            ),
                          ),

                          // Optional: Keep or remove this based on your use case
                          // ElevatedButton(
                          //   onPressed: _showLocationDialog,
                          //   child: const Text('Accept Application'),
                          //   style: ElevatedButton.styleFrom(
                          //     backgroundColor: theme.colorScheme.primary,
                          //     foregroundColor: theme.colorScheme.onPrimary,
                          //   ),
                          // ),
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


