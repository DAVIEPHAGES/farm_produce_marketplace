import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  String _reportType = 'daily';
  String _selectedYear = '2024';
  String _selectedMonth = 'all';
  
  Map<String, dynamic> _reportData = {};
  bool _isLoading = true;
  List<String> _availableYears = [];

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

      for (var doc in ordersSnapshot.docs) {
        final data = doc.data();
        
        // Get timestamp
        final timestamp = data['timestamp'];
        if (timestamp is Timestamp) {
          final year = timestamp.toDate().year.toString();
          years.add(year);
        }
        
        // Get order status - using correct field name
        final orderStatus = (data['orderStatus'] ?? data['status'] ?? 'pending').toString().toLowerCase();
        final paymentStatus = (data['paymentStatus'] ?? 'pending').toString().toLowerCase();
        
        // Count orders by status
        totalOrders++;
        
        if (orderStatus == 'delivered' || orderStatus == 'completed' || paymentStatus == 'completed') {
          completedOrders++;
          
          // Safely convert totalAmount
          final totalAmountValue = data['totalAmount'] ?? data['totalPrice'] ?? 0;
          if (totalAmountValue is num) {
            totalRevenue += totalAmountValue.toDouble();
          }
          
          // Track monthly revenue
          if (timestamp is Timestamp) {
            final date = timestamp.toDate();
            final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
            monthlyRevenue[monthKey] = (monthlyRevenue[monthKey] ?? 0) + (totalAmountValue.toDouble());
          }

          // Process items
          final items = data['items'] as List? ?? [];
          for (var item in items) {
            // Use correct field name: 'name' instead of 'productName'
            final productName = item['name']?.toString() ?? item['productName']?.toString() ?? '';
            final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
            
            if (productName.isNotEmpty) {
              productSales[productName] = (productSales[productName] ?? 0) + quantity;
            }
            
            // Track category if available
            final category = item['category']?.toString() ?? 'Uncategorized';
            categorySales[category] = (categorySales[category] ?? 0) + quantity;
          }
        } else if (orderStatus == 'pending') {
          pendingOrders++;
        } else if (orderStatus == 'cancelled') {
          cancelledOrders++;
        }
      }

      // Calculate average order value
      final averageOrderValue = completedOrders > 0 ? totalRevenue / completedOrders : 0;
      
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
        _availableYears = years.toList()..sort();
        if (_availableYears.isNotEmpty && _selectedYear == '2024') {
          _selectedYear = _availableYears.last;
        }
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
            // Filter Row
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                        value: _selectedYear,
                        items: _availableYears.map((year) {
                          return DropdownMenuItem(value: year, child: Text(year));
                        }).toList(),
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
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
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
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    title: 'Completed',
                    value: '${_reportData['completedOrders'] ?? 0}',
                    icon: Icons.check_circle,
                    color: Colors.green,
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
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    title: 'Cancelled',
                    value: '${_reportData['cancelledOrders'] ?? 0}',
                    icon: Icons.cancel,
                    color: Colors.red,
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
                      SizedBox(
                        height: 200,
                        child: _buildMonthlyChart(),
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
                                    Icon(Icons.inventory, size: 48, color: Colors.grey),
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
                        : (_reportData['topProducts'] as List).take(5).map((product) {
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
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Text(
                            '${category.key}: ${category.value} sold',
                            style: const TextStyle(fontSize: 13),
                          ),
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

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          ],
        ),
      ),
    );
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
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  monthName,
                  style: const TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _getMonthName(String monthNumber) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final index = int.tryParse(monthNumber) ?? 1;
    return months[index - 1];
  }
}