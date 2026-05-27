import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/cart_data.dart';
import 'payment_processing_screan.dart'; // Ensure this matches your actual filename
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

  // ✅ UPDATED: Prioritizes availableQuantity to prevent overselling (-2 issue)
  int? _parseStock(Map<String, dynamic> data) {
    if (data.containsKey('availableQuantity')) {
      return (data['availableQuantity'] as num).toInt();
    }
    if (data.containsKey('quantity')) {
      return (data['quantity'] as num).toInt();
    }
    return null;
  }

  // ✅ UPDATED: Final check before letting the customer pay
  Future<bool> _validateCartStock() async {
    for (final item in cartItems) {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(item.productId)
          .get();

      if (!doc.exists) {
        _showMessage('❌ ${item.name} is no longer available.');
        return false;
      }

      final data = doc.data()!;
      final stock = _parseStock(data);

      // If stock is 0 or less (e.g., -2), stop the payment
      if (stock != null && (stock <= 0 || item.quantity > stock)) {
        _showMessage(
          stock <= 0 
            ? '❌ Sorry, ${item.name} is out of stock!' 
            : '⚠️ Only $stock left of ${item.name}. Please reduce quantity.',
        );
        return false;
      }
    }
    return true;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<DocumentReference<Map<String, dynamic>>?> _createOrder({
    required String paymentMethod,
    required String paymentStatus,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final total = getTotal();
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final orderRef = FirebaseFirestore.instance.collection('orders').doc();
    final firstItem = cartItems.isNotEmpty ? cartItems.first : null;

    // Collect all unique farmer UIDs
    final farmerIds = cartItems.map((item) => item.farmerId).toSet().toList();

    await orderRef.set({
      'orderId': orderRef.id,
      'customerId': user.uid,
      'customerName': userDoc.data()?['name'] ?? 'Customer',
      'customerEmail': user.email,
      'customerPhone': userDoc.data()?['phone'] ?? '',
      'farmerIds': farmerIds,
      'imageUrl': firstItem?.imageUrl ?? '',
      'productName': firstItem?.name ?? '',
      'totalPrice': total,
      'totalAmount': total,
      'status': 'Pending',
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Create subcollection for items
    for (final item in cartItems) {
      await orderRef.collection('items').add({
        'productId': item.productId,
        'name': item.name,
        'quantity': item.quantity,
        'price': item.price,
        'totalPrice': item.price * item.quantity,
        'imageUrl': item.imageUrl,
        'farmerId': item.farmerId,
        'farmerName': item.farmerName,
        'unit': item.unit,
      });
    }

    await LocalNotificationService.showNewOrderNotification(
      userDoc.data()?['name'] ?? 'Customer',
      orderRef.id,
    );

    return orderRef;
  }

  Future<void> _proceedToPayment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showLoginRequiredDialog();
      return;
    }

    setState(() => _isProcessingPayment = true);

    try {
      // 1. Check stock one last time
      if (!await _validateCartStock()) {
        setState(() => _isProcessingPayment = false);
        return;
      }

      // 2. Create the order document
      final orderRef = await _createOrder(
        paymentMethod: 'paychangu',
        paymentStatus: 'pending',
      );

      if (orderRef == null || !mounted) {
        setState(() => _isProcessingPayment = false);
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      final customerName = userDoc.data()?['name'] ?? 'Customer';

      // 3. Move to processing screen with all necessary data
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (context) => PaymentProcessingScreen(
            amount: getTotal(),
            orderId: orderRef.id,
            customerName: customerName,
            customerEmail: user.email ?? '',
            cartItems: cartItems.map((item) => {
              'productId': item.productId, // Required for stock reduction
              'name': item.name,
              'price': item.price,
              'quantity': item.quantity,
              'imageUrl': item.imageUrl,
              'farmerId': item.farmerId, // Required for dashboard earnings
              'farmerName': item.farmerName,
              'unit': item.unit,
            }).toList(),
          ),
        ),
      );
    } catch (e) {
      _showMessage('Error: $e');
    } finally {
      if (mounted) setState(() => _isProcessingPayment = false);
    }
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Required'),
        content: const Text('Please login to complete your purchase.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/signin', arguments: {'redirectTo': '/cart'});
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  void _clearCart() {
    setState(() => cartItems.clear());
    _showMessage('Cart cleared');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        title: Text('Cart (${cartItems.length})'),
        actions: [
          if (cartItems.isNotEmpty)
            IconButton(onPressed: _clearCart, icon: const Icon(Icons.delete_sweep)),
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
                      return _buildCartItemTile(item, index);
                    },
                  ),
                ),
                _buildSummaryBar(),
              ],
            ),
    );
  }

  Widget _buildCartItemTile(CartItem item, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(item.imageUrl, width: 50, height: 50, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.image),
          ),
        ),
        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('MK ${item.price} / ${item.unit}\nFarmer: ${item.farmerName}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () => setState(() {
                if (item.quantity > 1) item.quantity--;
                else cartItems.removeAt(index);
              }),
            ),
            Text('${item.quantity}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => setState(() {
                if (item.stock == null || item.quantity < item.stock!) {
                  item.quantity++;
                } else {
                  _showMessage('Only ${item.stock} available');
                }
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Amount', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('MK ${getTotal().toStringAsFixed(2)}', 
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isProcessingPayment ? null : _proceedToPayment,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              child: _isProcessingPayment 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('PROCEED TO PAYMENT', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}