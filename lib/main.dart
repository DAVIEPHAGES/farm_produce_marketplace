import 'package:flutter/material.dart';
import 'screens/home_page.dart';
import 'screens/signin_page.dart';
import 'screens/signup_page.dart';
import 'screens/produce_details_page.dart';
import 'screens/payment_page.dart';
import 'screens/cart_page.dart';
import 'screens/farmers_dashboard.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Farm Produce Marketplace',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      initialRoute: '/home', // Start with sign in page
      routes: {
        '/home': (context) => const HomePage(),
        '/signin': (context) => const SignInPage(),
        '/signup': (context) => const SignUpPage(),
        '/payment': (context) => const PaymentPage(),
        '/produce': (context) => const ProduceDetailsPage(),
        '/cart': (context) => const CartPage(),
        '/myproduce': (context) => const MyProducePage(),
        '/orders': (context) => const OrdersPage(),
        '/farmers-dashboard': (context) => const FarmersDashboard(),
        '/admin-dashboard': (context) => const AdminDashboard(),
      },
      onGenerateRoute: (settings) {
        // Handle dynamic routes with arguments
        if (settings.name == '/home') {
          final args = settings.arguments as Map<String, dynamic>?;
          final userType = args?['userType'] ?? 'customer';
          return MaterialPageRoute(
            builder: (context) => HomeWrapper(userType: userType),
          );
        }
        return null;
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(builder: (context) => const SignInPage());
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'screens/home_page.dart';
import 'screens/signin_page.dart';
import 'screens/signup_page.dart';
import 'screens/produce_details_page.dart';
import 'screens/payment_page.dart';
import 'screens/cart_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Routing Example',
      initialRoute: '/home',  // This is the first page when app launches
      routes: {
        '/home': (context) => const HomePage(),
        '/signin': (context) => const SignInPage(),
        '/signup': (context) => const SignUpPage(),
        '/payment': (context) => const PaymentPage(),
        'produce': (context) => const ProduceDetailsPage(),
        'cart': (context) => const CartPage(),
      },
    );
  }
}