import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'profilePictureUploader.dart'; // Ensure pickAndUploadImageToCloudinary() and pickedImage are defined here
import 'package:firebase_auth/firebase_auth.dart';

class EditProfileDialog extends StatefulWidget {
  final String userId;

  const EditProfileDialog({super.key, required this.userId});

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  final TextEditingController _nameController = TextEditingController();
  bool _loading = false;
  String? imageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
    final data = doc.data();
    if (data != null) {
      _nameController.text = data['name'] ?? '';
      imageUrl = data['profileImage'];
      if (mounted) setState(() {}); // refresh UI safely
    }
  }

  Future<void> _uploadProfileImage() async {
    setState(() => _loading = true);

    final uploadedUrl = await pickAndUploadMediaToCloudinary(
      context: context,
      isVideo: false,
      allowMultiple: false,
    );
    print('Uploaded image URL: $uploadedUrl');

    if (!mounted) return;
    setState(() {
      imageUrl = uploadedUrl;
      _loading = false;
    });
  }

  Future<void> _saveChanges() async {
    setState(() => _loading = true);

    // imageUrl already updated during image pick
    await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
      'name': _nameController.text.trim(),
      'profileImage': imageUrl,
    });

    if (mounted) {
      setState(() => _loading = false);
      Navigator.of(context).pop();
    }
  }


  Widget _buildAvatar() {
    return GestureDetector(
      onTap: _loading ? null : _uploadProfileImage,
      child: CircleAvatar(
        radius: 40,
        backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
        child: imageUrl == null ? const Icon(Icons.camera_alt, size: 40) : null,
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Profile'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAvatar(),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Full Name'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _saveChanges,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
