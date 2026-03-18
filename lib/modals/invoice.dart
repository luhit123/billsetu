import 'package:billeasy/utils/number_utils.dart' as nu;
import 'package:cloud_firestore/cloud_firestore.dart';

import 'line_item.dart';

enum InvoiceStatus {
  paid,
  pending,
  overdue,
}

enum InvoiceDiscountType {
  percentage,
  overall,
}

class Invoice {
  const Invoice({
    required this.id,
    required this.ownerId,
    required this.invoiceNumber,
    required this.clientId,
    required this.clientName,
    required this.items,
    required this.createdAt,
    required this.status,
    this.discountType,
    this.discountValue = 0,
  });

  final String id;
  final String ownerId;
  final String invoiceNumber;
  final String clientId;
  final String clientName;
  final List<LineItem> items;
  final DateTime createdAt;
  final InvoiceStatus status;
  final InvoiceDiscountType? discountType;
  final double discountValue;

  double get subtotal {
    return items.fold(0, (runningTotal, item) => runningTotal + item.total);
  }

  double get discountAmount {
    if (discountType == null || discountValue <= 0) {
      return 0;
    }

    switch (discountType!) {
      case InvoiceDiscountType.percentage:
        return (subtotal * (discountValue / 100)).clamp(0, subtotal);
      case InvoiceDiscountType.overall:
        return discountValue.clamp(0, subtotal);
    }
  }

  bool get hasDiscount => discountAmount > 0;

  double get grandTotal {
    return subtotal - discountAmount;
  }

  factory Invoice.fromMap(Map<String, dynamic> map, {String? docId}) {
    final rawItems = map['items'] as List<dynamic>? ?? const [];

    return Invoice(
      id: docId ?? (map['id'] as String? ?? ''),
      ownerId: map['ownerId'] as String? ?? '',
      invoiceNumber: map['invoiceNumber'] as String? ?? '',
      clientId: map['clientId'] as String? ?? '',
      clientName:
          map['clientName'] as String? ??
          (map['clientId'] as String? ?? ''),
      items: rawItems
          .map((item) => LineItem.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList(),
      createdAt: _dateTimeFromMapValue(map['createdAt']),
      status: _statusFromMapValue(map['status']),
      discountType: _discountTypeFromMapValue(map['discountType']),
      discountValue: _doubleFromMapValue(map['discountValue']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'invoiceNumber': invoiceNumber,
      'clientId': clientId,
      'clientName': clientName,
      'clientNameLower': _normalizeClientName(clientName),
      'items': items.map((item) => item.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status.name,
      'discountType': discountType?.name,
      'discountValue': discountValue,
    };
  }

  static String _normalizeClientName(String value) {
    return value.trim().toLowerCase();
  }

  static DateTime _dateTimeFromMapValue(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }

    return DateTime.now();
  }

  static InvoiceStatus _statusFromMapValue(Object? value) {
    if (value is String) {
      return InvoiceStatus.values.firstWhere(
        (status) => status.name == value,
        orElse: () => InvoiceStatus.pending,
      );
    }

    return InvoiceStatus.pending;
  }

  static InvoiceDiscountType? _discountTypeFromMapValue(Object? value) {
    if (value is String) {
      return InvoiceDiscountType.values.firstWhere(
        (discountType) => discountType.name == value,
        orElse: () => InvoiceDiscountType.overall,
      );
    }

    return null;
  }

  static double _doubleFromMapValue(Object? value) {
    if (value is int) {
      return value.toDouble();
    }

    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return nu.parseDouble(value) ?? 0;
    }

    return 0;
  }
}
