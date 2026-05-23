import 'package:flutter/material.dart';
import 'home_page.dart';

class HomeWrapper extends StatefulWidget {
  final String userType;
  
  const HomeWrapper({
    super.key,
    required this.userType,
  });

  @override
  State<HomeWrapper> createState() => _HomeWrapperState();
}

class _HomeWrapperState extends State<HomeWrapper> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPaymentStatus();
    });
  }

  void _checkPaymentStatus() {
    final uri = Uri.base;
    
    // Check if payment callback exists
    if (uri.queryParameters['paychangu_callback'] == '1') {
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment Successful! Your order has been placed.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }

      // For mobile: do nothing (URL parameters don't matter)
      // For web: the URL will stay as is, but that's fine
      // The app still works perfectly
    }
  }

  @override
  Widget build(BuildContext context) {
    return const HomePage();
  }
}