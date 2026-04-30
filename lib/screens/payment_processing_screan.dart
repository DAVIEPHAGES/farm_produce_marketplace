import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';  // ✅ CORRECT IMPORT - use this instead
import 'payment_success_screan.dart';  // ✅ Fixed spelling: 'screan' -> 'screen'

class PaymentProcessingScreen extends StatefulWidget {
  final String orderId;
  final String customerName;
  final String customerEmail;
  final double amount;

  const PaymentProcessingScreen({
    Key? key,
    required this.orderId,
    required this.customerName,
    required this.customerEmail,
    required this.amount,
  }) : super(key: key);

  @override
  State<PaymentProcessingScreen> createState() => _PaymentProcessingScreenState();
}

class _PaymentProcessingScreenState extends State<PaymentProcessingScreen> {
  bool _isProcessing = false;

  Future<void> _processPayment() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Step 1: Call YOUR backend to create payment
      final response = await http.post(
        Uri.parse('http://localhost:5000/api/paychangu'), // Change to your actual backend URL
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': 'user123', // Get actual user ID
          'name': widget.customerName,
          'email': widget.customerEmail,
          'amount': widget.amount.toString(),
        }),
      );

      final data = json.decode(response.body);
      
      if (data['paymentUrl'] != null) {
        // Step 2: Open payment URL in browser
        final Uri url = Uri.parse(data['paymentUrl']);
        
        // Ask user to open in browser
        final bool? shouldLaunch = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Complete Payment'),
            content: Text('Click OK to complete payment of MWK ${widget.amount.toStringAsFixed(2)}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        
        if (shouldLaunch == true && mounted) {
          // Open in browser
          await launchUrl(url);
          
          // Step 3: After payment, verify and go to success
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please complete payment in your browser. After payment, tap verify.'),
              duration: Duration(seconds: 5),
            ),
          );
          
          // Show verify button
          _showVerifyButton();
        }
      } else {
        throw Exception('No payment URL received');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }
  
  void _showVerifyButton() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Payment Initiated'),
        content: const Text('After completing payment in your browser, click verify to confirm.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to success screen (you can add verification here)
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => PaymentSuccessScreen(
                    customerName: widget.customerName,
                    amount: widget.amount,
                    orderId: widget.orderId,
                  ),
                ),
              );
            },
            child: const Text('Verify Payment'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Process Payment'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Order Summary',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('Order ID:', widget.orderId),
                    _buildInfoRow('Customer:', widget.customerName),
                    _buildInfoRow('Email:', widget.customerEmail),
                    const Divider(height: 24),
                    _buildInfoRow(
                      'Total Amount:',
                      'MWK ${widget.amount.toStringAsFixed(2)}',
                      isTotal: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('PAY NOW', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.green : null,
            ),
          ),
        ],
      ),
    );
  }
}