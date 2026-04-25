// farmers_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_produce_page.dart';

class FarmersDashboardPage extends StatefulWidget {
  const FarmersDashboardPage({super.key});

  @override
  State<FarmersDashboardPage> createState() => _FarmersDashboardPageState();
}

class _FarmersDashboardPageState extends State<FarmersDashboardPage> {
  bool _isLoading = true;
  late Map<String, dynamic> farmerProfile;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      farmerProfile = await fetchFarmerData();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading farmer data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> fetchFarmerData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {
        'name': 'Unknown Farmer',
        'location': 'Unknown',
        'totalEarnings': 0.0,
        'products': [],
        'orders': [],
      };
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = doc.data() ?? {};

      final productsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('farmerId', isEqualTo: user.uid)
          .get();

      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('farmerId', isEqualTo: user.uid)
          .get();

      double totalEarnings = 0.0;
      for (var orderDoc in ordersSnapshot.docs) {
        final order = orderDoc.data();
        if (order['status'] == 'completed') {
          totalEarnings += (order['price'] ?? 0.0) * (order['quantity'] ?? 0);
        }
      }

      return {
        'name': userData['name'] ?? 'Unknown Farmer',
        'location': userData['location'] ?? 'Unknown',
        'totalEarnings': totalEarnings,
        'products': productsSnapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
        'orders': ordersSnapshot.docs.map((doc) => doc.data()).toList(),
      };
    } catch (e) {
      print('Error fetching farmer data: $e');
      return {
        'name': 'Unknown Farmer',
        'location': 'Unknown',
        'totalEarnings': 0.0,
        'products': [],
        'orders': [],
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
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
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
      drawer: Drawer(
        child: Container(
          color: Colors.white,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.green[700],
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
                        farmerProfile['name'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        farmerProfile['location'],
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
                subtitle:
                    'MWK ${farmerProfile['totalEarnings'].toStringAsFixed(2)}',
                color: Colors.green,
                onTap: () {
                  Navigator.pop(context);
                  _showEarningsDialog(context);
                },
              ),
              _buildDrawerItem(
                icon: Icons.agriculture,
                title: 'My Produce',
                subtitle: '${farmerProfile['products'].length} products listed',
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  _showMyProduceDialog(context);
                },
              ),
              _buildDrawerItem(
                icon: Icons.shopping_cart,
                title: 'New Orders',
                subtitle: '${farmerProfile['orders'].length} pending orders',
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddProducePage(),
                    ),
                  ).then((result) {
                    if (result != null) {
                      _loadData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✓ Produce added successfully!'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  });
                },
              ),
              const SizedBox(height: 20),
              const Divider(),
            ],
          ),
        ),
      ),
      body: Container(
        color: Colors.white,
        child: SingleChildScrollView(
          child: Column(
            children: [
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
                      farmerProfile['name'],
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 32),
                    
                    // 2x2 Grid Layout (2 cards per row)
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.1,
                      children: [
                        _buildDashboardCard(
                          'Total Earnings',
                          'MWK ${farmerProfile['totalEarnings'].toStringAsFixed(2)}',
                          Icons.attach_money,
                          Colors.green,
                          () => _showEarningsDialog(context),
                        ),
                        _buildDashboardCard(
                          'My Produce',
                          '${farmerProfile['products'].length} items',
                          Icons.agriculture,
                          Colors.orange,
                          () => _showMyProduceDialog(context),
                        ),
                        _buildDashboardCard(
                          'New Orders',
                          '${farmerProfile['orders'].length} pending',
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
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AddProducePage(),
                              ),
                            ).then((result) {
                              if (result != null) {
                                _loadData();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      '✓ Produce added successfully!',
                                    ),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    
                    if (farmerProfile['products'].isNotEmpty) ...[
                      const SizedBox(height: 32),
                      const Text(
                        'Recent Products',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: farmerProfile['products'].length > 3
                            ? 3
                            : farmerProfile['products'].length,
                        itemBuilder: (context, index) {
                          var product = farmerProfile['products'][index];
                          
                          // Safe data extraction
                          String productName = product['name']?.toString() ?? 'Unnamed Product';
                          String price = product['price']?.toString() ?? '0';
                          String quantity = product['quantity']?.toString() ?? '0';
                          String location = product['location']?.toString() ?? 'Unknown';
                          String productId = product['id']?.toString() ?? '';
                          
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
                                productName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('MWK $price'),
                                  Text('Quantity: $quantity'),
                                  Text('📍 $location'),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // ✅ DELETE BUTTON ADDED HERE
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteProduct(productId, index),
                                    tooltip: 'Delete product',
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: Colors.green,
                                  ),
                                ],
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
                      if (farmerProfile['products'].length > 3)
                        TextButton(
                          onPressed: () => _showMyProduceDialog(context),
                          child: const Text('View all products →'),
                        ),
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
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      onTap: onTap,
    );
  }

  Widget _buildDashboardCard(
    String title,
    String value,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
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
                child: Icon(icon, size: 40, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
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
                style: const TextStyle(fontSize: 13, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ IMPROVED DELETE METHOD with confirmation dialog
  Future<void> _deleteProduct(String productId, int index) async {
    // Show confirmation dialog first
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Product'),
          content: const Text('Are you sure you want to delete this product? This action cannot be undone.'),
          backgroundColor: Colors.white,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('products').doc(productId).delete();
      
      setState(() {
        farmerProfile['products'].removeAt(index);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Product deleted successfully!'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting product: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showProfileDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
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
                  value: farmerProfile['name'],
                ),
                const SizedBox(height: 12),
                _buildProfileInfo(
                  icon: Icons.location_on_outlined,
                  label: 'Location',
                  value: farmerProfile['location'],
                ),
                const Divider(height: 24),
                const Text(
                  'Products:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                if (farmerProfile['products'].isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No products added yet'),
                  )
                else
                  ...farmerProfile['products'].map<Widget>((product) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.agriculture,
                            size: 16,
                            color: Colors.green,
                          ),
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
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/signin');
              },
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileInfo({
    required IconData icon,
    required String label,
    required String value,
  }) {
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
          backgroundColor: Colors.white,
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
                'MWK ${farmerProfile['totalEarnings'].toStringAsFixed(2)}',
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
          backgroundColor: Colors.white,
          title: const Text('My Produce'),
          content: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: farmerProfile['products'].isEmpty
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
                    itemCount: farmerProfile['products'].length,
                    itemBuilder: (context, index) {
                      var product = farmerProfile['products'][index];
                      
                      String productName = product['name']?.toString() ?? 'Unnamed Product';
                      String price = product['price']?.toString() ?? '0';
                      String quantity = product['quantity']?.toString() ?? '0';
                      String location = product['location']?.toString() ?? 'Unknown';
                      String dateAdded = product['dateAdded']?.toString() ?? '';
                      String productId = product['id']?.toString() ?? '';
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(
                            Icons.agriculture,
                            color: Colors.green,
                          ),
                          title: Text(
                            productName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Price: MWK $price'),
                              Text('Quantity: $quantity'),
                              Text('Location: $location'),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (dateAdded.isNotEmpty)
                                Text(
                                  _formatDate(dateAdded),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteProduct(productId, index),
                                tooltip: 'Delete product',
                              ),
                            ],
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
          backgroundColor: Colors.white,
          title: const Text('New Orders'),
          content: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: farmerProfile['orders'].isEmpty
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
                    itemCount: farmerProfile['orders'].length,
                    itemBuilder: (context, index) {
                      var order = farmerProfile['orders'][index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(
                            Icons.shopping_cart,
                            color: Colors.blue,
                          ),
                          title: Text(order['product']?.toString() ?? 'Unknown Product'),
                          subtitle: Text(
                            'Customer: ${order['customer']?.toString() ?? "Unknown"}\nQuantity: ${order['quantity']?.toString() ?? "0"}',
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              order['status']?.toString() ?? 'pending',
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                              ),
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

  String _formatDate(String dateTime) {
    try {
      DateTime date = DateTime.parse(dateTime);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown date';
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}