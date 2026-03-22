import 'dart:async';

/// Result from the Razorpay checkout flow.
class RazorpayResult {
  final bool success;
  final String? paymentId;
  final String? signature;
  final String? errorMessage;
  final int? errorCode;
  final String? walletName;

  const RazorpayResult({
    required this.success,
    this.paymentId,
    this.signature,
    this.errorMessage,
    this.errorCode,
    this.walletName,
  });
}

/// Platform-agnostic Razorpay checkout.
/// Actual implementation is swapped via conditional imports.
class RazorpayCheckout {
  RazorpayCheckout();

  Future<RazorpayResult> open(Map<String, dynamic> options) {
    throw UnimplementedError('RazorpayCheckout not implemented for this platform');
  }

  void dispose() {}
}
