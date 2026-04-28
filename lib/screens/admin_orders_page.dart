import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  String _filterStatus = 'all';
  
  final List<String> _statusOptions = ['all', 'pending', 'paid', 'processing', 'shipped', 'delivered', 'cancelled'];
  
  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    await FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .update({
          'status': newStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Order status updated to $newStatus')),
    );
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
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No orders found'));
              }
              
              var orders = snapshot.data!.docs;
              
              if (_filterStatus != 'all') {
                orders = orders.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['status'] == _filterStatus;
                }).toList();
              }
              
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final data = order.data() as Map<String, dynamic>;
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: _getStatusColor(data['status']),
                        child: Icon(
                          _getStatusIcon(data['status']),
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      title: Text('Order #${order.id.substring(0, 8)}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Customer: ${data['customerName'] ?? 'Unknown'}'),
                          Text('Total: MK ${data['totalPrice']}'),
                        ],
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Order Items
                              const Text(
                                'Items:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              ...(data['items'] as List?)?.map((item) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text('${item['quantity']}x ${item['productName']}'),
                                      ),
                                      Text('MK ${item['totalPrice']}'),
                                    ],
                                  ),
                                );
                              }).toList() ?? [],
                              
                              const Divider(),
                              
                              // Customer Info
                              const Text(
                                'Customer Details:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text('Name: ${data['customerName'] ?? 'N/A'}'),
                              Text('Email: ${data['customerEmail'] ?? 'N/A'}'),
                              Text('Phone: ${data['customerPhone'] ?? 'N/A'}'),
                              
                              const Divider(),
                              
                              // Update Status
                              const Text(
                                'Update Status:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  'pending', 'paid', 'processing', 'shipped', 'delivered', 'cancelled'
                                ].map((status) {
                                  return FilterChip(
                                    label: Text(status.toUpperCase()),
                                    selected: data['status'] == status,
                                    onSelected: (selected) {
                                      if (selected) {
                                        _updateOrderStatus(order.id, status);
                                      }
                                    },
                                    backgroundColor: _getStatusColor(status),
                                    selectedColor: _getStatusColor(status),
                                    labelStyle: const TextStyle(color: Colors.white),
                                  );
                                }).toList(),
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
  
  Color _getStatusColor(String? status) {
    switch (status) {
      case 'paid': return Colors.green;
      case 'delivered': return Colors.green;
      case 'processing': return Colors.orange;
      case 'shipped': return Colors.blue;
      case 'pending': return Colors.orange;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }
  
  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'paid': return Icons.check;
      case 'delivered': return Icons.delivery_dining;
      case 'processing': return Icons.production_quantity_limits;
      case 'shipped': return Icons.local_shipping;
      case 'pending': return Icons.pending;
      case 'cancelled': return Icons.cancel;
      default: return Icons.receipt;
    }
  }
}