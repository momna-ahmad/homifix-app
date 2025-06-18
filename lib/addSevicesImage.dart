import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';

Future<dynamic> pickAndUploadMediaToCloudinary({
  required BuildContext context,
  required bool isVideo,
  bool allowMultiple = false, // this is ignored for videos
}) async {
  final picker = ImagePicker();
  try {
    if (isVideo) {
      final picked = await picker.pickVideo(source: ImageSource.gallery);
      if (picked == null) return null;

      final videoFile = File(picked.path);
      return await uploadToCloudinary(videoFile, isVideo: true);
    } else {
      final pickedList = await picker.pickMultiImage(); // For multiple image selection
      if (pickedList == null || pickedList.isEmpty) return null;

      final urls = <String>[];
      for (final picked in pickedList) {
        final file = File(picked.path);
        final url = await uploadToCloudinary(file, isVideo: false);
        if (url != null) urls.add(url);
      }
      return urls;
    }
  } catch (e) {
    debugPrint("Error uploading media: $e");
    return null;
  }
}


Future<String?> uploadToCloudinary(File file, {required bool isVideo}) async {
  var cloudName = dotenv.env['CLOUDINARY_NAME']!; // 🔁 Replace with your Cloudinary cloud name
  var uploadPreset = dotenv.env['UPLOAD_PRESET']!; // 🔁 Replace with your Cloudinary preset

  final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/${isVideo ? "video" : "image"}/upload');
  final request = http.MultipartRequest('POST', uri)
    ..fields['upload_preset'] = uploadPreset
    ..files.add(await http.MultipartFile.fromPath('file', file.path));

  final response = await request.send();

  if (response.statusCode == 200) {
    final resStr = await response.stream.bytesToString();
    return json.decode(resStr)['secure_url'];
  } else {
    debugPrint('Upload failed: ${response.statusCode}');
    return null;
  }
}
