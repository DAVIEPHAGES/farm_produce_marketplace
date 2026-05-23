import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MyOrdersPage extends StatefulWidget {
  const MyOrdersPage({super.key});

  @override
  State<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends State<MyOrdersPage> {
  bool _isProcessing = false;
  String _filterStatus = 'all';
  String _searchQuery = "";
  bool _isRefreshing = false;
  
  final List<String> _tabs = ["All", "Pending", "Confirmed", "Delivered", "Cancelled"];
  String _selectedTab = "All";

  /// Confirm receipt for a specific item in an order
  Future<void> _confirmItemReceipt(String orderId, String itemId, String productName) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();
      
      if (!orderDoc.exists) {
        throw Exception('Order not found');
      }
      
      final itemRef = orderDoc.reference.collection('items').doc(itemId);
      final itemDoc = await itemRef.get();
      
      if (!itemDoc.exists) {
        throw Exception('Item not found');
      }
      
      final currentItemStatus = itemDoc.data()?['deliveryStatus'] ?? 'pending';
      
      if (currentItemStatus == 'delivered') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$productName has already been marked as received'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      await itemRef.update({
        'deliveryStatus': 'delivered',
        'deliveryConfirmedAt': FieldValue.serverTimestamp(),
        'deliveryConfirmedBy': 'customer',
      });
      
      await _updateOrderOverallStatus(orderId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ $productName marked as received!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        setState(() {});
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
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  /// Update the overall order status based on individual item statuses
  Future<void> _updateOrderOverallStatus(String orderId) async {
    final itemsSnapshot = await FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .collection('items')
        .get();
    
    final items = itemsSnapshot.docs;
    final allItemsDelivered = items.every((item) {
      final data = item.data();
      return data['deliveryStatus'] == 'delivered';
    });
    
    if (allItemsDelivered) {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
        'orderStatus': 'delivered',
        'allItemsDeliveredAt': FieldValue.serverTimestamp(),
      });
    } else {
      final someItemsDelivered = items.any((item) {
        final data = item.data();
        return data['deliveryStatus'] == 'delivered';
      });
      
      if (someItemsDelivered) {
        await FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId)
            .update({
          'orderStatus': 'partially_delivered',
        });
      }
    }
  }

  /// Show confirmation dialog for individual item
  Future<void> _showConfirmDialog(String orderId, String itemId, String productName) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green),
            SizedBox(width: 8),
            Text('Confirm Receipt'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Product: $productName',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text(
              'Have you received this item?',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.amber, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This confirms you have received this item. This action cannot be undone.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _confirmItemReceipt(orderId, itemId, productName);
            },
            icon: const Icon(Icons.check),
            label: const Text('Yes, Mark as Received'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  String formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "";
    final date = timestamp.toDate();
    return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
  }

  String getOrderStatus(Map<String, dynamic> data) {
    if (data['paymentStatus'] == 'completed') {
      return 'Paid ✓';
    }
    if (data['orderStatus'] == 'cancelled') {
      return 'Cancelled';
    }
    if (data['orderStatus'] == 'delivered') {
      return 'Delivered';
    }
    if (data['orderStatus'] == 'partially_delivered') {
      return 'Partially Delivered';
    }
    if (data['orderStatus'] == 'confirmed') {
      return 'Confirmed';
    }
    return 'Pending';
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'Paid ✓':
        return Colors.green;
      case 'Delivered':
        return Colors.green;
      case 'Partially Delivered':
        return Colors.orange;
      case 'Confirmed':
        return Colors.blue;
      case 'Pending':
        return Colors.orange;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String mapStatusToTab(String status) {
    if (status == "Paid ✓") return "All";
    if (status == "Cancelled") return "Cancelled";
    if (status == "Pending") return "Pending";
    if (status == "Confirmed") return "Confirmed";
    if (status == "Delivered") return "Delivered";
    return "All";
  }

  Future<void> _refreshOrders() async {
    setState(() {
      _isRefreshing = true;
    });
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _isRefreshing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Orders'),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Please login to view your orders',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/signin');
                },
                icon: const Icon(Icons.login),
                label: const Text('Login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My Orders'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshOrders,
        child: CustomScrollView(
          slivers: [
            // Tabs + Search
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                child: Column(
                  children: [
                    SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _tabs.length,
                        itemBuilder: (context, index) {
                          final tab = _tabs[index];
                          final isSelected = _selectedTab == tab;
                          return GestureDetector(
                            onTap: () {
                              setState(() => _selectedTab = tab);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Column(
                                children: [
                                  const SizedBox(height: 12),
                                  Text(
                                    tab,
                                    style: TextStyle(
                                      color: isSelected ? Colors.green : Colors.grey,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    height: 2,
                                    width: 40,
                                    color: isSelected ? Colors.green : Colors.transparent,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                        decoration: InputDecoration(
                          hintText: "Search orders by ID...",
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() => _searchQuery = "");
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.grey.shade200,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Orders List
            SliverFillRemaining(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .where('customerId', isEqualTo: user.uid)
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;

                  final filtered = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final status = getOrderStatus(data);
                    
                    final matchesTab = _selectedTab == "All"
                        ? true
                        : status == _selectedTab;
                    
                    final matchesSearch = doc.id.toLowerCase().contains(_searchQuery);
                    
                    return matchesTab && matchesSearch;
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty ? "No matching orders found" : "No orders yet",
                            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                          ),
                          if (_searchQuery.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                setState(() => _searchQuery = "");
                              },
                              child: const Text("Clear Search"),
                            ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final doc = filtered[index];
                      final data = doc.data() as Map<String, dynamic>;
                      
                      final orderStatus = getOrderStatus(data);
                      final totalAmount = data['totalAmount'] ?? data['totalPrice'] ?? 0;
                      final imageUrl = data['imageUrl'] ?? '';
                      final itemsList = data['items'] as List? ?? [];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: getStatusColor(orderStatus).withOpacity(0.2),
                            child: Icon(
                              _getStatusIcon(orderStatus),
                              color: getStatusColor(orderStatus),
                            ),
                          ),
                          title: Text(
                            "Order #${doc.id.substring(0, 6)}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formatDate(data['timestamp']),
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: getStatusColor(orderStatus).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  orderStatus,
                                  style: TextStyle(
                                    color: getStatusColor(orderStatus),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          trailing: Text(
                            "MK ${totalAmount.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Order Details Section
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Order Summary",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        _buildInfoRow("Order ID:", doc.id),
                                        _buildInfoRow("Date:", formatDate(data['timestamp'])),
                                        _buildInfoRow("Payment Method:", data['paymentMethod'] ?? 'Not specified'),
                                        _buildInfoRow("Payment Status:", data['paymentStatus'] ?? 'pending'),
                                        const Divider(),
                                        _buildInfoRow("Total Amount:", "MK ${totalAmount.toStringAsFixed(2)}", isBold: true),
                                      ],
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  
                                  // Items List with Receive Buttons
                                  const Text(
                                    "Items",
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 8),
                                  FutureBuilder<QuerySnapshot>(
                                    future: doc.reference.collection('items').get(),
                                    builder: (context, itemsSnapshot) {
                                      if (itemsSnapshot.connectionState == ConnectionState.waiting) {
                                        return const Center(child: CircularProgressIndicator());
                                      }
                                      
                                      if (!itemsSnapshot.hasData || itemsSnapshot.data!.docs.isEmpty) {
                                        return const Padding(
                                          padding: EdgeInsets.all(16),
                                          child: Text('No items found'),
                                        );
                                      }
                                      
                                      final items = itemsSnapshot.data!.docs;
                                      return ListView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: items.length,
                                        itemBuilder: (context, itemIndex) {
                                          final item = items[itemIndex];
                                          final itemData = item.data() as Map<String, dynamic>;
                                          
                                          final productName = itemData['productName'] ?? itemData['name'] ?? 'Product';
                                          final quantity = itemData['quantity'] ?? 1;
                                          final price = (itemData['price'] ?? 0).toDouble();
                                          final totalItemPrice = (itemData['totalPrice'] ?? price * quantity).toDouble();
                                          final deliveryStatus = itemData['deliveryStatus'] ?? 'pending';
                                          final isDelivered = deliveryStatus == 'delivered';
                                          final imageUrl = itemData['imageUrl'] ?? '';
                                          
                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 12),
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: isDelivered ? Colors.green.shade50 : Colors.white,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isDelivered ? Colors.green : Colors.grey.shade200,
                                              ),
                                            ),
                                            child: Column(
                                              children: [
                                                Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    ClipRRect(
                                                      borderRadius: BorderRadius.circular(8),
                                                      child: Image.network(
                                                        imageUrl,
                                                        width: 60,
                                                        height: 60,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (_, __, ___) => Container(
                                                          width: 60,
                                                          height: 60,
                                                          color: Colors.grey[200],
                                                          child: const Icon(Icons.image),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            productName,
                                                            style: const TextStyle(
                                                              fontWeight: FontWeight.w600,
                                                              fontSize: 14,
                                                            ),
                                                          ),
                                                          const SizedBox(height: 4),
                                                          Text(
                                                            'Quantity: $quantity',
                                                            style: const TextStyle(fontSize: 12),
                                                          ),
                                                          Text(
                                                            'Price: MK ${price.toStringAsFixed(2)}',
                                                            style: const TextStyle(fontSize: 12),
                                                          ),
                                                          Text(
                                                            'Total: MK ${totalItemPrice.toStringAsFixed(2)}',
                                                            style: const TextStyle(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.w500,
                                                              color: Colors.green,
                                                            ),
                                                          ),
                                                          if (isDelivered)
                                                            Padding(
                                                              padding: const EdgeInsets.only(top: 4),
                                                              child: Text(
                                                                'Received on ${_formatDate(itemData['deliveryConfirmedAt'])}',
                                                                style: const TextStyle(
                                                                  fontSize: 10,
                                                                  color: Colors.green,
                                                                ),
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 10),
                                                if (!isDelivered)
                                                  SizedBox(
                                                    width: double.infinity,
                                                    child: ElevatedButton.icon(
                                                      onPressed: _isProcessing
                                                          ? null
                                                          : () => _showConfirmDialog(doc.id, item.id, productName),
                                                      icon: _isProcessing
                                                          ? const SizedBox(
                                                              width: 18,
                                                              height: 18,
                                                              child: CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                              ),
                                                            )
                                                          : const Icon(Icons.check_circle_outline, size: 18),
                                                      label: const Text('Mark as Received'),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.green,
                                                        foregroundColor: Colors.white,
                                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                else
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: Colors.green),
                                                    ),
                                                    child: const Row(
                                                      children: [
                                                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                                                        SizedBox(width: 8),
                                                        Expanded(
                                                          child: Text(
                                                            'Item Received',
                                                            style: TextStyle(
                                                              color: Colors.green,
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  
                                  // Customer Information
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Delivery Information",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        _buildInfoRow("Name:", data['customerName'] ?? 'Unknown'),
                                        _buildInfoRow("Email:", data['customerEmail'] ?? 'Not provided'),
                                        _buildInfoRow("Phone:", data['customerPhone'] ?? 'Not provided'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: isBold ? Colors.green : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
    }
    return 'N/A';
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Paid ✓':
        return Icons.payment;
      case 'Delivered':
        return Icons.delivery_dining;
      case 'Partially Delivered':
        return Icons.pending_actions;
      case 'Confirmed':
        return Icons.check_circle;
      case 'Pending':
        return Icons.pending;
      case 'Cancelled':
        return Icons.cancel;
      default:
        return Icons.receipt;
    }
  }
}
