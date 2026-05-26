import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'payment_success_screen.dart';
import '../services/local_notification_service.dart';
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

  static const String backendUrl = String.fromEnvironment(
    'PAYCHANGU_BACKEND_URL',
    defaultValue: 'https://taps-boneless-seventeen.ngrok-free.dev',
  );

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

    final farmerIds = widget.cartItems
        .map((item) => item['farmerId']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final firstItem = widget.cartItems.isNotEmpty
        ? widget.cartItems.first
        : null;

    await _firestore.collection('orders').doc(widget.orderId).set({
      'orderId': widget.orderId,
      'customerId': user.uid,
      'customerName': widget.customerName,
      'customerEmail': widget.customerEmail,
      'customerPhone': userData?['phone'] ?? '',
      'farmerIds': farmerIds,
      'imageUrl': firstItem?['imageUrl'] ?? '',
      'productName': firstItem?['name'] ?? '',
      'totalPrice': widget.amount,
      'totalAmount': widget.amount,
      'items': widget.cartItems,
      'paymentMethod': 'paychangu',
      'paymentStatus': 'pending',
      'status': 'Pending',
      'orderStatus': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    print('✅ Order saved to Firestore');
  }

  Future<void> _processPayment() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Call YOUR backend (not PayChangu directly)
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

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Backend returned ${response.statusCode}: ${response.body}',
        );
      }

      final data = json.decode(response.body);
      print('Backend Response: $data');

      final paymentUrl = data['paymentUrl'];

      if (paymentUrl != null && mounted) {
        final Uri url = Uri.parse(paymentUrl);
        print('Payment URL: $url');

        // Show dialog before opening browser
        _showOpenBrowserDialog(url);
      } else {
        throw Exception('No payment URL received from backend');
      }
    } catch (e) {
      print('❌ Payment error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showOpenBrowserDialog(Uri url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Open Payment Page'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'You will be redirected to PayChangu to complete your payment.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber[700]),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'After payment, please return to the app.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isProcessing = false;
              });
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _openInChrome(url);
            },
            icon: const Icon(Icons.open_in_browser),
            label: const Text('Open in Chrome'),
          ),
        ],
      ),
    );
  }

  Future<void> _openInChrome(Uri url) async {
    try {
      // Force open in external browser (Chrome)
      final bool launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );

      if (launched) {
        // Start listening for payment status
        _listenForPaymentStatus();
      } else {
        _showCopyUrlDialog(url);
      }
    } catch (e) {
      print('Error opening Chrome: $e');
      _showCopyUrlDialog(url);
    }
  }

  void _showCopyUrlDialog(Uri url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please open this link in your browser:'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                url.toString(),
                style: const TextStyle(color: Colors.blue, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isProcessing = false;
              });
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url.toString()));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Link copied to clipboard!'),
                  backgroundColor: Colors.green,
                ),
              );
              _listenForPaymentStatus();
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copy Link'),
          ),
        ],
      ),
    );
  }

  void _listenForPaymentStatus() {
    if (_isListening) return;
    _isListening = true;

    print('👂 Listening for payment status changes...');

    // Show waiting dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Processing Payment'),
        content: const Text('Please wait while we confirm your payment...'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isProcessing = false;
                _isListening = false;
              });
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    // Listen to Firestore for status change
    FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .snapshots()
        .listen((snapshot) async {
          if (snapshot.exists) {
            final data = snapshot.data() as Map<String, dynamic>;
            final paymentStatus = data['paymentStatus'];

            print('📢 Payment status: $paymentStatus');

            if (paymentStatus == 'completed') {
              print('🎉 Payment completed!');

              final currentUser = _auth.currentUser;
              if (currentUser != null) {
                await _firestore
                    .collection('carts')
                    .doc(currentUser.uid)
                    .delete();
              }
              cart_data.cartItems.clear();

              await LocalNotificationService.showPaymentSuccessNotification(
                widget.orderId,
                widget.amount,
              );

              if (mounted) Navigator.pop(context);
              _navigateToSuccess();
            }
          }
        });
  }

  void _navigateToSuccess() {
    if (mounted) {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay with PayChangu'),
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
                    _buildInfoRow('Customer:', widget.customerName),
                    _buildInfoRow('Email:', widget.customerEmail),
                    const Divider(),
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
            Center(
              child: SizedBox(
                width: 220,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _processPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(),
                        )
                      : const Text('PAY NOW', style: TextStyle(fontSize: 16)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'After payment, your order will be automatically confirmed.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
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
      ),
    );
  }
}
