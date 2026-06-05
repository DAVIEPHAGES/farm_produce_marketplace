import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminFarmersPage extends StatefulWidget {
  const AdminFarmersPage({super.key});

  @override
  State<AdminFarmersPage> createState() => _AdminFarmersPageState();
}

class _AdminFarmersPageState extends State<AdminFarmersPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleFarmerVerification(String farmerId, bool currentStatus) async {
    setState(() => _isLoading = true);
    
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(farmerId)
          .update({
            'isVerified': !currentStatus,
            'verifiedAt': !currentStatus ? FieldValue.serverTimestamp() : null,
          });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Farmer ${!currentStatus ? 'verified' : 'unverified'} successfully!'),
            backgroundColor: !currentStatus ? Colors.green : Colors.orange,
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
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteFarmer(String farmerId, String farmerName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Farmer'),
        content: Text('Are you sure you want to delete $farmerName? All their products will also be deleted. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    
    if (confirm == true) {
      setState(() => _isLoading = true);
      
      try {
        // Delete all products by this farmer
        final products = await FirebaseFirestore.instance
            .collection('products')
            .where('farmerId', isEqualTo: farmerId)
            .get();
        
        for (var product in products.docs) {
          await product.reference.delete();
        }
        
        // Delete the farmer
        await FirebaseFirestore.instance.collection('users').doc(farmerId).delete();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$farmerName deleted successfully!'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<Map<String, dynamic>> _getFarmerStats(String farmerId) async {
    // Get products count
    final productsSnapshot = await FirebaseFirestore.instance
        .collection('products')
        .where('farmerId', isEqualTo: farmerId)
        .get();
    
    // Get sales from orders
    final ordersSnapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('farmerIds', arrayContains: farmerId)
        .get();
    
    double totalSales = 0;
    int completedOrders = 0;
    
    for (var order in ordersSnapshot.docs) {
      final data = order.data();
      if (data['paymentStatus'] == 'completed' || data['orderStatus'] == 'delivered') {
        totalSales += (data['totalAmount'] ?? 0).toDouble();
        completedOrders++;
      }
    }
    
    return {
      'productCount': productsSnapshot.size,
      'totalSales': totalSales,
      'completedOrders': completedOrders,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search farmers by name, email, or farm name...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                          _searchController.clear();
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
        ),
        
        // Farmers List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('userType', isEqualTo: 'farmer')
                .orderBy('createdAt', descending: true)
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
                      Icon(Icons.agriculture, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No farmers registered yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ],
                  ),
                );
              }
              
              var farmers = snapshot.data!.docs;
              
              // Apply search filter
              if (_searchQuery.isNotEmpty) {
                farmers = farmers.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toLowerCase();
                  final email = (data['email'] ?? '').toLowerCase();
                  final farmName = (data['farmName'] ?? '').toLowerCase();
                  return name.contains(_searchQuery) || 
                         email.contains(_searchQuery) || 
                         farmName.contains(_searchQuery);
                }).toList();
              }
              
              if (farmers.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No farmers match your search', style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ],
                  ),
                );
              }
              
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: farmers.length,
                itemBuilder: (context, index) {
                  final farmer = farmers[index];
                  final data = farmer.data() as Map<String, dynamic>;
                  
                  return FutureBuilder<Map<String, dynamic>>(
                    future: _getFarmerStats(farmer.id),
                    builder: (context, statsSnapshot) {
                      final productCount = statsSnapshot.data?['productCount'] ?? 0;
                      final totalSales = statsSnapshot.data?['totalSales'] ?? 0;
                      final completedOrders = statsSnapshot.data?['completedOrders'] ?? 0;
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            radius: 25,
                            backgroundColor: data['isVerified'] == true
                                ? Colors.green
                                : Colors.orange,
                            child: Text(
                              data['name']?.substring(0, 1).toUpperCase() ?? 'F',
                              style: const TextStyle(color: Colors.white, fontSize: 18),
                            ),
                          ),
                          title: Text(
                            data['name'] ?? 'Unknown Farmer',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['email'] ?? 'No email'),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                children: [
                                  if (data['isVerified'] == true)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'Verified',
                                        style: TextStyle(color: Colors.white, fontSize: 10),
                                      ),
                                    ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$productCount products',
                                      style: const TextStyle(color: Colors.white, fontSize: 10),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (data['isVerified'] == true)
                                const Icon(Icons.verified, color: Colors.green, size: 20),
                              const SizedBox(width: 8),
                              Chip(
                                label: Text(data['isVerified'] == true ? 'Active' : 'Pending'),
                                backgroundColor: data['isVerified'] == true ? Colors.green : Colors.orange,
                                labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Farmer Basic Info
                                  const Text(
                                    'Farmer Information:',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildInfoRow('Farmer ID:', farmer.id),
                                  _buildInfoRow('Name:', data['name'] ?? 'Not provided'),
                                  _buildInfoRow('Email:', data['email'] ?? 'Not provided'),
                                  _buildInfoRow('Phone:', data['phone'] ?? 'Not provided'),
                                  _buildInfoRow('Joined:', _formatDate(data['createdAt'])),
                                  
                                  const Divider(),
                                  
                                  // Farm Details
                                  const Text(
                                    'Farm Details:',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildInfoRow('Farm Name:', data['farmName'] ?? 'Not provided'),
                                  _buildInfoRow('Address:', data['farmAddress'] ?? 'Not provided'),
                                  _buildInfoRow('City:', data['farmCity'] ?? 'Not provided'),
                                  _buildInfoRow('District:', data['farmDistrict'] ?? 'Not provided'),
                                  if (data['farmDescription'] != null && data['farmDescription'].isNotEmpty)
                                    _buildInfoRow('Description:', data['farmDescription']),
                                  
                                  const Divider(),
                                  
                                  // Statistics
                                  const Text(
                                    'Statistics:',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildInfoRow('Total Products:', productCount.toString()),
                                  _buildInfoRow('Total Sales:', 'MWK ${totalSales.toStringAsFixed(2)}'),
                                  _buildInfoRow('Completed Orders:', completedOrders.toString()),
                                  _buildInfoRow('Rating:', '⭐ ${data['rating'] ?? 0.0}'),
                                  
                                  const Divider(),
                                  
                                  // Actions
                                  const Text(
                                    'Actions:',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _isLoading
                                              ? null
                                              : () => _toggleFarmerVerification(
                                                  farmer.id,
                                                  data['isVerified'] ?? false,
                                                ),
                                          icon: Icon(
                                            data['isVerified'] == true
                                                ? Icons.verified
                                                : Icons.verified_user,
                                          ),
                                          label: Text(
                                            data['isVerified'] == true
                                                ? 'Unverify Farmer'
                                                : 'Verify Farmer',
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: data['isVerified'] == true
                                                ? Colors.orange
                                                : Colors.green,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => _deleteFarmer(farmer.id, data['name'] ?? 'Farmer'),
                                          icon: const Icon(Icons.delete),
                                          label: const Text('Delete Farmer'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.red,
                                            side: const BorderSide(color: Colors.red),
                                          ),
                                        ),
                                      ),
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
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    }
    return 'Unknown';
  }
}