import 'package:billeasy/utils/number_utils.dart' as nu;
import 'package:billeasy/utils/invoice_search.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'line_item.dart';

enum InvoiceStatus { paid, pending, overdue, partiallyPaid }

enum InvoiceDiscountType { percentage, overall }

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
    this.dueDate,
    this.discountType,
    this.discountValue = 0,
    this.gstEnabled = false,
    this.gstRate = 18.0,
    this.gstType = 'cgst_sgst',
    this.placeOfSupply = '',
    this.customerGstin = '',
    this.storedSubtotal,
    this.storedDiscountAmount,
    this.storedTaxableAmount,
    this.storedCgstAmount,
    this.storedSgstAmount,
    this.storedIgstAmount,
    this.storedTotalTax,
    this.storedGrandTotal,
    this.amountReceived = 0,
    this.notes,
  });

  final String id;
  final String ownerId;
  final String invoiceNumber;
  final String clientId;
  final String clientName;
  final List<LineItem> items;
  final DateTime createdAt;
  final InvoiceStatus status;
  final DateTime? dueDate;
  final String? notes;
  final InvoiceDiscountType? discountType;
  final double discountValue;
  // GST fields (optional, defaults to disabled)
  final bool gstEnabled;
  final double gstRate; // 5, 12, 18, or 28
  final String gstType; // 'cgst_sgst' (intrastate) or 'igst' (interstate)
  final String placeOfSupply;
  final String customerGstin;
  final double? storedSubtotal;
  final double? storedDiscountAmount;
  final double? storedTaxableAmount;
  final double? storedCgstAmount;
  final double? storedSgstAmount;
  final double? storedIgstAmount;
  final double? storedTotalTax;
  final double? storedGrandTotal;
  final double amountReceived;

  double get balanceDue => _roundCurrency(grandTotal - amountReceived);
  bool get isFullyPaid => amountReceived >= grandTotal && grandTotal > 0;
  bool get isPartiallyPaid => amountReceived > 0 && amountReceived < grandTotal;

  /// Auto-compute status from payment. This is the ONLY source of truth for display.
  InvoiceStatus get effectiveStatus {
    if (isFullyPaid) return InvoiceStatus.paid;
    if (isPartiallyPaid) return InvoiceStatus.partiallyPaid;
    if (status == InvoiceStatus.overdue) return InvoiceStatus.overdue;
    return InvoiceStatus.pending; // received == 0 → "Unpaid"
  }

  double get subtotal {
    return storedSubtotal ??
        _roundCurrency(
          items.fold(0, (runningTotal, item) => runningTotal + item.total),
        );
  }

  double get discountAmount {
    if (storedDiscountAmount != null) {
      return storedDiscountAmount!;
    }

    if (discountType == null || discountValue <= 0) {
      return 0;
    }

    switch (discountType!) {
      case InvoiceDiscountType.percentage:
        return _roundCurrency(
          (subtotal * (discountValue / 100)).clamp(0, subtotal),
        );
      case InvoiceDiscountType.overall:
        return _roundCurrency(discountValue.clamp(0, subtotal));
    }
  }

  bool get hasDiscount => discountAmount > 0;

  /// Amount on which GST is applied = subtotal minus any discount.
  double get taxableAmount =>
      storedTaxableAmount ?? _roundCurrency(subtotal - discountAmount);

  /// Ratio to apply discount proportionally to each item.
  double get _discountRatio =>
      subtotal > 0 ? (subtotal - discountAmount) / subtotal : 0;

  /// CGST computed per-item then summed (intrastate only).
  double get cgstAmount =>
      storedCgstAmount ??
      ((gstEnabled && gstType == 'cgst_sgst')
          ? _roundCurrency(items.fold(
              0.0, (s, i) => s + i.total * _discountRatio * i.gstRate / 200))
          : 0);

  /// SGST = equal to CGST (intrastate).
  double get sgstAmount => storedSgstAmount ?? cgstAmount;

  /// IGST computed per-item then summed (interstate only).
  double get igstAmount =>
      storedIgstAmount ??
      ((gstEnabled && gstType == 'igst')
          ? _roundCurrency(items.fold(
              0.0, (s, i) => s + i.total * _discountRatio * i.gstRate / 100))
          : 0);

  double get totalTax =>
      storedTotalTax ?? _roundCurrency(cgstAmount + sgstAmount + igstAmount);

  bool get hasGst => gstEnabled && totalTax > 0;

  double get grandTotal {
    return storedGrandTotal ?? _roundCurrency(taxableAmount + totalTax);
  }

  factory Invoice.fromMap(Map<String, dynamic> map, {String? docId}) {
    final rawItems = map['items'] as List<dynamic>? ?? const [];
    final orderGstRate = _doubleFromMapValue(map['gstRate']) > 0
        ? _doubleFromMapValue(map['gstRate'])
        : 18.0;
    final orderGstEnabled = map['gstEnabled'] as bool? ?? false;
    var parsedItems = rawItems
        .map(
          (item) => LineItem.fromMap(Map<String, dynamic>.from(item as Map)),
        )
        .toList();

    // Backward compat: if GST enabled but all items have gstRate 0
    // (saved before per-item GST), backfill with order-level rate.
    if (orderGstEnabled &&
        orderGstRate > 0 &&
        parsedItems.isNotEmpty &&
        parsedItems.every((i) => i.gstRate == 0)) {
      parsedItems = parsedItems
          .map((i) => LineItem(
                description: i.description,
                quantity: i.quantity,
                unitPrice: i.unitPrice,
                unit: i.unit,
                hsnCode: i.hsnCode,
                gstRate: orderGstRate,
              ))
          .toList();
    }

    return Invoice(
      id: docId ?? (map['id'] as String? ?? ''),
      ownerId: map['ownerId'] as String? ?? '',
      invoiceNumber: map['invoiceNumber'] as String? ?? '',
      clientId: map['clientId'] as String? ?? '',
      clientName:
          map['clientName'] as String? ?? (map['clientId'] as String? ?? ''),
      items: parsedItems,
      createdAt: _dateTimeFromMapValue(map['createdAt']),
      status: _statusFromMapValue(map['status']),
      dueDate: _nullableDateTimeFromMapValue(map['dueDate'] ?? map['dueAt']),
      discountType: _discountTypeFromMapValue(map['discountType']),
      discountValue: _doubleFromMapValue(map['discountValue']),
      gstEnabled: map['gstEnabled'] as bool? ?? false,
      gstRate: _doubleFromMapValue(map['gstRate']) > 0
          ? _doubleFromMapValue(map['gstRate'])
          : 18.0,
      gstType: map['gstType'] as String? ?? 'cgst_sgst',
      placeOfSupply: map['placeOfSupply'] as String? ?? '',
      customerGstin: map['customerGstin'] as String? ?? '',
      storedSubtotal: _nullableDoubleFromMapValue(map['subtotal']),
      storedDiscountAmount: _nullableDoubleFromMapValue(map['discountAmount']),
      storedTaxableAmount: _nullableDoubleFromMapValue(map['taxableAmount']),
      storedCgstAmount: _nullableDoubleFromMapValue(map['cgstAmount']),
      storedSgstAmount: _nullableDoubleFromMapValue(map['sgstAmount']),
      storedIgstAmount: _nullableDoubleFromMapValue(map['igstAmount']),
      storedTotalTax: _nullableDoubleFromMapValue(map['totalTax']),
      storedGrandTotal: _nullableDoubleFromMapValue(map['grandTotal']),
      amountReceived: _doubleFromMapValue(map['amountReceived']),
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    // Compute all financials from a single chain to guarantee Firestore rule
    // invariants hold exactly (no floating-point rounding drift between
    // independently rounded getters).
    final mapSubtotal = _roundCurrency(
      items.fold(0.0, (acc, item) => acc + item.total),
    );
    final mapDiscountAmount = _computeDiscount(mapSubtotal);
    // Do NOT round — Firestore rule checks: taxableAmount == subtotal - discountAmount
    final mapTaxableAmount = mapSubtotal - mapDiscountAmount;
    final discRatio = mapSubtotal > 0 ? mapTaxableAmount / mapSubtotal : 0.0;

    double mapCgst = 0, mapSgst = 0, mapIgst = 0;
    if (gstEnabled) {
      for (final item in items) {
        final itemTaxable = item.total * discRatio;
        if (gstType == 'cgst_sgst') {
          mapCgst += itemTaxable * item.gstRate / 200;
        } else {
          mapIgst += itemTaxable * item.gstRate / 100;
        }
      }
      mapCgst = _roundCurrency(mapCgst);
      mapSgst = mapCgst; // SGST always equals CGST for intra-state
      mapIgst = _roundCurrency(mapIgst);
    }

    // Derive totalTax and grandTotal as EXACT sums of already-rounded parts.
    // Do NOT re-round — Firestore rules check exact equality:
    //   totalTax == cgstAmount + sgstAmount + igstAmount
    //   grandTotal == taxableAmount + totalTax
    // Re-rounding can shift by 0.01 and fail the rule.
    final mapTotalTax = mapCgst + mapSgst + mapIgst;
    final mapGrandTotal = mapTaxableAmount + mapTotalTax;
    final mapHasGst = gstEnabled && mapTotalTax > 0;
    final mapBalanceDue = _roundCurrency(mapGrandTotal - amountReceived);

    return {
      'id': id,
      'ownerId': ownerId,
      'invoiceNumber': invoiceNumber,
      'clientId': clientId,
      'clientName': clientName,
      'clientNameLower': _normalizeClientName(clientName),
      'searchPrefixes': buildInvoiceSearchPrefixes(
        clientName: clientName,
        invoiceNumber: invoiceNumber,
      ),
      'items': items.map((item) => item.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate!),
      'status': status.name,
      'discountType': discountType?.name,
      'discountValue': discountValue,
      'gstEnabled': gstEnabled,
      'gstRate': gstRate,
      'gstType': gstType,
      'placeOfSupply': placeOfSupply,
      'customerGstin': customerGstin,
      'subtotal': mapSubtotal,
      'discountAmount': mapDiscountAmount,
      'taxableAmount': mapTaxableAmount,
      'cgstAmount': mapCgst,
      'sgstAmount': mapSgst,
      'igstAmount': mapIgst,
      'totalTax': mapTotalTax,
      'grandTotal': mapGrandTotal,
      'hasGst': mapHasGst,
      'amountReceived': amountReceived,
      'balanceDue': mapBalanceDue,
      if (notes != null) 'notes': notes,
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

  static DateTime? _nullableDateTimeFromMapValue(Object? value) {
    if (value == null) {
      return null;
    }

    return _dateTimeFromMapValue(value);
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

  static double? _nullableDoubleFromMapValue(Object? value) {
    if (value == null) {
      return null;
    }

    return _doubleFromMapValue(value);
  }

  /// Compute discount from subtotal (used by toMap to avoid getter drift).
  double _computeDiscount(double sub) {
    if (discountType == null || discountValue <= 0) return 0;
    switch (discountType!) {
      case InvoiceDiscountType.percentage:
        return _roundCurrency((sub * (discountValue / 100)).clamp(0, sub));
      case InvoiceDiscountType.overall:
        return _roundCurrency(discountValue.clamp(0, sub));
    }
  }

  static double _roundCurrency(num value) {
    return (value * 100).roundToDouble() / 100;
  }
}
