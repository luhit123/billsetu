import 'package:cloud_firestore/cloud_firestore.dart';

class Payment {
  final String id;
  final String userId;
  final String subscriptionId;
  final String? razorpayPaymentId;
  final String? razorpayOrderId;
  final String? razorpaySignature;
  final int amount; // in paise
  final String currency;
  final String status; // 'captured' | 'failed' | 'refunded'
  final String? method; // 'upi' | 'card' | 'netbanking' | 'wallet'
  final DateTime createdAt;
  final int gstAmount; // GST component in paise (18%)
  final int baseAmount; // pre-GST amount in paise

  const Payment({
    required this.id,
    required this.userId,
    required this.subscriptionId,
    this.razorpayPaymentId,
    this.razorpayOrderId,
    this.razorpaySignature,
    required this.amount,
    this.currency = 'INR',
    required this.status,
    this.method,
    required this.createdAt,
    required this.gstAmount,
    required this.baseAmount,
  });

  factory Payment.fromMap(Map<String, dynamic> map, {String? docId}) {
    final amount = map['amount'] as int? ?? 0;
    final gst = map['gstAmount'] as int? ?? (amount * 18 / 118).round();
    return Payment(
      id: docId ?? map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      subscriptionId: map['subscriptionId'] as String? ?? '',
      razorpayPaymentId: map['razorpayPaymentId'] as String?,
      razorpayOrderId: map['razorpayOrderId'] as String?,
      razorpaySignature: map['razorpaySignature'] as String?,
      amount: amount,
      currency: map['currency'] as String? ?? 'INR',
      status: map['status'] as String? ?? 'failed',
      method: map['method'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      gstAmount: gst,
      baseAmount: amount - gst,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'subscriptionId': subscriptionId,
      'razorpayPaymentId': razorpayPaymentId,
      'razorpayOrderId': razorpayOrderId,
      'razorpaySignature': razorpaySignature,
      'amount': amount,
      'currency': currency,
      'status': status,
      'method': method,
      'createdAt': Timestamp.fromDate(createdAt),
      'gstAmount': gstAmount,
      'baseAmount': baseAmount,
    };
  }
}
