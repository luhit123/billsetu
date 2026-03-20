import 'package:cloud_firestore/cloud_firestore.dart';

enum SubscriptionStatus { created, active, pending, halted, cancelled, expired }

class Subscription {
  final String id;
  final String userId;
  final String plan; // 'free' | 'raja' | 'maharaja'
  final String billingCycle; // 'monthly' | 'annual'
  final SubscriptionStatus status;
  final String? razorpaySubscriptionId;
  final String? razorpayPlanId;
  final String? razorpayCustomerId;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final DateTime? cancelledAt;
  final bool cancelAtPeriodEnd;
  final DateTime? graceExpiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int priceInPaise; // 14900 = ₹149.00

  const Subscription({
    required this.id,
    required this.userId,
    required this.plan,
    required this.billingCycle,
    required this.status,
    this.razorpaySubscriptionId,
    this.razorpayPlanId,
    this.razorpayCustomerId,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.cancelledAt,
    this.cancelAtPeriodEnd = false,
    this.graceExpiresAt,
    required this.createdAt,
    required this.updatedAt,
    this.priceInPaise = 0,
  });

  bool get isActive => status == SubscriptionStatus.active;
  bool get isInGracePeriod =>
      status == SubscriptionStatus.halted &&
      graceExpiresAt != null &&
      graceExpiresAt!.isAfter(DateTime.now());
  bool get hasAccess => isActive || isInGracePeriod;

  factory Subscription.fromMap(Map<String, dynamic> map, {String? docId}) {
    return Subscription(
      id: docId ?? map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      plan: map['plan'] as String? ?? 'free',
      billingCycle: map['billingCycle'] as String? ?? 'monthly',
      status: _parseStatus(map['status'] as String?),
      razorpaySubscriptionId: map['razorpaySubscriptionId'] as String?,
      razorpayPlanId: map['razorpayPlanId'] as String?,
      razorpayCustomerId: map['razorpayCustomerId'] as String?,
      currentPeriodStart: (map['currentPeriodStart'] as Timestamp?)?.toDate(),
      currentPeriodEnd: (map['currentPeriodEnd'] as Timestamp?)?.toDate(),
      cancelledAt: (map['cancelledAt'] as Timestamp?)?.toDate(),
      cancelAtPeriodEnd: map['cancelAtPeriodEnd'] as bool? ?? false,
      graceExpiresAt: (map['graceExpiresAt'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      priceInPaise: map['priceInPaise'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'plan': plan,
      'billingCycle': billingCycle,
      'status': status.name,
      'razorpaySubscriptionId': razorpaySubscriptionId,
      'razorpayPlanId': razorpayPlanId,
      'razorpayCustomerId': razorpayCustomerId,
      'currentPeriodStart': currentPeriodStart != null ? Timestamp.fromDate(currentPeriodStart!) : null,
      'currentPeriodEnd': currentPeriodEnd != null ? Timestamp.fromDate(currentPeriodEnd!) : null,
      'cancelledAt': cancelledAt != null ? Timestamp.fromDate(cancelledAt!) : null,
      'cancelAtPeriodEnd': cancelAtPeriodEnd,
      'graceExpiresAt': graceExpiresAt != null ? Timestamp.fromDate(graceExpiresAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'priceInPaise': priceInPaise,
    };
  }

  static SubscriptionStatus _parseStatus(String? s) {
    if (s == null) return SubscriptionStatus.created;
    return SubscriptionStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => SubscriptionStatus.created,
    );
  }
}
