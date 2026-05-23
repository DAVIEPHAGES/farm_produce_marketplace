import 'package:flutter/material.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html; // This allows us to clean the URL
import '../services/remember_me_service.dart';
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

    // After the screen loads, check if we need to show a success message and clean the URL
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyRememberMeChoice();
      _checkPaymentStatus();
    });
  }

  Future<void> _applyRememberMeChoice() async {
    await RememberMeService.signOutIfCurrentUserWasNotRemembered();
    if (mounted) {
      setState(() {});
    }
  }

  void _checkPaymentStatus() {
    final uri = Uri.base;
    
    // If the URL contains the PayChangu success flag
    if (uri.queryParameters['paychangu_callback'] == '1') {
      
      // 1. Show the Success Notification
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment Successful! Your order has been placed.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // 2. CLEAN THE URL (Scrubbing)
      // This changes http://localhost/?paychangu_callback=1... 
      // back to http://localhost/#/home
      try {
        html.window.history.replaceState(null, 'Home', '#/home');
      } catch (e) {
        debugPrint('URL scrubbing failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // This returns the actual Home Page UI
    return const HomePage();
  }
}
