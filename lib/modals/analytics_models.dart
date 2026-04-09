import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardAnalytics {
  const DashboardAnalytics({
    required this.totalInvoices,
    required this.paidInvoices,
    required this.pendingInvoices,
    required this.overdueInvoices,
    required this.totalBilled,
    required this.totalCollected,
    required this.totalOutstanding,
    required this.totalDiscounts,
    required this.totalTaxableAmount,
    required this.totalCgst,
    required this.totalSgst,
    required this.totalIgst,
    required this.totalTax,
    required this.gstInvoices,
    this.updatedAt,
  });

  final int totalInvoices;
  final int paidInvoices;
  final int pendingInvoices;
  final int overdueInvoices;
  final double totalBilled;
  final double totalCollected;
  final double totalOutstanding;
  final double totalDiscounts;
  final double totalTaxableAmount;
  final double totalCgst;
  final double totalSgst;
  final double totalIgst;
  final double totalTax;
  final int gstInvoices;
  final DateTime? updatedAt;

  factory DashboardAnalytics.fromMap(Map<String, dynamic> map) {
    return DashboardAnalytics(
      totalInvoices: _intFromMapValue(map['totalInvoices']),
      paidInvoices: _intFromMapValue(map['paidInvoices']),
      pendingInvoices: _intFromMapValue(map['pendingInvoices']),
      overdueInvoices: _intFromMapValue(map['overdueInvoices']),
      totalBilled: _doubleFromMapValue(map['totalBilled']),
      totalCollected: _doubleFromMapValue(map['totalCollected']),
      totalOutstanding: _doubleFromMapValue(map['totalOutstanding']),
      totalDiscounts: _doubleFromMapValue(map['totalDiscounts']),
      totalTaxableAmount: _doubleFromMapValue(map['totalTaxableAmount']),
      totalCgst: _doubleFromMapValue(map['totalCgst']),
      totalSgst: _doubleFromMapValue(map['totalSgst']),
      totalIgst: _doubleFromMapValue(map['totalIgst']),
      totalTax: _doubleFromMapValue(map['totalTax']),
      gstInvoices: _intFromMapValue(map['gstInvoices']),
      updatedAt: _dateTimeFromMapValue(map['updatedAt']),
    );
  }
}

class GstPeriodSummary {
  const GstPeriodSummary({
    required this.periodType,
    required this.periodKey,
    required this.invoiceCount,
    required this.taxableAmount,
    required this.discountAmount,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.igstAmount,
    required this.totalTax,
    required this.grandTotal,
    this.inputPoCount = 0,
    this.inputTaxableAmount = 0,
    this.inputDiscountAmount = 0,
    this.inputCgstAmount = 0,
    this.inputSgstAmount = 0,
    this.inputIgstAmount = 0,
    this.inputTotalTax = 0,
    this.inputGrandTotal = 0,
    this.intraTaxableAmount = 0,
    this.interTaxableAmount = 0,
    this.intraCgst = 0,
    this.intraSgst = 0,
    this.interIgst = 0,
    this.updatedAt,
  });

  final String periodType;
  final String periodKey;
  final int invoiceCount;
  final double taxableAmount;
  final double discountAmount;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double totalTax;
  final double grandTotal;
  final int inputPoCount;
  final double inputTaxableAmount;
  final double inputDiscountAmount;
  final double inputCgstAmount;
  final double inputSgstAmount;
  final double inputIgstAmount;
  final double inputTotalTax;
  final double inputGrandTotal;
  // GSTR-3B intra/inter breakdown (server-aggregated)
  final double intraTaxableAmount;
  final double interTaxableAmount;
  final double intraCgst;
  final double intraSgst;
  final double interIgst;
  final DateTime? updatedAt;

  double get outputTax => totalTax;
  double get netGstPayable => totalTax - inputTotalTax;

  factory GstPeriodSummary.fromMap(Map<String, dynamic> map) {
    return GstPeriodSummary(
      periodType: map['periodType'] as String? ?? '',
      periodKey: map['periodKey'] as String? ?? '',
      invoiceCount: _intFromMapValue(map['invoiceCount']),
      taxableAmount: _doubleFromMapValue(map['taxableAmount']),
      discountAmount: _doubleFromMapValue(map['discountAmount']),
      cgstAmount: _doubleFromMapValue(map['cgstAmount']),
      sgstAmount: _doubleFromMapValue(map['sgstAmount']),
      igstAmount: _doubleFromMapValue(map['igstAmount']),
      totalTax: _doubleFromMapValue(map['totalTax']),
      grandTotal: _doubleFromMapValue(map['grandTotal']),
      inputPoCount: _intFromMapValue(map['inputPoCount']),
      inputTaxableAmount: _doubleFromMapValue(map['inputTaxableAmount']),
      inputDiscountAmount: _doubleFromMapValue(map['inputDiscountAmount']),
      inputCgstAmount: _doubleFromMapValue(map['inputCgstAmount']),
      inputSgstAmount: _doubleFromMapValue(map['inputSgstAmount']),
      inputIgstAmount: _doubleFromMapValue(map['inputIgstAmount']),
      inputTotalTax: _doubleFromMapValue(map['inputTotalTax']),
      inputGrandTotal: _doubleFromMapValue(map['inputGrandTotal']),
      intraTaxableAmount: _doubleFromMapValue(map['intraTaxableAmount']),
      interTaxableAmount: _doubleFromMapValue(map['interTaxableAmount']),
      intraCgst: _doubleFromMapValue(map['intraCgst']),
      intraSgst: _doubleFromMapValue(map['intraSgst']),
      interIgst: _doubleFromMapValue(map['interIgst']),
      updatedAt: _dateTimeFromMapValue(map['updatedAt']),
    );
  }
}

int _intFromMapValue(Object? value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  if (value is String) {
    return int.tryParse(value) ?? 0;
  }

  return 0;
}

double _doubleFromMapValue(Object? value) {
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
    return double.tryParse(value) ?? 0;
  }

  return 0;
}

DateTime? _dateTimeFromMapValue(Object? value) {
  if (value is Timestamp) {
    return value.toDate();
  }

  if (value is DateTime) {
    return value;
  }

  if (value is String) {
    return DateTime.tryParse(value);
  }

  return null;
}
