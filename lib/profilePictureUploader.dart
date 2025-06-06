import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<String?> pickAndUploadImageToCloudinary() async {
  final picker = ImagePicker();
  final pickedFile = await picker.pickImage(source: ImageSource.gallery);

  if (pickedFile == null) return null;

  final file = File(pickedFile.path);

  final cloudName = dotenv.env['CLOUDINARY_NAME'];
  final uploadPreset = dotenv.env['UPLOAD_PRESET'] ?? 'default_preset';


  final url = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/image/upload");

  final request = http.MultipartRequest('POST', url)
    ..fields['upload_preset'] = uploadPreset
    ..files.add(await http.MultipartFile.fromPath('file', file.path));

  final response = await request.send();

  if (response.statusCode == 200) {
    final responseData = await http.Response.fromStream(response);
    final jsonData = jsonDecode(responseData.body);
    if (jsonData['secure_url'] != null) {
      return jsonData['secure_url'];
    } else {
      print('Error: ${jsonData['error']['message']}');
      return null;
    }
  } else {
    print('Upload failed: ${response.statusCode}');
    return null;
  }
}
