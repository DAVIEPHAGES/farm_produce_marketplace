import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/add_produce_page.dart';
import 'screens/admin_dashboard_page.dart';
import 'screens/cart_page.dart';
import 'screens/farmers_dashboard_page.dart';
import 'screens/home_wrapper.dart';
import 'screens/orders_page.dart';
import 'screens/payment_page.dart';
import 'screens/profile_page.dart';
import 'screens/produce_details_page.dart';
import 'screens/signin_page.dart';
import 'screens/signup_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Farm Produce Marketplace',
      debugShowCheckedModeBanner: false,
      // ✅ FIXED: Removed primarySwatch to fix the assertion error
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
      ),
      // ✅ CHANGED: Always start at Home page
      initialRoute: '/home',
      routes: {
        '/home': (context) => const HomeWrapper(userType: 'customer'),
        '/signin': (context) => const SignInPage(),
        '/signup': (context) => const SignUpPage(),
        '/cart': (context) => const CartPage(),
        '/orders': (context) => const OrdersPage(),
        '/profile': (context) => const ProfilePage(),
        '/farmers-dashboard': (context) => const FarmersDashboardPage(),
        '/admin-dashboard': (context) => const AdminDashboard(),
        '/add-produce': (context) => const AddProducePage(),
      },
      onGenerateRoute: (settings) {
        // Handle dynamic routing (Payment and Produce Details)
        switch (settings.name) {
          case '/payment':
            final args = settings.arguments;
            if (args is Map<String, dynamic>) {
              return MaterialPageRoute<void>(
                builder: (context) => PaymentPage(
                  totalAmount: (args['totalAmount'] as num).toDouble(),
                  orderId: args['orderId'] as String,
                  cartItems: (args['cartItems'] as List)
                      .map((item) => Map<String, dynamic>.from(item))
                      .toList(),
                ),
                settings: settings,
              );
            }
            break;
          case '/produce':
            final args = settings.arguments;
            if (args is QueryDocumentSnapshot) {
              return MaterialPageRoute<void>(
                builder: (context) => ProduceDetailsPage(data: args),
                settings: settings,
              );
            }
            break;
        }
        return null;
      },
      onUnknownRoute: (settings) =>
          MaterialPageRoute<void>(builder: (context) => const SignInPage()),
    );
  }
}