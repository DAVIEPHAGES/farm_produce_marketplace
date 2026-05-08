import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'payment_success_screen.dart';
import '../services/local_notification_service.dart';  // ✅ ADD THIS

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
  State<PaymentProcessingScreen> createState() => _PaymentProcessingScreenState();
}

class _PaymentProcessingScreenState extends State<PaymentProcessingScreen> {
  bool _isProcessing = false;
  bool _isListening = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Your ngrok URL from ngrok
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

    await _firestore.collection('orders').doc(widget.orderId).set({
      'orderId': widget.orderId,
      'customerId': user.uid,
      'customerName': widget.customerName,
      'customerEmail': widget.customerEmail,
      'customerPhone': userData?['phone'] ?? '',
      'totalAmount': widget.amount,
      'items': widget.cartItems,
      'paymentMethod': 'paychangu',
      'paymentStatus': 'pending',
      'orderStatus': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
    
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

      final data = json.decode(response.body);
      print('Backend Response: $data');
      
      final paymentUrl = data['paymentUrl'];

      if (paymentUrl != null && mounted) {
        // Open in browser
        final Uri url = Uri.parse(paymentUrl);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
          
          // Start listening for payment status
          _listenForPaymentStatus();
        }
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
    
    // Listen to Firestore for status change (webhook will update this)
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
          
          // ✅ SHOW LOCAL NOTIFICATION
          await LocalNotificationService.showPaymentSuccessNotification(
            widget.orderId,
            widget.amount,
          );
          
          // Close dialog
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
                    _buildInfoRow('Total:', 'MWK ${widget.amount.toStringAsFixed(2)}', isTotal: true),
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
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isProcessing
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator())
                  : const Text('PAY NOW', style: TextStyle(fontSize: 18)),
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
          Text(value, style: TextStyle(fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}