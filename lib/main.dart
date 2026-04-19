import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/home_page.dart';
import 'screens/signin_page.dart';
import 'screens/signup_page.dart';
import 'screens/produce_details_page.dart';
import 'screens/payment_page.dart';


import 'screens/farmers_dashboard_page.dart';
import 'screens/myproduce_page.dart';
import 'screens/orders_page.dart';
import 'screens/admin_dashboard_page.dart';
import 'screens/home_wrapper.dart';

Future<FirebaseApp> _initializeFirebase() {
  if (kIsWeb) {
    return Firebase.initializeApp(
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
  }

  return Firebase.initializeApp();
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: const AppBootstrap(),
      routes: {
        '/home': (context) => const HomeWrapper(userType: 'customer'),
        '/signin': (context) => const SignInPage(),
        '/signup': (context) => const SignUpPage(),
        '/payment': (context) => const PaymentPage(),
        
        
        '/orders': (context) => const OrdersPage(),
        '/farmers-dashboard': (context) => const FarmersDashboardPage(),
        '/admin-dashboard': (context) => const AdminDashboard(),
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const SignInPage(),
        );
      },
    );
  }
}

class AppBootstrap extends StatelessWidget {
  const AppBootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FirebaseApp>(
      future: _initializeFirebase().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception(
          'Firebase initialization timed out. Check your emulator network and Firebase configuration.',
        ),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'App startup failed:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return const HomeWrapper(userType: 'customer');
      },
    );
  }
}
