import 'dart:async';
import 'dart:js_interop';

import 'razorpay_checkout_stub.dart';

@JS('Object.assign')
external JSObject _objectAssign(JSObject target, JSObject source);

@JS('Razorpay')
@staticInterop
class _RazorpayJS {
  external factory _RazorpayJS(JSObject options);
}

extension _RazorpayJSExt on _RazorpayJS {
  external void open();
}

class RazorpayCheckout {
  RazorpayCheckout();

  Future<RazorpayResult> open(Map<String, dynamic> options) {
    final completer = Completer<RazorpayResult>();

    // Convert Dart map to JS object
    final jsOptions = options.jsify() as JSObject;

    // Create a new options object with our handler and modal callbacks
    final overrides = {
      'handler': ((JSAny response) {
        final map = (response as JSObject).dartify() as Map;
        final paymentId = map['razorpay_payment_id'] as String?;
        final signature = map['razorpay_signature'] as String?;
        if (!completer.isCompleted) {
          completer.complete(RazorpayResult(
            success: true,
            paymentId: paymentId,
            signature: signature,
          ));
        }
      }).toJS,
      'modal': {
        'ondismiss': (() {
          if (!completer.isCompleted) {
            completer.complete(const RazorpayResult(
              success: false,
              errorMessage: 'Payment cancelled.',
            ));
          }
        }).toJS,
      }.jsify(),
    }.jsify() as JSObject;

    final merged = _objectAssign(jsOptions, overrides);

    try {
      final rzp = _RazorpayJS(merged);
      rzp.open();
    } catch (e) {
      if (!completer.isCompleted) {
        completer.complete(RazorpayResult(
          success: false,
          errorMessage: 'Failed to open Razorpay checkout: $e',
        ));
      }
    }

    return completer.future;
  }

  void dispose() {}
}
