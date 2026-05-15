import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // Initialize local notifications
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('/ic_notification');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(settings);
    
    // Request permission
    await _requestPermission();
    
    // Get and save FCM token
    await _getAndSaveToken();
    
    // Setup message handlers
    _setupMessageHandlers();
  }

  static Future<void> _requestPermission() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('Notification permission: ${settings.authorizationStatus}');
  }

  static Future<void> _getAndSaveToken() async {
    String? token = await _firebaseMessaging.getToken();
    print('📱 FCM Token: $token');
    
    // Save token to Firestore based on user type
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && token != null) {
      // Get user data to know their type
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userType = userDoc.data()?['userType'];
      
      // Save token to users collection
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
      
      // If user is admin, also save to Admins collection
      if (userType == 'admin') {
        await FirebaseFirestore.instance.collection('Admins').doc(user.uid).set({
          'fcmToken': token,
          'email': user.email,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      
      print('✅ FCM Token saved for user: ${userType ?? 'customer'}');
    }
  }

  static void _setupMessageHandlers() {
    // When app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📨 Received message in foreground: ${message.notification?.title}');
      _showLocalNotification(message);
    });

    // When app is opened from background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📱 App opened from notification');
      _handleNotificationTap(message);
    });

    // When app is terminated but opened via notification
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        print('📱 App opened from terminated state');
        _handleNotificationTap(message);
      }
    });
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'farm_app_channel',
      'Farm App Notifications',
      channelDescription: 'Notifications for orders and payments',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
    );
    
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
    
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      message.notification?.title ?? 'Farm App',
      message.notification?.body ?? 'You have a new update',
      details,
    );
  }

  static void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final type = data['type'];
    final orderId = data['orderId'];
    
    print('🔔 Notification tapped: type=$type, orderId=$orderId');
    
    // Here you can navigate to specific screens based on notification type
    // For now, we'll just print
  }
}