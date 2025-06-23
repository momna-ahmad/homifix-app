import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'warningDisplay.dart' ;

class ViewServicesPage extends StatelessWidget {
  final String userId;
  final void Function(BuildContext context, DocumentSnapshot service) onEdit;
  final void Function(BuildContext context, String serviceId) onDelete;
  final String role;

  const ViewServicesPage({
    super.key,
    required this.userId,
    required this.role,
    required this.onEdit,
    required this.onDelete,
  });

  // Function to show the warnings dialog
  void _showWarningsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 0,
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Your Warnings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(),
                // Render the new WarningsDisplay widget
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                  child: WarningsDisplay(userId: userId),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isProfessional = role.toLowerCase() == 'professional';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F9FF), // Light blue background
      appBar: AppBar(
        title: const Text(
          'Home',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        actions: [
          // Notification Icon with Badge
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox.shrink(); // Hide icon while loading
              }
              if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                return const SizedBox.shrink(); // Hide icon on error or no data
              }

              final userData = snapshot.data!.data() as Map<String, dynamic>?;
              final warnings = (userData?['warnings'] as List<dynamic>?) ?? [];
              final hasWarnings = warnings.isNotEmpty;

              return Stack(
                children: [
                  Container(
                    margin: const EdgeInsets.only(right: 16),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFF22D3EE),
                      child: IconButton(
                        icon: const Icon(
                          Icons.notifications_none, // Notification icon
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: () => _showWarningsDialog(context),
                        tooltip: "View Warnings",
                      ),
                    ),
                  ),
                  if (hasWarnings)
                    Positioned(
                      right: 18, // Adjust positioning as needed for your UI
                      top: 8,    // Adjust positioning as needed for your UI
                      child: Container(
                        width: 10,   // Diameter of the red dot
                        height: 10,  // Diameter of the red dot
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle, // Make it a circle
                          border: Border.all(color: Colors.white, width: 1.5), // White border
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF22D3EE),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // Promo Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF22D3EE), Color(0xFF0EA5E9)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF22D3EE).withOpacity(0.3),
                          spreadRadius: 0,
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Earn Now',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const Text(
                                'Find Orders anywhere',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Add Services',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF22D3EE),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.home,
                          size: 60,
                          color: Colors.white30,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Your Services Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Services',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // Services List
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('services')
                  .where('userId', isEqualTo: userId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF22D3EE)),
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                final services = snapshot.data!.docs;
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: services.length,
                  itemBuilder: (context, index) {
                    final data = services[index].data() as Map<String, dynamic>;
                    return _buildServiceCard(context, data, services[index], isProfessional);
                  },
                );
              },
            ),

            const SizedBox(height: 100), // Bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem(IconData icon, String label, Color color) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildServiceCard(BuildContext context, Map<String, dynamic> data, DocumentSnapshot service, bool isProfessional) {
    final serviceName = data['service'] ?? 'House Cleaning';
    // final category = data['category'] ?? 'Cleaning'; // Category is not used here directly
    final price = data['price'] ?? '35';
    final rating = data['rating'] ?? '4.8';
    final imageUrls = List<String>.from(data['imageUrls'] ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Service Image
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFFF1F5F9),
              ),
              child: imageUrls.isNotEmpty
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrls.first,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.cleaning_services,
                      color: Color(0xFF22D3EE),
                      size: 32,
                    );
                  },
                ),
              )
                  : const Icon(
                Icons.cleaning_services,
                color: Color(0xFF22D3EE),
                size: 32,
              ),
            ),
            const SizedBox(width: 16),

            // Service Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    serviceName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'By ${data['providerName'] ?? 'Professional'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        size: 16,
                        color: Color(0xFFFBBF24),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        rating,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '\$$price',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF22D3EE),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Action Buttons
            if (isProfessional) ...[
              Column(
                children: [
                  IconButton(
                    onPressed: () => onEdit(context, service),
                    icon: const Icon(
                      Icons.edit,
                      color: Color(0xFF10B981),
                      size: 20,
                    ),
                  ),
                  IconButton(
                    onPressed: () => onDelete(context, service.id),
                    icon: const Icon(
                      Icons.delete,
                      color: Color(0xFFEF4444),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF22D3EE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.bookmark_border,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF22D3EE).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.cleaning_services,
              size: 48,
              color: Color(0xFF22D3EE),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Services Available',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start by adding your first service\nto showcase your expertise.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}