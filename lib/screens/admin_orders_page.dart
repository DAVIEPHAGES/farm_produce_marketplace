import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  String _filterStatus = 'all';
  bool _isUpdating = false;
  
  final List<String> _statusOptions = ['all', 'pending', 'confirmed', 'delivered', 'cancelled'];
  
  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    setState(() => _isUpdating = true);
    
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
            'orderStatus': newStatus,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order status updated to $newStatus'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter Dropdown
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text('Filter by status: '),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _filterStatus,
                  items: _statusOptions.map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(status.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _filterStatus = value!;
                    });
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Orders List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No orders found', style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ],
                  ),
                );
              }
              
              var orders = snapshot.data!.docs;
              
              if (_filterStatus != 'all') {
                orders = orders.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final orderStatus = data['orderStatus'] ?? data['status'] ?? 'pending';
                  return orderStatus == _filterStatus;
                }).toList();
              }
              
              if (orders.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.filter_alt_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No ${_filterStatus.toUpperCase()} orders', style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ],
                  ),
                );
              }
              
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final data = order.data() as Map<String, dynamic>;
                  
                  // Get correct field names
                  final orderId = data['orderId'] ?? order.id;
                  final customerName = data['customerName'] ?? 'Unknown';
                  final totalAmount = (data['totalAmount'] ?? data['totalPrice'] ?? 0).toDouble();
                  final orderStatus = data['orderStatus'] ?? data['status'] ?? 'pending';
                  final paymentMethod = data['paymentMethod'] ?? 'Not specified';
                  final paymentStatus = data['paymentStatus'] ?? 'pending';
                  final items = data['items'] as List? ?? [];
                  final timestamp = data['timestamp'];
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: _getStatusColor(orderStatus),
                        child: Icon(
                          _getStatusIcon(orderStatus),
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        'Order #${orderId.length > 8 ? orderId.substring(0, 8) : orderId}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Customer: $customerName'),
                          Text('Total: MWK ${totalAmount.toStringAsFixed(2)}'),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(orderStatus),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  orderStatus.toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontSize: 10),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: paymentStatus == 'completed' ? Colors.green : Colors.orange,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  paymentStatus.toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontSize: 10),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Order Details
                              const Text(
                                'Order Details:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              _buildInfoRow('Order ID:', orderId),
                              _buildInfoRow('Order Date:', _formatDate(timestamp)),
                              _buildInfoRow('Payment Method:', paymentMethod),
                              _buildInfoRow('Payment Status:', paymentStatus),
                              
                              const Divider(),
                              
                              // Order Items
                              const Text(
                                'Items:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              if (items.isEmpty)
                                const Text('No items found')
                              else
                                ...items.map((item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Text('${item['quantity']}x ${item['name'] ?? item['productName'] ?? 'Product'}'),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          'MWK ${(item['price'] * item['quantity']).toStringAsFixed(2)}',
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                              
                              const Divider(),
                              
                              // Customer Information
                              const Text(
                                'Customer Information:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              _buildInfoRow('Name:', customerName),
                              _buildInfoRow('Email:', data['customerEmail'] ?? 'Not provided'),
                              _buildInfoRow('Phone:', data['customerPhone'] ?? 'Not provided'),
                              
                              const Divider(),
                              
                              // Summary
                              const Text(
                                'Summary:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              _buildInfoRow('Subtotal:', 'MWK ${totalAmount.toStringAsFixed(2)}'),
                              _buildInfoRow('Total:', 'MWK ${totalAmount.toStringAsFixed(2)}'),
                              
                              const Divider(),
                              
                              // Update Status
                              const Text(
                                'Update Order Status:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildStatusChip('pending', orderStatus, order.id),
                                  _buildStatusChip('confirmed', orderStatus, order.id),
                                  _buildStatusChip('delivered', orderStatus, order.id),
                                  _buildStatusChip('cancelled', orderStatus, order.id),
                                ],
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
    );
  }

  Widget _buildStatusChip(String status, String currentStatus, String orderId) {
    return FilterChip(
      label: Text(status.toUpperCase()),
      selected: currentStatus == status,
      onSelected: _isUpdating
          ? null
          : (selected) {
              if (selected) {
                _updateOrderStatus(orderId, status);
              }
            },
      backgroundColor: Colors.grey[200],
      selectedColor: _getStatusColor(status),
      labelStyle: TextStyle(
        color: currentStatus == status ? Colors.white : Colors.black87,
        fontWeight: currentStatus == status ? FontWeight.bold : FontWeight.normal,
      ),
      showCheckmark: false,
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.normal),
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return Colors.green;
      case 'confirmed':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return Icons.delivery_dining;
      case 'confirmed':
        return Icons.check_circle;
      case 'pending':
        return Icons.pending;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.receipt;
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
    return 'Unknown';
  }
}