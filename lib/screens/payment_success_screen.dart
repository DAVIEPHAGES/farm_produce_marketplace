import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PaymentSuccessScreen extends StatelessWidget {
  final String customerName;
  final double amount;
  final String orderId;

  const PaymentSuccessScreen({
    Key? key,
    required this.customerName,
    required this.amount,
    required this.orderId,
  }) : super(key: key);

  Future<void> _logout(BuildContext context) async {
    // Clear user session data
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // This clears all saved session data

    // Optional: Clear specific items instead of everything
    // await prefs.remove('user_token');
    // await prefs.remove('user_id');

    if (context.mounted) {
      // Navigate to home page and remove all previous routes so user can't go back
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/', // Home page route
        (Route<dynamic> route) => false, // Remove all previous routes
      );
    }
  }

  void _makeAnotherOrder(BuildContext context) {
    // Navigate back to the order creation screen or home
    // Remove all previous routes and go to order creation
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/home', // Or '/farmers-market' or wherever user can create new order
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Successful'),
        automaticallyImplyLeading: false, // Remove back button
        backgroundColor: Colors.green,
      ),
      body: WillPopScope(
        onWillPop: () async {
          // Prevent going back to payment screen
          return false;
        },
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success Icon
              const Icon(Icons.check_circle, color: Colors.green, size: 100),
              const SizedBox(height: 24),

              // Success Message
              Text(
                'Thank you, $customerName!',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              Text(
                'Your payment of MWK ${amount.toStringAsFixed(2)} has been processed successfully.',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Order ID: $orderId',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),

              const SizedBox(height: 48),

              // Make Another Order Button
              Center(
                child: SizedBox(
                  width: 220,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _makeAnotherOrder(context),
                    icon: const Icon(Icons.shopping_cart),
                    label: const Text(
                      'MAKE ANOTHER ORDER',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Logout Button
              Center(
                child: SizedBox(
                  width: 220,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => _logout(context),
                    icon: const Icon(Icons.logout),
                    label: const Text(
                      'LOG OUT',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.red.shade700, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
