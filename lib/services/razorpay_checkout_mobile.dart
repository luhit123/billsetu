import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'razorpay_checkout_stub.dart';

class RazorpayCheckout {
  RazorpayCheckout() {
    _razorpay = Razorpay();
  }

  late final Razorpay _razorpay;
  Completer<RazorpayResult>? _completer;

  Future<RazorpayResult> open(Map<String, dynamic> options) {
    _completer = Completer<RazorpayResult>();

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onWallet);

    _razorpay.open(options);
    return _completer!.future;
  }

  void _onSuccess(PaymentSuccessResponse response) {
    _completer?.complete(RazorpayResult(
      success: true,
      paymentId: response.paymentId,
      signature: response.signature,
    ));
  }

  void _onError(PaymentFailureResponse response) {
    _completer?.complete(RazorpayResult(
      success: false,
      errorCode: response.code,
      errorMessage: response.message ?? 'Payment failed',
    ));
  }

  void _onWallet(ExternalWalletResponse response) {
    _completer?.complete(RazorpayResult(
      success: true,
      walletName: response.walletName,
    ));
  }

  void dispose() {
    _razorpay.clear();
  }
}
