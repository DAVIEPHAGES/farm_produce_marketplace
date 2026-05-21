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

  String selectedTab = "All";
  String searchQuery = "";

  final tabs = ["All", "Paid", "Pending", "Cancelled"];

  String formatDate(Timestamp? timestamp) {
    if (timestamp == null) return "";
    final date = timestamp.toDate();
    return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
  }

  // ✅ UPDATED: Use paymentStatus instead of status
  String getOrderStatus(Map<String, dynamic> data) {
    // Check paymentStatus first (from webhook)
    if (data['paymentStatus'] == 'completed') {
      return 'Paid ✓';
    }
    // Fallback to old status field
    return data['status'] ?? 'Pending';
  }

  // ✅ UPDATED: Color based on paymentStatus
  Color getStatusColor(String status) {
    switch (status) {
      case 'Paid ✓':
        return Colors.green;
      case 'Delivered':
        return Colors.green;
      case 'Processing':
        return Colors.blue;
      case 'Pending':
        return Colors.orange;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  // ✅ UPDATED: Map to tabs
  String mapStatusToTab(String status) {
    if (status == "Paid ✓") return "Paid";
    if (status == "Cancelled") return "Cancelled";
    if (status == "Pending") return "Pending";
    return "All";
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Please sign in")));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          /// HERO HEADER
          Stack(
            children: [
              Image.network(
                "https://images.unsplash.com/photo-1542838132-92c53300491e",
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              Container(
                height: 180,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.9),
                      Colors.white.withOpacity(0.6),
                      Colors.transparent,
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
              const Positioned(
                left: 16,
                top: 70,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "My Orders",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "Track and manage your farm fresh orders",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),

          /// TABS + SEARCH
          Container(
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: tabs.map((tab) {
                    final isSelected = selectedTab == tab;

                    return GestureDetector(
                      onTap: () {
                        setState(() => selectedTab = tab);
                      },
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              tab,
                              style: TextStyle(
                                color: isSelected ? Colors.green : Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            height: 2,
                            width: 60,
                            color: isSelected
                                ? Colors.green
                                : Colors.transparent,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),

                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    onChanged: (val) =>
                        setState(() => searchQuery = val.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: "Search orders...",
                      prefixIcon: const Icon(Icons.search),
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

          /// ORDER LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('customerId', isEqualTo: user!.uid)
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

                  // ✅ UPDATED: Use paymentStatus to determine status
                  String status;
                  if (data['paymentStatus'] == 'completed') {
                    status = 'Paid ✓';
                  } else if (data['orderStatus'] == 'cancelled') {
                    status = 'Cancelled';
                  } else {
                    status = 'Pending';
                  }

                  final matchesTab = selectedTab == "All"
                      ? true
                      : mapStatusToTab(status) == selectedTab;

                  final matchesSearch = doc.id.toLowerCase().contains(
                    searchQuery,
                  );

                  return matchesTab && matchesSearch;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text("No orders found"));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    final data = doc.data() as Map<String, dynamic>;

                    // ✅ UPDATED: Determine display status
                    String displayStatus;
                    if (data['paymentStatus'] == 'completed') {
                      displayStatus = 'Paid ✓';
                    } else if (data['orderStatus'] == 'cancelled') {
                      displayStatus = 'Cancelled';
                    } else {
                      displayStatus = 'Pending';
                    }

                    final totalAmount =
                        data['totalAmount'] ?? data['totalPrice'] ?? 0;
                    final imageUrl = data['imageUrl'] ?? '';
                    final itemsList = data['items'] as List? ?? [];

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OrderDetailsPage(
                              orderId: doc.id,
                              orderData: data,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    imageUrl,
                                    width: 70,
                                    height: 70,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.image),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Order #${doc.id.substring(0, 6)}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        formatDate(data['timestamp']),
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: getStatusColor(
                                            displayStatus,
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          displayStatus,
                                          style: TextStyle(
                                            color: getStatusColor(
                                              displayStatus,
                                            ),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "MK ${totalAmount.toStringAsFixed(2)}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 14,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Items preview
                            Row(
                              children: [
                                ...itemsList.take(3).map((item) {
                                  return Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    width: 35,
                                    height: 35,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.network(
                                        item['imageUrl'] ?? '',
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.image),
                                      ),
                                    ),
                                  );
                                }).toList(),
                                if (itemsList.length > 3)
                                  Container(
                                    width: 35,
                                    height: 35,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      "+${itemsList.length - 3}",
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// ORDER DETAILS PAGE
class OrderDetailsPage extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> orderData;

  const OrderDetailsPage({
    super.key,
    required this.orderId,
    required this.orderData,
  });

  String getDisplayStatus(Map<String, dynamic> data) {
    if (data['paymentStatus'] == 'completed') return 'Paid ✓';
    if (data['orderStatus'] == 'cancelled') return 'Cancelled';
    return 'Pending';
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'Paid ✓':
        return Colors.green;
      case 'Delivered':
        return Colors.green;
      case 'Processing':
        return Colors.blue;
      case 'Pending':
        return Colors.orange;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayStatus = getDisplayStatus(orderData);
    final totalAmount =
        orderData['totalAmount'] ?? orderData['totalPrice'] ?? 0;
    final itemsList = orderData['items'] as List? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Order Details"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: getStatusColor(displayStatus).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                displayStatus,
                style: TextStyle(
                  color: getStatusColor(displayStatus),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Total: MK ${totalAmount.toStringAsFixed(2)}",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            const Text("Items", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: itemsList.length,
                itemBuilder: (context, index) {
                  final item = itemsList[index];
                  return ListTile(
                    leading: Image.network(
                      item['imageUrl'] ?? '',
                      width: 40,
                      errorBuilder: (_, __, ___) => const Icon(Icons.image),
                    ),
                    title: Text(item['name'] ?? ''),
                    subtitle: Text("Qty: ${item['quantity']}"),
                    trailing: Text(
                      "MWK ${(item['price'] * item['quantity']).toStringAsFixed(2)}",
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
