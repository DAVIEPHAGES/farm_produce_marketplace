import 'package:paychangu_flutter/paychangu_flutter.dart';

import 'paychangu_keys.dart';

class PayChanguService {
  static final PayChangu _paychangu = PayChangu(
    PayChanguConfig(secretKey: payChanguSecretKey, isTestMode: false),
  );

  static PayChangu get instance => _paychangu;

  static PaymentRequest createPaymentRequest({
    required String orderId,
    required String customerName,
    required String customerEmail,
    required double amount,
  }) {
    final nameParts = customerName.split(' ');
    final firstName = nameParts.isNotEmpty ? nameParts[0] : 'Customer';
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    // Convert double to int (PayChangu expects integer amount)
    final intAmount = amount.toInt();

    return PaymentRequest(
      txRef: 'ORDER_${orderId}_${DateTime.now().millisecondsSinceEpoch}',
      firstName: firstName,
      lastName: lastName,
      email: customerEmail,
      currency: Currency.MWK,
      amount: intAmount, // int type
      callbackUrl: 'https://your-domain.com/api/payment/callback',
      returnUrl: 'farmapp://payment/return',
    );
  }

  static Future<bool> verifyTransaction(
    String txRef,
    double expectedAmount,
  ) async {
    try {
      final verification = await _paychangu.verifyTransaction(txRef);

      final expectedIntAmount = expectedAmount.toInt();

      final isValid = _paychangu.validatePayment(
        verification,
        expectedTxRef: txRef,
        expectedCurrency: 'MWK',
        expectedAmount: expectedIntAmount, // int type
      );

      if (isValid) {
        print('✅ Payment verified! Amount: ${verification.data.amount} MWK');
        return true;
      }
      return false;
    } on PayChanguException catch (e) {
      print('❌ Verification failed: ${e.message}');
      return false;
    }
  }
}
