import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/cart_data.dart';
import '../services/paychangu_service.dart';

class PaymentPage extends StatefulWidget {
  final double totalAmount;
  final String orderId;
  final List<Map<String, dynamic>> cartItems;

  const PaymentPage({
    super.key,
    required this.totalAmount,
    required this.orderId,
    required this.cartItems,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  bool _isProcessing = false;

  Future<void> _processPayment() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorDialog('Please login to continue');
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final customerName = userDoc.data()?['name'] ?? 'Customer';
      final customerEmail = user.email ?? 'customer@example.com';

      final request = PayChanguService.createPaymentRequest(
        orderId: widget.orderId,
        customerName: customerName,
        customerEmail: customerEmail,
        amount: widget.totalAmount,
      );

      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text('Pay with PayChangu'),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            body: PayChanguService.instance.launchPayment(
              request: request,
              onSuccess: (response) async {
                final isValid = await PayChanguService.verifyTransaction(
                  response['tx_ref'],
                  widget.totalAmount,
                );

                if (isValid && mounted) {
                  await FirebaseFirestore.instance
                      .collection('orders')
                      .doc(widget.orderId)
                      .update({
                        'status': 'Processing',
                        'paymentStatus': 'completed',
                        'paymentTxRef': response['tx_ref'],
                        'paidAt': FieldValue.serverTimestamp(),
                      });

                  final currentUser = FirebaseAuth.instance.currentUser;
                  if (currentUser != null) {
                    await FirebaseFirestore.instance
                        .collection('carts')
                        .doc(currentUser.uid)
                        .delete();
                  }

                  cartItems.clear();

                  if (mounted) {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute<void>(
                        builder: (context) => PaymentSuccessPage(
                          orderId: widget.orderId,
                          amount: widget.totalAmount,
                        ),
                      ),
                    );
                  }
                } else {
                  _showErrorDialog('Payment verification failed');
                  if (mounted) {
                    Navigator.pop(context);
                  }
                }
              },
              onError: (error) {
                _showErrorDialog('Payment failed: $error');
                if (mounted) {
                  Navigator.pop(context);
                }
              },
              onCancel: () {
                _showErrorDialog('Payment was cancelled');
                if (mounted) {
                  Navigator.pop(context);
                }
              },
            ),
          ),
        ),
      );
    } catch (e) {
      _showErrorDialog('Error processing payment: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Order Summary',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text('Order ID: ${widget.orderId}'),
                Text('Items: ${widget.cartItems.length}'),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Amount:', style: TextStyle(fontSize: 16)),
                    Text(
                      'MK ${widget.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.phone_android, color: Colors.orange),
                    title: Text('Mobile Money'),
                    subtitle: Text('Airtel Money / TNM Mpamba'),
                  ),
                ),
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.credit_card, color: Colors.blue),
                    title: Text('Card Payment'),
                    subtitle: Text('Visa / Mastercard'),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'You will be redirected to PayChangu secure payment page',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Pay Now', style: TextStyle(fontSize: 18)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, size: 16, color: Colors.grey),
                const SizedBox(width: 5),
                Text(
                  'Secure payment powered by PayChangu',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentSuccessPage extends StatelessWidget {
  final String orderId;
  final double amount;

  const PaymentSuccessPage({
    super.key,
    required this.orderId,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 100),
              const SizedBox(height: 20),
              const Text(
                'Payment Successful!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 10),
              Text('Order #$orderId', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 5),
              Text(
                'Amount paid: MK ${amount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              const Text(
                'You will receive a confirmation SMS shortly',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/orders',
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 15,
                  ),
                ),
                child: const Text(
                  'View My Orders',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
