import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/admin_services.dart';
import 'admin_products_page.dart';
import 'admin_orders_page.dart';
import 'admin_users_page.dart';  // This now handles both customers and farmers
import 'admin_reports_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  String _adminName = 'Admin';
  String _adminRole = '';
  bool _isLoading = true;

  // REMOVED AdminFarmersPage - now using AdminUsersPage for all users
  final List<Widget> _pages = [
    const DashboardHome(),
    const AdminProductsPage(),
    const AdminOrdersPage(),
    const AdminUsersPage(),    // This shows BOTH customers and farmers
    const AdminReportsPage(),
  ];

  final List<String> _titles = [
    'Dashboard',
    'Manage Products',
    'Manage Orders',
    'Manage Users',    // Changed from 'Manage Farmers' to 'Manage Users'
    'Reports',
  ];

  final List<IconData> _icons = [
    Icons.dashboard,
    Icons.inventory,
    Icons.shopping_cart,
    Icons.people,      // Changed from Icons.agriculture to Icons.people
    Icons.bar_chart,
  ];

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    try {
      final adminData = await AdminService.getCurrentAdmin();
      final role = await AdminService.getAdminRole();
      setState(() {
        _adminName = adminData?['name'] ?? 'Administrator';
        _adminRole = role ?? 'admin';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/signin');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _adminRole.toUpperCase(),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _pages[_selectedIndex],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            color: const Color(0xFF2E7D32),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.admin_panel_settings,
                    size: 40,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _adminName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _adminRole.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _titles.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: Icon(
                    _icons[index],
                    color: _selectedIndex == index
                        ? const Color(0xFF2E7D32)
                        : Colors.grey,
                  ),
                  title: Text(
                    _titles[index],
                    style: TextStyle(
                      color: _selectedIndex == index
                          ? const Color(0xFF2E7D32)
                          : Colors.black87,
                      fontWeight: _selectedIndex == index
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  selected: _selectedIndex == index,
                  selectedTileColor: Colors.green[50],
                  onTap: () {
                    setState(() {
                      _selectedIndex = index;
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout'),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}

// Dashboard Home Widget
class DashboardHome extends StatefulWidget {
  const DashboardHome({super.key});

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    
    try {
      final firestore = FirebaseFirestore.instance;
      
      // Get all users
      final usersSnapshot = await firestore.collection('users').get();
      
      // Get farmers (userType == 'farmer')
      final farmersSnapshot = await firestore
          .collection('users')
          .where('userType', isEqualTo: 'farmer')
          .get();
      
      // Get customers (userType == 'customer')
      final customersSnapshot = await firestore
          .collection('users')
          .where('userType', isEqualTo: 'customer')
          .get();
      
      // Get all products
      final productsSnapshot = await firestore.collection('products').get();
      
      // Get all orders
      final ordersSnapshot = await firestore.collection('orders').get();
      
      // Calculate revenue from orders
      double totalRevenue = 0;
      int completedOrders = 0;
      int pendingOrders = 0;
      int deliveredOrders = 0;
      
      for (var doc in ordersSnapshot.docs) {
        final data = doc.data();
        final paymentStatus = data['paymentStatus'] ?? data['status'] ?? 'pending';
        final orderStatus = data['orderStatus'] ?? data['status'] ?? 'pending';
        final amount = (data['totalAmount'] ?? data['totalPrice'] ?? 0).toDouble();
        
        if (paymentStatus == 'completed' || paymentStatus == 'paid' || orderStatus == 'delivered') {
          totalRevenue += amount;
          completedOrders++;
        }
        
        if (orderStatus == 'pending') pendingOrders++;
        if (orderStatus == 'delivered') deliveredOrders++;
      }
      
      setState(() {
        _stats = {
          'totalUsers': usersSnapshot.size,
          'totalFarmers': farmersSnapshot.size,
          'totalCustomers': customersSnapshot.size,
          'totalProducts': productsSnapshot.size,
          'totalOrders': ordersSnapshot.size,
          'completedOrders': completedOrders,
          'pendingOrders': pendingOrders,
          'deliveredOrders': deliveredOrders,
          'totalRevenue': totalRevenue,
        };
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading stats: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Stats Cards - Row 1
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.3,
              children: [
                _buildStatCard(
                  title: 'Total Users',
                  value: _stats['totalUsers'].toString(),
                  icon: Icons.people,
                  color: Colors.blue,
                ),
                _buildStatCard(
                  title: 'Farmers',
                  value: _stats['totalFarmers'].toString(),
                  icon: Icons.agriculture,
                  color: Colors.green,
                ),
                _buildStatCard(
                  title: 'Customers',
                  value: _stats['totalCustomers'].toString(),
                  icon: Icons.shopping_cart,
                  color: Colors.orange,
                ),
                _buildStatCard(
                  title: 'Products',
                  value: _stats['totalProducts'].toString(),
                  icon: Icons.inventory,
                  color: Colors.purple,
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Stats Cards - Row 2
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.3,
              children: [
                _buildStatCard(
                  title: 'Total Orders',
                  value: _stats['totalOrders'].toString(),
                  icon: Icons.receipt,
                  color: Colors.teal,
                ),
                _buildStatCard(
                  title: 'Pending Orders',
                  value: _stats['pendingOrders'].toString(),
                  icon: Icons.pending,
                  color: Colors.orange,
                ),
                _buildStatCard(
                  title: 'Delivered',
                  value: _stats['deliveredOrders'].toString(),
                  icon: Icons.delivery_dining,
                  color: Colors.green,
                ),
                _buildStatCard(
                  title: 'Revenue',
                  value: 'MK ${_stats['totalRevenue'].toStringAsFixed(2)}',
                  icon: Icons.attach_money,
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Recent Orders
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recent Orders',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('orders')
                          .orderBy('timestamp', descending: true)
                          .limit(5)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        }
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        final orders = snapshot.data!.docs;
                        if (orders.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text('No orders yet'),
                            ),
                          );
                        }
                        
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: orders.length,
                          itemBuilder: (context, index) {
                            final order = orders[index];
                            final data = order.data() as Map<String, dynamic>;
                            
                            final orderId = data['orderId'] ?? order.id;
                            final customerName = data['customerName'] ?? 'Unknown';
                            final totalAmount = (data['totalAmount'] ?? data['totalPrice'] ?? 0).toDouble();
                            final orderStatus = data['orderStatus'] ?? data['status'] ?? 'pending';
                            
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getStatusColor(orderStatus),
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                              title: Text(
                                'Order #${orderId.length > 8 ? orderId.substring(0, 8) : orderId}',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text('$customerName - MWK ${totalAmount.toStringAsFixed(2)}'),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(orderStatus).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  orderStatus,
                                  style: TextStyle(
                                    color: _getStatusColor(orderStatus),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              onTap: () {
                                _showOrderDetails(order.id, data);
                              },
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOrderDetails(String orderId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Order #${orderId.substring(0, 8)}'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Customer:', data['customerName'] ?? 'Unknown'),
                _buildDetailRow('Email:', data['customerEmail'] ?? 'Not provided'),
                _buildDetailRow('Phone:', data['customerPhone'] ?? 'Not provided'),
                const Divider(),
                _buildDetailRow('Total:', 'MWK ${(data['totalAmount'] ?? 0).toStringAsFixed(2)}'),
                _buildDetailRow('Payment:', data['paymentMethod'] ?? 'Not specified'),
                _buildDetailRow('Status:', data['orderStatus'] ?? 'pending'),
                const Divider(),
                const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (data['items'] != null)
                  ...(data['items'] as List).map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• ${item['name']} x ${item['quantity']} = MWK ${(item['price'] * item['quantity']).toStringAsFixed(2)}'),
                  )),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'paid':
      case 'delivered':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'shipped':
        return Colors.purple;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}