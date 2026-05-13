import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // Initialize the notification service
  static Future<void> initialize() async {
    // Android settings - USING APP ICON (guaranteed to exist)
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings);
    print('✅ Local Notification Service Initialized');
  }

  // Show a simple notification
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'farm_app_channel',
      'Farm App Notifications',
      channelDescription: 'Notifications for orders and payments',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',  // FIXED: Using app icon instead
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // Show payment success notification
  static Future<void> showPaymentSuccessNotification(
    String orderId,
    double amount,
  ) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: '✅ Payment Successful!',
      body: 'Your payment of MWK ${amount.toStringAsFixed(2)} has been confirmed.',
      payload: 'order_$orderId',
    );
  }

  // Show new order notification for farmer
  static Future<void> showNewOrderNotification(
    String customerName,
    String orderId,
  ) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: '🛒 New Order Received!',
      body: '$customerName has placed a new order.',
      payload: 'order_$orderId',
    );
  }

  // Show order status update notification
  static Future<void> showOrderStatusNotification(
    String orderId,
    String status,
  ) async {
    String title = '';
    String body = '';

    switch (status.toLowerCase()) {
      case 'confirmed':
        title = '✅ Order Confirmed!';
        body = 'Your order #${orderId.substring(0, 8)} has been confirmed.';
        break;
      case 'processing':
        title = '🔄 Order Processing';
        body = 'Your order #${orderId.substring(0, 8)} is being prepared.';
        break;
      case 'shipped':
        title = '🚚 Order Shipped!';
        body = 'Your order #${orderId.substring(0, 8)} is on the way!';
        break;
      case 'delivered':
        title = '🎉 Order Delivered!';
        body = 'Your order #${orderId.substring(0, 8)} has been delivered.';
        break;
      default:
        return;
    }

    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
      payload: 'order_$orderId',
    );
  }

  // Show cart reminder notification
  static Future<void> showCartReminderNotification(int itemCount) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: '🛒 Items in Your Cart',
      body: 'You have $itemCount item(s) in your cart. Complete your purchase!',
    );
  }
}