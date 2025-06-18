import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';

Future<String?> pickAndUploadProfileImage(BuildContext context) async {
  final picker = ImagePicker();

  try {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return null;

    final file = File(picked.path);
    return await uploadToCloudinary(file, isVideo: false);
  } catch (e) {
    debugPrint("Error uploading profile image: $e");
    return null;
  }
}

Future<String?> uploadToCloudinary(File file, {required bool isVideo}) async {
  final cloudName = dotenv.env['CLOUDINARY_NAME'];
  final uploadPreset = dotenv.env['UPLOAD_PRESET'];

  if (cloudName == null || uploadPreset == null) {
    debugPrint("Cloudinary config missing in .env");
    return null;
  }

  final uri = Uri.parse(
    'https://api.cloudinary.com/v1_1/$cloudName/${isVideo ? "video" : "image"}/upload',
  );

  final request = http.MultipartRequest('POST', uri)
    ..fields['upload_preset'] = uploadPreset
    ..files.add(await http.MultipartFile.fromPath('file', file.path));

  final response = await request.send();
  final responseBody = await response.stream.bytesToString();

  if (response.statusCode == 200) {
    final data = json.decode(responseBody);
    return data['secure_url'];
  } else {
    debugPrint('Upload failed (${response.statusCode}): $responseBody');
    return null;
  }
}
