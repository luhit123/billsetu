import 'package:billeasy/utils/number_utils.dart' as nu;
import 'package:billeasy/utils/invoice_search.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'line_item.dart';

enum InvoiceStatus { paid, pending, overdue, partiallyPaid }

enum InvoiceDiscountType { percentage, overall }

/// Immutable snapshot of all computed financial values for an invoice.
///
/// **This is the single source of truth for GST/discount/total math.**
/// Both [Invoice.toMap] (persistence) and the create-invoice screen (live
/// preview) MUST use [Invoice.computeFinancials] to obtain this record,
/// guaranteeing identical results everywhere.
class FinancialSummary {
  const FinancialSummary({
    required this.subtotal,
    required this.discountAmount,
    required this.taxableAmount,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.igstAmount,
    required this.totalTax,
    required this.grandTotal,
    required this.hasGst,
    required this.balanceDue,
  });

  final double subtotal;
  final double discountAmount;
  final double taxableAmount;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double totalTax;
  final double grandTotal;
  final bool hasGst;
  final double balanceDue;
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
    this.paymentMethod = '',
    this.notes,
    this.createdByUid = '',
    this.createdByName = '',
    this.createdBySignatureUrl = '',
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
  final String paymentMethod; // Cash, UPI, Bank Transfer, Cheque, Other
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

  /// The UID of the team member who actually created this invoice.
  /// For solo users this equals [ownerId]. For team members it's their own UID.
  final String createdByUid;

  /// Display name of the creator (for quick reference without lookup).
  final String createdByName;

  /// Firebase Storage URL of the creator's signature at time of creation.
  final String createdBySignatureUrl;

  // ── B2B / B2C classification (Phase 2 GST compliance) ─────────────────────

  /// True if the customer has a valid GSTIN (B2B transaction).
  /// A valid GSTIN is exactly 15 characters per GST format rules.
  bool get isB2B => customerGstin.trim().length >= 15;

  /// "B2B" or "B2C" for GSTR-1 classification.
  String get gstTransactionType => isB2B ? 'B2B' : 'B2C';

  /// Schema version for forward-compatible data migrations.
  /// Version history:
  ///   1 = original (order-level GST only)
  ///   2 = per-item GST rates
  ///   3 = B2B/B2C classification + schema field + RCM foundation
  static const int currentSchemaVersion = 3;

  // ── Reverse Charge Mechanism (RCM) foundation ─────────────────────────────

  /// Whether this invoice is under reverse charge mechanism.
  /// When true, the recipient (buyer) is liable to pay GST instead of supplier.
  /// Commonly applies to services from unregistered dealers or specified services.
  bool get isReverseCharge => false; // TODO: wire to a field when RCM is enabled

  // ── Place of Supply helpers ────────────────────────────────────────────────

  /// Extracts the 2-digit state code from the customer's GSTIN (first 2 digits).
  /// Returns empty string if GSTIN is not set or invalid.
  String get customerStateCode {
    if (customerGstin.length < 2) return '';
    return customerGstin.substring(0, 2);
  }

  /// Determines if the supply is inter-state based on placeOfSupply vs
  /// the business's registered state. If placeOfSupply differs from business
  /// state code, it's inter-state (IGST applies).
  /// Returns null if determination cannot be made (missing data).
  bool? isInterStateSupply(String businessStateCode) {
    if (placeOfSupply.isEmpty || businessStateCode.isEmpty) return null;
    // placeOfSupply may be a 2-digit code or a full state name
    final supplyCode = placeOfSupply.length == 2
        ? placeOfSupply
        : placeOfSupply; // TODO: map state names to codes
    return supplyCode != businessStateCode;
  }

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

  // ── Unified financial computation (FIX G-1) ──────────────────────────────

  /// **Single source of truth** for all GST / discount / total math.
  ///
  /// Both [toMap] (Firestore persistence) and the create-invoice screen's live
  /// preview MUST call this method so the numbers are always identical.
  ///
  /// The method accepts raw inputs rather than reading from `this` so that the
  /// create-screen can pass uncommitted form values without constructing a
  /// throw-away Invoice.
  static FinancialSummary computeFinancials({
    required List<LineItem> items,
    required InvoiceDiscountType? discountType,
    required double discountValue,
    required bool gstEnabled,
    required String gstType,
    required double amountReceived,
  }) {
    final sub = _roundCurrency(
      items.fold(0.0, (acc, item) => acc + item.total),
    );
    final disc = _computeDiscountStatic(sub, discountType, discountValue);
    // Do NOT round — Firestore rules check: taxableAmount == subtotal - discountAmount
    final taxable = sub - disc;
    final discRatio = sub > 0 ? taxable / sub : 0.0;

    double cgst = 0, sgst = 0, igst = 0;
    if (gstEnabled) {
      for (final item in items) {
        final itemTaxable = item.total * discRatio;
        if (gstType == 'cgst_sgst') {
          cgst += itemTaxable * item.gstRate / 200;
        } else {
          igst += itemTaxable * item.gstRate / 100;
        }
      }
      cgst = _roundCurrency(cgst);
      sgst = cgst; // SGST always equals CGST for intra-state
      igst = _roundCurrency(igst);
    }

    // Derive totalTax and grandTotal as EXACT sums of already-rounded parts.
    // Do NOT re-round — Firestore rules check exact equality.
    final tax = cgst + sgst + igst;
    final grand = taxable + tax;

    return FinancialSummary(
      subtotal: sub,
      discountAmount: disc,
      taxableAmount: taxable,
      cgstAmount: cgst,
      sgstAmount: sgst,
      igstAmount: igst,
      totalTax: tax,
      grandTotal: grand,
      hasGst: gstEnabled && tax > 0,
      balanceDue: _roundCurrency(grand - amountReceived),
    );
  }

  /// Convenience wrapper that reads inputs from `this` invoice instance.
  FinancialSummary get financials => computeFinancials(
        items: items,
        discountType: discountType,
        discountValue: discountValue,
        gstEnabled: gstEnabled,
        gstType: gstType,
        amountReceived: amountReceived,
      );

  factory Invoice.fromMap(Map<String, dynamic> map, {String? docId}) {
    final rawItems = map['items'] as List<dynamic>? ?? const [];
    final orderGstRate = _doubleFromMapValue(map['gstRate']) > 0
        ? _doubleFromMapValue(map['gstRate'])
        : 18.0;
    final orderGstEnabled = map['gstEnabled'] as bool? ?? false;
    final schemaVersion = map['schemaVersion'] as int? ?? 1;
    var parsedItems = rawItems
        .map(
          (item) => LineItem.fromMap(Map<String, dynamic>.from(item as Map)),
        )
        .toList();

    // FIX G-3: Only backfill items with order-level GST rate for schema v1
    // (before per-item rates existed). Schema v2+ may legitimately have
    // items at 0% (exempt goods), so backfilling would be incorrect.
    if (schemaVersion < 2 &&
        orderGstEnabled &&
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
      paymentMethod: map['paymentMethod'] as String? ?? '',
      notes: map['notes'] as String?,
      createdByUid: map['createdByUid'] as String? ?? '',
      createdByName: map['createdByName'] as String? ?? '',
      createdBySignatureUrl: map['createdBySignatureUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    // FIX G-1: Use the single computeFinancials() path so the numbers saved
    // to Firestore are byte-for-byte identical to what the create-screen shows.
    final f = financials;

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
      'subtotal': f.subtotal,
      'discountAmount': f.discountAmount,
      'taxableAmount': f.taxableAmount,
      'cgstAmount': f.cgstAmount,
      'sgstAmount': f.sgstAmount,
      'igstAmount': f.igstAmount,
      'totalTax': f.totalTax,
      'grandTotal': f.grandTotal,
      'hasGst': f.hasGst,
      'amountReceived': amountReceived,
      'balanceDue': f.balanceDue,
      if (paymentMethod.isNotEmpty) 'paymentMethod': paymentMethod,
      if (notes != null) 'notes': notes,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'createdBySignatureUrl': createdBySignatureUrl,
      'schemaVersion': currentSchemaVersion,
      // FIX G-4: Use the same isB2B logic (>= 15 chars) as the getter,
      // not the weaker isNotEmpty check that was here before.
      'gstTransactionType': gstTransactionType,
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

  /// Compute discount from subtotal — static so [computeFinancials] can use it.
  static double _computeDiscountStatic(
    double sub,
    InvoiceDiscountType? type,
    double value,
  ) {
    if (type == null || value <= 0) return 0;
    switch (type) {
      case InvoiceDiscountType.percentage:
        return _roundCurrency((sub * (value / 100)).clamp(0, sub));
      case InvoiceDiscountType.overall:
        return _roundCurrency(value.clamp(0, sub));
    }
  }

  // NOTE G-5 (future migration): IEEE 754 `double` can accumulate drift when
  // summing many items (up to 200). The current round-after-sum strategy is
  // sound for typical invoice sizes, but for future-proofing consider:
  //   1. Compute all amounts in **paisa** (integer cents): qty * priceInPaisa.
  //   2. Divide by 100 only at display/serialization time.
  //   3. Use `int` throughout to eliminate floating-point entirely.
  // This is a pure internal refactor — no UI or Firestore schema change needed.
  static double _roundCurrency(num value) {
    return (value * 100).roundToDouble() / 100;
  }
}
