import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MyProducePage extends StatefulWidget {
  const MyProducePage({super.key});

  @override
  State<MyProducePage> createState() => _MyProducePageState();
}

class _MyProducePageState extends State<MyProducePage> {
  final String? _farmerId = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    if (_farmerId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Produce'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Please login to view your produce'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Produce'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // REAL-TIME STREAM
        stream: FirebaseFirestore.instance
            .collection('products')
            .where('farmerId', isEqualTo: _farmerId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No produce added yet'));
          }

          // 1. Process Data & Totals
          final List<Map<String, dynamic>> produceItems = docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            
            // Logic: if availableQuantity doesn't exist yet, fallback to original quantity
            final int totalQty = (data['quantity'] ?? 0).toInt();
            final int availableQty = (data['availableQuantity'] ?? totalQty).toInt();
            final double price = (data['price'] ?? 0).toDouble();

            return {
              'id': doc.id,
              'name': data['name'] ?? 'Unknown',
              'totalQuantity': totalQty,
              'availableQuantity': availableQty,
              'unit': data['sellingUnit'] ?? data['unit'] ?? 'unit',
              'price': price,
              'totalValue': price * availableQty,
              'imageUrl': data['imageUrl'] ?? '',
              'status': data['status'] ?? 'in_stock',
            };
          }).toList();

          final totalValue = produceItems.fold(0.0, (sum, item) => sum + item['totalValue']);

          return Column(
            children: [
              // Summary Cards
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Items',
                        produceItems.length.toString(),
                        Icons.inventory,
                        Colors.green.shade100,
                        Colors.green.shade800,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        'Total Stock Value',
                        'MK ${totalValue.toStringAsFixed(0)}',
                        Icons.account_balance_wallet,
                        Colors.orange.shade100,
                        Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ),

              // Produce List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: produceItems.length,
                  itemBuilder: (context, index) {
                    final item = produceItems[index];
                    return _buildProduceCard(item);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProduceCard(Map<String, dynamic> item) {
    final int avail = item['availableQuantity'];
    final int total = item['totalQuantity'];
    
    // Status Logic for your -2 situation
    Color statusColor = Colors.green;
    String statusText = "In Stock";
    if (avail < 0) {
      statusColor = Colors.red;
      statusText = "Oversold ($avail)";
    } else if (avail == 0) {
      statusColor = Colors.red;
      statusText = "Out of Stock";
    } else if (avail < 5) {
      statusColor = Colors.orange;
      statusText = "Low Stock";
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                // Product Image
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[200],
                  ),
                  child: item['imageUrl'].isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(item['imageUrl'], fit: BoxFit.cover),
                        )
                      : const Icon(Icons.agriculture),
                ),
                const SizedBox(width: 12),
                
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text('Total: $total', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const Text(' | ', style: TextStyle(color: Colors.grey)),
                          Text(
                            'Available: $avail',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                      Text('MK ${item['price']} per ${item['unit']}', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),

                // Status Badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'MK ${(item['price'] * avail).toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {/* Navigate to Edit */},
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: () => _confirmDelete(item['id'], item['name']),
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  label: const Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _confirmDelete(String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product?'),
        content: Text('Are you sure you want to remove $name?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('products').doc(id).delete();
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: text, size: 20),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontSize: 12, color: text.withOpacity(0.7))),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: text)),
        ],
      ),
    );
  }
}