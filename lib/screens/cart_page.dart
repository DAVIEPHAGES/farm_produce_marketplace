import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/cart_data.dart';
import 'payment_processing_screan.dart';
import '../services/local_notification_service.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  bool _isProcessingPayment = false;
  bool _hasAutoProceed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Auto proceed to payment after login if cart has items
    final user = FirebaseAuth.instance.currentUser;
    if (user != null &&
        cartItems.isNotEmpty &&
        !_hasAutoProceed &&
        !_isProcessingPayment) {
      _hasAutoProceed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _proceedToPayment();
      });
    }
  }

  double getTotal() {
    double total = 0;
    for (final item in cartItems) {
      total += item.price * item.quantity;
    }
    return total;
  }

  int? _parseStock(Map<String, dynamic> data) {
    final stockValue = data['stock'];
    if (stockValue is num) return stockValue.toInt();
    if (stockValue is String) return int.tryParse(stockValue);

    final quantityValue = data['quantity'];
    if (quantityValue is num) return quantityValue.toInt();
    if (quantityValue is String) return int.tryParse(quantityValue);

    return null;
  }

  Future<bool> _validateCartStock() async {
    for (final item in cartItems) {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(item.productId)
          .get();

      if (!doc.exists) {
        continue;
      }

      final data = doc.data();
      if (data == null) {
        continue;
      }

      final stock = _parseStock(data);
      if (stock != null && item.quantity > stock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot place order: only $stock unit${stock == 1 ? '' : 's'} available for ${item.name}.',
            ),
          ),
        );
        return false;
      }
    }
    return true;
  }

  Future<DocumentReference<Map<String, dynamic>>?> _createOrder({
    required String paymentMethod,
    required String paymentStatus,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return null;
    }

    final total = getTotal();
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final orderRef = FirebaseFirestore.instance.collection('orders').doc();
    final firstItem = cartItems.isNotEmpty ? cartItems.first : null;

    // ✅ Get farmer UIDs (not names)
    final farmerIds = cartItems.map((item) => item.farmerId).toSet().toList();

    await orderRef.set({
      'customerId': user.uid,
      'customerName': userDoc.data()?['name'] ?? 'Customer',
      'customerEmail': user.email,
      'customerPhone': userDoc.data()?['phone'] ?? '',
      'farmerIds': farmerIds, // ✅ Now stores UIDs like "1XER15ZNEcgDrqBLfcnhKVR3yDp1"
      'imageUrl': firstItem?.imageUrl ?? '',
      'productName': firstItem?.name ?? '',
      'totalPrice': total,
      'status': 'Pending',
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // ✅ Create items subcollection with farmer UID
    for (final item in cartItems) {
      await orderRef.collection('items').add({
        'productId': item.productId,
        'productName': item.name,
        'name': item.name,
        'quantity': item.quantity,
        'price': item.price,
        'totalPrice': item.price * item.quantity,
        'imageUrl': item.imageUrl,
        'farmerId': item.farmerId, // ✅ Store farmer UID
        'farmerName': item.farmerName, // ✅ Store farmer name for display
        'unit': item.unit,
      });
    }

    // Show local notification for new order
    final customerName = userDoc.data()?['name'] ?? 'Customer';
    await LocalNotificationService.showNewOrderNotification(
      customerName,
      orderRef.id,
    );

    return orderRef;
  }

  // Show login dialog with redirect info
  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Login Required'),
        content: const Text(
          'Please login or create an account to complete your payment.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Pass redirect info to signin page
              Navigator.pushNamed(
                context,
                '/signin',
                arguments: {'redirectTo': '/cart'},
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  Future<void> _proceedToPayment() async {
    final user = FirebaseAuth.instance.currentUser;

    // If not logged in, show login dialog
    if (user == null) {
      _showLoginRequiredDialog();
      return;
    }

    // Reset auto proceed flag
    _hasAutoProceed = true;

    setState(() {
      _isProcessingPayment = true;
    });

    try {
      if (!await _validateCartStock()) {
        if (mounted) {
          setState(() {
            _isProcessingPayment = false;
          });
        }
        return;
      }

      final orderRef = await _createOrder(
        paymentMethod: 'paychangu',
        paymentStatus: 'pending',
      );

      if (orderRef == null || !mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data();
      final customerName = userData?['name'] ?? 'Customer';
      final customerEmail = user.email ?? 'customer@example.com';

      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (context) => PaymentProcessingScreen(
            amount: getTotal(),
            orderId: orderRef.id,
            customerName: customerName,
            customerEmail: customerEmail,
            cartItems: cartItems
                .map(
                  (item) => {
                    'id': item.productId,
                    'name': item.name,
                    'price': item.price,
                    'quantity': item.quantity,
                    'imageUrl': item.imageUrl,
                    'farmerId': item.farmerId,
                    'farmerName': item.farmerName,
                    'unit': item.unit,
                  },
                )
                .toList(),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error starting payment: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
      }
    }
  }

  void _clearCart() {
    setState(() {
      cartItems.clear();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Cart cleared')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Text('Cart (${cartItems.length})'),
        foregroundColor: Colors.white,
        actions: [
          if (cartItems.isNotEmpty)
            TextButton(
              onPressed: _clearCart,
              child: const Text('Clear', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: cartItems.isEmpty
          ? const Center(child: Text('Your cart is empty'))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      final subtotal = item.price * item.quantity;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Product Image
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                item.imageUrl,
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 70,
                                  height: 70,
                                  color: Colors.grey.shade200,
                                  child: const Icon(
                                    Icons.image,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Product Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),

                                  // Price per unit
                                  Row(
                                    children: [
                                      Text(
                                        'MK ${item.price.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: Colors.green.shade700,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '/ ${item.unit}',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  // ✅ Farmer name (for display)
                                  Text(
                                    'By: ${item.farmerName}',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 11,
                                    ),
                                  ),

                                  const SizedBox(height: 6),

                                  // Quantity controls with subtotal
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.remove,
                                                size: 18,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  if (item.quantity > 1) {
                                                    item.quantity -= 1;
                                                  } else {
                                                    cartItems.removeAt(index);
                                                  }
                                                });
                                              },
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(
                                                minWidth: 32,
                                                minHeight: 32,
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                  ),
                                              child: Text(
                                                '${item.quantity}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.add,
                                                size: 18,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  if (item.stock == null ||
                                                      item.quantity <
                                                          item.stock!) {
                                                    item.quantity += 1;
                                                  } else {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          'Only ${item.stock} unit${item.stock == 1 ? '' : 's'} available',
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                });
                                              },
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(
                                                minWidth: 32,
                                                minHeight: 32,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Subtotal
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          const Text(
                                            'Subtotal',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          Text(
                                            'MK ${subtotal.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
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
                  ),
                ),

                // Bottom Summary Bar
                Container(
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
                  child: Column(
                    children: [
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Items:',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              '${cartItems.length} item${cartItems.length > 1 ? 's' : ''}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Amount',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'MK ${getTotal().toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: ElevatedButton.icon(
                            onPressed: cartItems.isEmpty || _isProcessingPayment
                                ? null
                                : _proceedToPayment,
                            icon: _isProcessingPayment
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.payment, size: 20),
                            label: const Text(
                              'Pay with PayChangu',
                              style: TextStyle(fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 14,
                              ),
                              minimumSize: const Size(220, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
