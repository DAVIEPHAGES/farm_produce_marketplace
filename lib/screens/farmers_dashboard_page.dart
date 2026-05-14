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

  Future<void> _editProduct(Map<String, dynamic> product, String productId, int index) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddProducePage(
          isEditing: true,
          existingProduct: product,
          productId: productId,
        ),
      ),
    );
    
    if (result == true) {
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Product updated successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
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

    // Calculate responsive sizes based on screen height
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Calculate available height after AppBar and padding
    final appBarHeight = AppBar().preferredSize.height;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final availableHeight = screenHeight - appBarHeight - statusBarHeight - 40; // 40 for padding
    
    // Responsive card height based on available space (fit exactly 2 rows of cards)
    final cardHeight = availableHeight * 0.35; // 35% of available height for each card row
    final cardAspectRatio = screenWidth > 600 ? 1.5 : 1.2; // Wider cards on desktop

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'FARMER DASHBOARD',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 1,
          ),
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, size: 24),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Menu',
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () => _showProfileDialog(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withOpacity(0.2),
              ),
              child: const Row(
                children: [
                  Icon(Icons.person, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'PROFILE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
        centerTitle: false,
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      drawer: Drawer(
        child: Container(
          color: Colors.white,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.green[700],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.agriculture,
                          size: 40,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        farmerProfile['name'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        farmerProfile['location'],
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
                subtitle: '${farmerProfile['products'].length} products',
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  _showMyProduceDialog(context);
                },
              ),
              _buildDrawerItem(
                icon: Icons.shopping_cart,
                title: 'New Orders',
                subtitle: '${farmerProfile['orders'].length} pending',
                color: Colors.blue,
                onTap: () {
                  Navigator.pop(context);
                  _showOrdersDialog(context);
                },
              ),
              _buildDrawerItem(
                icon: Icons.add_box,
                title: 'Add Produce',
                subtitle: 'Post new items',
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
        child: Column(
          children: [
            // Welcome message - compact
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.waving_hand, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome back!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          farmerProfile['name'],
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Dashboard Cards Grid - 2 per row always
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(), // No scrolling
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, // ALWAYS 2 per row
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: cardAspectRatio, // Responsive aspect ratio
                    mainAxisExtent: cardHeight, // Fixed responsive height
                  ),
                  itemCount: 4, // Exactly 4 cards (2 rows)
                  itemBuilder: (context, index) {
                    final cards = [
                      {
                        'title': 'Total Earnings',
                        'value': 'MWK ${(farmerProfile['totalEarnings'] ?? 0).toStringAsFixed(0)}',
                        'icon': Icons.attach_money,
                        'color': Colors.green,
                        'onTap': () => _showEarningsDialog(context),
                      },
                      {
                        'title': 'My Produce',
                        'value': '${farmerProfile['products'].length}',
                        'icon': Icons.agriculture,
                        'color': Colors.orange,
                        'onTap': () => _showMyProduceDialog(context),
                      },
                      {
                        'title': 'New Orders',
                        'value': '${farmerProfile['orders'].length}',
                        'icon': Icons.shopping_cart,
                        'color': Colors.blue,
                        'onTap': () => _showOrdersDialog(context),
                      },
                      {
                        'title': 'Add Produce',
                        'value': 'New',
                        'icon': Icons.add_box,
                        'color': Colors.purple,
                        'onTap': () {
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
                                  content: Text('✓ Produce added!'),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            }
                          });
                        },
                      },
                    ];
                    
                    final card = cards[index];
                    return _buildResponsiveDashboardCard(
                      title: card['title'] as String,
                      value: card['value'] as String,
                      icon: card['icon'] as IconData,
                      color: card['color'] as Color,
                      onTap: card['onTap'] as VoidCallback,
                      screenWidth: screenWidth,
                    );
                  },
                ),
              ),
            ),
            
            // Recent Products Section - Compact (only if products exist)
            if (farmerProfile['products'].isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Products',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (farmerProfile['products'].length > 2)
                      TextButton(
                        onPressed: () => _showMyProduceDialog(context),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(60, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'View all →',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 70,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: farmerProfile['products'].length > 3
                      ? 3
                      : farmerProfile['products'].length,
                  itemBuilder: (context, index) {
                    var product = farmerProfile['products'][index];
                    String productName = product['name']?.toString() ?? 'Unnamed';
                    String price = product['price']?.toString() ?? '0';
                    String productId = product['id']?.toString() ?? '';
                    
                    return Container(
                      width: 130,
                      margin: const EdgeInsets.only(right: 8),
                      child: Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: InkWell(
                          onTap: () => _editProduct(product, productId, index),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.agriculture, size: 14, color: Colors.green[600]),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        productName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'MWK $price',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(Icons.edit, size: 12, color: Colors.blue[300]),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => _deleteProduct(productId, index),
                                      child: Icon(Icons.delete, size: 12, color: Colors.red[300]),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8), // Small bottom padding
            ],
          ],
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
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      onTap: onTap,
    );
  }

  Widget _buildResponsiveDashboardCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required double screenWidth,
  }) {
    // Responsive sizes based on screen width
    final iconSize = screenWidth > 600 ? 32.0 : 28.0;
    final valueFontSize = screenWidth > 600 ? 20.0 : 18.0;
    final titleFontSize = screenWidth > 600 ? 13.0 : 12.0;
    
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: iconSize, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: TextStyle(
                  fontSize: valueFontSize,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: titleFontSize,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteProduct(String productId, int index) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Product'),
          content: const Text('Are you sure?'),
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
            content: Text('✓ Product deleted'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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
                child: const Icon(Icons.person, color: Colors.green, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Farmer Profile',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
        Icon(icon, size: 18, color: Colors.green),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
          title: const Text('Total Earnings', style: TextStyle(fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.attach_money,
                  size: 40,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'MWK ${farmerProfile['totalEarnings'].toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
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
          title: const Text('My Produce', style: TextStyle(fontSize: 16)),
          content: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: farmerProfile['products'].isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.agriculture, size: 40, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('No produce added yet', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: farmerProfile['products'].length,
                    itemBuilder: (context, index) {
                      var product = farmerProfile['products'][index];
                      String productName = product['name']?.toString() ?? 'Unnamed';
                      String price = product['price']?.toString() ?? '0';
                      String quantity = product['quantity']?.toString() ?? '0';
                      String productId = product['id']?.toString() ?? '';
                      
                      return ListTile(
                        leading: const Icon(Icons.agriculture, color: Colors.green, size: 20),
                        title: Text(productName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: Text('MWK $price | Qty: $quantity', style: const TextStyle(fontSize: 11)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                              onPressed: () async {
                                Navigator.pop(context);
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddProducePage(
                                      isEditing: true,
                                      existingProduct: product,
                                      productId: productId,
                                    ),
                                  ),
                                );
                                if (result == true) {
                                  _loadData();
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                              onPressed: () => _deleteProduct(productId, index),
                            ),
                          ],
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
          title: const Text('Orders', style: TextStyle(fontSize: 16)),
          content: Container(
            width: double.maxFinite,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: farmerProfile['orders'].isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shopping_cart, size: 40, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('No orders yet', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: farmerProfile['orders'].length,
                    itemBuilder: (context, index) {
                      var order = farmerProfile['orders'][index];
                      return ListTile(
                        leading: const Icon(Icons.shopping_cart, color: Colors.blue, size: 20),
                        title: Text(order['product']?.toString() ?? 'Unknown', style: const TextStyle(fontSize: 13)),
                        subtitle: Text(
                          'Qty: ${order['quantity']?.toString() ?? "0"}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            order['status']?.toString() ?? 'pending',
                            style: const TextStyle(color: Colors.orange, fontSize: 10),
                          ),
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

  @override
  void dispose() {
    super.dispose();
  }
}