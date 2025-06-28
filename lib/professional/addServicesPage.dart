import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/categories.dart';
import 'addSevicesImage.dart';
import '../services/serviceVideoPlayer.dart';
import 'viewServices.dart';

class AddServicesPage extends StatelessWidget {
  final String userId;
  final String role;
  const AddServicesPage({super.key, required this.userId,required this.role});

  void _showAddServiceModal(BuildContext context, {DocumentSnapshot? serviceToEdit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ServiceForm(userId: userId, serviceToEdit: serviceToEdit),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ViewServicesPage(
        userId: userId,
        role: role,
        onEdit: (context, service) => _showAddServiceModal(context, serviceToEdit: service),
        onDelete: (context, serviceId) async {
          final confirm = await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Delete Service"),
              content: const Text("Are you sure you want to delete this service?"),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
              ],
            ),
          );
          if (confirm == true) {
            await FirebaseFirestore.instance.collection('services').doc(serviceId).delete();
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddServiceModal(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ServiceForm extends StatefulWidget {
  final String userId;
  final DocumentSnapshot? serviceToEdit;
  const _ServiceForm({required this.userId, this.serviceToEdit});

  @override
  State<_ServiceForm> createState() => _ServiceFormState();
}

class _ServiceFormState extends State<_ServiceForm> {
  String? _selectedCategory;
  String? _selectedSubcategory;
  final _customSubcategoryController = TextEditingController();
  final _priceController = TextEditingController();
  final _unitController = TextEditingController();
  List<String> _imageUrls = [];
  String? _videoUrl;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.serviceToEdit != null) {
      final data = widget.serviceToEdit!.data() as Map<String, dynamic>;
      _selectedCategory = data['category'];
      _selectedSubcategory = data['service'];
      _priceController.text = data['price']?.toString() ?? '';
      _unitController.text = data['unit'] ?? '';
      _imageUrls = List<String>.from(data['imageUrls'] ?? []);
      _videoUrl = data['videoUrl'];
      _customSubcategoryController.text = subcategories[_selectedCategory]?.contains(_selectedSubcategory) == false
          ? _selectedSubcategory ?? ''
          : '';
    }
  }

  Future<void> _uploadMedia(bool isVideo) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    if (isVideo) {
      final url = await pickAndUploadMediaToCloudinary(context: context, isVideo: true);
      Navigator.pop(context);
      if (url != null) setState(() => _videoUrl = url);
    } else {
      final urls = await pickAndUploadMediaToCloudinary(context: context, isVideo: false, allowMultiple: true);
      Navigator.pop(context);
      if (urls != null) setState(() => _imageUrls = urls);
    }
  }

  Future<void> _submitService() async {
    if (_selectedCategory == null || _selectedSubcategory == null || _selectedSubcategory!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete all fields')));
      return;
    }

    setState(() => _isSubmitting = true);

    final data = {
      'userId': widget.userId,
      'category': _selectedCategory!,
      'service': _selectedSubcategory!.trim(),
      'price': _priceController.text.trim(),
      'unit': _unitController.text.trim(),
      'imageUrls': _imageUrls,
      'videoUrl': _videoUrl ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      if (widget.serviceToEdit != null) {
        await FirebaseFirestore.instance.collection('services').doc(widget.serviceToEdit!.id).update(data);
      } else {
        await FirebaseFirestore.instance.collection('services').add(data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _customSubcategoryController.dispose();
    _priceController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 0,
              blurRadius: 20,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.add_business,
                      color: Color(0xFF0EA5E9),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Add/Edit Service',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Category Dropdown
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    labelText: "Category",
                    labelStyle: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 14,
                    ),
                    prefixIcon: Container(
                      padding: const EdgeInsets.all(12),
                      child: const Icon(
                        Icons.category,
                        color: Color(0xFF0EA5E9),
                        size: 20,
                      ),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  items: categories.map((c) {
                    return DropdownMenuItem(
                      value: c,
                      child: Text(c),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() {
                    _selectedCategory = val;
                    _selectedSubcategory = null;
                    _customSubcategoryController.clear();
                  }),
                ),
              ),
              const SizedBox(height: 16),

              // Subcategory Chips
              if (_selectedCategory != null && subcategories[_selectedCategory!]!.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Subcategory',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: subcategories[_selectedCategory!]!.map((s) {
                        final selected = s == _selectedSubcategory;
                        final disabled = _customSubcategoryController.text.isNotEmpty;
                        return FilterChip(
                          label: Text(
                            s,
                            style: TextStyle(
                              color: selected ? Colors.white : const Color(0xFF64748B),
                              fontSize: 14,
                            ),
                          ),
                          selected: selected,
                          backgroundColor: const Color(0xFFF8FAFC),
                          selectedColor: const Color(0xFF0EA5E9),
                          checkmarkColor: Colors.white,
                          side: BorderSide(
                            color: selected ? const Color(0xFF0EA5E9) : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                          onSelected: disabled ? null : (sel) => setState(() => _selectedSubcategory = sel ? s : null),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              const SizedBox(height: 16),

              // Custom Subcategory Input
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _customSubcategoryController,
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Or enter custom subcategory',
                    labelStyle: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 14,
                    ),
                    prefixIcon: Container(
                      padding: const EdgeInsets.all(12),
                      child: const Icon(
                        Icons.edit,
                        color: Color(0xFF0EA5E9),
                        size: 20,
                      ),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  onChanged: (val) => setState(() {
                    _selectedSubcategory = val.trim().isEmpty ? null : val.trim();
                  }),
                ),
              ),
              const SizedBox(height: 16),

              // Price and Unit Fields
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Standard Price',
                          labelStyle: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 14,
                          ),
                          prefixIcon: Container(
                            padding: const EdgeInsets.all(12),
                            child: const Icon(
                              Icons.attach_money,
                              color: Color(0xFF0EA5E9),
                              size: 20,
                            ),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _unitController,
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Unit',
                          labelStyle: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 14,
                          ),
                          prefixIcon: Container(
                            padding: const EdgeInsets.all(12),
                            child: const Icon(
                              Icons.straighten,
                              color: Color(0xFF0EA5E9),
                              size: 20,
                            ),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Upload Buttons
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF22D3EE), Color(0xFF0EA5E9)],
                        ),
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x300EA5E9),
                            spreadRadius: 0,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextButton.icon(
                        icon: const Icon(Icons.image, color: Colors.white),
                        label: const Text(
                          "Upload Images",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _uploadMedia(false),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF22D3EE), Color(0xFF0EA5E9)],
                        ),
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x300EA5E9),
                            spreadRadius: 0,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextButton.icon(
                        icon: const Icon(Icons.videocam, color: Colors.white),
                        label: const Text(
                          "Upload Video",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _uploadMedia(true),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Image Preview
              if (_imageUrls.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Uploaded Images',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 100,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _imageUrls.map((url) => Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(url, width: 100, fit: BoxFit.cover),
                          ),
                        )).toList(),
                      ),
                    ),
                  ],
                ),

              // Video Preview
              if (_videoUrl != null && _videoUrl!.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const Text(
                      'Uploaded Video',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ServiceVideoPlayer(videoUrl: _videoUrl!),
                  ],
                ),
              const SizedBox(height: 24),

              // Submit Button
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF22D3EE), Color(0xFF0EA5E9)],
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x300EA5E9),
                      spreadRadius: 0,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: TextButton.icon(
                  icon: _isSubmitting
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : const Icon(Icons.save, color: Colors.white),
                  label: Text(
                    _isSubmitting ? "Saving..." : "Submit",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isSubmitting ? null : _submitService,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}