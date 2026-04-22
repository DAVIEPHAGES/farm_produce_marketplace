import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddProducePage extends StatefulWidget {
  const AddProducePage({super.key});

  @override
  State<AddProducePage> createState() => _AddProducePageState();
}

class _AddProducePageState extends State<AddProducePage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();

  String? selectedQuantity;

  File? _image;           // Mobile
  Uint8List? _webImage;   // Web

  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  // ✅ PICK IMAGE (WEB + MOBILE)
  Future<void> pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (pickedFile == null) return;

      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _webImage = bytes;
          _image = null;
        });
      } else {
        setState(() {
          _image = File(pickedFile.path);
          _webImage = null;
        });
      }
    } catch (e) {
      debugPrint("Image pick error: $e");
    }
  }

  // ✅ UPLOAD IMAGE (WEB + MOBILE)
  Future<String?> uploadImageToCloudinary() async {
    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/dvdbts38x/image/upload',
      );

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = 'farm_produce';

      if (kIsWeb && _webImage != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            _webImage!,
            filename: 'upload.jpg',
          ),
        );
      } else if (_image != null) {
        request.files.add(
          await http.MultipartFile.fromPath('file', _image!.path),
        );
      } else {
        return null;
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final jsonMap = jsonDecode(responseBody);
        return jsonMap['secure_url'];
      } else {
        debugPrint("Cloudinary upload failed: ${response.statusCode} $responseBody");
        return null;
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  // ✅ UPLOAD PRODUCE
  Future<void> uploadProduce() async {
    if (nameController.text.trim().isEmpty ||
        priceController.text.trim().isEmpty ||
        selectedQuantity == null ||
        (_image == null && _webImage == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and select an image')),
      );
      return;
    }

    double? price = double.tryParse(priceController.text);
    if (price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid price')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception("User not logged in");
      }

      // 🔥 Upload Image
      final imageUrl = await uploadImageToCloudinary();
      if (imageUrl == null) throw Exception("Image upload failed");

      // 🔥 Save to Firestore
      await FirebaseFirestore.instance.collection('products').add({
        'name': nameController.text.trim(),
        'price': price,
        'quantity': selectedQuantity,
        'imageUrl': imageUrl,
        'farmerId': user.uid,
        'farmerName': user.displayName ?? "Farmer",
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Produce added successfully')),
      );

      // ✅ CLEAR FORM
      nameController.clear();
      priceController.clear();
      setState(() {
        selectedQuantity = null;
        _image = null;
        _webImage = null;
      });

    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade700,
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        elevation: 0,
        title: const Text("Add Produce"),
        centerTitle: true,
      ),
      body: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Produce Name"),
              const SizedBox(height: 5),
              TextField(
                controller: nameController,
                decoration: _inputDecoration("e.g Maize"),
              ),

              const SizedBox(height: 15),
              const Text("Price (MWK)"),
              const SizedBox(height: 5),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration("Enter price"),
              ),

              const SizedBox(height: 15),
              const Text("Minimum Quantity"),
              const SizedBox(height: 5),
              _buildDropdown(),

              const SizedBox(height: 15),
              const Text("Upload Produce Image"),
              const SizedBox(height: 5),
              GestureDetector(
                onTap: pickImage,
                child: Container(
                  height: 50,
                  decoration: _boxDecoration(),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt),
                      SizedBox(width: 8),
                      Text("Tap to upload")
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // ✅ FIXED IMAGE PREVIEW
              if (_webImage != null)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(_webImage!, height: 120),
                  ),
                )
              else if (_image != null)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(_image!, height: 120),
                  ),
                ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : uploadProduce,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade800,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Add Produce"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.grey.shade300,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: _boxDecoration(),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedQuantity,
          hint: const Text("e.g 50kg"),
          isExpanded: true,
          items: ["10kg", "20kg", "50kg", "100kg"]
              .map((value) =>
                  DropdownMenuItem(value: value, child: Text(value)))
              .toList(),
          onChanged: (value) => setState(() => selectedQuantity = value),
        ),
      ),
    );
  }

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: Colors.grey.shade300,
      borderRadius: BorderRadius.circular(20),
    );
  }
}