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
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController locationController = TextEditingController(); // ADDED
  final TextEditingController descriptionController = TextEditingController(); // ADDED

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
    // VALIDATE ALL FIELDS
    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter produce name')),
      );
      return;
    }
    
    if (priceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter price')),
      );
      return;
    }
    
    if (quantityController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter quantity')),
      );
      return;
    }
    
    if (locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter location')),
      );
      return;
    }
    
    if (_image == null && _webImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image')),
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

      // Get farmer name and location from user profile
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};
      String farmerName = userData['name'] ?? user.displayName ?? "Farmer";
      String farmerLocation = userData['location'] ?? locationController.text.trim();

      // 🔥 Upload Image
      final imageUrl = await uploadImageToCloudinary();
      if (imageUrl == null) throw Exception("Image upload failed");

      // 🔥 Save to Firestore with ALL REQUIRED FIELDS
      final productData = {
        'name': nameController.text.trim(),
        'price': price,
        'quantity': quantityController.text.trim(), // Store as string
        'location': locationController.text.trim(), // ADDED - CRITICAL!
        'description': descriptionController.text.trim(), // ADDED
        'imageUrl': imageUrl,
        'farmerId': user.uid,
        'farmerName': farmerName,
        'dateAdded': DateTime.now().toIso8601String(), // ADDED for sorting
        'timestamp': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('products').add(productData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Produce added successfully')),
      );

      // ✅ CLEAR FORM
      nameController.clear();
      priceController.clear();
      quantityController.clear();
      locationController.clear();
      descriptionController.clear();
      setState(() {
        _image = null;
        _webImage = null;
      });

      // Return success to dashboard
      Navigator.pop(context, true);

    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: ${e.toString()}')),
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
    quantityController.dispose();
    locationController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Changed to white
      appBar: AppBar(
        backgroundColor: Colors.green[700],
        elevation: 0,
        title: const Text("Add Produce"),
        centerTitle: true,
        foregroundColor: Colors.white,
      ),
      body: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, // Changed to white
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Produce Name",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 5),
              TextField(
                controller: nameController,
                decoration: _inputDecoration("e.g., Maize, Tomatoes, Cabbage"),
              ),

              const SizedBox(height: 15),
              const Text(
                "Price (MWK)",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 5),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration("Enter price in Malawi Kwacha"),
              ),

              const SizedBox(height: 15),
              const Text(
                "Quantity",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 5),
              TextField(
                controller: quantityController,
                decoration: _inputDecoration("e.g., 50 kg, 100 pieces, 20 bunches"),
              ),

              const SizedBox(height: 15),
              const Text(
                "Location",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 5),
              TextField(
                controller: locationController,
                decoration: _inputDecoration("e.g., Lilongwe, Mzuzu, Blantyre"),
              ),

              const SizedBox(height: 15),
              const Text(
                "Description (Optional)",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 5),
              TextField(
                controller: descriptionController,
                decoration: _inputDecoration("Describe your produce..."),
                maxLines: 2,
              ),

              const SizedBox(height: 15),
              const Text(
                "Upload Produce Image",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 5),
              GestureDetector(
                onTap: pickImage,
                child: Container(
                  height: 50,
                  decoration: _boxDecoration(),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, color: Colors.green),
                      SizedBox(width: 8),
                      Text("Tap to upload image"),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // ✅ IMAGE PREVIEW
              if (_webImage != null)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(_webImage!, height: 120, fit: BoxFit.cover),
                  ),
                )
              else if (_image != null)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(_image!, height: 120, fit: BoxFit.cover),
                  ),
                ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : uploadProduce,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Add Produce",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
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
      fillColor: Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Colors.green),
      ),
    );
  }

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: Colors.grey[50],
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.grey[300]!),
    );
  }
}