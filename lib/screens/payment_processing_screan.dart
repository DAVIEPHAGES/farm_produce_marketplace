import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'payment_success_screen.dart';
import '../services/local_notification_service.dart';
// ✅ Import cart_data to clear it after success
import '../data/cart_data.dart' as cart_data;

class PaymentProcessingScreen extends StatefulWidget {
  final String orderId;
  final String customerName;
  final String customerEmail;
  final double amount;
  final List<Map<String, dynamic>> cartItems;

  const PaymentProcessingScreen({
    Key? key,
    required this.orderId,
    required this.customerName,
    required this.customerEmail,
    required this.amount,
    required this.cartItems,
  }) : super(key: key);

  @override
  State<PaymentProcessingScreen> createState() =>
      _PaymentProcessingScreenState();
}

class _PaymentProcessingScreenState extends State<PaymentProcessingScreen> {
  bool _isProcessing = false;
  bool _isListening = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final String backendUrl = 'https://taps-boneless-seventeen.ngrok-free.dev';

  @override
  void initState() {
    super.initState();
    _saveOrderToFirestore();
  }

  Future<void> _saveOrderToFirestore() async {
    final User? user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    final orderDoc = await _firestore
        .collection('orders')
        .doc(widget.orderId)
        .get();
    final orderData = orderDoc.data();

    // ✅ NEW: Extract farmerIds so the order shows up on the Farmer's Dashboard
    final farmerIds = widget.cartItems
        .map((item) => item['farmerId']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final firstProductData = await _firstProductData();
    final pickupLocation = _firstNonEmpty([
      orderData?['pickupLocation'],
      orderData?['pickupAddress'],
      if (widget.cartItems.isNotEmpty) widget.cartItems.first['pickupLocation'],
      if (widget.cartItems.isNotEmpty) widget.cartItems.first['location'],
      if (widget.cartItems.isNotEmpty) widget.cartItems.first['farmerLocation'],
      firstProductData?['location'],
      firstProductData?['farmerLocation'],
      firstProductData?['pickupLocation'],
      firstProductData?['pickupAddress'],
    ], 'Pickup location not specified');
    final deliveryLocation = _firstNonEmpty([
      orderData?['deliveryLocation'],
      orderData?['deliveryAddress'],
      _customerDeliveryLocation(userData),
    ], 'Delivery address not specified');

    await _firestore.collection('orders').doc(widget.orderId).set({
      'orderId': widget.orderId,
      'customerId': user.uid,
      'customerName': widget.customerName,
      'customerEmail': widget.customerEmail,
      'customerPhone': userData?['phone'] ?? '',
      'farmerIds': farmerIds, // ✅ Added for dashboard logic
      'pickupLocation': pickupLocation,
      'pickupAddress': pickupLocation,
      'deliveryLocation': deliveryLocation,
      'deliveryAddress': deliveryLocation,
      'totalAmount': widget.amount,
      'totalPrice': widget.amount,
      'items': widget.cartItems,
      'paymentMethod': 'paychangu',
      'paymentStatus': 'pending',
      'orderStatus': 'pending',
      'status': 'Pending',
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    print('✅ Order saved to Firestore with Farmer IDs');
  }

  String _firstNonEmpty(List<dynamic> values, String fallback) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  String _customerDeliveryLocation(Map<String, dynamic>? userData) {
    return _firstNonEmpty([
      userData?['deliveryLocation'],
      userData?['deliveryAddress'],
      userData?['customerAddress'],
      userData?['address'],
      userData?['location'],
      userData?['fullAddress'],
    ], 'Delivery address not specified');
  }

  Future<Map<String, dynamic>?> _firstProductData() async {
    if (widget.cartItems.isEmpty) return null;

    final productId = widget.cartItems.first['productId']?.toString() ?? '';
    if (productId.isEmpty) return null;

    final productDoc = await _firestore
        .collection('products')
        .doc(productId)
        .get();
    return productDoc.data();
  }

  Future<void> _processPayment() async {
    setState(() => _isProcessing = true);
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/paychangu'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': _auth.currentUser?.uid,
          'name': widget.customerName,
          'email': widget.customerEmail,
          'amount': widget.amount.toString(),
          'orderId': widget.orderId,
        }),
      );

      final data = json.decode(response.body);
      final paymentUrl = data['paymentUrl'];

      if (paymentUrl != null && mounted) {
        _showOpenBrowserDialog(Uri.parse(paymentUrl));
      } else {
        throw Exception('No payment URL received');
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      _showError(e.toString());
    }
  }

  void _listenForPaymentStatus() {
    if (_isListening) return;
    _isListening = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('Processing Payment'),
        content: Text('Please wait while we confirm your payment...'),
      ),
    );

    _firestore.collection('orders').doc(widget.orderId).snapshots().listen((
      snapshot,
    ) async {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        if (data['paymentStatus'] == 'completed') {
          // ✅ STEP 1: Clear local cart memory
          cart_data.cartItems.clear();

          // ✅ STEP 2: Clear cart from Firestore database
          final user = _auth.currentUser;
          if (user != null) {
            await _firestore.collection('carts').doc(user.uid).delete();
          }

          // ✅ STEP 3: Notification
          await LocalNotificationService.showPaymentSuccessNotification(
            widget.orderId,
            widget.amount,
          );

          if (mounted) {
            Navigator.pop(context); // Close dialog
            _navigateToSuccess();
          }
        }
      }
    });
  }

  // --- Helper UI Methods ---

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _navigateToSuccess() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => PaymentSuccessScreen(
          customerName: widget.customerName,
          amount: widget.amount,
          orderId: widget.orderId,
        ),
      ),
    );
  }

  void _showOpenBrowserDialog(Uri url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Complete Payment'),
        content: const Text(
          'You will be redirected to PayChangu to pay MWK safely.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openInChrome(url);
            },
            child: const Text('Open Browser'),
          ),
        ],
      ),
    );
  }

  Future<void> _openInChrome(Uri url) async {
    if (await launchUrl(url, mode: LaunchMode.externalApplication)) {
      _listenForPaymentStatus();
    }
  }

  void _showCopyUrlDialog(Uri url) {
    /* ... Logic for manual copy ... */
    _listenForPaymentStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PayChangu Payment'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildInfoRow('Order ID:', widget.orderId),
                    _buildInfoRow(
                      'Total:',
                      'MWK ${widget.amount.toStringAsFixed(2)}',
                      isTotal: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isProcessing ? null : _processPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isProcessing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('PAY NOW'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          value,
          style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
