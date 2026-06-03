// farmers_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/remember_me_service.dart';
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

      // Fetch only farmer's products
      final productsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('farmerId', isEqualTo: user.uid)
          .get();
      final farmerProductIds = productsSnapshot.docs
          .map((doc) => doc.id)
          .toSet();

      // OPTIMIZED: Query only orders where farmerIds array contains this farmer
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('farmerIds', arrayContains: user.uid)
          .get();

      double totalEarnings = 0.0;
      final List<Map<String, dynamic>> orders = [];

      for (var orderDoc in ordersSnapshot.docs) {
        final order = orderDoc.data();
        final orderStatus = (order['orderStatus'] ?? order['status'] ?? '')
            .toString()
            .toLowerCase();
        final paymentStatus = (order['paymentStatus'] ?? '')
            .toString()
            .toLowerCase();

        // Get embedded items from order document (most common pattern)
        final embeddedItems = order['items'] is List
            ? order['items'] as List
            : [];

        double farmerItemQuantity = 0.0;
        double farmerItemEarnings = 0.0;
        final List<Map<String, dynamic>> farmerItems = [];

        // Process embedded items only (avoid subcollection read)
        for (final item in embeddedItems.whereType<Map>()) {
          final itemMap = Map<String, dynamic>.from(item);
          final double price = _toDouble(itemMap['price']);
          final double quantity = _toDouble(itemMap['quantity']);

          farmerItemQuantity += quantity;
          farmerItemEarnings += _toDouble(
            itemMap['totalPrice'],
            fallback: price * quantity,
          );
          farmerItems.add(itemMap);
        }

        if (paymentStatus == 'completed' ||
            paymentStatus == 'paid' ||
            orderStatus == 'completed' ||
            orderStatus == 'delivered') {
          totalEarnings += farmerItemEarnings;
        }

        orders.add({
          ...order,
          'id': orderDoc.id,
          'productName':
              order['productName'] ?? order['product'] ?? 'Unknown Product',
          'customerName':
              order['customerName'] ?? order['customer'] ?? 'Unknown Customer',
          'quantity': farmerItemQuantity,
          'status': orderStatus.isNotEmpty ? orderStatus : 'pending',
          'paymentStatus': paymentStatus.isNotEmpty ? paymentStatus : 'pending',
          'totalPrice': order['totalPrice'] ?? order['totalAmount'] ?? 0,
          'farmerEarnings': farmerItemEarnings,
          'items': farmerItems,
        });
      }

      return {
        'name': userData['name'] ?? 'Unknown Farmer',
        'location': userData['location'] ?? 'Unknown',
        'totalEarnings': totalEarnings,
        'products': productsSnapshot.docs.map((doc) {
          final data = doc.data();
          final int total = (data['quantity'] ?? 0).toInt();
          final int available = (data['availableQuantity'] ?? total).toInt();
          return {
            'id': doc.id,
            ...data,
            'realAvailable': available,
            'isOversold': available < 0,
          };
        }).toList(),
        'orders': orders,
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

  double _toDouble(dynamic value, {double fallback = 0.0}) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  List<Map<String, dynamic>> _buildProduceDemandStats() {
    final statsByProduct = <String, Map<String, dynamic>>{};

    final products = farmerProfile['products'] is List
        ? farmerProfile['products'] as List
        : const [];
    final orders = farmerProfile['orders'] is List
        ? farmerProfile['orders'] as List
        : const [];

    for (final product in products.whereType<Map>()) {
      final name = (product['name'] ?? 'Unnamed Product').toString();
      statsByProduct[name] = {
        'name': name,
        'quantity': 0.0,
        'orders': 0,
        'earnings': 0.0,
        'lastOrdered': null,
      };
    }

    for (final order in orders.whereType<Map>()) {
      final orderData = Map<String, dynamic>.from(order);
      final orderDate = _readOrderDate(orderData);
      final items = orderData['items'] is List
          ? orderData['items'] as List
          : [];

      if (items.isEmpty) {
        final name = (orderData['productName'] ?? 'Unknown Product').toString();
        _addDemandStat(
          statsByProduct,
          name,
          _toDouble(orderData['quantity']),
          _toDouble(orderData['farmerEarnings']),
          orderDate,
        );
        continue;
      }

      for (final item in items.whereType<Map>()) {
        final name = (item['productName'] ?? item['name'] ?? 'Unknown Product')
            .toString();
        final price = _toDouble(item['price']);
        final quantity = _toDouble(item['quantity']);
        _addDemandStat(
          statsByProduct,
          name,
          quantity,
          _toDouble(item['totalPrice'], fallback: price * quantity),
          orderDate,
        );
      }
    }

    final stats = statsByProduct.values.toList();
    stats.sort(
      (a, b) => _toDouble(b['quantity']).compareTo(_toDouble(a['quantity'])),
    );
    return stats;
  }

  void _addDemandStat(
    Map<String, Map<String, dynamic>> statsByProduct,
    String productName,
    double quantity,
    double earnings,
    DateTime? orderDate,
  ) {
    final stats = statsByProduct.putIfAbsent(productName, () {
      return {
        'name': productName,
        'quantity': 0.0,
        'orders': 0,
        'earnings': 0.0,
        'lastOrdered': null,
      };
    });

    stats['quantity'] = _toDouble(stats['quantity']) + quantity;
    stats['orders'] = (stats['orders'] as int? ?? 0) + 1;
    stats['earnings'] = _toDouble(stats['earnings']) + earnings;

    final lastOrdered = stats['lastOrdered'];
    if (orderDate != null &&
        (lastOrdered is! DateTime || orderDate.isAfter(lastOrdered))) {
      stats['lastOrdered'] = orderDate;
    }
  }

  DateTime? _readOrderDate(Map<String, dynamic> order) {
    final rawDate = order['paidAt'] ?? order['timestamp'] ?? order['createdAt'];
    if (rawDate is Timestamp) return rawDate.toDate();
    if (rawDate is DateTime) return rawDate;
    if (rawDate is String) return DateTime.tryParse(rawDate);
    return null;
  }

  bool _isCompletedOrder(Map<String, dynamic> order) {
    final orderStatus = (order['status'] ?? order['orderStatus'] ?? '')
        .toString()
        .toLowerCase();
    final paymentStatus = (order['paymentStatus'] ?? '')
        .toString()
        .toLowerCase();

    return paymentStatus == 'completed' ||
        paymentStatus == 'paid' ||
        orderStatus == 'completed' ||
        orderStatus == 'delivered';
  }

  List<Map<String, dynamic>> _ordersByCompletion({required bool completed}) {
    final orders = farmerProfile['orders'] is List
        ? farmerProfile['orders'] as List
        : const [];

    return orders
        .whereType<Map>()
        .map((order) => Map<String, dynamic>.from(order))
        .where((order) => _isCompletedOrder(order) == completed)
        .toList();
  }

  /// Group orders by customer name for better organization
  Map<String, List<Map<String, dynamic>>> _groupOrdersByCustomer(
    List<Map<String, dynamic>> orders,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final order in orders) {
      final customerName =
          order['customerName']?.toString() ?? 'Unknown Customer';
      grouped.putIfAbsent(customerName, () => []).add(order);
    }
    return grouped;
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
                children: const [
                  Icon(Icons.person, size: 18),
                  SizedBox(width: 6),
                  Text(
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
      drawer: _buildDrawer(),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final demandStats = _buildProduceDemandStats();
    final pendingOrders = _ordersByCompletion(completed: false);
    final completedOrders = _ordersByCompletion(completed: true);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back,',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green[700],
            ),
          ),
          Text(
            farmerProfile['name'],
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 10),

          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildStatCard(
                    title: 'Total Earnings',
                    value:
                        'MWK ${farmerProfile['totalEarnings'].toStringAsFixed(2)}',
                    icon: Icons.attach_money,
                    color: Colors.green,
                    onTap: () => _showEarningsDialog(context),
                  ),
                  _buildStatCard(
                    title: 'My Produce',
                    value: '${farmerProfile['products'].length} items',
                    icon: Icons.agriculture,
                    color: Colors.orange,
                    onTap: _openMyProducePage,
                  ),
                  _buildStatCard(
                    title: 'Pending Orders',
                    value: '${pendingOrders.length} pending',
                    icon: Icons.pending_actions,
                    color: Colors.blue,
                    onTap: () => _openOrdersPage(
                      title: 'Pending Orders',
                      orders: pendingOrders,
                      emptyMessage: 'No pending orders at the moment',
                      icon: Icons.pending_actions,
                      color: Colors.blue,
                    ),
                  ),
                  _buildStatCard(
                    title: 'Completed Orders',
                    value: '${completedOrders.length} completed',
                    icon: Icons.task_alt,
                    color: Colors.green,
                    onTap: () => _openOrdersPage(
                      title: 'Completed Orders',
                      orders: completedOrders,
                      emptyMessage: 'No completed orders yet',
                      icon: Icons.task_alt,
                      color: Colors.green,
                    ),
                  ),
                  _buildStatCard(
                    title: 'Demand Trends',
                    value: 'Demand Trends',
                    icon: Icons.insights,
                    color: Colors.teal,
                    onTap: _openDemandStatsPage,
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width - 24,
                    child: _buildDemandOverview(demandStats),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 170,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 28, color: color),
                const SizedBox(height: 10),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openAddProducePage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddProducePage()),
    ).then((result) {
      if (result != null) {
        _loadData();
      }
    });
  }

  Widget _buildDrawer() {
    final pendingOrders = _ordersByCompletion(completed: false);
    final completedOrders = _ordersByCompletion(completed: true);

    return Drawer(
      child: Container(
        color: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              height: MediaQuery.of(context).size.height * 0.25,
              decoration: BoxDecoration(color: Colors.green[700]),
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
                _openMyProducePage();
              },
            ),
            _buildDrawerItem(
              icon: Icons.pending_actions,
              title: 'Pending Orders',
              subtitle: '${pendingOrders.length} pending orders',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                _openOrdersPage(
                  title: 'Pending Orders',
                  orders: pendingOrders,
                  emptyMessage: 'No pending orders at the moment',
                  icon: Icons.pending_actions,
                  color: Colors.blue,
                );
              },
            ),
            _buildDrawerItem(
              icon: Icons.task_alt,
              title: 'Completed Orders',
              subtitle: '${completedOrders.length} completed orders',
              color: Colors.green,
              onTap: () {
                Navigator.pop(context);
                _openOrdersPage(
                  title: 'Completed Orders',
                  orders: completedOrders,
                  emptyMessage: 'No completed orders yet',
                  icon: Icons.task_alt,
                  color: Colors.green,
                );
              },
            ),
            _buildDrawerItem(
              icon: Icons.insights,
              title: 'Demand Trends',
              subtitle: 'Customer demand by produce',
              color: Colors.teal,
              onTap: () {
                Navigator.pop(context);
                _openDemandStatsPage();
              },
            ),
            _buildDrawerItem(
              icon: Icons.add_box,
              title: 'Add Produce',
              subtitle: 'Post new items to marketplace',
              color: Colors.purple,
              onTap: () {
                Navigator.pop(context);
                _openAddProducePage();
              },
            ),
            const SizedBox(height: 20),
            const Divider(),
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

  Widget _buildDemandOverview(List<Map<String, dynamic>> stats) {
    final topStats = stats.take(4).toList();
    final totalQuantity = stats.fold<double>(
      0,
      (sum, item) => sum + _toDouble(item['quantity']),
    );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: Colors.teal[700]),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Produce Demand',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                TextButton(
                  onPressed: _openDemandStatsPage,
                  child: const Text('View'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (topStats.isEmpty || totalQuantity == 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No customer demand data yet. Orders will appear here after customers buy your produce.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ...topStats.map((stat) {
                return _buildDemandBar(
                  name: stat['name'].toString(),
                  quantity: _toDouble(stat['quantity']),
                  maxQuantity: _toDouble(topStats.first['quantity']),
                  orders: stat['orders'] as int? ?? 0,
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildDemandBar({
    required String name,
    required double quantity,
    required double maxQuantity,
    required int orders,
  }) {
    final percent = maxQuantity <= 0
        ? 0.0
        : (quantity / maxQuantity).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 1)} units',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 9,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.teal[600]!),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '$orders customer order${orders == 1 ? '' : 's'}',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProduct(String productId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Product'),
          content: const Text(
            'Are you sure you want to delete this product? This action cannot be undone.',
          ),
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
      await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .delete();
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
              const Expanded(
                child: Text(
                  'Farmer Profile',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width > 520
                ? 480
                : double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.62,
            child: Scrollbar(
              child: SingleChildScrollView(
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
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                RememberMeService.markSignedOut();
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/signin');
                }
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
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

  void _openDemandStatsPage() {
    final stats = _buildProduceDemandStats();
    final orderedStats = stats
        .where((stat) => _toDouble(stat['quantity']) > 0)
        .toList();
    final maxQuantity = orderedStats.isEmpty
        ? 0.0
        : _toDouble(orderedStats.first['quantity']);
    final totalOrders = orderedStats.fold<int>(
      0,
      (sum, stat) => sum + (stat['orders'] as int? ?? 0),
    );
    final totalQuantity = orderedStats.fold<double>(
      0,
      (sum, stat) => sum + _toDouble(stat['quantity']),
    );
    final totalEarnings = orderedStats.fold<double>(
      0,
      (sum, stat) => sum + _toDouble(stat['earnings']),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: const Text('Produce Demand Trends'),
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: orderedStats.isEmpty
                    ? const Center(
                        child: Text(
                          'No demand trend yet. Customer orders will create statistics here.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : Column(
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildMiniMetric(
                                'Orders',
                                totalOrders.toString(),
                                Icons.receipt_long,
                                Colors.blue,
                              ),
                              _buildMiniMetric(
                                'Units Needed',
                                totalQuantity.toStringAsFixed(
                                  totalQuantity % 1 == 0 ? 0 : 1,
                                ),
                                Icons.inventory_2,
                                Colors.teal,
                              ),
                              _buildMiniMetric(
                                'Value',
                                'MWK ${totalEarnings.toStringAsFixed(2)}',
                                Icons.payments,
                                Colors.green,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Expanded(
                            child: ListView.builder(
                              itemCount: orderedStats.length,
                              itemBuilder: (context, index) {
                                final stat = orderedStats[index];
                                final lastOrdered = stat['lastOrdered'];

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                stat['name'].toString(),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '${stat['orders']} orders',
                                              style: TextStyle(
                                                color: Colors.grey[700],
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        _buildDemandBar(
                                          name: 'Customer demand',
                                          quantity: _toDouble(stat['quantity']),
                                          maxQuantity: maxQuantity,
                                          orders: stat['orders'] as int? ?? 0,
                                        ),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Earnings: MWK ${_toDouble(stat['earnings']).toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                            ),
                                            if (lastOrdered is DateTime)
                                              Text(
                                                'Last: ${lastOrdered.day}/${lastOrdered.month}/${lastOrdered.year}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMiniMetric(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return SizedBox(
      width: 150,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ UPDATED: REAL-TIME MY PRODUCE PAGE
  void _openMyProducePage() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (pageContext) => Scaffold(
          appBar: AppBar(
            title: const Text('My Produce'),
            backgroundColor: Colors.green[700],
            foregroundColor: Colors.white,
          ),
          body: StreamBuilder<QuerySnapshot>(
            // REAL-TIME LISTENER
            stream: FirebaseFirestore.instance
                .collection('products')
                .where('farmerId', isEqualTo: user.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return Center(child: Text('Error: ${snapshot.error}'));
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Center(child: Text('No produce added yet.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final id = docs[index].id;

                  // Inventory Stock Logic
                  final int totalQty = (data['quantity'] ?? 0).toInt();
                  final int availableQty =
                      (data['availableQuantity'] ?? totalQty).toInt();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.green,
                        child: Icon(Icons.agriculture, color: Colors.white),
                      ),
                      title: Text(
                        data['name'] ?? 'Unnamed',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Price: MWK ${data['price']}'),
                          Text(
                            'Available: $availableQty',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: availableQty <= 0
                                  ? Colors.red
                                  : Colors.black87,
                            ),
                          ),
                          if (availableQty < 0)
                            const Text(
                              '⚠️ OVERSOLD',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddProducePage(
                                  isEditing: true,
                                  existingProduct: data,
                                  productId: id,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteProduct(id),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: Colors.green[700],
            child: const Icon(Icons.add, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddProducePage()),
            ),
          ),
        ),
      ),
    ).then((_) => _loadData()); // Refresh summary cards on return
  }

  void _showOrdersDialog(
    BuildContext context, {
    required String title,
    required List<Map<String, dynamic>> orders,
    required String emptyMessage,
    required IconData icon,
    required Color color,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.6,
            child: orders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 50, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(emptyMessage),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      var order = orders[index];
                      final status = order['status']?.toString() ?? 'pending';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(icon, color: color),
                          title: Text(
                            order['productName']?.toString() ??
                                'Unknown Product',
                          ),
                          subtitle: Text(
                            'Customer: ${order['customerName']?.toString() ?? "Unknown"}\nQuantity needed: ${order['quantity']?.toString() ?? "0"}\nStatus: ${order['paymentStatus']?.toString() ?? order['status']?.toString() ?? 'pending'}',
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(color: color, fontSize: 12),
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

  void _openOrdersPage({
    required String title,
    required List<Map<String, dynamic>> orders,
    required String emptyMessage,
    required IconData icon,
    required Color color,
  }) {
    final isCompletedOrders = title.toLowerCase().contains('completed');
    final groupedOrders = _groupOrdersByCustomer(orders);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: Text(title),
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: groupedOrders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 56, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(emptyMessage),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: groupedOrders.keys.length,
                        itemBuilder: (context, customerIndex) {
                          final customerName = groupedOrders.keys.elementAt(
                            customerIndex,
                          );
                          final customerOrders = groupedOrders[customerName]!;
                          final totalItems = customerOrders.fold<double>(
                            0,
                            (sum, order) =>
                                sum +
                                _toDouble(order['quantity'], fallback: 1.0),
                          );
                          final totalValue = customerOrders.fold<double>(
                            0,
                            (sum, order) =>
                                sum +
                                _toDouble(
                                  order['totalPrice'] ??
                                      order['farmerEarnings'],
                                  fallback: 0.0,
                                ),
                          );

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            child: ExpansionTile(
                              title: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: color.withOpacity(0.3),
                                    child: Icon(
                                      Icons.person,
                                      color: color,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          customerName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          '${customerOrders.length} order${customerOrders.length > 1 ? 's' : ''} • $totalItems items',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'MWK ${totalValue.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    children: [
                                      ...customerOrders.asMap().entries.map((
                                        entry,
                                      ) {
                                        final orderIndex = entry.key;
                                        final order = entry.value;
                                        final status =
                                            order['status']
                                                ?.toString()
                                                .toUpperCase() ??
                                            'PENDING';
                                        final items = order['items'] is List
                                            ? order['items'] as List
                                            : [];

                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (orderIndex > 0) const Divider(),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  'Order #${order['id']?.toString().substring(0, 8).toUpperCase() ?? orderIndex}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: status == 'PENDING'
                                                        ? Colors.orange
                                                              .withOpacity(0.2)
                                                        : Colors.green
                                                              .withOpacity(0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    status,
                                                    style: TextStyle(
                                                      color: status == 'PENDING'
                                                          ? Colors.orange[700]
                                                          : Colors.green[700],
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            // Product details
                                            ...items.whereType<Map>().map((
                                              item,
                                            ) {
                                              return Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 4,
                                                    ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        '${item['productName'] ?? item['name'] ?? 'Unknown'} x${_toDouble(item['quantity']).toStringAsFixed(0)}',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      'MWK ${_toDouble(item['totalPrice']).toStringAsFixed(0)}',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }),
                                            if (items.isEmpty)
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 4,
                                                    ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        '${order['productName'] ?? 'Unknown'} x${_toDouble(order['quantity']).toStringAsFixed(0)}',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      'MWK ${_toDouble(order['totalPrice'] ?? order['farmerEarnings']).toStringAsFixed(0)}',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            const SizedBox(height: 8),
                                            // Assign to Logistics button (only for completed)
                                            if (isCompletedOrders)
                                              Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: ElevatedButton.icon(
                                                  onPressed: () =>
                                                      _showAssignLogisticsDialog(
                                                        context,
                                                        order,
                                                      ),
                                                  icon: const Icon(
                                                    Icons
                                                        .local_shipping_outlined,
                                                  ),
                                                  label: const Text(
                                                    'Assign to Logistics',
                                                  ),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.green[600],
                                                        foregroundColor:
                                                            Colors.white,
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 16,
                                                          vertical: 8,
                                                        ),
                                                      ),
                                                ),
                                              ),
                                          ],
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAssignLogisticsDialog(
    BuildContext context,
    Map<String, dynamic> order,
  ) async {
    showDialog(
      context: context,
      builder: (dialogContext) => FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .where('userType', isEqualTo: 'logistics_company')
            .get(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return AlertDialog(
              title: const Text('Error'),
              content: Text(
                'Error loading logistics companies: ${snapshot.error}',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return AlertDialog(
              content: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading logistics companies...'),
                  ],
                ),
              ),
            );
          }

          final companies = snapshot.data?.docs ?? [];
          if (companies.isEmpty) {
            return AlertDialog(
              title: const Text('No Logistics Companies'),
              content: const Text(
                'No logistics companies available. Please contact the administrator.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          }

          return AlertDialog(
            title: const Text('Assign to Logistics Company'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: companies.length,
                itemBuilder: (context, index) {
                  final company =
                      companies[index].data() as Map<String, dynamic>;
                  final companyId = companies[index].id;
                  final companyName =
                      company['companyName'] ?? company['name'] ?? 'Unknown';
                  final phone = company['phone'] ?? 'N/A';
                  final location = company['location'] ?? 'N/A';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue[100],
                        child: const Icon(
                          Icons.local_shipping,
                          color: Colors.blue,
                        ),
                      ),
                      title: Text(
                        companyName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Phone: $phone',
                            style: const TextStyle(fontSize: 11),
                          ),
                          Text(
                            'Location: $location',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                      trailing: ElevatedButton(
                        onPressed: () => _assignOrderToLogistics(
                          order,
                          companyId,
                          companyName,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                        ),
                        child: const Text(
                          'Select',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _assignOrderToLogistics(
    Map<String, dynamic> order,
    String companyId,
    String companyName,
  ) async {
    try {
      final orderId = order['id']?.toString();
      if (orderId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Order ID not found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Update order with logistics assignment
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
            'assignedLogisticsCompanyId': companyId,
            'assignedLogisticsCompanyName': companyName,
            'logisticsAssignedAt': FieldValue.serverTimestamp(),
            'logisticsStatus': 'assigned',
          });

      if (mounted) {
        Navigator.pop(context); // Close logistics selection dialog
        Navigator.pop(context); // Close orders page

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Order assigned to $companyName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Refresh farmer data
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error assigning order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
