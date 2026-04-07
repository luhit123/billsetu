import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class PaymentLinkService {
  PaymentLinkService._();

  static final PaymentLinkService instance = PaymentLinkService._();
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<String?> createUpiWebPaymentLink({
    required String upiId,
    required String businessName,
    required double amount,
    required String invoiceNumber,
  }) async {
    final trimmedUpiId = upiId.trim();
    final trimmedBusinessName = businessName.trim();
    final trimmedInvoiceNumber = invoiceNumber.trim();

    if (trimmedUpiId.isEmpty ||
        trimmedBusinessName.isEmpty ||
        trimmedInvoiceNumber.isEmpty ||
        !amount.isFinite ||
        amount <= 0) {
      return null;
    }

    try {
      final result = await _functions
          .httpsCallable('createUpiPaymentLink')
          .call({
            'upiId': trimmedUpiId,
            'businessName': trimmedBusinessName,
            'amount': amount,
            'invoiceNumber': trimmedInvoiceNumber,
          });

      final data = result.data;
      if (data is Map && data['url'] is String) {
        final url = (data['url'] as String).trim();
        return url.isEmpty ? null : url;
      }
    } catch (error) {
      debugPrint('[PaymentLinkService] Signed payment link failed: $error');
    }

    return null;
  }
}
