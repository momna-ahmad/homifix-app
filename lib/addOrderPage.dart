import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'customerOrderPage.dart';

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
  final _locationController = TextEditingController();
  final _serviceController = TextEditingController();
  final _priceController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSubmitting = false;

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
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
    _animationController.forward();
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _locationController.dispose();
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
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _submitOrder() async {
    if (_categoryController.text.trim().isEmpty ||
        _locationController.text.trim().isEmpty ||
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
      'location': _locationController.text.trim(),
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
                    _buildColoredIconTextField(_categoryController, 'Category', Icons.category, Colors.deepPurple.shade400),
                    const SizedBox(height: 16),
                    _buildColoredIconTextField(_serviceController, 'Service (e.g. AC Repair)', Icons.build_circle_outlined, Colors.orange.shade600),
                    const SizedBox(height: 16),
                    _buildColoredIconTextField(_locationController, 'Location', Icons.location_on, Colors.redAccent.shade400),
                    const SizedBox(height: 20),
                    _buildDateTimeTile('Service Date', _selectedDate == null ? 'No date chosen' : DateFormat('EEE, MMM d, yyyy').format(_selectedDate!), Icons.calendar_today, Colors.lightBlue.shade600, () => _pickDate(context)),
                    const SizedBox(height: 10),
                    _buildDateTimeTile('Service Time', _selectedTime == null ? 'No time chosen' : _selectedTime!.format(context), Icons.access_time, Colors.lightBlue.shade600, () => _pickTime(context)),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_outline, size: 24),
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
