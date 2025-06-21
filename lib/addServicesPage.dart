import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../shared/categories.dart';
import 'addSevicesImage.dart';
import 'services/serviceVideoPlayer.dart';
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
    super.dispose();
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Gradient Background
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFBBDEFB), Color(0xFF64B5F6), Color(0xFF1976D2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        // Blur effect
        BackdropFilter(filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2), child: Container(color: Colors.black26)),
        // Draggable Modal Content
        DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.6,
          maxChildSize: 0.95,
          builder: (_, controller) => Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(16),
            child: ListView(
              controller: controller,
              children: [
                const Center(child: Text("Add/Edit Service", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: "Category",
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: categories.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Row(
                          children: [
                            const Icon(Icons.label_outline, size: 20, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(c),
                          ],
                        ),
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
                if (_selectedCategory != null && subcategories[_selectedCategory!]!.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    children: subcategories[_selectedCategory!]!.map((s) {
                      final selected = s == _selectedSubcategory;
                      final disabled = _customSubcategoryController.text.isNotEmpty;
                      return ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_border, size: 16, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(s, style: const TextStyle(color: Colors.white)),
                          ],
                        ),
                        selected: selected,
                        backgroundColor: Colors.blue.shade300,
                        selectedColor: Colors.blue.shade700,
                        onSelected: disabled ? null : (sel) => setState(() => _selectedSubcategory = sel ? s : null),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _customSubcategoryController,
                  decoration: const InputDecoration(
                    labelText: 'Or enter custom subcategory',
                    prefixIcon: Icon(Icons.edit),
                  ),
                  onChanged: (val) => setState(() {
                    _selectedSubcategory = val.trim().isEmpty ? null : val.trim();
                  }),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.image),
                        label: const Text("Upload Images"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlue.shade600,
                        ),
                        onPressed: () => _uploadMedia(false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.videocam),
                        label: const Text("Upload Video"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlue.shade800,
                        ),
                        onPressed: () => _uploadMedia(true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_imageUrls.isNotEmpty)
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
                if (_videoUrl != null && _videoUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: ServiceVideoPlayer(videoUrl: _videoUrl!),
                  ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: _isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save),
                  label: Text(_isSubmitting ? "Saving..." : "Submit"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSubmitting ? null : _submitService,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

}
