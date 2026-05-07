const functions = require('firebase-functions');
const admin = require('firebase-admin');
const fetch = require('node-fetch');

admin.initializeApp();

// ==================== HELPER: SEND NOTIFICATION ====================
async function sendNotification(deviceToken, title, body, data = {}) {
  if (!deviceToken) {
    console.log('No device token provided');
    return false;
  }

  try {
    const message = {
      token: deviceToken,
      notification: {
        title: title,
        body: body,
      },
      data: {
        ...data,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: { priority: 'high' },
      apns: { payload: { aps: { sound: 'default' } } },
    };
    
    await admin.messaging().send(message);
    console.log('✅ Notification sent successfully');
    return true;
  } catch (error) {
    console.error('❌ Error sending notification:', error);
    return false;
  }
}

// ==================== CREATE PAYMENT ====================
exports.createPayChanguPayment = functions.https.onCall(async (data, context) => {
  console.log('📦 Creating payment for order:', data.orderId);
  
  const { name, email, amount, orderId } = data;
  
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be logged in');
  }
  
  const PAYCHANGU_SECRET_KEY = "sec-live-Vwx9oEpCf5LRMWetNs2wnELnSskOXeMx";
  const txRef = `ORDER_${orderId}_${Date.now()}`;
  
  try {
    const response = await fetch("https://api.paychangu.com/payment", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${PAYCHANGU_SECRET_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        amount: amount,
        currency: "MWK",
        email: email,
        first_name: name,
        tx_ref: txRef,
        description: "Farm App Payment",
        redirect_url: "farmapp://payment/success",
      }),
    });
    
    const result = await response.json();
    console.log('PayChangu Response:', result);
    
    if (result.status === "success") {
      await admin.firestore().collection('orders').doc(orderId).update({
        transactionRef: txRef,
        paymentUrl: result.data.checkout_url,
        paymentCreatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      return { 
        success: true, 
        paymentUrl: result.data.checkout_url, 
        txRef: txRef 
      };
    } else {
      throw new Error(result.message || 'Payment creation failed');
    }
  } catch (error) {
    console.error('Error creating payment:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ==================== 1. NOTIFY WHEN PAYMENT IS COMPLETED ====================
exports.onPaymentCompleted = functions.firestore
    .document('orders/{orderId}')
    .onUpdate(async (change, context) => {
      const beforeData = change.before.data();
      const afterData = change.after.data();
      const orderId = context.params.orderId;
      
      if (beforeData.paymentStatus === 'pending' && afterData.paymentStatus === 'completed') {
        console.log(`🎉 Payment completed for order: ${orderId}`);
        
        // Notify customer
        const customerDoc = await admin.firestore().collection('users').doc(afterData.customerId).get();
        const customerToken = customerDoc.data()?.fcmToken;
        await sendNotification(
          customerToken,
          '✅ Payment Successful!',
          `Your payment of MWK ${afterData.totalAmount} for order #${orderId.substring(0, 8)} has been confirmed.`,
          { orderId: orderId, type: 'payment_success' }
        );
        
        // Notify farmers
        const items = afterData.items || [];
        const farmerIds = [...new Set(items.map(item => item.farmerId).filter(id => id))];
        
        for (const farmerId of farmerIds) {
          const farmerProducts = items.filter(item => item.farmerId === farmerId);
          const farmerTotal = farmerProducts.reduce((sum, item) => sum + (item.price * item.quantity), 0);
          const productNames = farmerProducts.map(item => item.name).join(', ');
          
          const farmerDoc = await admin.firestore().collection('users').doc(farmerId).get();
          const farmerToken = farmerDoc.data()?.fcmToken;
          
          await sendNotification(
            farmerToken,
            '💰 Payment Received!',
            `${afterData.customerName} paid MWK ${farmerTotal} for: ${productNames}`,
            { orderId: orderId, type: 'farmer_payment' }
          );
        }
        
        // Notify admins
        const adminsSnapshot = await admin.firestore().collection('Admins').get();
        for (const adminDoc of adminsSnapshot.docs) {
          const adminToken = adminDoc.data()?.fcmToken;
          await sendNotification(
            adminToken,
            '📊 Payment Alert - Admin',
            `Order #${orderId.substring(0, 8)}: ${afterData.customerName} paid MWK ${afterData.totalAmount}`,
            { orderId: orderId, type: 'admin_payment' }
          );
        }
      }
      
      return null;
    });

// ==================== 2. NOTIFY FARMERS WHEN NEW ORDER IS CREATED ====================
exports.onNewOrderCreated = functions.firestore
    .document('orders/{orderId}')
    .onCreate(async (snap, context) => {
      const orderData = snap.data();
      const orderId = context.params.orderId;
      
      const items = orderData.items || [];
      const farmerIds = [...new Set(items.map(item => item.farmerId).filter(id => id))];
      
      for (const farmerId of farmerIds) {
        const farmerProducts = items.filter(item => item.farmerId === farmerId);
        const productNames = farmerProducts.map(item => item.name).join(', ');
        
        const farmerDoc = await admin.firestore().collection('users').doc(farmerId).get();
        const farmerToken = farmerDoc.data()?.fcmToken;
        
        await sendNotification(
          farmerToken,
          '🛒 New Order Received!',
          `${orderData.customerName} ordered from you: ${productNames}`,
          { orderId: orderId, type: 'new_order' }
        );
      }
      
      return null;
    });