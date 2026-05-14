import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/add_produce_page.dart';
import 'screens/admin_dashboard_page.dart';
import 'screens/cart_page.dart';
import 'screens/farmers_dashboard_page.dart';
import 'screens/home_wrapper.dart';
import 'screens/my_orders_page.dart'; // ADD THIS IMPORT
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
    final payChanguCallback =
        Uri.base.queryParameters['paychangu_callback'] == '1';

    return MaterialApp(
      title: 'Farm Produce Marketplace',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      initialRoute: payChanguCallback ? '/payment' : '/home',
      routes: {
        '/home': (context) => const HomeWrapper(userType: 'customer'),
        '/signin': (context) => const SignInPage(),
        '/signup': (context) => const SignUpPage(),
        '/cart': (context) => const CartPage(),
        '/orders': (context) => const OrdersPage(),
        '/my-orders': (context) => const MyOrdersPage(), // ADD THIS ROUTE
        '/profile': (context) => const ProfilePage(),
        '/farmers-dashboard': (context) => const FarmersDashboardPage(),
        '/admin-dashboard': (context) => const AdminDashboard(),
        '/add-produce': (context) => const AddProducePage(),
        '/notifications': (context) => const _PlaceholderPage(
          title: 'Notifications',
          message: 'Notifications will appear here soon.',
        ),
      },
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/payment':
            final args = settings.arguments;
            if (args is Map<String, dynamic>) {
              final totalAmount = args['totalAmount'];
              final orderId = args['orderId'];
              final cartItems = args['cartItems'];

              if (totalAmount is num &&
                  orderId is String &&
                  cartItems is List) {
                return MaterialPageRoute<void>(
                  builder: (context) => PaymentPage(
                    totalAmount: totalAmount.toDouble(),
                    orderId: orderId,
                    cartItems: cartItems
                        .whereType<Map>()
                        .map(
                          (item) => item.map(
                            (key, value) => MapEntry(key.toString(), value),
                          ),
                        )
                        .toList(),
                  ),
                  settings: settings,
                );
              }
            }

            final queryParams = Uri.base.queryParameters;
            final orderId = queryParams['orderId'];
            final totalAmount = double.tryParse(queryParams['amount'] ?? '');

            if (queryParams['paychangu_callback'] == '1' &&
                orderId != null &&
                totalAmount != null) {
              return MaterialPageRoute<void>(
                builder: (context) => PaymentPage(
                  totalAmount: totalAmount,
                  orderId: orderId,
                  cartItems: const [],
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