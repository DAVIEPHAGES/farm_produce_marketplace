import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminProductsPage extends StatefulWidget {
  const AdminProductsPage({super.key});

  @override
  State<AdminProductsPage> createState() => _AdminProductsPageState();
}

class _AdminProductsPageState extends State<AdminProductsPage> {
  String _searchQuery = '';
  bool _isDeleting = false;
  
  final TextEditingController _editNameController = TextEditingController();
  final TextEditingController _editPriceController = TextEditingController();
  final TextEditingController _editStockController = TextEditingController();
  final TextEditingController _editDescriptionController = TextEditingController();

  @override
  void dispose() {
    _editNameController.dispose();
    _editPriceController.dispose();
    _editStockController.dispose();
    _editDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _deleteProduct(String productId, String productName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "$productName"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      setState(() => _isDeleting = true);
      
      try {
        await FirebaseFirestore.instance
            .collection('products')
            .doc(productId)
            .delete();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product deleted successfully'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting product: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        setState(() => _isDeleting = false);
      }
    }
  }

  Future<void> _editProduct(String productId, Map<String, dynamic> data) async {
    _editNameController.text = data['name'] ?? '';
    _editPriceController.text = data['price']?.toString() ?? '';
    _editStockController.text = (data['stock'] ?? 0).toString();
    _editDescriptionController.text = data['description'] ?? '';
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Product'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _editNameController,
                decoration: const InputDecoration(labelText: 'Product Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _editPriceController,
                decoration: const InputDecoration(labelText: 'Price (MWK)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _editStockController,
                decoration: const InputDecoration(labelText: 'Stock Quantity'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _editDescriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      setState(() => _isDeleting = true);
      try {
        await FirebaseFirestore.instance
            .collection('products')
            .doc(productId)
            .update({
              'name': _editNameController.text,
              'price': double.tryParse(_editPriceController.text) ?? 0,
              'stock': int.tryParse(_editStockController.text) ?? 0,
              'description': _editDescriptionController.text,
              'updatedAt': FieldValue.serverTimestamp(),
            });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product updated successfully'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating product: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search products...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
        
        // Products List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('products')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              var products = snapshot.data!.docs;
              if (_searchQuery.isNotEmpty) {
                products = products.where((doc) {
                  final name = (doc['name'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery);
                }).toList();
              }
              
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  final data = product.data() as Map<String, dynamic>;
                  final productName = data['name'] ?? 'Unknown';
                  final price = (data['price'] ?? 0).toDouble();
                  final stock = data['stock'] ?? 0;
                  final imageUrl = data['imageUrl'];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 2,
                    child: ExpansionTile(
                      // ✅ FIXED: Added specific tile padding to gain horizontal space
                      tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: imageUrl != null && imageUrl.isNotEmpty
                            ? Image.network(imageUrl, width: 50, height: 50, fit: BoxFit.cover)
                            : Container(width: 50, height: 50, color: Colors.grey[200], child: const Icon(Icons.image)),
                      ),
                      title: Text(
                        productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis, // ✅ FIXED: Prevent long titles from causing overflow
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('MWK ${price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 4),
                          // ✅ FIXED: Using Wrap instead of Row to handle overflow of labels
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              _buildMiniChip(
                                stock > 0 ? 'In Stock ($stock)' : 'Out of Stock',
                                stock > 0 ? Colors.green : Colors.red,
                              ),
                              _buildMiniChip(data['category'] ?? 'Produce', Colors.blue),
                            ],
                          ),
                        ],
                      ),
                      // ✅ FIXED: Replaced Row of IconButtons with a PopupMenuButton to save horizontal space
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) {
                          if (value == 'edit') _editProduct(product.id, data);
                          if (value == 'delete') _deleteProduct(product.id, productName);
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: ListTile(
                              leading: Icon(Icons.edit, color: Colors.blue, size: 20),
                              title: Text('Edit'),
                              dense: true,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                              leading: Icon(Icons.delete, color: Colors.red, size: 20),
                              title: Text('Delete'),
                              dense: true,
                            ),
                          ),
                        ],
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoRow('Product ID:', product.id),
                              _buildInfoRow('Farmer:', data['farmerName'] ?? 'Unknown'),
                              _buildInfoRow('Description:', data['description'] ?? 'No description'),
                              _buildInfoRow('Listed On:', _formatDate(data['timestamp'])),
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

  Widget _buildMiniChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    }
    return 'Unknown';
  }
}