import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'customerOrderPage.dart';
import 'package:flutter_nominatim/flutter_nominatim.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_nominatim/flutter_nominatim.dart' as nominatim;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import '../shared/categories.dart'; // Import the new category structure


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

  // Called when user types
  void _onTextChanged(String input) async {
    if (input.length < 3) {
      setState(() {
        _suggestions = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final results = await Nominatim.instance.search(input);
      setState(() {
        _suggestions = results;
      });
    } catch (e) {
      print('Nominatim search error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: 'Location',
            suffixIcon: _isLoading ? const CircularProgressIndicator(strokeWidth: 2) : null,
          ),
          onChanged: _onTextChanged,
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



class AddOrderPage extends StatelessWidget {
  final String userId;
  const AddOrderPage({required this.userId, super.key});



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

  void _submitOrder() async {
    if (_categoryController.text.trim().isEmpty ||
        _selectedAddress.isEmpty ||
        _serviceController.text.trim().isEmpty ||
        _priceController.text.trim().isEmpty ||
        _selectedDate == null ||
        _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate!);
    final formattedTime = _selectedTime!.format(context);

    await FirebaseFirestore.instance.collection('orders').add({
      'customerId': widget.userId,
      'category': _categoryController.text.trim(),
      'service': _serviceController.text.trim(),
      'location': {
        'lat': _selectedLatLng!.latitude,
        'lng': _selectedLatLng!.longitude,
        'address': _selectedAddress, // This is the place's display name
      },

      'priceOffer': _priceController.text.trim(),
      'serviceDate': formattedDate,
      'serviceTime': formattedTime,
      'applications': [],
      'selectedWorkerId': null,
      'status': 'waiting',
      'createdAt': FieldValue.serverTimestamp(),
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerOrdersPage(userId: widget.userId),
      ),
    );
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
              initialChildSize: 0.75,
              minChildSize: 0.6,
              maxChildSize: 0.9,
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
                      "Create New Order",
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.lightBlue.shade800,
                        letterSpacing: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    _buildColoredIconTextField(_priceController, 'Your Price Offer', Icons.attach_money, Colors.amber.shade700, TextInputType.number),
                    const SizedBox(height: 16),

                    // ✅ Updated Category Dropdown
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

                    // ✅ Updated Service Text Field with suggestions
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
                            enabled: _selectedService == null ||
                                !subcategories[_selectedCategory!]!.contains(_selectedService),
                            decoration: InputDecoration(
                              labelText: 'Or type custom service',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              prefixIcon:
                              Icon(Icons.edit_note, color: Colors.orange.shade600),
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
                    //_buildColoredIconTextField(_locationController, 'Location', Icons.location_on, Colors.redAccent.shade400),
                    LocationAutocompleteField(
                      onPlaceSelected: (latLng, address) {
                        setState(() {
                          _selectedLatLng = latLng;
                          _selectedAddress = address;
                        });
                      },
                    ),
                    if (_selectedLatLng != null)
                      Text('Selected location: $_selectedAddress (${_selectedLatLng!.latitude}, ${_selectedLatLng!.longitude})'),
                    // Other form fields
                    const SizedBox(height: 20),
                    _buildDateTimeTile('Service Date', _selectedDate == null ? 'No date chosen' : DateFormat('EEE, MMM d, yyyy').format(_selectedDate!), Icons.calendar_today, Colors.lightBlue.shade600, () => _pickDate(context)),
                    const SizedBox(height: 10),
                    _buildDateTimeTile('Service Time', _selectedTime == null ? 'No time chosen' : _selectedTime!.format(context), Icons.access_time, Colors.lightBlue.shade600, () => _pickTime(context)),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_outline),
                        label: _isSubmitting
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Submit Request'),
                        onPressed: _isSubmitting ? null : _submitOrder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlue.shade700,
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

  Widget _buildColoredIconTextField(TextEditingController controller, String label, IconData icon, Color iconColor, [TextInputType? type]) {
    return TextField(
      controller: controller,
      keyboardType: type ?? TextInputType.text,
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

  Widget _buildDateTimeTile(String title, String subtitle, IconData icon, Color iconColor, VoidCallback onTap) {
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
    );
  }
}
