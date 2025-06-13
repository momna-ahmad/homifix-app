import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/serviceVideoPlayer.dart';

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


  @override
  Widget build(BuildContext context) {
    final bool isProfessional = role.toLowerCase() == 'professional';

    return StreamBuilder<QuerySnapshot>(
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
          padding: const EdgeInsets.all(12),
          itemCount: services.length,
          itemBuilder: (context, index) {
            final data = services[index].data() as Map<String, dynamic>;
            final category = data['category'] ?? 'No Category';
            final description = data['service'] ?? 'No Description';
            final imageUrls = List<String>.from(data['imageUrls'] ?? []);
            final videoUrl = data['videoUrl'] as String?;

            return Card(
              elevation: 5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              margin: const EdgeInsets.symmetric(vertical: 10),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            category,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                        ),
                        if (isProfessional) ...[
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blueAccent),
                            onPressed: () => onEdit(context, services[index]),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                            onPressed: () => onDelete(context, services[index].id),
                          ),
                        ],

                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    if (imageUrls.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Center(
                          child: SizedBox(
                            width: 300, // Match the video width or set as desired
                            height: 200, // Match the video height
                            child: PageView.builder( // Optional: swipable image view
                              itemCount: imageUrls.length,
                              itemBuilder: (_, i) => ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  imageUrls[i],
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (videoUrl != null && videoUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    child: ServiceVideoPlayer(videoUrl: videoUrl),
                  ),
                ),
              ),
                ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
