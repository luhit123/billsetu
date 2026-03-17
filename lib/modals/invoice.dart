import 'package:cloud_firestore/cloud_firestore.dart';

import 'line_item.dart';

enum InvoiceStatus {
  paid,
  pending,
  overdue,
}

class Invoice {
  const Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.clientId,
    required this.clientName,
    required this.items,
    required this.createdAt,
    required this.status,
  });

  final String id;
  final String invoiceNumber;
  final String clientId;
  final String clientName;
  final List<LineItem> items;
  final DateTime createdAt;
  final InvoiceStatus status;

  double get grandTotal {
    return items.fold(0, (runningTotal, item) => runningTotal + item.total);
  }

  factory Invoice.fromMap(Map<String, dynamic> map, {String? docId}) {
    final rawItems = map['items'] as List<dynamic>? ?? const [];

    return Invoice(
      id: docId ?? (map['id'] as String? ?? ''),
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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'clientId': clientId,
      'clientName': clientName,
      'items': items.map((item) => item.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status.name,
    };
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
}
