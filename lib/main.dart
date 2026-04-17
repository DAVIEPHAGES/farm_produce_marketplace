import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/home_page.dart';
import 'screens/signin_page.dart';
import 'screens/signup_page.dart';
import 'screens/produce_details_page.dart';
import 'screens/payment_page.dart';
import 'screens/cart_page.dart';
import 'screens/farmers_dashboard_page.dart';
import 'screens/myproduce_page.dart';
import 'screens/orders_page.dart';
import 'screens/admin_dashboard_page.dart';
import 'screens/home_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pass Firebase options directly
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyB7qNtGJ2o_0WM4yw1AxLITu2efhZCdmtY",
      authDomain: "farm-36c66.firebaseapp.com",
      projectId: "farm-36c66",
      storageBucket: "farm-36c66.firebasestorage.app",
      messagingSenderId: "488620623240",
      appId: "1:488620623240:web:693c1f944e3cb377b4a63d",
      measurementId: "G-3BFF52S82G",
    ),
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
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),        
      initialRoute: '/signin',
      routes: {
        '/home': (context) => const HomePage(),
        '/signin': (context) => const SignInPage(),
        '/signup': (context) => const SignUpPage(),
        '/payment': (context) => const PaymentPage(),
        '/produce': (context) => const ProduceDetailsPage(),
        '/cart': (context) => const CartPage(),
        '/farmers-dashboard': (context) => const FarmersDashboardPage(),
      },
    );
  }
}
