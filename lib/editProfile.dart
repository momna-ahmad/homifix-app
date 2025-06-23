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

  // --- Standardized Color & Style Definitions (Copied from ProfessionalProfile) ---
  Color get _primaryBlue => const Color(0xFF0EA5E9);
  Color get _secondaryBlue => const Color(0xFF22D3EE);
  Color get _darkTextColor => const Color(0xFF1E293B);
  Color get _secondaryTextColor => const Color(0xFF64748B);
  Color get _lightBlueBackground => const Color(0xFFF0F9FF);
  Color get _cardBackground => Colors.white;
  BoxShadow get _cardShadow => BoxShadow(
    color: Colors.black.withOpacity(0.05),
    spreadRadius: 0,
    blurRadius: 10,
    offset: const Offset(0, 4),
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
      // Show success message before popping
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile updated successfully!'),
          backgroundColor: _primaryBlue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Widget _buildAvatar() {
    return Stack(
      alignment: Alignment.center,
      children: [
        GestureDetector(
          onTap: _loading ? null : _uploadProfileImage,
          child: CircleAvatar(
            radius: 45, // Slightly larger avatar
            backgroundColor: _primaryBlue.withOpacity(0.1), // Light background for empty state
            backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
            child: imageUrl == null
                ? Icon(Icons.camera_alt, size: 40, color: _primaryBlue.withOpacity(0.7))
                : null,
          ),
        ),
        if (_loading)
          const CircularProgressIndicator(
            color: Colors.blueAccent, // Use primary blue for loading
          ),
      ],
    );
  }

  bool get isValidInputs {
    // Validate all fields of the form. This will trigger the validators for each field.
    return _formKey.currentState?.validate() ?? false;
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      elevation: 8,
      backgroundColor: _cardBackground, // Use white for dialog background
      title: Text(
        'Edit Profile',
        style: TextStyle(
          color: _darkTextColor,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
        textAlign: TextAlign.center,
      ),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Form(
            key: _formKey,
            onChanged: () {
              // This ensures the button's enabled/disabled state updates in real-time
              _formKey.currentState!.validate(); // Re-run validation to update error messages
              setState(() {}); // Trigger rebuild to update button state
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAvatar(),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    labelStyle: TextStyle(color: _secondaryTextColor),
                    filled: true,
                    fillColor: _lightBlueBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none, // Remove default border
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: _primaryBlue, width: 2), // Blue border when focused
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: _lightBlueBackground, width: 1), // Light blue border
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name cannot be empty';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cnicController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [cnicMaskFormatter],
                  decoration: InputDecoration(
                    labelText: 'CNIC (e.g. 12345-6789012-3)',
                    labelStyle: TextStyle(color: _secondaryTextColor),
                    counterText: '',
                    filled: true,
                    fillColor: _lightBlueBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: _primaryBlue, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: _lightBlueBackground, width: 1),
                    ),
                  ),
                  validator: (value) {
                    if (value!.isEmpty) return null; // CNIC can be empty
                    return RegExp(r'^\d{5}-\d{7}-\d$').hasMatch(value)
                        ? null
                        : 'Invalid CNIC format';
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone, // Use phone keyboard
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: InputDecoration(
                    labelText: 'WhatsApp Number',
                    labelStyle: TextStyle(color: _secondaryTextColor),
                    prefixText: '+92 ', // Changed to '+92 ' for better visual
                    prefixStyle: TextStyle(color: _darkTextColor, fontWeight: FontWeight.w500),
                    filled: true,
                    fillColor: _lightBlueBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: _primaryBlue, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: _lightBlueBackground, width: 1),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return null; // Phone can be empty
                    if (value.length != 10) {
                      return 'Enter 10 digits (e.g., 3XX-XXXXXXX)'; // More descriptive error
                    }
                    // Basic validation for Pakistan numbers: usually start with 3
                    return RegExp(r'^[3-9]\d{9}$').hasMatch(value)
                        ? null
                        : 'Invalid phone number format';
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.all(16.0), // Padding around actions
      actions: [
        // Wrap buttons in a Row to place them side-by-side
        Row(
          mainAxisAlignment: MainAxisAlignment.end, // Align buttons to the end (right)
          children: [
            TextButton(
              onPressed: _loading ? null : () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: _secondaryTextColor, // Consistent color for cancel
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8), // Small space between buttons
            ElevatedButton(
              onPressed: _loading || !isValidInputs ? null : _saveChanges,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),

                backgroundColor: Colors.transparent, // Make background transparent for gradient
                shadowColor: Colors.transparent, // Remove default shadow
              ).copyWith(
                // Apply gradient only when enabled
                overlayColor: MaterialStateProperty.resolveWith((states) {
                  if (states.contains(MaterialState.pressed)) {
                    return _primaryBlue.withOpacity(0.2); // Ripple effect
                  }
                  return Colors.transparent;
                }),
                elevation: MaterialStateProperty.resolveWith((states) {
                  if (states.contains(MaterialState.disabled)) return 0;
                  return 4; // Add a slight shadow when enabled
                }),
              ),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: _loading || !isValidInputs
                      ? null // No gradient when disabled
                      : LinearGradient(
                    colors: [_primaryBlue, _secondaryBlue],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Container(
                  alignment: Alignment.center,
                  constraints: const BoxConstraints(minWidth: 80),
                  child: _loading
                      ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}