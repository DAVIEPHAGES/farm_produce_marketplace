import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';

class FirebaseConfig {
  // Your actual Firebase web configuration
  static const FirebaseOptions webOptions = FirebaseOptions(
    apiKey: "AIzaSyB7qNtGJ2o_0WM4yw1AxLITu2efhZCdmtY",
    authDomain: "farm-36c66.firebaseapp.com",
    projectId: "farm-36c66",
    storageBucket: "farm-36c66.firebasestorage.app",
    messagingSenderId: "488620623240",
    appId: "1:488620623240:web:693c1f944e3cb377b4a63d",
    measurementId: "G-3BFF52S82G",
  );

  static Future<void> initialize() async {
    if (kIsWeb) {
      // For web browser
      await Firebase.initializeApp(options: webOptions);
    } else {
      // For Windows desktop - use the same web configuration
      await Firebase.initializeApp(options: webOptions);
    }
  }
}