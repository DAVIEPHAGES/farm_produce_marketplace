import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LogisticsDashboardPage extends StatefulWidget {
  const LogisticsDashboardPage({super.key});

  @override
  State<LogisticsDashboardPage> createState() => _LogisticsDashboardPageState();
}

class _LogisticsDashboardPageState extends State<LogisticsDashboardPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _isOnline = true;
  int _selectedBottomNavIndex = 0;

  Stream<QuerySnapshot<Map<String, dynamic>>> _assignedOrdersStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('orders')
        .where('assignedLogisticsCompanyId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  String _getLogisticsStatus(Map<String, dynamic> orderData) {
    return (orderData['logisticsStatus'] as String?)?.toLowerCase() ??
        (orderData['status'] as String?)?.toLowerCase() ??
        'unassigned';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'assigned':
        return Colors.orange;
      case 'in_transit':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'assigned':
        return 'Assigned';
      case 'in_transit':
        return 'In Transit';
      case 'delivered':
        return 'Delivered';
      default:
        return 'Unassigned';
    }
  }

  String _getActionLabel(String status) {
    if (status == 'assigned') return 'Start Delivery';
    if (status == 'in_transit') return 'Mark Delivered';
    return '';
  }

  String _firstNonEmpty(List<dynamic> values, String fallback) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  String _getPickupLocation(Map<String, dynamic> orderData) {
    final items = orderData['items'];
    dynamic firstItemLocation;
    if (items is List && items.isNotEmpty && items.first is Map) {
      final firstItem = Map<String, dynamic>.from(items.first as Map);
      firstItemLocation =
          firstItem['pickupLocation'] ??
          firstItem['location'] ??
          firstItem['farmerLocation'];
    }

    return _firstNonEmpty([
      orderData['pickupLocation'],
      orderData['pickupAddress'],
      orderData['farmerLocation'],
      firstItemLocation,
    ], 'Pickup location not specified');
  }

  String _getDeliveryLocation(Map<String, dynamic> orderData) {
    return _firstNonEmpty([
      orderData['deliveryLocation'],
      orderData['deliveryAddress'],
      orderData['customerLocation'],
      orderData['customerAddress'],
    ], 'Delivery address not specified');
  }

  Future<void> _updateLogisticsStatus(
    DocumentReference<Map<String, dynamic>> orderRef,
    String newStatus,
  ) async {
    final updateData = <String, dynamic>{'logisticsStatus': newStatus};

    if (newStatus == 'in_transit') {
      updateData['logisticsStartedAt'] = FieldValue.serverTimestamp();
      updateData['orderStatus'] = 'out_for_delivery';
    } else if (newStatus == 'delivered') {
      updateData['logisticsDeliveredAt'] = FieldValue.serverTimestamp();
      updateData['orderStatus'] = 'delivered';
    }

    await orderRef.update(updateData);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _loadCompanyData() {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user found');
    }
    return _firestore.collection('users').doc(user.uid).get();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F5),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2E7D32),
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => _showMenuDialog(context),
        ),
        title: const Text('Logistics Dashboard'),
        actions: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none),
                onPressed: () => _showNotificationsDialog(context),
              ),
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      '3',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => _showProfileDialog(context),
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: const Color(0xFF2E7D32)),
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _loadCompanyData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading company data: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text('Logistics company data not found.'),
            );
          }

          final data = snapshot.data!.data() ?? {};
          final companyName =
              data['companyName'] ?? data['name'] ?? 'GreenMove Logistics';

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _assignedOrdersStream(),
            builder: (context, orderSnapshot) {
              if (orderSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (orderSnapshot.hasError) {
                return Center(
                  child: Text('Error loading orders: ${orderSnapshot.error}'),
                );
              }

              final orders = orderSnapshot.data?.docs ?? [];
              final assignedOrders = orders
                  .where(
                    (order) => _getLogisticsStatus(order.data()) == 'assigned',
                  )
                  .toList();
              final inTransitOrders = orders
                  .where(
                    (order) =>
                        _getLogisticsStatus(order.data()) == 'in_transit',
                  )
                  .toList();
              final deliveredOrders = orders
                  .where(
                    (order) => _getLogisticsStatus(order.data()) == 'delivered',
                  )
                  .toList();
              final activeOrder = inTransitOrders.isNotEmpty
                  ? inTransitOrders.first
                  : null;

              return Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildStatusCard(companyName),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.inventory_2_outlined,
                                  label: 'Active Deliveries',
                                  value: inTransitOrders.length.toString(),
                                  color: const Color(0xFF2E7D32),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  icon: Icons.check_circle_outline,
                                  label: 'Completed Today',
                                  value: deliveredOrders.length.toString(),
                                  color: const Color(0xFF2E7D32),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildSectionHeader('Active Delivery'),
                          const SizedBox(height: 12),
                          activeOrder != null
                              ? _buildActiveDeliveryCard(activeOrder)
                              : _buildEmptyStateCard(
                                  title: 'No active deliveries yet',
                                  description:
                                      'Once a shipment is in transit, it will appear here.',
                                ),
                          const SizedBox(height: 20),
                          _buildSectionHeader('Assigned Deliveries'),
                          const SizedBox(height: 12),
                          if (assignedOrders.isEmpty)
                            _buildEmptyStateCard(
                              title: 'No assigned deliveries',
                              description:
                                  'Orders assigned to your company will show up here.',
                            )
                          else
                            ...assignedOrders
                                .map(_buildAssignedDeliveryCard)
                                .toList(),
                          const SizedBox(height: 20),
                          _buildSectionHeader('Recent History'),
                          const SizedBox(height: 12),
                          if (deliveredOrders.isEmpty)
                            _buildEmptyStateCard(
                              title: 'No delivery history yet',
                              description:
                                  'Completed deliveries will appear in this section.',
                            )
                          else
                            _buildRecentHistoryCard(deliveredOrders),
                        ],
                      ),
                    ),
                  ),
                  _buildBottomNavigationBar(),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(String companyName) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.local_shipping,
                  color: Color(0xFF2E7D32),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      companyName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Available for deliveries',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _isOnline ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          color: _isOnline ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _isOnline,
                    activeColor: const Color(0xFF2E7D32),
                    onChanged: (value) {
                      setState(() {
                        _isOnline = value;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildActiveDeliveryCard(
    QueryDocumentSnapshot<Map<String, dynamic>> order,
  ) {
    final orderData = order.data();
    final orderId = orderData['orderId'] ?? order.id;
    final status = _getLogisticsStatus(orderData);
    final pickup = _getPickupLocation(orderData);
    final delivery = _getDeliveryLocation(orderData);
    final totalAmount =
        (orderData['totalAmount'] ?? orderData['totalPrice'] ?? 0).toString();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Order $orderId',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _getStatusLabel(status),
                  style: TextStyle(
                    color: _getStatusColor(status),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildDeliveryInfoRow(
            icon: Icons.location_on,
            label: 'Pickup',
            value: pickup,
          ),
          const SizedBox(height: 12),
          _buildDeliveryInfoRow(
            icon: Icons.flag,
            label: 'Delivery',
            value: delivery,
          ),
          const SizedBox(height: 12),
          _buildDeliveryInfoRow(
            icon: Icons.attach_money,
            label: 'Total',
            value: 'MWK $totalAmount',
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: status == 'in_transit'
                ? () async {
                    try {
                      await _updateLogisticsStatus(
                        order.reference,
                        'delivered',
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Marked as delivered'),
                            backgroundColor: Color(0xFF2E7D32),
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
                : null,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Mark as Delivered'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedDeliveryCard(
    QueryDocumentSnapshot<Map<String, dynamic>> order,
  ) {
    final orderData = order.data();
    final orderId = orderData['orderId'] ?? order.id;
    final pickup = _getPickupLocation(orderData);
    final delivery = _getDeliveryLocation(orderData);
    final status = _getLogisticsStatus(orderData);
    final customerName = orderData['customerName'] ?? 'Customer';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.local_shipping_outlined,
                    color: Color(0xFFF57C00),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Order $orderId',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF57C00)),
                  ),
                  child: Text(
                    _getStatusLabel(status),
                    style: const TextStyle(
                      color: Color(0xFFF57C00),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Customer: $customerName',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            _buildDeliveryInfoRow(
              icon: Icons.location_on,
              label: 'Pickup',
              value: pickup,
            ),
            const SizedBox(height: 10),
            _buildDeliveryInfoRow(
              icon: Icons.flag,
              label: 'Delivery',
              value: delivery,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: status == 'assigned'
                  ? () async {
                      try {
                        await _updateLogisticsStatus(
                          order.reference,
                          'in_transit',
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Delivery started'),
                              backgroundColor: Color(0xFF2E7D32),
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
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: status == 'assigned'
                    ? const Color(0xFFF57C00)
                    : Colors.grey.shade300,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                _getActionLabel(status),
                style: TextStyle(
                  color: status == 'assigned'
                      ? Colors.white
                      : Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentHistoryCard(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> deliveredOrders,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: deliveredOrders.map((order) {
          final orderData = order.data();
          final orderId = orderData['orderId'] ?? order.id;
          final deliveredAt = orderData['logisticsDeliveredAt'];
          final time = deliveredAt is Timestamp
              ? deliveredAt.toDate().toLocal().toString()
              : 'Completed';

          return Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                title: Text(
                  'Order $orderId',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Delivered at $time',
                  style: const TextStyle(color: Colors.grey),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Delivered',
                    style: const TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (order != deliveredOrders.last)
                const Divider(height: 1, indent: 16, endIndent: 16),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyStateCard({
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildDeliveryInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.green.shade700, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showMenuDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Menu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Dashboard'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedBottomNavIndex = 0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('History'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedBottomNavIndex = 1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                _showProfileDialog(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () => _handleLogout(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notifications'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.local_shipping, color: Colors.blue),
                title: const Text('New Delivery Assigned'),
                subtitle: const Text('2 hours ago'),
              ),
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text('Delivery Completed'),
                subtitle: const Text('5 hours ago'),
              ),
              ListTile(
                leading: const Icon(Icons.info, color: Colors.orange),
                title: const Text('Order Update'),
                subtitle: const Text('1 day ago'),
              ),
            ],
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

  void _showProfileDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) =>
          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: _loadCompanyData(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const AlertDialog(content: CircularProgressIndicator());
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return AlertDialog(
                  title: const Text('Profile'),
                  content: const Text('Profile not found'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                );
              }

              final data = snapshot.data!.data() ?? {};
              final companyName =
                  data['companyName'] ?? data['name'] ?? 'Logistics Company';
              final email = data['email'] ?? 'Not provided';
              final phone = data['phone'] ?? 'Not provided';
              final location = data['location'] ?? 'Not provided';
              final licenseNumber = data['licenseNumber'] ?? 'Not provided';

              return AlertDialog(
                title: const Text('Company Profile'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Center(
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: const Color(0xFF2E7D32),
                          child: const Icon(
                            Icons.local_shipping,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        companyName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildProfileInfoRow('Email:', email),
                      _buildProfileInfoRow('Phone:', phone),
                      _buildProfileInfoRow('Location:', location),
                      _buildProfileInfoRow('License:', licenseNumber),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text('Status: '),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _isOnline ? Colors.green : Colors.grey,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _isOnline ? 'Online' : 'Offline',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() => _isOnline = !_isOnline);
                              Navigator.pop(context);
                            },
                            icon: Icon(_isOnline ? Icons.logout : Icons.login),
                            label: Text(_isOnline ? 'Go Offline' : 'Go Online'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isOnline
                                  ? Colors.red
                                  : Colors.green,
                            ),
                          ),
                        ],
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
                    onPressed: () => _handleLogout(context),
                    child: const Text(
                      'Logout',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }

  Widget _buildProfileInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _auth.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/signin');
      }
    }
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _selectedBottomNavIndex,
      selectedItemColor: const Color(0xFF2E7D32),
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_filled),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Profile',
        ),
      ],
      onTap: (index) {
        setState(() => _selectedBottomNavIndex = index);
        if (index == 2) {
          _showProfileDialog(context);
        }
      },
    );
  }
}
