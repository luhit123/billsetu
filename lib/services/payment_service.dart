import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../modals/payment.dart';

/// Razorpay key — use test key for debug, live key for release.
/// Override at build time: --dart-define=RAZORPAY_KEY=rzp_live_XXXXXXX
const _razorpayKey = String.fromEnvironment(
  'RAZORPAY_KEY',
  defaultValue: 'rzp_test_STaoGCEVgretD0',
);

class PaymentService {
  PaymentService._() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }
  static final PaymentService instance = PaymentService._();

  late final Razorpay _razorpay;
  final _functions = FirebaseFunctions.instance;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  // Completer to bridge Razorpay callbacks → purchasePlan future
  Completer<PaymentResult>? _purchaseCompleter;
  String? _pendingSubscriptionId;

  /// Purchase a plan via Razorpay Checkout.
  ///
  /// 1. Calls Cloud Function to create a Razorpay subscription
  /// 2. Opens Razorpay Checkout with the subscription_id
  /// 3. Waits for payment callback (success/error)
  /// 4. On success, verifies payment server-side
  Future<PaymentResult> purchasePlan({
    required String planId,
    required String billingCycle,
  }) async {
    if (_isProcessing) {
      return const PaymentResult(
        success: false,
        message: 'Payment already in progress',
      );
    }

    _isProcessing = true;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return const PaymentResult(success: false, message: 'Not signed in');
      }

      // Step 1: Create Razorpay subscription via Cloud Function
      final result = await _functions
          .httpsCallable('createSubscription')
          .call({'planId': planId, 'billingCycle': billingCycle});

      final data = result.data as Map<String, dynamic>;
      if (data['success'] != true) {
        return PaymentResult(
          success: false,
          message: data['message'] as String? ?? 'Failed to create subscription',
        );
      }

      final subscriptionId = data['subscriptionId'] as String;
      _pendingSubscriptionId = subscriptionId;

      // Step 2: Open Razorpay Checkout
      _purchaseCompleter = Completer<PaymentResult>();

      final options = <String, dynamic>{
        'key': _razorpayKey,
        'subscription_id': subscriptionId,
        'name': 'BillEasy',
        'description': '${_planDisplayName(planId)} Plan — ${billingCycle == 'annual' ? 'Annual' : 'Monthly'}',
        'prefill': <String, String>{
          if (user.email != null) 'email': user.email!,
          if (user.phoneNumber != null) 'contact': user.phoneNumber!,
        },
        'theme': <String, String>{'color': '#0057FF'},
        'notes': <String, String>{
          'userId': user.uid,
          'planId': planId,
          'billingCycle': billingCycle,
        },
      };

      _razorpay.open(options);

      // Wait for Razorpay callback
      return await _purchaseCompleter!.future;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Cloud Function error: ${e.code} — ${e.message}');
      return PaymentResult(
        success: false,
        message: e.message ?? 'Failed to initiate payment',
      );
    } catch (e) {
      debugPrint('PaymentService error: $e');
      return PaymentResult(success: false, message: 'Payment failed: $e');
    } finally {
      _isProcessing = false;
      _purchaseCompleter = null;
      _pendingSubscriptionId = null;
    }
  }

  // ── Razorpay callbacks ──────────────────────────────────────────────

  void _onPaymentSuccess(PaymentSuccessResponse response) async {
    debugPrint('Razorpay success: paymentId=${response.paymentId}');

    try {
      // Verify payment server-side
      final verifyResult = await _functions
          .httpsCallable('verifyPayment')
          .call({
        'razorpayPaymentId': response.paymentId,
        'razorpaySubscriptionId': _pendingSubscriptionId,
        'razorpaySignature': response.signature,
      });

      final data = verifyResult.data as Map<String, dynamic>;
      if (data['verified'] == true) {
        _purchaseCompleter?.complete(PaymentResult(
          success: true,
          message: 'Plan activated successfully!',
          paymentId: response.paymentId,
        ));
      } else {
        _purchaseCompleter?.complete(PaymentResult(
          success: false,
          message: data['message'] as String? ?? 'Payment verification failed',
        ));
      }
    } catch (e) {
      // Even if verification call fails, the webhook will still activate
      // the plan. Show success optimistically since Razorpay confirmed it.
      debugPrint('Verify call failed (webhook will handle): $e');
      _purchaseCompleter?.complete(PaymentResult(
        success: true,
        message: 'Plan activated successfully!',
        paymentId: response.paymentId,
      ));
    }
  }

  void _onPaymentError(PaymentFailureResponse response) {
    debugPrint('Razorpay error: code=${response.code} message=${response.message}');

    String message;
    switch (response.code) {
      case Razorpay.NETWORK_ERROR:
        message = 'Network error. Please check your connection and try again.';
        break;
      case Razorpay.INVALID_OPTIONS:
        message = 'Payment configuration error. Please contact support.';
        break;
      case Razorpay.PAYMENT_CANCELLED:
        message = 'Payment cancelled.';
        break;
      default:
        message = response.message ?? 'Payment failed. Please try again.';
    }

    _purchaseCompleter?.complete(PaymentResult(success: false, message: message));
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    debugPrint('External wallet: ${response.walletName}');
    // External wallet selected — payment flow continues in the wallet app.
    // The webhook will handle plan activation. Show a waiting message.
    _purchaseCompleter?.complete(PaymentResult(
      success: true,
      message: 'Redirecting to ${response.walletName}. Your plan will activate once payment completes.',
      paymentId: null,
    ));
  }

  // ── Cancel / Reactivate ─────────────────────────────────────────────

  /// Cancel subscription at period end (or immediately).
  Future<bool> cancelSubscription({bool immediate = false}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    try {
      final result = await _functions
          .httpsCallable('cancelSubscription')
          .call({'immediate': immediate});
      final data = result.data as Map<String, dynamic>;
      return data['success'] == true;
    } catch (e) {
      debugPrint('Cancel error: $e');
      return false;
    }
  }

  /// Reactivate a subscription that was set to cancel at period end.
  Future<bool> reactivateSubscription() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    try {
      await FirebaseFirestore.instance
          .collection('subscriptions')
          .doc(uid)
          .update({
        'cancelAtPeriodEnd': false,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Stream of payment history
  Stream<List<Payment>> watchPayments() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value([]);
    return FirebaseFirestore.instance
        .collection('subscriptions')
        .doc(uid)
        .collection('payments')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Payment.fromMap(d.data(), docId: d.id))
            .toList());
  }

  /// Clean up Razorpay listeners (call from app dispose if needed)
  void dispose() {
    _razorpay.clear();
  }

  static String _planDisplayName(String planId) {
    switch (planId) {
      case 'raja':
        return 'Raja';
      case 'maharaja':
        return 'Maharaja';
      case 'king':
        return 'King';
      default:
        return planId;
    }
  }
}

class PaymentResult {
  final bool success;
  final String message;
  final String? paymentId;

  const PaymentResult({
    required this.success,
    required this.message,
    this.paymentId,
  });
}
