import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:farm_app/data/cart_data.dart'; // Ensure this path is correct

class ProduceDetailsPage extends StatefulWidget {
  final QueryDocumentSnapshot data;

  const ProduceDetailsPage({super.key, required this.data});

  @override
  State<ProduceDetailsPage> createState() => _ProduceDetailsPageState();
}

class _ProduceDetailsPageState extends State<ProduceDetailsPage> {
  int quantity = 1;
  int _availableStock = 0;
  String _unit = 'unit';

  @override
  void initState() {
    super.initState();
    final data = widget.data.data() as Map<String, dynamic>;
    
    // ✅ FIX: Using 'availableQuantity' to prevent overselling.
    // Fallback to 'quantity' if 'availableQuantity' doesn't exist.
    // If stock is negative (-2), we treat it as 0 for the customer.
    int rawStock = (data['availableQuantity'] ?? data['quantity'] ?? 0).toInt();
    _availableStock = rawStock < 0 ? 0 : rawStock; 
    
    _unit = data['sellingUnit'] ?? data['unit'] ?? 'unit';
  }

  void _showMessage(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void addToCart() {
    // 1. Double check stock before adding
    if (_availableStock <= 0) {
      _showMessage('❌ Sorry, this item is currently out of stock');
      return;
    }

    if (quantity > _availableStock) {
      _showMessage('❌ Not enough stock. Only $_availableStock $_unit left');
      return;
    }

    final existingIndex = cartItems.indexWhere(
      (item) => item.productId == widget.data.id,
    );

    if (existingIndex >= 0) {
      final existingItem = cartItems[existingIndex];
      final desiredQuantity = existingItem.quantity + quantity;

      if (desiredQuantity > _availableStock) {
        _showMessage('❌ You already have items in cart. Cannot exceed available stock.');
        return;
      } else {
        setState(() {
          existingItem.quantity = desiredQuantity;
        });
        _showMessage('✅ Cart updated', isError: false);
      }
      return;
    }

    final data = widget.data.data() as Map<String, dynamic>;
    
    setState(() {
      cartItems.add(
        CartItem(
          productId: widget.data.id,
          name: data['name'] ?? 'Unknown',
          price: (data['price'] ?? 0).toDouble(),
          quantity: quantity,
          imageUrl: data['imageUrl'] ?? '',
          farmerId: data['farmerId'] ?? '',
          farmerName: data['farmerName'] ?? 'Farmer',
          unit: _unit,
          stock: _availableStock,
        ),
      );
    });

    _showMessage('✅ Added to cart', isError: false);
  }

  void _increaseQuantity() {
    if (quantity < _availableStock) {
      setState(() {
        quantity++;
      });
    }
  }

  void _decreaseQuantity() {
    if (quantity > 1) {
      setState(() {
        quantity--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data.data() as Map<String, dynamic>;
    final price = (data['price'] ?? 0).toDouble();
    
    // ✅ Logic for UI state
    final isOutOfStock = _availableStock <= 0;
    final isLowStock = _availableStock > 0 && _availableStock < 5;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(data['name'] ?? 'Product Details'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image
                  Image.network(
                    data['imageUrl'] ?? '',
                    width: double.infinity,
                    height: 250,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 250, 
                      color: Colors.grey[200], 
                      child: const Icon(Icons.image, size: 50)
                    ),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['name'] ?? '',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "MK ${price.toStringAsFixed(2)} / $_unit",
                          style: const TextStyle(fontSize: 20, color: Colors.green, fontWeight: FontWeight.bold),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // ✅ STOCK INDICATOR
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isOutOfStock ? Colors.red[50] : isLowStock ? Colors.orange[50] : Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isOutOfStock ? Colors.red : isLowStock ? Colors.orange : Colors.green),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isOutOfStock ? Icons.cancel : isLowStock ? Icons.warning_amber : Icons.check_circle,
                                color: isOutOfStock ? Colors.red : isLowStock ? Colors.orange : Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isOutOfStock 
                                  ? 'Currently Out of Stock' 
                                  : isLowStock 
                                    ? 'Low Stock: Only $_availableStock left!' 
                                    : 'In Stock: $_availableStock $_unit available',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isOutOfStock ? Colors.red : isLowStock ? Colors.orange : Colors.green
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),
                        const Text("Description", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text(data['description'] ?? 'No description provided.', style: const TextStyle(color: Colors.grey)),
                        
                        const SizedBox(height: 24),
                        
                        // ✅ QUANTITY SELECTOR (Hidden if out of stock)
                        if (!isOutOfStock)
                          Row(
                            children: [
                              const Text("Quantity:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 20),
                              IconButton(onPressed: _decreaseQuantity, icon: const Icon(Icons.remove_circle_outline)),
                              Text('$quantity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              IconButton(onPressed: _increaseQuantity, icon: const Icon(Icons.add_circle_outline)),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // ✅ BOTTOM BUTTON (Disabled if out of stock)
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: isOutOfStock ? null : addToCart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOutOfStock ? Colors.grey : Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  isOutOfStock ? "NOT AVAILABLE" : "ADD TO CART • MK ${(price * quantity).toStringAsFixed(2)}",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}