import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'profilePictureUploader.dart';

class EditProfileDialog extends StatefulWidget {
  final String userId;
  const EditProfileDialog({super.key, required this.userId});

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cnicController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _loading = false;
  String? imageUrl;

  final _formKey = GlobalKey<FormState>();

  final cnicMaskFormatter = MaskTextInputFormatter(
    mask: '#####-#######-#',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

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
      _cnicController.text = data['cnic'] ?? '';

      final rawPhone = data['whatsapp'] ?? '';
      _phoneController.text = rawPhone.startsWith('92')
          ? rawPhone.substring(2) // strip the 92 prefix
          : rawPhone;             // use as-is (assume it's already clean)


      imageUrl = data['profileImage'];
      if (mounted) setState(() {});
    }
  }

  Future<void> _uploadProfileImage() async {
    setState(() => _loading = true);
    final uploadedUrl = await pickAndUploadProfileImage(context);
    if (!mounted) return;
    setState(() {
      imageUrl = uploadedUrl;
      _loading = false;
    });
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
      'name': _nameController.text.trim(),
      'profileImage': imageUrl,
      'cnic': _cnicController.text.trim(),
      'whatsapp': '92${_phoneController.text.trim()}',


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

  bool get isValidInputs {
    final cnicText = _cnicController.text.trim();
    final phoneText = _phoneController.text.trim();
    final isValidCnic = cnicText.isEmpty || RegExp(r'^\d{5}-\d{7}-\d$').hasMatch(cnicText);
    final isValidPhone = phoneText.isEmpty || RegExp(r'^\d{10}$').hasMatch(phoneText);
    return isValidCnic && isValidPhone;
  }


  @override
  void dispose() {
    _nameController.dispose();
    _cnicController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Profile'),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Form(
            key: _formKey,
            onChanged: () => setState(() {}),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAvatar(),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _cnicController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [cnicMaskFormatter],
                  decoration: const InputDecoration(
                    labelText: 'CNIC (e.g. 12345-6789012-3)',
                    counterText: '',
                  ),
                  validator: (value) {
                    if (value!.isEmpty) return null;
                    return RegExp(r'^\d{5}-\d{7}-\d$').hasMatch(value)
                        ? null
                        : 'Invalid CNIC format';
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp Number',
                    prefixText: '92',
                    prefixStyle: TextStyle(color: Colors.grey),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return null;
                    return RegExp(r'^\d{10}$').hasMatch(value)
                        ? null
                        : 'Enter 10 digits after 92';
                  },
                ),

              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading || !isValidInputs
              ? null
              : () {
            print("Saving...");
            _saveChanges();
          },
          child: const Text('Save'),
        ),

      ],
    );
  }
}
