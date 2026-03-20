import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:billeasy/modals/purchase_line_item.dart';

enum PurchaseOrderStatus { draft, confirmed, received, cancelled }

class PurchaseOrder {
  const PurchaseOrder({
    required this.id,
    required this.ownerId,
    required this.orderNumber,
    required this.supplierName,
    this.supplierPhone = '',
    this.supplierAddress = '',
    this.supplierGstin = '',
    required this.items,
    this.status = PurchaseOrderStatus.draft,
    required this.createdAt,
    this.receivedAt,
    this.expectedDate,
    this.notes = '',
    this.discountType,
    this.discountValue = 0,
    this.gstEnabled = false,
    this.gstRate = 18.0,
    this.gstType = 'cgst_sgst', // 'cgst_sgst' or 'igst'
  });

  final String id;
  final String ownerId;
  final String orderNumber; // e.g. PO-2025-00001
  final String supplierName;
  final String supplierPhone;
  final String supplierAddress;
  final String supplierGstin;
  final List<PurchaseLineItem> items;
  final PurchaseOrderStatus status;
  final DateTime createdAt;
  final DateTime? receivedAt;
  final DateTime? expectedDate;
  final String notes;
  final String? discountType; // 'percentage' or 'overall'
  final double discountValue;
  final bool gstEnabled;
  final double gstRate;
  final String gstType;

  double get subtotal => items.fold(0, (s, i) => s + i.total);
  int get totalItems => items.length;
  bool get isDraft => status == PurchaseOrderStatus.draft;
  bool get isReceived => status == PurchaseOrderStatus.received;
  bool get isCancelled => status == PurchaseOrderStatus.cancelled;

  // Discount computed properties
  double get discountAmount {
    if (discountType == null || discountValue <= 0) return 0;
    if (discountType == 'percentage') {
      return (subtotal * discountValue / 100).clamp(0, subtotal).toDouble();
    }
    // 'overall' — flat amount clamped to subtotal
    return discountValue.clamp(0, subtotal).toDouble();
  }

  bool get hasDiscount => discountAmount > 0;

  // GST computed properties (per-item rates)
  double get taxableAmount => subtotal - discountAmount;

  /// Ratio to apply discount proportionally to each item.
  double get _discountRatio =>
      subtotal > 0 ? (subtotal - discountAmount) / subtotal : 0;

  double get cgstAmount {
    if (!gstEnabled || gstType != 'cgst_sgst') return 0;
    return items.fold(
        0.0, (s, i) => s + i.total * _discountRatio * i.gstRate / 200);
  }

  double get sgstAmount => cgstAmount;

  double get igstAmount {
    if (!gstEnabled || gstType != 'igst') return 0;
    return items.fold(
        0.0, (s, i) => s + i.total * _discountRatio * i.gstRate / 100);
  }

  double get totalTax => cgstAmount + sgstAmount + igstAmount;
  bool get hasGst => gstEnabled && totalTax > 0;
  double get grandTotal => taxableAmount + totalTax;

  PurchaseOrder copyWith({
    String? id,
    String? ownerId,
    String? orderNumber,
    String? supplierName,
    String? supplierPhone,
    String? supplierAddress,
    String? supplierGstin,
    List<PurchaseLineItem>? items,
    PurchaseOrderStatus? status,
    DateTime? createdAt,
    DateTime? receivedAt,
    DateTime? expectedDate,
    String? notes,
    String? discountType,
    double? discountValue,
    bool? gstEnabled,
    double? gstRate,
    String? gstType,
  }) {
    return PurchaseOrder(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      orderNumber: orderNumber ?? this.orderNumber,
      supplierName: supplierName ?? this.supplierName,
      supplierPhone: supplierPhone ?? this.supplierPhone,
      supplierAddress: supplierAddress ?? this.supplierAddress,
      supplierGstin: supplierGstin ?? this.supplierGstin,
      items: items ?? this.items,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      receivedAt: receivedAt ?? this.receivedAt,
      expectedDate: expectedDate ?? this.expectedDate,
      notes: notes ?? this.notes,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      gstEnabled: gstEnabled ?? this.gstEnabled,
      gstRate: gstRate ?? this.gstRate,
      gstType: gstType ?? this.gstType,
    );
  }

  factory PurchaseOrder.fromMap(Map<String, dynamic> map, {String? docId}) {
    final rawItems = map['items'];
    final orderGstRate = (map['gstRate'] as num? ?? 18.0).toDouble();
    final orderGstEnabled = map['gstEnabled'] as bool? ?? false;
    var items = rawItems is List
        ? rawItems
            .map((e) =>
                PurchaseLineItem.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList()
        : <PurchaseLineItem>[];

    // Backward compat: if GST enabled but all items have gstRate 0
    // (saved before per-item GST), backfill with order-level rate.
    if (orderGstEnabled &&
        orderGstRate > 0 &&
        items.isNotEmpty &&
        items.every((i) => i.gstRate == 0)) {
      items = items.map((i) => i.copyWith(gstRate: orderGstRate)).toList();
    }

    return PurchaseOrder(
      id: docId ?? (map['id'] as String? ?? ''),
      ownerId: map['ownerId'] as String? ?? '',
      orderNumber: map['orderNumber'] as String? ?? '',
      supplierName: map['supplierName'] as String? ?? '',
      supplierPhone: map['supplierPhone'] as String? ?? '',
      supplierAddress: map['supplierAddress'] as String? ?? '',
      supplierGstin: map['supplierGstin'] as String? ?? '',
      items: items,
      status: _parseStatus(map['status']),
      createdAt: _ts(map['createdAt']) ?? DateTime.now(),
      receivedAt: _ts(map['receivedAt']),
      expectedDate: _ts(map['expectedDate']),
      notes: map['notes'] as String? ?? '',
      discountType: map['discountType'] as String?,
      discountValue: (map['discountValue'] as num? ?? 0).toDouble(),
      gstEnabled: map['gstEnabled'] as bool? ?? false,
      gstRate: (map['gstRate'] as num? ?? 18.0).toDouble(),
      gstType: map['gstType'] as String? ?? 'cgst_sgst',
    );
  }

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'id': id,
      'ownerId': ownerId,
      'orderNumber': orderNumber,
      'supplierName': supplierName,
      'supplierPhone': supplierPhone,
      'supplierAddress': supplierAddress,
      'supplierGstin': supplierGstin,
      'items': items.map((i) => i.toMap()).toList(),
      'status': status.name,
      'subtotal': subtotal,
      'totalItems': totalItems,
      'createdAt': Timestamp.fromDate(createdAt),
      'receivedAt':
          receivedAt == null ? null : Timestamp.fromDate(receivedAt!),
      'expectedDate':
          expectedDate == null ? null : Timestamp.fromDate(expectedDate!),
      'notes': notes,
      'discountType': discountType,
      'discountValue': discountValue,
      'discountAmount': discountAmount,
      'gstEnabled': gstEnabled,
      'gstRate': gstRate,
      'gstType': gstType,
      'taxableAmount': taxableAmount,
      'totalTax': totalTax,
      'grandTotal': grandTotal,
    };
    data.removeWhere((_, v) => v == null);
    return data;
  }

  static PurchaseOrderStatus _parseStatus(Object? v) {
    switch (v as String?) {
      case 'confirmed':
        return PurchaseOrderStatus.confirmed;
      case 'received':
        return PurchaseOrderStatus.received;
      case 'cancelled':
        return PurchaseOrderStatus.cancelled;
      default:
        return PurchaseOrderStatus.draft;
    }
  }

  static DateTime? _ts(Object? v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}
