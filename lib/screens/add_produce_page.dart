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

  File? _image;
  Uint8List? _webImage;
  String? _existingImageUrl;

  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  String? _selectedSellingUnit;
  bool _isCustomUnit = false;
  final TextEditingController _customUnitController = TextEditingController();

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
    if (widget.isEditing && widget.existingProduct != null) {
      _preFillForm();
    }
  }

  void _preFillForm() {
    nameController.text = widget.existingProduct!['name']?.toString() ?? '';
    priceController.text = widget.existingProduct!['price']?.toString() ?? '';
    
    // ✅ Handle quantity - convert from int to string for display
    final quantity = widget.existingProduct!['quantity'];
    if (quantity is int) {
      quantityController.text = quantity.toString();
    } else {
      quantityController.text = quantity?.toString() ?? '';
    }
    
    String? existingUnit = widget.existingProduct!['sellingUnit']?.toString();
    
    if (existingUnit != null && _predefinedUnits.contains(existingUnit)) {
      _selectedSellingUnit = existingUnit;
      _isCustomUnit = false;
      sellingUnitController.text = existingUnit;
    } else if (existingUnit != null && existingUnit.isNotEmpty) {
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

  String _getSellingUnit() {
    if (_isCustomUnit) {
      return _customUnitController.text.trim();
    } else {
      return _selectedSellingUnit ?? '';
    }
  }

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
          _existingImageUrl = null;
        });
      } else {
        setState(() {
          _image = File(pickedFile.path);
          _webImage = null;
          _existingImageUrl = null;
        });
      }
    } catch (e) {
      debugPrint("Image pick error: $e");
    }
  }

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

  // ✅ UPDATE PRODUCE (EDIT MODE) - Now saves quantity as int
  Future<void> updateProduce() async {
    if (nameController.text.trim().isEmpty) {
      _showError('Please enter produce name');
      return;
    }
    
    if (priceController.text.trim().isEmpty) {
      _showError('Please enter price');
      return;
    }
    
    if (quantityController.text.trim().isEmpty) {
      _showError('Please enter quantity');
      return;
    }
    
    if (locationController.text.trim().isEmpty) {
      _showError('Please enter location');
      return;
    }

    String sellingUnit = _getSellingUnit();
    if (sellingUnit.isEmpty) {
      _showError('Please select or enter a selling unit');
      return;
    }

    double? price = double.tryParse(priceController.text);
    if (price == null) {
      _showError('Enter a valid price');
      return;
    }

    // ✅ Parse quantity as integer
    int? quantity = int.tryParse(quantityController.text);
    if (quantity == null || quantity <= 0) {
      _showError('Enter a valid quantity (must be a positive number)');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      String? imageUrl = _existingImageUrl;
      if (_image != null || _webImage != null) {
        imageUrl = await uploadImageToCloudinary();
        if (imageUrl == null) throw Exception("Image upload failed");
      }

      // ✅ Update with quantity as INTEGER
      await FirebaseFirestore.instance
          .collection('products')
          .doc(widget.productId)
          .update({
        'name': nameController.text.trim(),
        'price': price,
        'quantity': quantity, // ✅ NOW SAVED AS INTEGER
        'sellingUnit': sellingUnit,
        'location': locationController.text.trim(),
        'description': descriptionController.text.trim(),
        'imageUrl': imageUrl,
        'priceDisplay': '$price per $sellingUnit',
        'lastUpdated': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;

      _showSuccess('✅ Product updated successfully!');
      Navigator.pop(context, true);

    } catch (e) {
      debugPrint("Error: $e");
      _showError('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ UPLOAD PRODUCE (ADD MODE) - Now saves quantity as int
  Future<void> uploadProduce() async {
    if (nameController.text.trim().isEmpty) {
      _showError('Please enter produce name');
      return;
    }
    
    if (priceController.text.trim().isEmpty) {
      _showError('Please enter price');
      return;
    }
    
    if (quantityController.text.trim().isEmpty) {
      _showError('Please enter quantity');
      return;
    }
    
    String sellingUnit = _getSellingUnit();
    if (sellingUnit.isEmpty) {
      _showError('Please select or enter a selling unit');
      return;
    }
    
    if (locationController.text.trim().isEmpty) {
      _showError('Please enter location');
      return;
    }
    
    if (_image == null && _webImage == null) {
      _showError('Please select an image');
      return;
    }

    double? price = double.tryParse(priceController.text);
    if (price == null) {
      _showError('Enter a valid price');
      return;
    }

    // ✅ Parse quantity as integer
    int? quantity = int.tryParse(quantityController.text);
    if (quantity == null || quantity <= 0) {
      _showError('Enter a valid quantity (must be a positive number)');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};
      String farmerName = userData['name'] ?? user.displayName ?? "Farmer";

      final imageUrl = await uploadImageToCloudinary();
      if (imageUrl == null) throw Exception("Image upload failed");

      String priceDisplay = '$price per $sellingUnit';

      // ✅ Save quantity as INTEGER
      final productData = {
        'name': nameController.text.trim(),
        'price': price,
        'quantity': quantity, // ✅ NOW SAVED AS INTEGER
        'sellingUnit': sellingUnit,
        'priceDisplay': priceDisplay,
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

      _showSuccess('✅ Produce added successfully');
      
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

      Navigator.pop(context, true);

    } catch (e) {
      debugPrint("Error: $e");
      _showError('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
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
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            width: 400,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFieldLabel("Produce Name"),
                _buildSmallTextField(
                  controller: nameController,
                  hint: "e.g., Maize, Tomatoes",
                ),
                const SizedBox(height: 12),

                _buildFieldLabel("Price (MWK)"),
                _buildSmallTextField(
                  controller: priceController,
                  hint: "e.g., 1500",
                  isNumber: true,
                ),
                const SizedBox(height: 12),

                // ✅ Updated label to make it clear it's a number
                _buildFieldLabel("Quantity Available (Number only)"),
                _buildSmallTextField(
                  controller: quantityController,
                  hint: "e.g., 50, 100",
                  isNumber: true,
                ),
                const SizedBox(height: 4),
                Text(
                  "Enter the total quantity available (e.g., 50 kg, 100 bags)",
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 12),

                _buildFieldLabel("Selling Unit (per unit)"),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedSellingUnit,
                        hint: const Text('Select unit'),
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.green),
                        iconSize: 24,
                        items: [
                          ..._predefinedUnits.map((unit) {
                            return DropdownMenuItem(
                              value: unit,
                              child: Text(unit, style: const TextStyle(fontSize: 13)),
                            );
                          }),
                          const DropdownMenuItem(
                            value: 'custom',
                            child: Text(
                              '+ Add custom',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
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
                
                if (_isCustomUnit) ...[
                  const SizedBox(height: 8),
                  _buildSmallTextField(
                    controller: _customUnitController,
                    hint: "e.g., Bundle, Sack",
                    onChanged: (value) {
                      sellingUnitController.text = value;
                    },
                  ),
                ],
                const SizedBox(height: 12),

                _buildFieldLabel("Location"),
                _buildSmallTextField(
                  controller: locationController,
                  hint: "e.g., Lilongwe, Mzuzu",
                ),
                const SizedBox(height: 12),

                _buildFieldLabel("Description (Optional)"),
                _buildSmallTextField(
                  controller: descriptionController,
                  hint: "Describe your produce...",
                  maxLines: 2,
                ),
                const SizedBox(height: 12),

                _buildFieldLabel("Upload Image"),
                GestureDetector(
                  onTap: pickImage,
                  child: Container(
                    height: 45,
                    decoration: _boxDecoration(),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt, color: Colors.green, size: 18),
                        SizedBox(width: 6),
                        Text("Tap to upload", style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                if (_webImage != null)
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(_webImage!, height: 80, fit: BoxFit.cover),
                    ),
                  )
                else if (_image != null)
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(_image!, height: 80, fit: BoxFit.cover),
                    ),
                  )
                else if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty)
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _existingImageUrl!,
                        height: 80,
                        width: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 80,
                            width: 80,
                            color: Colors.grey[200],
                            child: const Icon(Icons.broken_image, size: 30, color: Colors.grey),
                          );
                        },
                      ),
                    ),
                  ),

                if (priceController.text.isNotEmpty && _getSellingUnit().isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.preview, size: 16, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Preview: MK ${priceController.text} per ${_getSellingUnit()}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),
                
                Center(
                  child: SizedBox(
                    width: 160,
                    child: ElevatedButton(
                      onPressed: _isLoading 
                          ? null 
                          : (widget.isEditing ? updateProduce : uploadProduce),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              widget.isEditing ? "Update" : "Add",
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildSmallTextField({
    required TextEditingController controller,
    required String hint,
    bool isNumber = false,
    int maxLines = 1,
    Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.green),
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
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.grey[300]!),
    );
  }
}