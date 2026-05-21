import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:farm_app/data/cart_data.dart';

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
    // Get stock from 'quantity' field (now int64)
    _availableStock = (data['quantity'] ?? 0).toInt();
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

  // ✅ UPDATED: Add to cart with both farmerId (UID) and farmerName
  void addToCart() {
    // Check 1: Is product in stock?
    if (_availableStock <= 0) {
      _showMessage('❌ Product is out of stock');
      return;
    }

    // Check 2: Is requested quantity available?
    if (quantity > _availableStock) {
      _showMessage('❌ Only $_availableStock $_unit available');
      return;
    }

    final existingIndex = cartItems.indexWhere(
      (item) => item.productId == widget.data.id,
    );

    if (existingIndex >= 0) {
      final existingItem = cartItems[existingIndex];
      final desiredQuantity = existingItem.quantity + quantity;

      // Check 3: Will total exceed stock?
      if (desiredQuantity > _availableStock) {
        final remaining = _availableStock - existingItem.quantity;
        if (remaining <= 0) {
          _showMessage('❌ No more items available for this product');
          return;
        }

        setState(() {
          existingItem.quantity = _availableStock;
        });
        _showMessage(
          '⚠️ Only $_availableStock $_unit available. Added remaining $remaining.',
          isError: false,
        );
      } else {
        setState(() {
          existingItem.quantity = desiredQuantity;
        });
        _showMessage('✅ Added to cart', isError: false);
      }
      return;
    }

    // ✅ Add new item to cart with proper fields
    final data = widget.data.data() as Map<String, dynamic>;
    
    // Get farmerId (UID) from product data
    final farmerId = data['farmerId']?.toString() ?? '';
    final farmerName = data['farmerName']?.toString() ?? 'Farmer';
    final name = data['name']?.toString() ?? 'Unknown';
    final price = (data['price'] ?? 0).toDouble();
    final imageUrl = data['imageUrl']?.toString() ?? '';
    
    setState(() {
      cartItems.add(
        CartItem(
          productId: widget.data.id,
          name: name,
          price: price,
          quantity: quantity,
          imageUrl: imageUrl,
          farmerId: farmerId,      // ✅ Store farmer UID
          farmerName: farmerName,  // ✅ Store farmer name for display
          unit: _unit,
          stock: _availableStock,
        ),
      );
    });

    _showMessage('✅ Added $quantity $_unit to cart', isError: false);
  }

  void _increaseQuantity() {
    if (quantity < _availableStock) {
      setState(() {
        quantity++;
      });
    } else {
      _showMessage('❌ Only $_availableStock $_unit available');
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
    final farmerName = data['farmerName'] ?? data['farmer'] ?? 'Unknown';
    final farmerPhone = data['farmerPhone'] ?? 'Not set';
    final farmerLocation = data['location'] ?? data['farmerLocation'] ?? 'Not set';
    final price = (data['price'] ?? 0).toDouble();
    final imageUrl = data['imageUrl'] ?? '';
    final priceDisplay = data['priceDisplay'] ?? '';
    final isOutOfStock = _availableStock == 0;
    final isLowStock = _availableStock > 0 && _availableStock < 5;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: Text(data['name'] ?? 'Product'),
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
                    imageUrl,
                    width: double.infinity,
                    height: 250,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 250,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.image, size: 100, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product Name
                        Text(
                          data['name'] ?? '',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        // Price
                        Text(
                          priceDisplay.isNotEmpty 
                              ? priceDisplay 
                              : "MK $price / $_unit",
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Stock Indicator
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isOutOfStock 
                                ? Colors.red.shade50 
                                : isLowStock 
                                    ? Colors.orange.shade50 
                                    : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isOutOfStock 
                                    ? Icons.warning 
                                    : isLowStock 
                                        ? Icons.info_outline 
                                        : Icons.check_circle,
                                color: isOutOfStock 
                                    ? Colors.red 
                                    : isLowStock 
                                        ? Colors.orange 
                                        : Colors.green,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isOutOfStock 
                                    ? '❌ Out of Stock' 
                                    : isLowStock 
                                        ? '⚠️ Only $_availableStock $_unit left!'
                                        : '✅ Available: $_availableStock $_unit',
                                style: TextStyle(
                                  color: isOutOfStock 
                                      ? Colors.red.shade700 
                                      : isLowStock 
                                          ? Colors.orange.shade700 
                                          : Colors.green.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),
                        
                        // Farmer Details Card
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "👨‍🌾 Farmer Details",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(Icons.person, size: 18),
                                  const SizedBox(width: 8),
                                  Text("Name: $farmerName"),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 18),
                                  const SizedBox(width: 8),
                                  Text("Location: $farmerLocation"),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.phone, size: 18),
                                  const SizedBox(width: 8),
                                  Text("Phone: $farmerPhone"),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Quantity Selector (only if in stock)
                        if (!isOutOfStock) ...[
                          Row(
                            children: [
                              const Text(
                                "Quantity",
                                style: TextStyle(fontSize: 16),
                              ),
                              const SizedBox(width: 20),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove),
                                      onPressed: _decreaseQuantity,
                                    ),
                                    Text(
                                      quantity.toString(),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add),
                                      onPressed: quantity < _availableStock 
                                          ? _increaseQuantity 
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Max: $_availableStock $_unit',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Bottom Add to Cart Button
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: isOutOfStock ? null : addToCart,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isOutOfStock 
                    ? "Out of Stock" 
                    : "Add to Cart • MK ${(price * quantity).toStringAsFixed(2)}",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}