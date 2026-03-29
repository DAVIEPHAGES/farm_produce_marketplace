import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'js_stub.dart' as js;
 // ignore: deprecated_member_use
 import 'dart:js' as js;
import 'screens/home_page.dart';
import 'screens/signin_page.dart';
import 'screens/signup_page.dart';
import 'screens/produce_details_page.dart';
import 'screens/payment_page.dart';
import 'screens/cart_page.dart';
import 'screens/myproduce_page.dart';
import 'screens/orders_page.dart';
import 'screens/farmers_dashboard-page.dart';
import 'screens/admin_dashboard_page.dart';
import 'screens/home_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase differently for web vs mobile
  if (kIsWeb) {
    // For web: Get config from index.html
    final config = js.context['firebaseConfig'];
    
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: config['apiKey'],
        authDomain: config['authDomain'],
        projectId: config['projectId'],
        storageBucket: config['storageBucket'],
        messagingSenderId: config['messagingSenderId'],
        appId: config['appId'],
      ),
    );
  } else {
    // For Android/iOS: Auto-detects from google-services.json / GoogleService-Info.plist
    await Firebase.initializeApp();
  }
  
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