import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';

import 'screens/home_page.dart';
import 'screens/signin_page.dart';
import 'screens/signup_page.dart';
import 'screens/produce_details_page.dart';
import 'screens/payment_page.dart';
import 'screens/orders_page.dart';

import 'screens/farmers_dashboard_page.dart';



import 'screens/home_wrapper.dart';
import 'screens/add_produce_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Farm Produce Marketplace',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      initialRoute: '/signin',
      routes: {
        '/home': (context) => const HomeWrapper(userType: 'customer'),
        '/signin': (context) => const SignInPage(),
        '/signup': (context) => const SignUpPage(),
        '/payment': (context) => const PaymentPage(),
        '/produce': (context) => const ProduceDetailsPage(),
        '/cart': (context) => const CartPage(),
       
      '/farmers-dashboard': (context) => const FarmersDashboardPage(),
       
        '/add-produce': (context) => AddProducePage(), // ← no const
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/home') {
          final args = settings.arguments as Map<String, dynamic>?;
          final userType = args?['userType'] ?? 'customer';
          return MaterialPageRoute(
            builder: (context) => HomeWrapper(userType: userType),
          );
        }
        return null;
      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (context) => const SignInPage(),
      ),
    );
  }
}
