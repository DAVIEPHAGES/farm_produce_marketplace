import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/cart_data.dart';
import 'payment_page.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  bool _isProcessingPayment = false;

  double getTotal() {
    double total = 0;
    for (final item in cartItems) {
      total += item.price * item.quantity;
    }
    return total;
  }

  Future<DocumentReference<Map<String, dynamic>>?> _createOrder({
    required String paymentMethod,
    required String paymentStatus,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    // ✅ If not logged in, return null and show login dialog
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

    await orderRef.set({
      'customerId': user.uid,
      'customerName': userDoc.data()?['name'] ?? 'Customer',
      'customerEmail': user.email,
      'customerPhone': userDoc.data()?['phone'] ?? '',
      'farmerIds': cartItems.map((item) => item.farmer).toSet().toList(),
      'imageUrl': firstItem?.imageUrl ?? '',
      'productName': firstItem?.name ?? '',
      'totalPrice': total,
      'status': 'Pending',
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'timestamp': FieldValue.serverTimestamp(),
    });

    for (final item in cartItems) {
      await orderRef.collection('items').add({
        'productId': item.productId,
        'productName': item.name,
        'name': item.name,
        'quantity': item.quantity,
        'price': item.price,
        'totalPrice': item.price * item.quantity,
        'imageUrl': item.imageUrl,
        'farmerId': item.farmer,
      });
    }

    return orderRef;
  }

  // ✅ Show login dialog when user tries to pay without logging in
  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Login Required'),
        content: const Text('Please login or create an account to complete your payment.'),
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
              Navigator.pushNamed(context, '/signin');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  Future<void> _proceedToPayment() async {
    final user = FirebaseAuth.instance.currentUser;
    
    // ✅ If not logged in, show login dialog instead of redirecting
    if (user == null) {
      _showLoginRequiredDialog();
      return;
    }

    setState(() {
      _isProcessingPayment = true;
    });

    try {
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

      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (context) => PaymentPage(
            totalAmount: getTotal(),
            orderId: orderRef.id,
            cartItems: cartItems
                .map(
                  (item) => {
                    'id': item.productId,
                    'name': item.name,
                    'price': item.price,
                    'quantity': item.quantity,
                    'imageUrl': item.imageUrl,
                    'farmerId': item.farmer,
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
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Text('Cart (${cartItems.length})'),
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

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                item.imageUrl,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.image),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'MK ${(item.price * item.quantity).toStringAsFixed(2)}',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      if (item.quantity > 1) {
                                        item.quantity -= 1;
                                      } else {
                                        cartItems.removeAt(index);
                                      }
                                    });
                                  },
                                ),
                                Text(
                                  '${item.quantity}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      item.quantity += 1;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'MK ${getTotal().toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                // Pay with PayChangu button - NOT full width
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Center(
                    child: ElevatedButton.icon(
                      onPressed: cartItems.isEmpty || _isProcessingPayment
                          ? null
                          : _proceedToPayment,
                      icon: _isProcessingPayment
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.payment),
                      label: const Text(
                        'Pay with PayChangu',
                        style: TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}