import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../modals/payment.dart';
import 'razorpay_checkout.dart';

/// Razorpay key — use test key for debug, live key for release.
/// Override at build time: --dart-define=RAZORPAY_KEY=rzp_live_XXXXXXX
const _razorpayKey = String.fromEnvironment(
  'RAZORPAY_KEY',
  defaultValue: 'rzp_test_STaoGCEVgretD0',
);

class PaymentService {
  PaymentService._() {
    _checkout = RazorpayCheckout();
  }
  static final PaymentService instance = PaymentService._();

  late final RazorpayCheckout _checkout;
  final _functions = FirebaseFunctions.instance;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

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

      // Step 2: Open Razorpay Checkout
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

      final rzpResult = await _checkout.open(options);

      // Step 3: Handle result
      if (rzpResult.walletName != null) {
        return PaymentResult(
          success: true,
          message: 'Redirecting to ${rzpResult.walletName}. Your plan will activate once payment completes.',
          paymentId: null,
        );
      }

      if (!rzpResult.success) {
        return PaymentResult(
          success: false,
          message: rzpResult.errorMessage ?? 'Payment failed. Please try again.',
        );
      }

      // Step 4: Verify payment server-side
      try {
        final verifyResult = await _functions
            .httpsCallable('verifyPayment')
            .call({
          'razorpayPaymentId': rzpResult.paymentId,
          'razorpaySubscriptionId': subscriptionId,
          'razorpaySignature': rzpResult.signature,
        });

        final verifyData = verifyResult.data as Map<String, dynamic>;
        if (verifyData['verified'] == true) {
          return PaymentResult(
            success: true,
            message: 'Plan activated successfully!',
            paymentId: rzpResult.paymentId,
          );
        } else {
          return PaymentResult(
            success: false,
            message: verifyData['message'] as String? ?? 'Payment verification failed',
          );
        }
      } catch (e) {
        // Even if verification call fails, the webhook will still activate
        // the plan. Show success optimistically since Razorpay confirmed it.
        debugPrint('Verify call failed (webhook will handle): $e');
        return PaymentResult(
          success: true,
          message: 'Plan activated successfully!',
          paymentId: rzpResult.paymentId,
        );
      }
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
    }
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

  /// Clean up listeners (call from app dispose if needed)
  void dispose() {
    _checkout.dispose();
  }

  static String _planDisplayName(String planId) {
    switch (planId) {
      case 'pro':
        return 'Pro';
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
