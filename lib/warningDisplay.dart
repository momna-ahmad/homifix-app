import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WarningsDisplay extends StatefulWidget {
  final String userId;

  const WarningsDisplay({super.key, required this.userId});

  @override
  State<WarningsDisplay> createState() => _WarningsDisplayState();
}

class _WarningsDisplayState extends State<WarningsDisplay> {
  Future<void> _removeWarning(Map<String, dynamic> warning) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
        'warnings': FieldValue.arrayRemove([warning]),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Warning "${warning['message']}" removed.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error removing warning: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove warning: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('User data not found.'));
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        final warnings = (userData?['warnings'] as List<dynamic>?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ??
            [];

        if (warnings.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.green, size: 50),
                  SizedBox(height: 10),
                  Text(
                    'No new warnings!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 5),
                  Text('Keep up the good work.'),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          itemCount: warnings.length,
          itemBuilder: (context, index) {
            final warning = warnings[index];
            final message = warning['message'] ?? 'No message';
            // You can format the timestamp if needed
            // final timestamp = warning['timestamp'];

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
              color: Colors.red.shade50, // Light red background for warnings
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.red, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: const TextStyle(color: Colors.red, fontSize: 15),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => _removeWarning(warning),
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