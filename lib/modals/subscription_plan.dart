import 'package:cloud_firestore/cloud_firestore.dart';

enum PlanDuration { weekly, monthly, quarterly, halfYearly, yearly, custom }

enum PlanType { recurring, package }

class SubscriptionPlan {
  final String id;
  final String ownerId;
  final String name;
  final String description;
  final List<String> benefits;
  final PlanDuration duration;
  final int customDays;
  final double price;
  final double joiningFee;
  final double discountPercent;
  final int gracePeriodDays;
  final PlanType planType; // recurring or package (one-time)
  final bool autoRenew;
  final bool isActive;
  final bool isDeleted;
  final int memberCount;
  final String colorHex; // e.g. '#1E3A8A'
  final bool gstEnabled;
  final double gstRate; // 5, 12, 18, or 28
  final String gstType; // 'cgst_sgst' or 'igst'
  final DateTime createdAt;
  final DateTime updatedAt;

  const SubscriptionPlan({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description = '',
    this.benefits = const [],
    this.duration = PlanDuration.monthly,
    this.customDays = 30,
    this.price = 0,
    this.joiningFee = 0,
    this.discountPercent = 0,
    this.gracePeriodDays = 3,
    this.planType = PlanType.recurring,
    this.autoRenew = true,
    this.isActive = true,
    this.isDeleted = false,
    this.memberCount = 0,
    this.colorHex = '#1E3A8A',
    this.gstEnabled = false,
    this.gstRate = 18.0,
    this.gstType = 'cgst_sgst',
    required this.createdAt,
    required this.updatedAt,
  });

  int get durationDays {
    switch (duration) {
      case PlanDuration.weekly:
        return 7;
      case PlanDuration.monthly:
        return 30;
      case PlanDuration.quarterly:
        return 90;
      case PlanDuration.halfYearly:
        return 180;
      case PlanDuration.yearly:
        return 365;
      case PlanDuration.custom:
        return customDays;
    }
  }

  String get durationLabel {
    switch (duration) {
      case PlanDuration.weekly:
        return 'Weekly';
      case PlanDuration.monthly:
        return 'Monthly';
      case PlanDuration.quarterly:
        return 'Quarterly';
      case PlanDuration.halfYearly:
        return '6 Months';
      case PlanDuration.yearly:
        return 'Yearly';
      case PlanDuration.custom:
        return '$customDays Days';
    }
  }

  double get effectivePrice {
    if (discountPercent > 0) {
      return price - (price * discountPercent / 100);
    }
    return price;
  }

  factory SubscriptionPlan.fromMap(Map<String, dynamic> map, {String? docId}) {
    return SubscriptionPlan(
      id: docId ?? map['id'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      benefits:
          (map['benefits'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      duration: _parseDuration(map['duration'] as String?),
      customDays: map['customDays'] as int? ?? 30,
      price: (map['price'] as num?)?.toDouble() ?? 0,
      joiningFee: (map['joiningFee'] as num?)?.toDouble() ?? 0,
      discountPercent: (map['discountPercent'] as num?)?.toDouble() ?? 0,
      gracePeriodDays: map['gracePeriodDays'] as int? ?? 3,
      planType: (map['planType'] as String?) == 'package'
          ? PlanType.package
          : PlanType.recurring,
      autoRenew: map['autoRenew'] as bool? ?? true,
      isActive: map['isActive'] as bool? ?? true,
      isDeleted: map['isDeleted'] as bool? ?? false,
      memberCount: map['memberCount'] as int? ?? 0,
      colorHex: map['colorHex'] as String? ?? '#1E3A8A',
      gstEnabled: map['gstEnabled'] as bool? ?? false,
      gstRate: (map['gstRate'] as num?)?.toDouble() ?? 18.0,
      gstType: map['gstType'] as String? ?? 'cgst_sgst',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'name': name,
      'nameLower': name.toLowerCase(),
      'description': description,
      'benefits': benefits,
      'duration': duration.name,
      'customDays': customDays,
      'price': price,
      'joiningFee': joiningFee,
      'discountPercent': discountPercent,
      'gracePeriodDays': gracePeriodDays,
      'planType': planType.name,
      'autoRenew': autoRenew,
      'isActive': isActive,
      'isDeleted': isDeleted,
      'memberCount': memberCount,
      'colorHex': colorHex,
      'gstEnabled': gstEnabled,
      'gstRate': gstRate,
      'gstType': gstType,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  SubscriptionPlan copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? description,
    List<String>? benefits,
    PlanDuration? duration,
    int? customDays,
    double? price,
    double? joiningFee,
    double? discountPercent,
    int? gracePeriodDays,
    PlanType? planType,
    bool? autoRenew,
    bool? isActive,
    bool? isDeleted,
    int? memberCount,
    String? colorHex,
    bool? gstEnabled,
    double? gstRate,
    String? gstType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SubscriptionPlan(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      description: description ?? this.description,
      benefits: benefits ?? this.benefits,
      duration: duration ?? this.duration,
      customDays: customDays ?? this.customDays,
      price: price ?? this.price,
      joiningFee: joiningFee ?? this.joiningFee,
      discountPercent: discountPercent ?? this.discountPercent,
      gracePeriodDays: gracePeriodDays ?? this.gracePeriodDays,
      planType: planType ?? this.planType,
      autoRenew: autoRenew ?? this.autoRenew,
      isActive: isActive ?? this.isActive,
      isDeleted: isDeleted ?? this.isDeleted,
      memberCount: memberCount ?? this.memberCount,
      colorHex: colorHex ?? this.colorHex,
      gstEnabled: gstEnabled ?? this.gstEnabled,
      gstRate: gstRate ?? this.gstRate,
      gstType: gstType ?? this.gstType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static PlanDuration _parseDuration(String? s) {
    if (s == null) return PlanDuration.monthly;
    return PlanDuration.values.firstWhere(
      (e) => e.name == s,
      orElse: () => PlanDuration.monthly,
    );
  }
}
