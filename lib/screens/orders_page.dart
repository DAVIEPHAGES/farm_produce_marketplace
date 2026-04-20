import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final user = FirebaseAuth.instance.currentUser;

  String formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "Unknown date";
    final date = timestamp.toDate();
    return DateFormat('yyyy-MM-dd HH:mm').format(date);
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'Delivered':
        return Colors.green;
      case 'Processing':
        return Colors.blue;
      case 'Pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Please sign in to view orders")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        backgroundColor: const Color(0xFF2E7D32),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('customerId', isEqualTo: user!.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_bag_outlined,
                      size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No orders yet',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Your orders will appear here',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final orders = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final orderDoc = orders[index];
              final order = orderDoc.data() as Map<String, dynamic>;
              final status = order['status'] ?? 'Pending';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ExpansionTile(
                  title: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Order ${orderDoc.id.substring(0, 6)}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),

                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: getStatusColor(status)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: getStatusColor(status),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),

                  subtitle: Text(
                    "MK ${order['totalPrice']} • ${formatDate(order['timestamp'])}",
                  ),

                  children: [
                    // 🔥 ITEMS INSIDE ORDER
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('orders')
                          .doc(orderDoc.id)
                          .collection('items')
                          .snapshots(),

                      builder: (context, itemSnapshot) {
                        if (!itemSnapshot.hasData) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          );
                        }

                        final items = itemSnapshot.data!.docs;

                        return Column(
                          children: items.map((itemDoc) {
                            final item = itemDoc.data()
                                as Map<String, dynamic>;

                            return ListTile(
                              leading: Image.network(
                                item['imageUrl'] ?? '',
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.image),
                              ),
                              title: Text(
                                  item['productName'] ?? ''),
                              subtitle: Text(
                                  "Qty: ${item['quantity']}"),
                              trailing: Text(
                                "MK ${item['totalPrice']}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}