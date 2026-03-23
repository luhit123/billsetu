import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:billeasy/widgets/connectivity_banner.dart';

class InvoiceNumberService {
  InvoiceNumberService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  static const _timeout = Duration(seconds: 5);

  Future<String> reserveNextInvoiceNumber({int? year}) async {
    final resolvedYear = year ?? DateTime.now().year;

    // Skip Cloud Function entirely when offline.
    if (ConnectivityService.instance.isOffline) {
      return _localInvoiceNumber(resolvedYear);
    }

    // Try Cloud Function with a short timeout.
    try {
      final payload = <String, dynamic>{'year': resolvedYear};
      final result = await _functions
          .httpsCallable('reserveInvoiceNumber')
          .call(payload)
          .timeout(_timeout);

      final data = result.data;
      if (data is Map && data['invoiceNumber'] is String) {
        final invoiceNumber = (data['invoiceNumber'] as String).trim();
        if (invoiceNumber.isNotEmpty) {
          await _cacheSequence(invoiceNumber, resolvedYear);
          return invoiceNumber;
        }
      }
      throw StateError('Invalid response from reserveInvoiceNumber.');
    } catch (e) {
      debugPrint('[InvoiceNumber] Cloud Function failed, using local: $e');
      return _localInvoiceNumber(resolvedYear);
    }
  }

  // ── Local fallback ──────────────────────────────────────────────────────

  Future<String> _localInvoiceNumber(int year) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'last_invoice_seq_$year';
    final last = prefs.getInt(key) ?? 0;
    final next = last + 1;
    await prefs.setInt(key, next);
    return 'BR-$year-${next.toString().padLeft(5, '0')}';
  }

  /// Parses sequence from a successful server response (e.g. BR-2026-00042 → 42)
  /// and caches it so the local counter stays in sync.
  Future<void> _cacheSequence(String invoiceNumber, int year) async {
    final parts = invoiceNumber.split('-');
    if (parts.length == 3) {
      final seq = int.tryParse(parts[2]);
      if (seq != null) {
        final prefs = await SharedPreferences.getInstance();
        final key = 'last_invoice_seq_$year';
        final current = prefs.getInt(key) ?? 0;
        // Only update if server sequence is ahead.
        if (seq > current) {
          await prefs.setInt(key, seq);
        }
      }
    }
  }
}
