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
  // NEW: Optional parameters for editing mode
  final Map<String, dynamic>? existingProduct;
  final String? productId;
  final bool isEditing;
  
  const AddProducePage({
    super.key,
    this.existingProduct,
    this.productId,
    this.isEditing = false,
  });

  @override
  State<AddProducePage> createState() => _AddProducePageState();
}

class _AddProducePageState extends State<AddProducePage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController sellingUnitController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  File? _image;           // Mobile
  Uint8List? _webImage;   // Web
  String? _existingImageUrl; // Store existing image URL for editing

  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  // Dropdown variables
  String? _selectedSellingUnit;
  bool _isCustomUnit = false;
  final TextEditingController _customUnitController = TextEditingController();

  // List of predefined selling units
  final List<String> _predefinedUnits = [
    'Kilogram (kg)',
    'Gram (g)',
    'Litres (L)',
    'Millilitres (ml)',
    'Bag (50kg)',
    'Bag (25kg)',
    'Bag (10kg)',
    'Crate',
    'Bunch',
    'Piece',
    'Dozen',
    'Tray',
    'Basket',
    'Bucket',
    'Sack',
    'Carton',
    'Box',
  ];

  @override
  void initState() {
    super.initState();
    // If editing, pre-fill the form with existing product data
    if (widget.isEditing && widget.existingProduct != null) {
      _preFillForm();
    }
  }

  void _preFillForm() {
    nameController.text = widget.existingProduct!['name']?.toString() ?? '';
    priceController.text = widget.existingProduct!['price']?.toString() ?? '';
    quantityController.text = widget.existingProduct!['quantity']?.toString() ?? '';
    
    String? existingUnit = widget.existingProduct!['sellingUnit']?.toString();
    
    // Check if the existing unit is in the predefined list
    if (existingUnit != null && _predefinedUnits.contains(existingUnit)) {
      _selectedSellingUnit = existingUnit;
      _isCustomUnit = false;
      sellingUnitController.text = existingUnit;
    } else if (existingUnit != null && existingUnit.isNotEmpty) {
      // It's a custom unit
      _isCustomUnit = true;
      _customUnitController.text = existingUnit;
      sellingUnitController.text = existingUnit;
    }
    
    locationController.text = widget.existingProduct!['location']?.toString() ?? '';
    descriptionController.text = widget.existingProduct!['description']?.toString() ?? '';
    _existingImageUrl = widget.existingProduct!['imageUrl']?.toString();
  }

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    quantityController.dispose();
    sellingUnitController.dispose();
    locationController.dispose();
    descriptionController.dispose();
    _customUnitController.dispose();
    super.dispose();
  }

  // Helper method to get the final selling unit value
  String _getSellingUnit() {
    if (_isCustomUnit) {
      return _customUnitController.text.trim();
    } else {
      return _selectedSellingUnit ?? '';
    }
  }

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
          _existingImageUrl = null; // Clear existing image when new one is picked
        });
      } else {
        setState(() {
          _image = File(pickedFile.path);
          _webImage = null;
          _existingImageUrl = null; // Clear existing image when new one is picked
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

  // ✅ UPDATE PRODUCE (EDIT MODE)
  Future<void> updateProduce() async {
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

    String sellingUnit = _getSellingUnit();
    if (sellingUnit.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or enter a selling unit')),
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
      if (user == null) throw Exception("User not logged in");

      // If user selected a new image, upload it; otherwise keep existing
      String? imageUrl = _existingImageUrl;
      if (_image != null || _webImage != null) {
        imageUrl = await uploadImageToCloudinary();
        if (imageUrl == null) throw Exception("Image upload failed");
      }

      // Update the product in Firestore
      await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId)
          .update({
        'name': nameController.text.trim(),
        'price': price,
        'quantity': quantityController.text.trim(),
        'sellingUnit': sellingUnit,
        'location': locationController.text.trim(),
        'description': descriptionController.text.trim(),
        'imageUrl': imageUrl,
        'lastUpdated': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Product updated successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

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

  // ✅ UPLOAD PRODUCE (ADD MODE)
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
    
    String sellingUnit = _getSellingUnit();
    if (sellingUnit.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or enter a selling unit')),
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

      // Upload Image
      final imageUrl = await uploadImageToCloudinary();
      if (imageUrl == null) throw Exception("Image upload failed");

      // Save to Firestore with ALL REQUIRED FIELDS
      final productData = {
        'name': nameController.text.trim(),
        'price': price,
        'quantity': quantityController.text.trim(),
        'sellingUnit': sellingUnit,
        'location': locationController.text.trim(),
        'description': descriptionController.text.trim(),
        'imageUrl': imageUrl,
        'farmerId': user.uid,
        'farmerName': farmerName,
        'dateAdded': DateTime.now().toIso8601String(),
        'timestamp': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('products').add(productData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Produce added successfully')),
      );

      // Clear form
      nameController.clear();
      priceController.clear();
      quantityController.clear();
      sellingUnitController.clear();
      locationController.clear();
      descriptionController.clear();
      setState(() {
        _image = null;
        _webImage = null;
        _existingImageUrl = null;
        _selectedSellingUnit = null;
        _isCustomUnit = false;
        _customUnitController.clear();
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.green[700],
        elevation: 0,
        title: Text(widget.isEditing ? "Edit Produce" : "Add Produce"),
        centerTitle: true,
        foregroundColor: Colors.white,
      ),
      body: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
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
                decoration: _inputDecoration("e.g., 1500"),
              ),

              const SizedBox(height: 15),
              const Text(
                "Quantity",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 5),
              TextField(
                controller: quantityController,
                decoration: _inputDecoration("e.g., 50, 100, 20"),
              ),

              const SizedBox(height: 15),
              const Text(
                "Selling Unit",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 5),
              
              // Dropdown for selling units
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.grey[300]!),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedSellingUnit,
                      hint: const Text('Select a selling unit'),
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.green),
                      iconSize: 30,
                      items: [
                        ..._predefinedUnits.map((unit) {
                          return DropdownMenuItem(
                            value: unit,
                            child: Text(unit),
                          );
                        }),
                        const DropdownMenuItem(
                          value: 'custom',
                          child: Text(
                            '+ Add custom unit...',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          if (value == 'custom') {
                            _isCustomUnit = true;
                            _selectedSellingUnit = null;
                          } else {
                            _isCustomUnit = false;
                            _selectedSellingUnit = value;
                            sellingUnitController.text = value ?? '';
                          }
                        });
                      },
                    ),
                  ),
                ),
              ),
              
              // Custom unit text field (shown when "Add custom unit" is selected)
              if (_isCustomUnit) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _customUnitController,
                  decoration: _inputDecoration("e.g., Bundle, Sack, Crate, etc."),
                  onChanged: (value) {
                    sellingUnitController.text = value;
                  },
                ),
              ],
              
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

              // IMAGE PREVIEW (New image OR existing image)
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
                )
              else if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      _existingImageUrl!,
                      height: 120,
                      width: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 120,
                          width: 120,
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                        );
                      },
                    ),
                  ),
                ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading 
                      ? null 
                      : (widget.isEditing ? updateProduce : uploadProduce),
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
                      : Text(
                          widget.isEditing ? "Update Produce" : "Add Produce",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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