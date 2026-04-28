import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  String _reportType = 'daily';
  Map<String, dynamic> _reportData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);

    try {
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .get();

      double totalRevenue = 0;
      int totalOrders = 0;
      int completedOrders = 0;
      Map<String, int> productSales = {};
      Map<String, int> categorySales = {};

      for (var doc in ordersSnapshot.docs) {
        final data = doc.data();
        final orderStatus = data['status']?.toString().toLowerCase() ?? '';
        
        // Count completed orders (paid or delivered)
        if (orderStatus == 'paid' || orderStatus == 'delivered') {
          completedOrders++;
          
          // Safely convert totalPrice
          final totalPriceValue = data['totalPrice'];
          if (totalPriceValue is num) {
            totalRevenue += totalPriceValue.toDouble();
          }
          totalOrders++;

          // Process items
          final items = data['items'] as List? ?? [];
          for (var item in items) {
            final productName = item['productName']?.toString() ?? '';
            // Safely convert quantity
            final quantityValue = item['quantity'];
            final quantity = quantityValue is num ? quantityValue.toInt() : 0;
            
            productSales[productName] = (productSales[productName] ?? 0) + quantity;
            
            // Track category if available
            final category = item['category']?.toString() ?? 'Uncategorized';
            categorySales[category] = (categorySales[category] ?? 0) + quantity;
          }
        }
      }

      // Calculate average order value
      final averageOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0;
      
      // Get top selling products (limit to 5)
      final topProducts = productSales.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      // Get top categories
      final topCategories = categorySales.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      setState(() {
        _reportData = {
          'totalRevenue': totalRevenue,
          'totalOrders': totalOrders,
          'completedOrders': completedOrders,
          'averageOrderValue': averageOrderValue,
          'topProducts': topProducts.take(5).toList(),
          'topCategories': topCategories.take(3).toList(),
        };
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading report: $e');
      setState(() => _isLoading = false);
    }
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
            // Revenue Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text(
                      'Total Revenue',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'MK ${(_reportData['totalRevenue'] ?? 0.0).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Stats Row
            Row(
              children: [
                Expanded(
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Icon(Icons.receipt, size: 32, color: Colors.blue),
                          const SizedBox(height: 8),
                          Text(
                            '${_reportData['totalOrders'] ?? 0}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'Total Orders',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle, size: 32, color: Colors.green),
                          const SizedBox(height: 8),
                          Text(
                            '${_reportData['completedOrders'] ?? 0}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const Text(
                            'Completed',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
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
                    const Text(
                      'Average Order Value:',
                      style: TextStyle(fontSize: 16),
                    ),
                    Text(
                      'MK ${(_reportData['averageOrderValue'] ?? 0.0).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
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
                    const SizedBox(height: 16),
                    ...(_reportData['topProducts'] as List? ?? []).isEmpty
                        ? [
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: Text(
                                  'No products sold yet',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ),
                          ]
                        : (_reportData['topProducts'] as List).map((product) {
                            final index = (_reportData['topProducts'] as List).indexOf(product) + 1;
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
                      children: (_reportData['topCategories'] as List? ?? []).map((category) {
                        return Chip(
                          label: Text('${category.key}: ${category.value} sold'),
                          backgroundColor: Colors.orange.shade100,
                          avatar: const Icon(Icons.category, size: 16),
                        );
                      }).toList(),
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
}