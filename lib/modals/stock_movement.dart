import 'package:cloud_firestore/cloud_firestore.dart';

enum StockMovementType {
  purchaseIn,
  saleOut,
  manualIn,
  manualOut,
  openingStock,
}

class StockMovement {
  const StockMovement({
    required this.id,
    required this.ownerId,
    required this.productId,
    required this.productName,
    required this.type,
    required this.quantity, // always positive
    required this.balanceAfter,
    this.referenceId = '', // PO id or invoice id
    this.referenceNumber = '', // PO-2025-00001 or BR-2025-00001
    this.unitPrice = 0,
    required this.createdAt,
    this.notes = '',
  });

  final String id;
  final String ownerId;
  final String productId;
  final String productName;
  final StockMovementType type;
  final double quantity;
  final double balanceAfter;
  final String referenceId;
  final String referenceNumber;
  final double unitPrice;
  final DateTime createdAt;
  final String notes;

  bool get isInbound =>
      type == StockMovementType.purchaseIn ||
      type == StockMovementType.manualIn ||
      type == StockMovementType.openingStock;

  String get typeLabel {
    switch (type) {
      case StockMovementType.purchaseIn:
        return 'Purchase In';
      case StockMovementType.saleOut:
        return 'Sale Out';
      case StockMovementType.manualIn:
        return 'Manual Addition';
      case StockMovementType.manualOut:
        return 'Manual Removal';
      case StockMovementType.openingStock:
        return 'Opening Stock';
    }
  }

  factory StockMovement.fromMap(Map<String, dynamic> map, {String? docId}) {
    return StockMovement(
      id: docId ?? (map['id'] as String? ?? ''),
      ownerId: map['ownerId'] as String? ?? '',
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      type: _parseType(map['type']),
      quantity: (map['quantity'] as num? ?? 0).toDouble(),
      balanceAfter: (map['balanceAfter'] as num? ?? 0).toDouble(),
      referenceId: map['referenceId'] as String? ?? '',
      referenceNumber: map['referenceNumber'] as String? ?? '',
      unitPrice: (map['unitPrice'] as num? ?? 0).toDouble(),
      createdAt: _ts(map['createdAt']) ?? DateTime.now(),
      notes: map['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'id': id,
      'ownerId': ownerId,
      'productId': productId,
      'productName': productName,
      'type': type.name,
      'quantity': quantity,
      'balanceAfter': balanceAfter,
      'referenceId': referenceId,
      'referenceNumber': referenceNumber,
      'unitPrice': unitPrice,
      'createdAt': Timestamp.fromDate(createdAt),
      'notes': notes,
    };
    data.removeWhere((_, v) => v == null);
    return data;
  }

  static StockMovementType _parseType(Object? v) {
    switch (v as String?) {
      case 'purchaseIn':
        return StockMovementType.purchaseIn;
      case 'saleOut':
        return StockMovementType.saleOut;
      case 'manualIn':
        return StockMovementType.manualIn;
      case 'manualOut':
        return StockMovementType.manualOut;
      default:
        return StockMovementType.openingStock;
    }
  }

  static DateTime? _ts(Object? v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}
