import 'package:flutter/material.dart';
import 'screens/home_page.dart';
import 'screens/signin_page.dart';
import 'screens/signup_page.dart';
import 'screens/produce_details_page.dart';
import 'screens/payment_page.dart';
import 'screens/cart_page.dart';
import 'screens/farmers_dashboard-page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Farm Produce Marketplace',
      initialRoute: '/home', // Start with home page
      routes: {
        '/home': (context) => const HomePage(),
        '/signin': (context) => const SignInPage(),
        '/signup': (context) => const SignUpPage(),
        '/payment': (context) => const PaymentPage(),
        '/produce': (context) => const ProduceDetailsPage(),
        '/cart': (context) => const CartPage(),
        '/farmers-dashboard': (context) => const FarmersDashboard(),
      },
    );
  }
}
