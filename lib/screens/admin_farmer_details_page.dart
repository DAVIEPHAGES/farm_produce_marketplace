import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminFarmerDetailsPage extends StatefulWidget {
  final String farmerId;
  final String farmerName;

  const AdminFarmerDetailsPage({
    super.key,
    required this.farmerId,
    required this.farmerName,
  });

  @override
  State<AdminFarmerDetailsPage> createState() => _AdminFarmerDetailsPageState();
}

class _AdminFarmerDetailsPageState extends State<AdminFarmerDetailsPage> {
  bool _isLoading = true;
  double _completedEarnings = 0.0;
  double _pendingEarnings = 0.0;
  double _totalItemsSold = 0.0;
  int _ordersCount = 0;
  int _customerCount = 0;
  final List<Map<String, dynamic>> _orderSummaries = [];
  final Map<String, double> _salesByProduct = {};
  final Set<String> _customers = {};
  final Set<String> _productIds = {};

  @override
  void initState() {
    super.initState();
    _loadFarmerSales();
  }

  Future<void> _loadFarmerSales() async {
    try {
      final farmerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.farmerId)
          .get();
      final farmerData = farmerDoc.data() ?? {};
      final farmerName = (farmerData['name'] ?? widget.farmerName)
          .toString()
          .trim()
          .toLowerCase();

      final productsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('farmerId', isEqualTo: widget.farmerId)
          .get();
      _productIds.addAll(productsSnapshot.docs.map((doc) => doc.id.toString()));

      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .get();

      final futures = ordersSnapshot.docs.map((orderDoc) async {
        final itemsSnapshot = await orderDoc.reference
            .collection('items')
            .get();
        return {'orderDoc': orderDoc, 'itemsSnapshot': itemsSnapshot};
      }).toList();

      final itemsResults = await Future.wait(futures);

      for (final result in itemsResults) {
        final orderDoc = result['orderDoc'] as QueryDocumentSnapshot;
        final itemsSnapshot = result['itemsSnapshot'] as QuerySnapshot;
        final order = orderDoc.data() as Map<String, dynamic>;
        final orderStatus = (order['orderStatus'] ?? order['status'] ?? '')
            .toString()
            .toLowerCase();
        final paymentStatus = (order['paymentStatus'] ?? '')
            .toString()
            .toLowerCase();
        final customerName =
            (order['customerName'] ??
                    order['customer'] ??
                    order['customerEmail'] ??
                    'Unknown Customer')
                .toString();

        final embeddedItems = order['items'] is List
            ? (order['items'] as List)
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
            : <Map<String, dynamic>>[];

        final allItems = <Map<String, dynamic>>[
          ...itemsSnapshot.docs.map(
            (doc) => doc.data() as Map<String, dynamic>,
          ),
          ...embeddedItems,
        ];

        bool belongsToFarmer = _orderBelongsToFarmer(
          order,
          widget.farmerId,
          farmerName,
        );
        double orderQuantity = 0.0;
        double orderEarnings = 0.0;
        final List<Map<String, dynamic>> farmerItems = [];

        for (final item in allItems) {
          if (!_itemBelongsToFarmer(
            item,
            widget.farmerId,
            farmerName,
            _productIds,
          )) {
            continue;
          }

          belongsToFarmer = true;
          final double price = _toDouble(item['price']);
          final double quantity = _toDouble(item['quantity']);
          final double totalPrice = _toDouble(
            item['totalPrice'],
            fallback: price * quantity,
          );

          orderQuantity += quantity;
          orderEarnings += totalPrice;
          farmerItems.add(item);

          final productName =
              (item['productName'] ??
                      item['name'] ??
                      item['product'] ??
                      'Unknown Product')
                  .toString();
          _salesByProduct[productName] =
              (_salesByProduct[productName] ?? 0) + totalPrice;
        }

        if (!belongsToFarmer) {
          continue;
        }

        final bool isCompleted =
            paymentStatus == 'completed' ||
            paymentStatus == 'paid' ||
            orderStatus == 'completed' ||
            orderStatus == 'delivered';

        if (farmerItems.isEmpty) {
          orderQuantity = _toDouble(order['quantity']);
          orderEarnings = _toDouble(
            order['farmerEarnings'],
            fallback: _toDouble(order['totalPrice'] ?? order['totalAmount']),
          );
        }

        _ordersCount += 1;
        _customers.add(customerName);
        if (isCompleted) {
          _completedEarnings += orderEarnings;
          _totalItemsSold += orderQuantity;
        } else {
          _pendingEarnings += orderEarnings;
        }

        _orderSummaries.add({
          'orderId': orderDoc.id,
          'customerName': customerName,
          'status': orderStatus.isNotEmpty ? orderStatus : 'pending',
          'paymentStatus': paymentStatus.isNotEmpty ? paymentStatus : 'pending',
          'quantity': orderQuantity,
          'earnings': orderEarnings,
          'items': farmerItems,
          'timestamp': order['timestamp'],
        });
      }

      setState(() {
        _customerCount = _customers.length;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading farmer details: $e')),
        );
      }
    }
  }

  bool _orderBelongsToFarmer(
    Map<String, dynamic> order,
    String farmerId,
    String farmerName,
  ) {
    final dynamic farmerIds = order['farmerIds'];
    if (farmerIds is List) {
      return farmerIds.any(
        (id) => id.toString().trim().toLowerCase() == farmerId.toLowerCase(),
      );
    }

    final farmerIdField = (order['farmerId'] ?? order['ownerId'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (farmerIdField.isNotEmpty && farmerIdField == farmerId.toLowerCase()) {
      return true;
    }

    final farmerNameField = (order['farmerName'] ?? order['farmer'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    return farmerNameField.isNotEmpty && farmerNameField == farmerName;
  }

  bool _itemBelongsToFarmer(
    Map<String, dynamic> item,
    String farmerId,
    String farmerName,
    Set<String> farmerProductIds,
  ) {
    final farmerIdField = (item['farmerId'] ?? item['ownerId'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (farmerIdField.isNotEmpty && farmerIdField == farmerId.toLowerCase()) {
      return true;
    }

    final farmerNameField = (item['farmerName'] ?? item['farmer'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (farmerNameField.isNotEmpty && farmerNameField == farmerName) {
      return true;
    }

    final productId = (item['productId'] ?? item['id'] ?? '').toString().trim();
    return productId.isNotEmpty && farmerProductIds.contains(productId);
  }

  double _toDouble(dynamic value, {double fallback = 0.0}) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    }
    return timestamp.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sales for ${widget.farmerName}'),
        backgroundColor: const Color(0xFF2E7D32),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.farmerName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Farmer sales summary'),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildSummaryCard(
                        title: 'Completed Earnings',
                        value: 'MWK ${_completedEarnings.toStringAsFixed(2)}',
                        color: Colors.green,
                      ),
                      _buildSummaryCard(
                        title: 'Pending Earnings',
                        value: 'MWK ${_pendingEarnings.toStringAsFixed(2)}',
                        color: Colors.orange,
                      ),
                      _buildSummaryCard(
                        title: 'Orders',
                        value: '$_ordersCount',
                        color: Colors.blue,
                      ),
                      _buildSummaryCard(
                        title: 'Customers',
                        value: '$_customerCount',
                        color: Colors.purple,
                      ),
                      _buildSummaryCard(
                        title: 'Items Sold',
                        value: _totalItemsSold.toStringAsFixed(0),
                        color: Colors.teal,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Product Sales',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_salesByProduct.isEmpty)
                            const Text('No product sales found yet.')
                          else
                            Column(
                              children: _salesByProduct.entries
                                  .map(
                                    (entry) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              entry.key,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            'MWK ${entry.value.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Recent Orders',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (_orderSummaries.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text('No orders found for this farmer.'),
                      ),
                    )
                  else
                    Column(
                      children: _orderSummaries
                          .map((order) => _buildOrderCard(order))
                          .toList(),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return SizedBox(
      width: 160,
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final items = order['items'] as List<dynamic>? ?? [];
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order ${order['orderId']?.toString().substring(0, 8) ?? 'N/A'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    order['status']?.toString().toUpperCase() ?? 'PENDING',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildInfoRow('Customer:', order['customerName'] ?? 'Unknown'),
            _buildInfoRow('Payment:', order['paymentStatus'] ?? 'pending'),
            _buildInfoRow('Date:', _formatDate(order['timestamp'])),
            _buildInfoRow(
              'Total:',
              'MWK ${_toDouble(order['earnings']).toStringAsFixed(2)}',
            ),
            _buildInfoRow('Items:', items.length.toString()),
            if (items.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Products:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...items.map((item) {
                final itemMap = item as Map<String, dynamic>;
                final productName =
                    (itemMap['productName'] ??
                            itemMap['name'] ??
                            itemMap['product'] ??
                            'Unknown')
                        .toString();
                final quantity = _toDouble(
                  itemMap['quantity'],
                ).toStringAsFixed(0);
                final itemTotal = _toDouble(
                  itemMap['totalPrice'],
                  fallback:
                      _toDouble(itemMap['price']) *
                      _toDouble(itemMap['quantity']),
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '• $productName x $quantity = MWK ${itemTotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                );
              }),
            ],
          ],
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
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
