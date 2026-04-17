// farmers_dashboard_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FarmersDashboardPage extends StatefulWidget {
  const FarmersDashboardPage({super.key});

  @override
  State<FarmersDashboardPage> createState() => _FarmersDashboardPageState();
}

class _FarmersDashboardPageState extends State<FarmersDashboardPage> {
  bool _isLoading = true;
  Map<String, dynamic> farmerProfile = {};
  
  bool showAddProduceForm = false;
  final TextEditingController produceNameController = TextEditingController();
  final TextEditingController unitPriceController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _image;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadFarmerData();
  }

  Future<void> _loadFarmerData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _redirectToLogin();
        return;
      }

      // Get farmer profile from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      // Get farmer's products
      final productsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('farmerId', isEqualTo: user.uid)
          .get();
      
      // Get farmer's orders
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('farmerId', isEqualTo: user.uid)
          .get();
      
      // Calculate total earnings
      double totalEarnings = 0.0;
      for (var orderDoc in ordersSnapshot.docs) {
        final orderData = orderDoc.data();
        if (orderData['status'] == 'completed') {
          totalEarnings += (orderData['price'] ?? 0) * (orderData['quantity'] ?? 0);
        }
      }
      
      setState(() {
        farmerProfile = {
          'name': userDoc.data()?['name'] ?? 'Farmer',
          'location': userDoc.data()?['location'] ?? 'Unknown',
          'totalEarnings': totalEarnings,
          'products': productsSnapshot.docs.map((doc) => doc.data()).toList(),
          'orders': ordersSnapshot.docs.map((doc) => doc.data()).toList(),
          'email': user.email,
          'phone': userDoc.data()?['phone'] ?? '',
        };
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading farmer data: $e');
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load data: $e');
    }
  }

  Future<void> _addNewProduce() async {
    if (produceNameController.text.isEmpty ||
        unitPriceController.text.isEmpty ||
        locationController.text.isEmpty ||
        quantityController.text.isEmpty) {
      _showErrorSnackBar('Please fill all fields');
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String? imageUrl;
      
      // Upload image if selected
      if (_image != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('products/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await storageRef.putFile(_image!);
        imageUrl = await storageRef.getDownloadURL();
      }

      // Save product to Firestore
      final productData = {
        'name': produceNameController.text,
        'price': double.parse(unitPriceController.text),
        'location': locationController.text,
        'quantity': quantityController.text,
        'farmerId': user.uid,
        'farmerName': farmerProfile['name'],
        'imageUrl': imageUrl,
        'dateAdded': Timestamp.now(),
        'status': 'available',
      };

      final docRef = await FirebaseFirestore.instance
          .collection('products')
          .add(productData);

      // Add to local list with document ID
      final newProduct = {
        ...productData,
        'id': docRef.id,
      };

      setState(() {
        (farmerProfile['products'] as List).insert(0, newProduct);
        showAddProduceForm = false;
        
        // Clear controllers
        produceNameController.clear();
        unitPriceController.clear();
        locationController.clear();
        quantityController.clear();
        _image = null;
        _isUploading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Produce added successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      _showErrorSnackBar('Failed to add produce: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error picking image: $e');
    }
  }

  void _redirectToLogin() {
    Navigator.pushReplacementNamed(context, '/signin');
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'FARMER DASHBOARD',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 1,
          ),
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Menu',
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () => _showProfileDialog(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withOpacity(0.2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, size: 18),
                  const SizedBox(width: 6),
                  const Text(
                    'MY PROFILE',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        centerTitle: false,
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      drawer: _buildDrawer(context),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green[50]!, Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              if (showAddProduceForm)
                _buildAddProduceForm(),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome back!',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      farmerProfile['name'] ?? 'Farmer',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildDashboardCards(context),
                    if ((farmerProfile['products'] as List).isNotEmpty) ...[
                      const SizedBox(height: 32),
                      const Text(
                        'Recent Products',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildRecentProductsList(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Container(
        color: Colors.green[50],
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.green[700]!, Colors.green[800]!],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.agriculture,
                        size: 50,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      farmerProfile['name'] ?? 'Farmer',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      farmerProfile['location'] ?? 'Unknown',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildDrawerItem(
              icon: Icons.attach_money,
              title: 'Total Earnings',
              subtitle: 'MWK ${(farmerProfile['totalEarnings'] ?? 0).toStringAsFixed(2)}',
              color: Colors.green,
              onTap: () {
                Navigator.pop(context);
                _showEarningsDialog(context);
              },
            ),
            _buildDrawerItem(
              icon: Icons.agriculture,
              title: 'My Produce',
              subtitle: '${(farmerProfile['products'] as List).length} products listed',
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                _showMyProduceDialog(context);
              },
            ),
            _buildDrawerItem(
              icon: Icons.shopping_cart,
              title: 'New Orders',
              subtitle: '${(farmerProfile['orders'] as List).length} pending orders',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                _showOrdersDialog(context);
              },
            ),
            _buildDrawerItem(
              icon: Icons.add_box,
              title: 'Add Produce',
              subtitle: 'Post new items to marketplace',
              color: Colors.purple,
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  showAddProduceForm = true;
                });
              },
            ),
            const SizedBox(height: 20),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Logout',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/signin');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddProduceForm() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Add New Produce',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    showAddProduceForm = false;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Image picker button
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: _image != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_image!, fit: BoxFit.cover),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_upload, size: 50, color: Colors.green[300]),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to upload product image',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: produceNameController,
            label: 'Produce Name',
            hint: 'e.g., Maize, Tomatoes, Cabbage',
            icon: Icons.agriculture,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: unitPriceController,
            label: 'Unit Price (MWK)',
            hint: 'e.g., 5000',
            icon: Icons.attach_money,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: locationController,
            label: 'Location',
            hint: 'e.g., Lilongwe, Zomba',
            icon: Icons.location_on,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: quantityController,
            label: 'Quantity',
            hint: 'e.g., 100 kg, 50 bunches',
            icon: Icons.numbers,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isUploading ? null : _addNewProduce,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: _isUploading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'POST PRODUCE',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCards(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildDashboardCard(
          'Total Earnings',
          'MWK ${(farmerProfile['totalEarnings'] ?? 0).toStringAsFixed(2)}',
          Icons.attach_money,
          Colors.green,
          () => _showEarningsDialog(context),
        ),
        _buildDashboardCard(
          'My Produce',
          '${(farmerProfile['products'] as List).length} items',
          Icons.agriculture,
          Colors.orange,
          () => _showMyProduceDialog(context),
        ),
        _buildDashboardCard(
          'New Orders',
          '${(farmerProfile['orders'] as List).length} pending',
          Icons.shopping_cart,
          Colors.blue,
          () => _showOrdersDialog(context),
        ),
        _buildDashboardCard(
          'Add Produce',
          'Post new items',
          Icons.add_box,
          Colors.purple,
          () {
            setState(() {
              showAddProduceForm = true;
            });
          },
        ),
      ],
    );
  }

  Widget _buildRecentProductsList() {
    final products = (farmerProfile['products'] as List).take(3).toList();
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      itemBuilder: (context, index) {
        var product = products[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green[100],
              child: const Icon(
                Icons.agriculture,
                color: Colors.green,
              ),
            ),
            title: Text(
              product['name'] ?? 'Unknown',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MWK ${product['price'] ?? 0}'),
                Text('Quantity: ${product['quantity'] ?? 'N/A'}'),
                Text('📍 ${product['location'] ?? 'Unknown'}'),
              ],
            ),
            trailing: const Icon(
              Icons.chevron_right,
              color: Colors.green,
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12),
      ),
      onTap: onTap,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        prefixIcon: Icon(icon, color: Colors.green),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      keyboardType: keyboardType,
    );
  }

  Widget _buildDashboardCard(String title, String value, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.1), Colors.white],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfileDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: Colors.green),
              ),
              const SizedBox(width: 12),
              const Text(
                'Farmer Profile',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                _buildProfileInfo(
                  icon: Icons.person_outline,
                  label: 'Name',
                  value: farmerProfile['name'] ?? 'N/A',
                ),
                const SizedBox(height: 12),
                _buildProfileInfo(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: farmerProfile['email'] ?? 'N/A',
                ),
                const SizedBox(height: 12),
                _buildProfileInfo(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: farmerProfile['phone'] ?? 'N/A',
                ),
                const SizedBox(height: 12),
                _buildProfileInfo(
                  icon: Icons.location_on_outlined,
                  label: 'Location',
                  value: farmerProfile['location'] ?? 'N/A',
                ),
                const Divider(height: 24),
                const Text(
                  'Products:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                if ((farmerProfile['products'] as List).isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No products added yet'),
                  )
                else
                  ...(farmerProfile['products'] as List).map<Widget>((product) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.agriculture, size: 16, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${product['name']} (${product['quantity']}) - MWK ${product['price']}',
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileInfo({required IconData icon, required String label, required String value}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.green),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ],
    );
  }

  void _showEarningsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Total Earnings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.attach_money,
                  size: 60,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'MWK ${(farmerProfile['totalEarnings'] ?? 0).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Total earnings from all completed sales',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showMyProduceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('My Produce'),
          content: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: (farmerProfile['products'] as List).isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.agriculture, size: 50, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No produce added yet'),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: (farmerProfile['products'] as List).length,
                    itemBuilder: (context, index) {
                      var product = (farmerProfile['products'] as List)[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.agriculture, color: Colors.green),
                          title: Text(
                            product['name'] ?? 'Unknown',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Price: MWK ${product['price'] ?? 0}'),
                              Text('Quantity: ${product['quantity'] ?? 'N/A'}'),
                              Text('Location: ${product['location'] ?? 'Unknown'}'),
                            ],
                          ),
                          trailing: Text(
                            _formatDate(product['dateAdded']),
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showOrdersDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('New Orders'),
          content: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: (farmerProfile['orders'] as List).isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shopping_cart, size: 50, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No new orders at the moment'),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: (farmerProfile['orders'] as List).length,
                    itemBuilder: (context, index) {
                      var order = (farmerProfile['orders'] as List)[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.shopping_cart, color: Colors.blue),
                          title: Text(order['product'] ?? 'Unknown'),
                          subtitle: Text('Customer: ${order['customer'] ?? 'Unknown'}\nQuantity: ${order['quantity'] ?? 0}'),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              order['status'] ?? 'pending',
                              style: const TextStyle(color: Colors.orange, fontSize: 12),
                            ),
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(dynamic dateTime) {
    if (dateTime == null) return 'Unknown date';
    
    try {
      if (dateTime is Timestamp) {
        DateTime date = dateTime.toDate();
        return '${date.day}/${date.month}/${date.year}';
      } else if (dateTime is String) {
        DateTime date = DateTime.parse(dateTime);
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return 'Unknown date';
    }
    return 'Unknown date';
  }

  @override
  void dispose() {
    produceNameController.dispose();
    unitPriceController.dispose();
    locationController.dispose();
    quantityController.dispose();
    super.dispose();
  }
}