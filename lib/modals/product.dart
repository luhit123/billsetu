import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  const Product({
    required this.id,
    required this.name,
    this.description = '',
    this.unitPrice = 0,
    this.unit = 'pcs',
    this.category = '',
    this.createdAt,
    this.updatedAt,
    this.hsnCode = '',
    this.gstRate = 18.0,
    this.gstApplicable = false,
    this.currentStock = 0.0,
    this.minStockAlert = 0.0,
    this.trackInventory = false,
  });

  final String id;
  final String name;
  final String description;
  final double unitPrice;
  final String unit;
  final String category;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String hsnCode;
  final double gstRate;
  final bool gstApplicable;
  final double currentStock; // default 0.0
  final double minStockAlert; // alert when stock <= this, default 0.0
  final bool trackInventory; // opt-in inventory tracking, default false

  /// First two letters of name in uppercase — used for avatar.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    final first = parts.isNotEmpty && parts[0].isNotEmpty ? parts[0][0] : '';
    final second =
        parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    final v = '$first$second'.trim();
    return v.isEmpty ? '?' : v.toUpperCase();
  }

  String get priceLabel {
    final formatted = unitPrice == unitPrice.truncateToDouble()
        ? unitPrice.toStringAsFixed(0)
        : unitPrice.toStringAsFixed(2);
    return '₹$formatted / $unit';
  }

  Product copyWith({
    String? id,
    String? name,
    String? description,
    double? unitPrice,
    String? unit,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? hsnCode,
    double? gstRate,
    bool? gstApplicable,
    double? currentStock,
    double? minStockAlert,
    bool? trackInventory,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      unitPrice: unitPrice ?? this.unitPrice,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      hsnCode: hsnCode ?? this.hsnCode,
      gstRate: gstRate ?? this.gstRate,
      gstApplicable: gstApplicable ?? this.gstApplicable,
      currentStock: currentStock ?? this.currentStock,
      minStockAlert: minStockAlert ?? this.minStockAlert,
      trackInventory: trackInventory ?? this.trackInventory,
    );
  }

  factory Product.fromMap(Map<String, dynamic> map, {String? docId}) {
    return Product(
      id: docId ?? (map['id'] as String? ?? ''),
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      unitPrice: (map['unitPrice'] as num? ?? 0).toDouble(),
      unit: map['unit'] as String? ?? 'pcs',
      category: map['category'] as String? ?? '',
      createdAt: _ts(map['createdAt']),
      updatedAt: _ts(map['updatedAt']),
      hsnCode: map['hsnCode'] as String? ?? '',
      gstRate: (map['gstRate'] as num? ?? 18.0).toDouble(),
      gstApplicable: map['gstApplicable'] as bool? ?? false,
      currentStock: (map['currentStock'] as num? ?? 0).toDouble(),
      minStockAlert: (map['minStockAlert'] as num? ?? 0).toDouble(),
      trackInventory: map['trackInventory'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'id': id,
      'name': name,
      'nameLower': name.trim().toLowerCase(),
      'description': description,
      'unitPrice': unitPrice,
      'unit': unit,
      'category': category,
      'createdAt':
          createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updatedAt':
          updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
      'hsnCode': hsnCode,
      'gstRate': gstRate,
      'gstApplicable': gstApplicable,
      'currentStock': currentStock,
      'minStockAlert': minStockAlert,
      'trackInventory': trackInventory,
    };
    data.removeWhere((_, v) => v == null);
    return data;
  }

  static DateTime? _ts(Object? v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}
