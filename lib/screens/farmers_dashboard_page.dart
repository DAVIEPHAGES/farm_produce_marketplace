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
      final farmerName = (userData['name'] ?? user.displayName ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final farmerAliases = {
        user.uid.toLowerCase(),
        if (farmerName.isNotEmpty) farmerName,
        if ((userData['farmName'] ?? '').toString().trim().isNotEmpty)
          (userData['farmName'] ?? '').toString().trim().toLowerCase(),
        if ((userData['displayName'] ?? '').toString().trim().isNotEmpty)
          (userData['displayName'] ?? '').toString().trim().toLowerCase(),
      };

      final productsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('farmerId', isEqualTo: user.uid)
          .get();
      final farmerProductIds = productsSnapshot.docs.map((doc) => doc.id).toSet();

      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
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

        final itemsSnapshot = await orderDoc.reference
            .collection('items')
            .get();
        final embeddedItems = order['items'] is List ? order['items'] as List : [];

        double farmerItemQuantity = 0.0;
        double farmerItemEarnings = 0.0;
        final List<Map<String, dynamic>> farmerItems = [];

        final allItems = <Map<String, dynamic>>[
          ...itemsSnapshot.docs.map((itemDoc) => itemDoc.data()),
          ...embeddedItems
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item)),
        ];

        bool belongsToFarmer = _orderBelongsToFarmer(order, farmerAliases);

        for (final item in allItems) {
          if (!_itemBelongsToFarmer(item, farmerAliases, farmerProductIds)) {
            continue;
          }

          belongsToFarmer = true;
          final double price = _toDouble(item['price']);
          final double quantity = _toDouble(item['quantity']);

          farmerItemQuantity += quantity;
          farmerItemEarnings += _toDouble(item['totalPrice'], fallback: price * quantity);
          farmerItems.add(item);
        }

        if (!belongsToFarmer) {
          continue;
        }

        if (farmerItems.isEmpty) {
          farmerItemQuantity = _toDouble(order['quantity']);
          farmerItemEarnings = _toDouble(order['farmerEarnings'],
              fallback: _toDouble(order['totalPrice'] ?? order['totalAmount']));
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
        // ✅ UPDATED: Added real-time availableQuantity logic to the fetching phase
        'products': productsSnapshot.docs
            .map((doc) {
              final data = doc.data();
              final int total = (data['quantity'] ?? 0).toInt();
              // Look for availableQuantity, fallback to quantity
              final int available = (data['availableQuantity'] ?? total).toInt();
              return {
                'id': doc.id, 
                ...data, 
                'realAvailable': available,
                'isOversold': available < 0
              };
            })
            .toList(),
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

  bool _orderBelongsToFarmer(
    Map<String, dynamic> order,
    Set<String> farmerAliases,
  ) {
    final farmerIds = order['farmerIds'];
    if (farmerIds is List) {
      return farmerIds.any(
        (id) => farmerAliases.contains(id.toString().trim().toLowerCase()),
      );
    }

    final farmerId = (order['farmerId'] ?? order['ownerId'] ?? '').toString();
    if (farmerId.trim().isNotEmpty &&
        farmerAliases.contains(farmerId.trim().toLowerCase())) {
      return true;
    }

    final farmerName = (order['farmerName'] ?? order['farmer'] ?? '').toString();
    return farmerName.trim().isNotEmpty &&
        farmerAliases.contains(farmerName.trim().toLowerCase());
  }

  bool _itemBelongsToFarmer(
    Map<String, dynamic> item,
    Set<String> farmerAliases,
    Set<String> farmerProductIds,
  ) {
    final farmerId = (item['farmerId'] ?? item['ownerId'] ?? '').toString();
    if (farmerId.trim().isNotEmpty &&
        farmerAliases.contains(farmerId.trim().toLowerCase())) {
      return true;
    }

    final farmerName = (item['farmerName'] ?? item['farmer'] ?? '').toString();
    if (farmerName.trim().isNotEmpty &&
        farmerAliases.contains(farmerName.trim().toLowerCase())) {
      return true;
    }

    final productId = (item['productId'] ?? item['id'] ?? '').toString();
    return productId.trim().isNotEmpty && farmerProductIds.contains(productId);
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
      final items = orderData['items'] is List ? orderData['items'] as List : [];

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
    stats.sort((a, b) => _toDouble(b['quantity']).compareTo(_toDouble(a['quantity'])));
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
      MaterialPageRoute(
        builder: (context) => const AddProducePage(),
      ),
    ).then((result) {
      if (result != null) {
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Produce added successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
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
    final percent = maxQuantity <= 0 ? 0.0 : (quantity / maxQuantity).clamp(0.0, 1.0);

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

  Future<void> _deleteProduct(String productId, int index) async {
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
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                                          quantity:
                                              _toDouble(stat['quantity']),
                                          maxQuantity: maxQuantity,
                                          orders:
                                              stat['orders'] as int? ?? 0,
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

  void _openMyProducePage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (pageContext) {
          return StatefulBuilder(
            builder: (context, refreshPage) {
              final products = farmerProfile['products'] is List
                  ? farmerProfile['products'] as List
                  : const [];

              return Scaffold(
                backgroundColor: Colors.white,
                appBar: AppBar(
                  title: const Text('My Produce'),
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                ),
                body: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Expanded(
                          child: products.isEmpty
                              ? const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.agriculture,
                                        size: 56,
                                        color: Colors.grey,
                                      ),
                                      SizedBox(height: 16),
                                      Text('No produce added yet'),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: products.length,
                                  itemBuilder: (context, index) {
                                    final product = products[index];
                                    final productName =
                                        product['name']?.toString() ??
                                            'Unnamed Product';
                                    final price =
                                        product['price']?.toString() ?? '0';
                                    
                                    // ✅ FIXED: Using real-time available stock logic
                                    final int totalQty = (product['quantity'] ?? 0).toInt();
                                    final int availableQty = (product['realAvailable'] ?? totalQty).toInt();
                                    final String quantityDisplay = availableQty.toString();
                                    
                                    final location =
                                        product['location']?.toString() ??
                                            'Unknown';
                                    final dateAdded =
                                        product['dateAdded']?.toString() ?? '';
                                    final productId =
                                        product['id']?.toString() ?? '';

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        leading: const Icon(
                                          Icons.agriculture,
                                          color: Colors.green,
                                        ),
                                        title: Text(
                                          productName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text('Price: MWK $price'),
                                            // ✅ UPDATED: Visual feedback for oversold or out of stock items
                                            Text(
                                              'Available: $quantityDisplay',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: availableQty < 0 
                                                  ? Colors.red 
                                                  : (availableQty == 0 ? Colors.orange : Colors.black87)
                                              ),
                                            ),
                                            if (availableQty < 0)
                                              const Text(
                                                '⚠️ OVERSOLD (Need to restock)',
                                                style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
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
                                              icon: const Icon(
                                                Icons.edit,
                                                color: Colors.blue,
                                              ),
                                              onPressed: () async {
                                                final result =
                                                    await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        AddProducePage(
                                                      isEditing: true,
                                                      existingProduct: product,
                                                      productId: productId,
                                                    ),
                                                  ),
                                                );
                                                if (result == true) {
                                                  await _loadData();
                                                  refreshPage(() {});
                                                }
                                              },
                                              tooltip: 'Edit product',
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                              ),
                                              onPressed: () async {
                                                await _deleteProduct(
                                                  productId,
                                                  index,
                                                );
                                                refreshPage(() {});
                                              },
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
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const AddProducePage(),
                                ),
                              );
                              if (result != null) {
                                await _loadData();
                                refreshPage(() {});
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Produce added successfully!',
                                      ),
                                      backgroundColor: Colors.green,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Post new item'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              elevation: 3,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
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
                      final status =
                          order['status']?.toString() ?? 'pending';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            icon,
                            color: color,
                          ),
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
                              style: TextStyle(
                                color: color,
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

  void _openOrdersPage({
    required String title,
    required List<Map<String, dynamic>> orders,
    required String emptyMessage,
    required IconData icon,
    required Color color,
  }) {
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
                child: orders.isEmpty
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
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          final status =
                              order['status']?.toString() ?? 'pending';

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
                                  style: TextStyle(
                                    color: color,
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
            ),
          );
        },
      ),
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