import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  String _selectedYear = '2024';

  Map<String, dynamic> _reportData = {};
  bool _isLoading = true;
  List<String> _availableYears = [];
  List<Map<String, dynamic>> _orders = [];
  Map<String, String> _farmerNames = {};

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);

    try {
      // Get all orders
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .get();
      final farmersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('userType', isEqualTo: 'farmer')
          .get();

      double totalRevenue = 0;
      int totalOrders = 0;
      int completedOrders = 0;
      int pendingOrders = 0;
      int cancelledOrders = 0;
      Map<String, int> productSales = {};
      Map<String, int> categorySales = {};
      Map<String, double> monthlyRevenue = {};

      // Track years for filter
      Set<String> years = {};

      final List<Map<String, dynamic>> loadedOrders = [];
      final farmerNames = <String, String>{};

      for (final farmerDoc in farmersSnapshot.docs) {
        final farmerData = farmerDoc.data();
        final name = _text(
          farmerData['name'] ??
              farmerData['displayName'] ??
              farmerData['fullName'] ??
              farmerData['farmName'],
        );
        if (name.isNotEmpty) {
          farmerNames[farmerDoc.id] = name;
        }
      }

      for (var doc in ordersSnapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        final items = await _loadOrderItems(doc.reference, data);
        data['items'] = items;

        loadedOrders.add({'id': doc.id, 'data': data});

        // Get timestamp
        final timestamp = data['timestamp'];
        if (timestamp is Timestamp) {
          final year = timestamp.toDate().year.toString();
          years.add(year);
        }

        // Get order status - using correct field name
        final orderStatus = (data['orderStatus'] ?? data['status'] ?? 'pending')
            .toString()
            .toLowerCase();
        final paymentStatus = (data['paymentStatus'] ?? 'pending')
            .toString()
            .toLowerCase();

        // Count orders by status
        totalOrders++;

        if (_matchesStatus(orderStatus, paymentStatus, 'completed')) {
          completedOrders++;

          // Safely convert totalAmount
          final totalAmountValue = _toDouble(
            data['totalAmount'] ?? data['totalPrice'] ?? 0,
          );
          totalRevenue += totalAmountValue;

          // Track monthly revenue
          if (timestamp is Timestamp) {
            final date = timestamp.toDate();
            final monthKey =
                '${date.year}-${date.month.toString().padLeft(2, '0')}';
            monthlyRevenue[monthKey] =
                (monthlyRevenue[monthKey] ?? 0) + totalAmountValue;
          }

          // Process items
          for (var item in items) {
            // Use correct field name: 'name' instead of 'productName'
            final productName =
                item['name']?.toString() ??
                item['productName']?.toString() ??
                '';
            final quantity = (item['quantity'] as num?)?.toInt() ?? 0;

            if (productName.isNotEmpty) {
              productSales[productName] =
                  (productSales[productName] ?? 0) + quantity;
            }

            // Track category if available
            final category = item['category']?.toString() ?? 'Uncategorized';
            categorySales[category] = (categorySales[category] ?? 0) + quantity;
          }
        } else if (_matchesStatus(orderStatus, paymentStatus, 'cancelled')) {
          cancelledOrders++;
        } else if (_matchesStatus(orderStatus, paymentStatus, 'pending')) {
          pendingOrders++;
        }
      }

      // Calculate average order value
      final averageOrderValue = completedOrders > 0
          ? totalRevenue / completedOrders
          : 0;

      // Get top selling products (limit to 10)
      final topProducts = productSales.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Get top categories
      final topCategories = categorySales.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Get monthly revenue list
      final monthlyRevenueList = monthlyRevenue.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));

      setState(() {
        _reportData = {
          'totalRevenue': totalRevenue,
          'totalOrders': totalOrders,
          'completedOrders': completedOrders,
          'pendingOrders': pendingOrders,
          'cancelledOrders': cancelledOrders,
          'averageOrderValue': averageOrderValue,
          'topProducts': topProducts.take(10).toList(),
          'topCategories': topCategories.take(5).toList(),
          'monthlyRevenue': monthlyRevenueList.take(12).toList(),
        };
        _orders = loadedOrders;
        _farmerNames = farmerNames;
        _availableYears = years.toList()..sort();
        if (_availableYears.isNotEmpty && _selectedYear == '2024') {
          _selectedYear = _availableYears.last;
        }
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading report: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _loadOrderItems(
    DocumentReference<Map<String, dynamic>> orderRef,
    Map<String, dynamic> orderData,
  ) async {
    final inlineItems = orderData['items'];
    if (inlineItems is List && inlineItems.isNotEmpty) {
      return inlineItems
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    final itemsSnapshot = await orderRef.collection('items').get();
    return itemsSnapshot.docs.map((doc) => doc.data()).toList();
  }

  bool _matchesStatus(String orderStatus, String paymentStatus, String filter) {
    switch (filter) {
      case 'pending':
        return orderStatus == 'pending' ||
            (orderStatus == 'processing' && paymentStatus != 'completed');
      case 'completed':
        return paymentStatus == 'completed' ||
            paymentStatus == 'paid' ||
            orderStatus == 'completed' ||
            orderStatus == 'delivered';
      case 'cancelled':
        return orderStatus == 'cancelled' || paymentStatus == 'failed';
      default:
        return true;
    }
  }

  List<Map<String, dynamic>> _filteredOrders(String filter) {
    if (filter == 'all') return _orders;

    return _orders.where((order) {
      final data = order['data'] as Map<String, dynamic>;
      final orderStatus = (data['orderStatus'] ?? data['status'] ?? 'pending')
          .toString()
          .toLowerCase();
      final paymentStatus = (data['paymentStatus'] ?? 'pending')
          .toString()
          .toLowerCase();
      return _matchesStatus(orderStatus, paymentStatus, filter);
    }).toList();
  }

  void _showOrders(String filter, String title) {
    final orders = _filteredOrders(filter);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.82,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$title (${orders.length})',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: orders.isEmpty
                      ? const Center(child: Text('No orders found'))
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: orders.length,
                          itemBuilder: (context, index) {
                            final order = orders[index];
                            return _buildOrderReportCard(
                              order['id'] as String,
                              order['data'] as Map<String, dynamic>,
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadReport,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // Filter Row
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.filter_alt, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Text('Filter:'),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(_selectedYear),
                        initialValue: _selectedYear,
                        items:
                            (_availableYears.isEmpty
                                    ? <String>[_selectedYear]
                                    : _availableYears)
                                .map((year) {
                                  return DropdownMenuItem(
                                    value: year,
                                    child: Text(year),
                                  );
                                })
                                .toList(),
                        onChanged: (value) {
                          setState(() => _selectedYear = value!);
                          _loadReport();
                        },
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Revenue Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Text(
                        'Total Revenue',
                        style: TextStyle(fontSize: 16, color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'MK ${(_reportData['totalRevenue'] ?? 0.0).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'From ${_reportData['completedOrders'] ?? 0} completed orders',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Stats Row
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Total Orders',
                    value: '${_reportData['totalOrders'] ?? 0}',
                    icon: Icons.receipt,
                    color: Colors.blue,
                    onTap: () => _showOrders('all', 'Total Orders'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    title: 'Completed',
                    value: '${_reportData['completedOrders'] ?? 0}',
                    icon: Icons.check_circle,
                    color: Colors.green,
                    onTap: () => _showOrders('completed', 'Completed Orders'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Pending',
                    value: '${_reportData['pendingOrders'] ?? 0}',
                    icon: Icons.pending,
                    color: Colors.orange,
                    onTap: () => _showOrders('pending', 'Pending Orders'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    title: 'Cancelled',
                    value: '${_reportData['cancelledOrders'] ?? 0}',
                    icon: Icons.cancel,
                    color: Colors.red,
                    onTap: () => _showOrders('cancelled', 'Cancelled Orders'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Average Order Value Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.trending_up, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Average Order Value:',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    Text(
                      'MK ${(_reportData['averageOrderValue'] ?? 0.0).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Monthly Revenue Chart
            if ((_reportData['monthlyRevenue'] as List? ?? []).isNotEmpty)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Monthly Revenue Trend',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(height: 200, child: _buildMonthlyChart()),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Top Selling Products
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Top Selling Products',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Most popular items by quantity sold',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ...(_reportData['topProducts'] as List? ?? []).isEmpty
                        ? [
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.inventory,
                                      size: 48,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'No products sold yet',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ]
                        : (_reportData['topProducts'] as List).take(5).map((
                            product,
                          ) {
                            final index =
                                (_reportData['topProducts'] as List).indexOf(
                                  product,
                                ) +
                                1;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$index',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      product.key,
                                      style: const TextStyle(fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      '${product.value} sold',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Top Categories
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Top Categories',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: (_reportData['topCategories'] as List? ?? [])
                          .map((category) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.orange.shade200,
                                ),
                              ),
                              child: Text(
                                '${category.key}: ${category.value} sold',
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          })
                          .toList(),
                    ),
                    if ((_reportData['topCategories'] as List? ?? []).isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            'No category data available',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
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

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Icon(icon, size: 28, color: color),
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
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Icon(Icons.touch_app, size: 14, color: Colors.grey.shade500),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderReportCard(String docId, Map<String, dynamic> data) {
    final orderId = _text(data['orderId'], fallback: docId);
    final totalAmount = _toDouble(data['totalAmount'] ?? data['totalPrice']);
    final orderStatus = _text(
      data['orderStatus'] ?? data['status'],
      fallback: 'pending',
    );
    final paymentStatus = _text(data['paymentStatus'], fallback: 'pending');
    final items = data['items'] as List? ?? [];

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: CircleAvatar(
          backgroundColor: _statusColor(orderStatus),
          child: const Icon(Icons.receipt_long, color: Colors.white, size: 20),
        ),
        title: Text(
          'Order #${orderId.length > 8 ? orderId.substring(0, 8) : orderId}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${_text(data['customerName'], fallback: 'Unknown customer')} - MK ${totalAmount.toStringAsFixed(2)}',
        ),
        children: [
          _buildSectionTitle('Customer Information'),
          _buildInfoRow(
            'Name:',
            _text(data['customerName'], fallback: 'Unknown'),
          ),
          _buildInfoRow(
            'Email:',
            _text(data['customerEmail'], fallback: 'Not provided'),
          ),
          _buildInfoRow(
            'Phone:',
            _text(data['customerPhone'], fallback: 'Not provided'),
          ),
          _buildInfoRow('Date:', _formatDate(data['timestamp'])),
          const Divider(height: 24),
          _buildSectionTitle('Order Status'),
          _buildInfoRow('Order:', orderStatus),
          _buildInfoRow('Payment:', paymentStatus),
          _buildInfoRow('Total:', 'MK ${totalAmount.toStringAsFixed(2)}'),
          const Divider(height: 24),
          _buildSectionTitle('Produce And Owner'),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('No produce items found for this order'),
            )
          else
            ...items.map((item) {
              final itemData = item is Map
                  ? Map<String, dynamic>.from(item)
                  : <String, dynamic>{};
              return _buildProduceOwnerTile(itemData, data);
            }),
        ],
      ),
    );
  }

  Widget _buildProduceOwnerTile(
    Map<String, dynamic> item,
    Map<String, dynamic> orderData,
  ) {
    final productName = _text(
      item['name'] ?? item['productName'],
      fallback: 'Product',
    );
    final farmerId = _resolveFarmerId(item, orderData);
    final farmerName = _resolveFarmerName(item, farmerId);
    final quantity = _toDouble(
      item['quantity'],
    ).toStringAsFixed(_toDouble(item['quantity']) % 1 == 0 ? 0 : 2);
    final unit = _text(item['unit'], fallback: '');
    final price = _toDouble(item['price']);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            productName,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          _buildInfoRow('Quantity:', '$quantity $unit'.trim()),
          _buildInfoRow('Price:', 'MK ${price.toStringAsFixed(2)}'),
          _buildInfoRow('Owner:', farmerName),
          _buildInfoRow(
            'Farmer ID:',
            farmerId.isEmpty ? 'Not provided' : farmerId,
          ),
        ],
      ),
    );
  }

  String _resolveFarmerId(
    Map<String, dynamic> item,
    Map<String, dynamic> orderData,
  ) {
    final itemFarmerId = _text(item['farmerId'] ?? item['ownerId']);
    if (itemFarmerId.isNotEmpty) return itemFarmerId;

    final farmerIds = orderData['farmerIds'];
    if (farmerIds is List && farmerIds.length == 1) {
      return _text(farmerIds.first);
    }

    return '';
  }

  String _resolveFarmerName(Map<String, dynamic> item, String farmerId) {
    final itemFarmerName = _text(
      item['farmerName'] ??
          item['farmer'] ??
          item['ownerName'] ??
          item['producerName'],
    );
    if (itemFarmerName.isNotEmpty) return itemFarmerName;

    final storedFarmerName = _farmerNames[farmerId];
    if (storedFarmerName != null && storedFarmerName.isNotEmpty) {
      return storedFarmerName;
    }

    if (farmerId.isNotEmpty && !_looksLikeUid(farmerId)) {
      return farmerId;
    }

    return 'Unknown farmer';
  }

  bool _looksLikeUid(String value) {
    return value.length >= 20 && !value.contains(' ') && !value.contains('@');
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _text(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'paid':
      case 'delivered':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'processing':
        return Colors.indigo;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
    return 'Unknown';
  }

  Widget _buildMonthlyChart() {
    final monthlyRevenue = _reportData['monthlyRevenue'] as List? ?? [];

    if (monthlyRevenue.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    double maxRevenue = 0;
    for (var item in monthlyRevenue) {
      if (item.value > maxRevenue) maxRevenue = item.value;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: monthlyRevenue.map((entry) {
        final monthName = _getMonthName(entry.key.split('-')[1]);
        final revenue = entry.value;
        final height = maxRevenue > 0 ? (revenue / maxRevenue) * 150 : 0;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Transform.rotate(
                      angle: -1.57,
                      child: Text(
                        'MK ${revenue.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(monthName, style: const TextStyle(fontSize: 10)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _getMonthName(String monthNumber) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final index = int.tryParse(monthNumber) ?? 1;
    return months[index - 1];
  }
}
