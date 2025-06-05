// AddServicesPage.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../shared/categories.dart';

class AddServicesPage extends StatelessWidget {
  final String userId;
  const AddServicesPage({required this.userId, super.key});

  void _showAddServiceModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ServiceForm(userId: userId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Services')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('services')
            .where('userId', isEqualTo: userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No services added yet.'));
          }

          final services = snapshot.data!.docs;

          return ListView.builder(
            itemCount: services.length,
            itemBuilder: (context, index) {
              final service = services[index];
              final category = service['category'] ?? 'No Category';

              final description = service['service'] ?? 'No Description';
              final timing = service['timing'] ?? 'No Timing';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  leading:
                  const Icon(Icons.home_repair_service, color: Colors.blue),
                  title:
                  Text(category, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(description),
                      const SizedBox(height: 4),
                      Text('Timing: $timing', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              );
            },
          );
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
  const _ServiceForm({required this.userId});

  @override
  State<_ServiceForm> createState() => _ServiceFormState();
}

class _ServiceFormState extends State<_ServiceForm> {
  String? _selectedCategory;
  String? _selectedSubcategory;
  final TextEditingController _customSubcategoryController = TextEditingController();
  final TextEditingController _timingController = TextEditingController();

  bool _isSubmitting = false;

  void _submitService() async {
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }
    if (_selectedSubcategory == null || _selectedSubcategory!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or enter a subcategory')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    await FirebaseFirestore.instance.collection('services').add({
      'userId': widget.userId,
      'category': _selectedCategory ?? 'Other',
      'service': _selectedSubcategory!.trim(),
      'timing': _timingController.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _customSubcategoryController.dispose();
    _timingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(color: Colors.black.withOpacity(0.3)),
        ),
        DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (_, controller) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: ListView(
              controller: controller,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.build, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      "Add New Service",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Category',
                    prefixIcon: const Icon(Icons.category),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  value: _selectedCategory,
                  onChanged: (val) {
                    setState(() {
                      _selectedCategory = val;
                      _selectedSubcategory = null;
                      _customSubcategoryController.clear();
                    });
                  },
                ),
                const SizedBox(height: 16),

                if (_selectedCategory != null && subcategories[_selectedCategory!]!.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Subcategory:',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8.0,
                        children: subcategories[_selectedCategory!]!.map((subcat) {
                          final isSelected = _selectedSubcategory == subcat;
                          final isDisabled = _customSubcategoryController.text.trim().isNotEmpty;
                          return ChoiceChip(
                            label: Text(subcat),
                            selected: isSelected,
                            onSelected: isDisabled
                                ? null
                                : (selected) {
                              setState(() {
                                _selectedSubcategory = selected ? subcat : null;
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _customSubcategoryController,
                        decoration: InputDecoration(
                          labelText: 'Or enter custom subcategory',
                          prefixIcon: const Icon(Icons.add),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.check),
                            onPressed: () {
                              final text = _customSubcategoryController.text.trim();
                              if (text.isNotEmpty) {
                                setState(() {
                                  _selectedSubcategory = text;
                                });
                              }
                            },
                          ),
                        ),
                        onChanged: (val) {
                          final text = val.trim();
                          if (text.isNotEmpty) {
                            setState(() {
                              _selectedSubcategory = text;
                            });
                          } else {
                            setState(() {
                              _selectedSubcategory = null;
                            });
                          }
                        },
                      ),
                    ],
                  ),

                const SizedBox(height: 16),
                TextField(
                  controller: _timingController,
                  decoration: InputDecoration(
                    labelText: 'Timing (e.g., 10am - 2pm)',
                    prefixIcon: const Icon(Icons.access_time),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check),
                    label: _isSubmitting
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                        : const Text('Submit'),
                    onPressed: _isSubmitting ? null : _submitService,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

