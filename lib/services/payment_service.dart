import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../modals/payment.dart';

/// Demo payment service that simulates Razorpay flow.
/// Replace with real razorpay_flutter when going to production.
class PaymentService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();

  // ignore: unused_field
  final _functions = FirebaseFunctions.instance; // reserved for production
  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  /// DEMO: Simulates creating a Razorpay subscription and immediately
  /// activating the plan in Firestore. In production, this would call
  /// the Cloud Function which creates a real Razorpay subscription,
  /// then open Razorpay checkout UI.
  Future<PaymentResult> purchasePlan({
    required String planId, // 'raja' | 'maharaja'
    required String billingCycle, // 'monthly' | 'annual'
  }) async {
    if (_isProcessing) {
      return PaymentResult(success: false, message: 'Payment already in progress');
    }

    _isProcessing = true;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        return PaymentResult(success: false, message: 'Not signed in');
      }

      // In DEMO mode, simulate a 2-second payment processing delay
      await Future.delayed(const Duration(seconds: 2));

      // Calculate price
      final priceInPaise = _getPrice(planId, billingCycle);
      final now = DateTime.now();
      final periodEnd = billingCycle == 'annual'
          ? DateTime(now.year + 1, now.month, now.day)
          : DateTime(now.year, now.month + 1, now.day);

      // Generate demo IDs
      final demoSubId = 'demo_sub_${now.millisecondsSinceEpoch}';
      final demoPayId = 'demo_pay_${now.millisecondsSinceEpoch}';

      // Write subscription doc (in production, Cloud Function does this after webhook)
      await FirebaseFirestore.instance
          .collection('subscriptions')
          .doc(uid)
          .set({
        'id': demoSubId,
        'userId': uid,
        'plan': planId,
        'billingCycle': billingCycle,
        'status': 'active',
        'razorpaySubscriptionId': demoSubId,
        'currentPeriodStart': Timestamp.fromDate(now),
        'currentPeriodEnd': Timestamp.fromDate(periodEnd),
        'cancelAtPeriodEnd': false,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'priceInPaise': priceInPaise,
        'launchOffer': false,
        'demoMode': true,
      });

      // Write payment record
      final gst = (priceInPaise * 18 / 118).round();
      await FirebaseFirestore.instance
          .collection('subscriptions')
          .doc(uid)
          .collection('payments')
          .doc(demoPayId)
          .set({
        'id': demoPayId,
        'userId': uid,
        'subscriptionId': demoSubId,
        'razorpayPaymentId': demoPayId,
        'amount': priceInPaise,
        'currency': 'INR',
        'status': 'captured',
        'method': 'demo',
        'createdAt': Timestamp.fromDate(now),
        'gstAmount': gst,
        'baseAmount': priceInPaise - gst,
      });

      return PaymentResult(
        success: true,
        message: 'Plan activated successfully!',
        paymentId: demoPayId,
      );
    } catch (e) {
      debugPrint('PaymentService error: $e');
      return PaymentResult(success: false, message: 'Payment failed: $e');
    } finally {
      _isProcessing = false;
    }
  }

  /// Cancel subscription (sets cancelAtPeriodEnd = true in demo)
  Future<bool> cancelSubscription() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    try {
      await FirebaseFirestore.instance
          .collection('subscriptions')
          .doc(uid)
          .update({
        'cancelAtPeriodEnd': true,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      return true;
    } catch (e) {
      debugPrint('Cancel error: $e');
      return false;
    }
  }

  /// Reactivate cancelled subscription (undo cancel)
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

  int _getPrice(String planId, String billingCycle) {
    if (planId == 'raja') {
      return billingCycle == 'annual' ? 119900 : 14900; // ₹1,199 or ₹149
    } else if (planId == 'maharaja') {
      return billingCycle == 'annual' ? 299900 : 39900; // ₹2,999 or ₹399
    }
    return 0;
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
