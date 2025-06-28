import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'CustomerOrderPage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import '../shared/categories.dart'; // Import the new category structure
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

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

Widget _buildColoredIconTextField(TextEditingController? controller, String label, IconData icon, Color iconColor, ValueChanged<String>? onChanged, [TextInputType? type]) {
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

class AddOrderPage extends StatefulWidget {
  final String userId;
  const AddOrderPage({required this.userId, super.key});

  @override
  State<AddOrderPage> createState() => _AddOrderPageState();
}

class _AddOrderPageState extends State<AddOrderPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        centerTitle: true,
        backgroundColor: Colors.lightBlue.shade700,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            'Add new orders using the + button.',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class OrderForm extends StatefulWidget {
  final String userId;
  const OrderForm({required this.userId});

  @override
  State<OrderForm> createState() => OrderFormState();
}

class OrderFormState extends State<OrderForm> with SingleTickerProviderStateMixin {
  final _categoryController = TextEditingController();
  final _serviceController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSubmitting = false;
  gmaps.LatLng? _selectedLatLng;
  String _selectedAddress = '';

  String? _selectedCategory;
  String? _selectedService;

  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
    _animationController.forward();
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _serviceController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.lightBlue.shade600,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.lightBlue.shade600,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  // Validate form data
  bool _validateForm() {
    if (_selectedCategory == null) {
      _showSnackBar('Please select a category', Colors.red);
      return false;
    }

    if (_selectedService == null || _selectedService!.isEmpty) {
      _showSnackBar('Please select or enter a service', Colors.red);
      return false;
    }

    if (_selectedAddress.isEmpty || _selectedLatLng == null) {
      _showSnackBar('Please select a location', Colors.red);
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
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  void _submitOrder() async {
    if (!_validateForm()) return;

    setState(() => _isSubmitting = true);

    try {
      // Generate order ID
      final orderRef = FirebaseFirestore.instance.collection('orders').doc();
      final orderId = orderRef.id;

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

      // Create order data with customer_post orderType
      final orderData = {
        'orderId': orderId,
        'customerId': widget.userId,
        'category': _selectedCategory!,
        'service': _selectedService!,
        'location': {
          'lat': _selectedLatLng!.latitude,
          'lng': _selectedLatLng!.longitude,
          'address': _selectedAddress,
        },
        'priceOffer': _priceController.text.trim(),
        'serviceDate': formattedDate,
        'serviceTime': formattedTime,
        'serviceDateTime': formattedDateTime,
        'description': _descriptionController.text.trim(),
        'applications': [], // Array for provider applications
        'selectedWorkerId': null, // No worker selected initially
        'status': 'waiting', // Waiting for provider applications
        'orderType': 'customer_post', // ✅ Added orderType for customer job posts
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Save order to Firestore
      await orderRef.set(orderData);

      // Log success
      print('✅ Customer job post created successfully!');
      print('Order ID: $orderId');
      print('Customer ID: ${widget.userId}');
      print('Status: waiting');
      print('Order Type: customer_post');
      print('Order Data: $orderData');

      // Show success message
      if (mounted) {
        _showSnackBar('Job post created successfully!', Colors.green);

        // Navigate to customer orders page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CustomerOrderPage(userId: widget.userId),
          ),
        );
      }

    } catch (e) {
      print('❌ Error creating job post: $e');
      if (mounted) {
        _showSnackBar('Failed to create job post: $e', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            child: DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.7,
              maxChildSize: 0.95,
              builder: (_, controller) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                      "Create New Job Post",
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.lightBlue.shade800,
                        letterSpacing: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Price Offer - Changed from Icons.attach_money to Icons.monetization_on
                    _buildColoredIconTextField(
                        _priceController,
                        'Your Price Offer (Rs.)',
                        Icons.monetization_on,
                        Colors.amber.shade700,
                        null,
                        TextInputType.number
                    ),
                    const SizedBox(height: 16),

                    // Category Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      items: categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value;
                          _selectedService = null;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Category',
                        prefixIcon: Icon(Icons.category, color: Colors.deepPurple.shade400),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        filled: true,
                        fillColor: Colors.lightBlue.shade50.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Service Selection
                    if (_selectedCategory != null && subcategories[_selectedCategory!]!.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Select Service (only one):',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: subcategories[_selectedCategory!]!.map((service) {
                              final isSelected = _selectedService == service;
                              final isDisabled = _selectedService != null &&
                                  _selectedService!.isNotEmpty &&
                                  !subcategories[_selectedCategory!]!.contains(_selectedService);
                              return ChoiceChip(
                                label: Text(service),
                                selected: isSelected,
                                onSelected: isDisabled
                                    ? null
                                    : (selected) {
                                  setState(() {
                                    _selectedService = selected ? service : null;
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _serviceController,
                            enabled: _selectedService == null ||
                                !subcategories[_selectedCategory!]!.contains(_selectedService),
                            decoration: InputDecoration(
                              labelText: 'Or type custom service',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.check),
                                onPressed: () {
                                  final text = _serviceController.text.trim();
                                  if (text.isNotEmpty) {
                                    setState(() {
                                      _selectedService = text;
                                    });
                                  }
                                },
                              ),
                              prefixIcon: Icon(Icons.edit_note, color: Colors.orange.shade600),
                              filled: true,
                              fillColor: Colors.lightBlue.shade50.withOpacity(0.6),
                            ),
                            onChanged: (val) {
                              setState(() {
                                _selectedService = val.trim();
                              });
                            },
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),

                    // Location Selection
                    LocationAutocompleteField(
                      onPlaceSelected: (latLng, address) {
                        print("Selected location: $latLng, $address");
                        setState(() {
                          _selectedLatLng = latLng;
                          _selectedAddress = address;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Job Description',
                        hintText: 'Describe the job details, requirements, and expectations...',
                        prefixIcon: Container(
                          margin: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Colors.teal.shade400.withOpacity(0.7), Colors.teal.shade400],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(color: Colors.teal.shade400.withOpacity(0.5), blurRadius: 5, offset: const Offset(1, 2)),
                            ],
                          ),
                          child: Icon(Icons.description, color: Colors.white),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        filled: true,
                        fillColor: Colors.lightBlue.shade50.withOpacity(0.6),
                        labelStyle: TextStyle(color: Colors.lightBlue.shade800, fontWeight: FontWeight.w600),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.lightBlue.shade700, width: 2),
                        ),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Date and Time Selection
                    _buildDateTimeTile(
                        'Service Date',
                        _selectedDate == null
                            ? 'No date chosen'
                            : DateFormat('EEE, MMM d, yyyy').format(_selectedDate!),
                        Icons.calendar_today,
                        Colors.lightBlue.shade600,
                            () => _pickDate(context)
                    ),
                    const SizedBox(height: 10),
                    _buildDateTimeTile(
                        'Service Time',
                        _selectedTime == null
                            ? 'No time chosen'
                            : _selectedTime!.format(context),
                        Icons.access_time,
                        Colors.lightBlue.shade600,
                            () => _pickTime(context)
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
                                color: Colors.white
                            )
                        )
                            : const Icon(Icons.check_circle_outline),
                        label: Text(_isSubmitting
                            ? 'Creating Job Post...'
                            : 'Create Job Post'),
                        onPressed: _isSubmitting ? null : _submitOrder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          elevation: 10,
                          shadowColor: Colors.lightBlue.shade300,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimeTile(String title, String subtitle, IconData icon, Color iconColor, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
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
              BoxShadow(color: iconColor.withOpacity(0.4), blurRadius: 5, offset: const Offset(1, 2)),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
        trailing: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: iconColor,
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
          child: const Text("Pick"),
        ),
      ),
    );
  }
}