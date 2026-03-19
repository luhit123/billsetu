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

  double get subtotal => items.fold(0, (s, i) => s + i.total);
  int get totalItems => items.length;
  bool get isDraft => status == PurchaseOrderStatus.draft;
  bool get isReceived => status == PurchaseOrderStatus.received;
  bool get isCancelled => status == PurchaseOrderStatus.cancelled;

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
    );
  }

  factory PurchaseOrder.fromMap(Map<String, dynamic> map, {String? docId}) {
    final rawItems = map['items'];
    final items = rawItems is List
        ? rawItems
            .map((e) =>
                PurchaseLineItem.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList()
        : <PurchaseLineItem>[];

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
