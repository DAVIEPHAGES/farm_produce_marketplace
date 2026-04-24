import 'dart:convert';
import 'dart:html' as html;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/paychangu_keys.dart';

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
  bool _isHandlingCallback = false;
  bool _isPaymentSuccessful = false;
  String? _statusMessage;
  String? _txRef;
  bool _callbackHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleCallbackIfPresent();
    });
  }

  Future<void> _handleCallbackIfPresent() async {
    if (_callbackHandled || !_isPayChanguCallback) {
      return;
    }

    _callbackHandled = true;

    final queryParams = Uri.base.queryParameters;
    final txRef = queryParams['tx_ref'] ?? queryParams['txRef'];
    final status = (queryParams['status'] ?? '').toLowerCase();

    if (txRef == null || txRef.isEmpty) {
      setState(() {
        _statusMessage =
            'PayChangu returned to the app, but no transaction reference was included.';
      });
      _clearCallbackFromUrl();
      return;
    }

    setState(() {
      _isHandlingCallback = true;
      _txRef = txRef;
      _statusMessage = null;
    });

    try {
      if (status == 'success') {
        final verified = await _verifyTransaction(txRef);
        if (verified) {
          await _markOrderPaid(txRef);
          setState(() {
            _isPaymentSuccessful = true;
            _statusMessage = 'Payment verified successfully.';
          });
        } else {
          await _markOrderVerificationPending(txRef);
          setState(() {
            _statusMessage =
                'Payment returned successfully, but browser-side verification could not be completed. The order was left pending verification.';
          });
        }
      } else {
        await _markOrderFailed(txRef, status);
        setState(() {
          _statusMessage = status == 'failed'
              ? 'Payment was not completed.'
              : 'Payment was cancelled or interrupted.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isHandlingCallback = false;
        });
      }
      _clearCallbackFromUrl();
    }
  }

  Future<void> _startHostedCheckout() async {
    if (payChanguPublicKey.isEmpty) {
      _showMessage(
        'Add your PayChangu public key with --dart-define=PAYCHANGU_PUBLIC_KEY=pub-... before using web checkout.',
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.pushNamed(context, '/signin');
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = null;
    });

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final customerName =
          (userDoc.data()?['name'] ?? user.displayName ?? 'Customer')
              .toString()
              .trim();
      final customerEmail = (user.email ?? 'customer@example.com').trim();
      final txRef =
          'ORDER_${widget.orderId}_${DateTime.now().millisecondsSinceEpoch}';

      final callbackUrl = _buildReturnUri().toString();
      final nameParts = _splitName(customerName);

      final form = html.FormElement()
        ..method = 'POST'
        ..action = 'https://api.paychangu.com/hosted-payment-page'
        ..target = '_self';

      void addHiddenField(String name, String value) {
        form.children.add(
          html.InputElement()
            ..type = 'hidden'
            ..name = name
            ..value = value,
        );
      }

      addHiddenField('public_key', payChanguPublicKey);
      addHiddenField('callback_url', callbackUrl);
      addHiddenField('return_url', callbackUrl);
      addHiddenField('tx_ref', txRef);
      addHiddenField('amount', widget.totalAmount.toInt().toString());
      addHiddenField('currency', 'MWK');
      addHiddenField('email', customerEmail);
      addHiddenField('first_name', nameParts.$1);
      addHiddenField('last_name', nameParts.$2);
      addHiddenField('title', 'Farm Produce Marketplace');
      addHiddenField('description', 'Order ${widget.orderId}');

      html.document.body?.children.add(form);
      form.submit();
      form.remove();
    } catch (e) {
      _showMessage('Unable to start PayChangu checkout: $e');
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<bool> _verifyTransaction(String txRef) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.paychangu.com/verify-payment/$txRef'),
        headers: {
          'Authorization': 'Bearer $payChanguSecretKey',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        return false;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        return false;
      }

      final status = (data['status'] ?? '').toString().toLowerCase();
      final currency = (data['currency'] ?? '').toString().toUpperCase();
      final amount =
          (data['amount'] as num?)?.toDouble() ??
          double.tryParse('${data['amount'] ?? ''}') ??
          0;

      return status == 'success' &&
          currency == 'MWK' &&
          amount >= widget.totalAmount;
    } catch (_) {
      return false;
    }
  }

  Future<void> _markOrderPaid(String txRef) async {
    await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .update({
          'status': 'Processing',
          'paymentStatus': 'completed',
          'paymentTxRef': txRef,
          'paidAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> _markOrderVerificationPending(String txRef) async {
    await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .update({
          'paymentStatus': 'verification_pending',
          'paymentTxRef': txRef,
          'paymentUpdatedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> _markOrderFailed(String txRef, String status) async {
    await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .update({
          'paymentStatus': status.isEmpty ? 'failed' : status,
          'paymentTxRef': txRef,
          'paymentUpdatedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> _recheckPayment() async {
    if (_txRef == null) {
      return;
    }

    setState(() {
      _isHandlingCallback = true;
      _statusMessage = null;
    });

    try {
      final verified = await _verifyTransaction(_txRef!);
      if (verified) {
        await _markOrderPaid(_txRef!);
        setState(() {
          _isPaymentSuccessful = true;
          _statusMessage = 'Payment verified successfully.';
        });
      } else {
        await _markOrderVerificationPending(_txRef!);
        setState(() {
          _statusMessage =
              'Payment is still pending verification. Please try again in a moment.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isHandlingCallback = false;
        });
      }
    }
  }

  Uri _buildReturnUri() {
    return Uri.base.replace(
      queryParameters: {
        'paychangu_callback': '1',
        'orderId': widget.orderId,
        'amount': widget.totalAmount.toStringAsFixed(2),
      },
      fragment: '',
    );
  }

  bool get _isPayChanguCallback =>
      Uri.base.queryParameters['paychangu_callback'] == '1' &&
      Uri.base.queryParameters['orderId'] == widget.orderId;

  (String, String) _splitName(String fullName) {
    final parts = fullName.split(' ').where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) {
      return ('Customer', '');
    }

    final firstName = parts.first;
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    return (firstName, lastName);
  }

  void _clearCallbackFromUrl() {
    final cleanUri = Uri.base.replace(queryParameters: {}, fragment: '');
    html.window.history.replaceState(
      null,
      html.document.title,
      cleanUri.toString(),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final webCheckoutConfigured = payChanguPublicKey.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
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
                  Text(
                    'Total: MK ${widget.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (!webCheckoutConfigured)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Text(
                  'Web checkout needs your PayChangu public key. Start Chrome with --dart-define=PAYCHANGU_PUBLIC_KEY=pub-...',
                ),
              ),
            if (_statusMessage != null) ...[
              if (!webCheckoutConfigured) const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isPaymentSuccessful
                      ? Colors.green.shade50
                      : Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isPaymentSuccessful
                          ? 'Payment complete'
                          : 'Payment status',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(_statusMessage!),
                    if (_txRef != null) ...[
                      const SizedBox(height: 8),
                      Text('Transaction Ref: $_txRef'),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              'Web checkout uses PayChangu hosted checkout and returns you to this app after payment.',
            ),
            const Spacer(),
            if (_isPaymentSuccessful)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/orders',
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('View My Orders'),
                ),
              )
            else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isProcessing || _isHandlingCallback)
                      ? null
                      : _startHostedCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: (_isProcessing || _isHandlingCallback)
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Pay with PayChangu'),
                ),
              ),
              const SizedBox(height: 12),
              if (_txRef != null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isHandlingCallback ? null : _recheckPayment,
                    child: const Text('Check Payment Again'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
