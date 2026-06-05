import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/add_produce_page.dart';
import 'screens/admin_dashboard_page.dart';
import 'screens/cart_page.dart';
import 'screens/farmers_dashboard_page.dart';
import 'screens/home_wrapper.dart';
import 'screens/logistics_dashboard_page.dart';
import 'screens/my_orders_page.dart';
import 'screens/orders_page.dart';
import 'screens/payment_processing_screan.dart';
import 'screens/profile_page.dart';
import 'screens/produce_details_page.dart';
import 'screens/signin_page.dart';
import 'screens/signup_page.dart';
import 'utils/fix_olders.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ NEW: Check if the browser URL contains the PayChangu success callback
    // This ensures that when the payment is done, the app stays on '/home'
    final bool isPaymentCallback =
        Uri.base.queryParameters['paychangu_callback'] == '1';

    return MaterialApp(
      title: 'Farm Produce Marketplace',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.green),
      // ✅ UPDATED: If we just finished a payment, force the app to stay on /home
      initialRoute: isPaymentCallback ? '/home' : '/home',
      routes: {
        '/home': (context) => const HomeWrapper(userType: 'customer'),
        '/signin': (context) => const SignInPage(),
        '/signup': (context) => const SignUpPage(),
        '/cart': (context) => const CartPage(),
        '/orders': (context) => const OrdersPage(),
        '/my-orders': (context) => const MyOrdersPage(),
        '/profile': (context) => const ProfilePage(),
        '/farmers-dashboard': (context) => const FarmersDashboardPage(),
        '/logistics-dashboard': (context) => const LogisticsDashboardPage(),
        '/admin-dashboard': (context) => const AdminDashboard(),
        '/add-produce': (context) => const AddProducePage(),
        '/fix-orders': (context) => const FixOrdersWithNames(),
      },
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/payment':
            final args = settings.arguments;
            if (args is Map<String, dynamic>) {
              return MaterialPageRoute<void>(
                // ✅ UPDATED: Now points to PaymentProcessingScreen to handle inventory reduction
                builder: (context) => PaymentProcessingScreen(
                  orderId: args['orderId'] as String,
                  customerName: args['customerName'] ?? 'Customer',
                  customerEmail: args['customerEmail'] ?? '',
                  amount: (args['totalAmount'] as num).toDouble(),
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

class _PlaceholderPage extends StatelessWidget {
  final String title;
  final String message;

  const _PlaceholderPage({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
