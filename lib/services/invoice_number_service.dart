import 'dart:async';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:billeasy/widgets/connectivity_banner.dart';

class InvoiceNumberService {
  InvoiceNumberService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  static const _timeout = Duration(seconds: 10);

  /// Returns true if this invoice number was generated locally (offline).
  /// Locally-generated numbers use a device-scoped offset that starts at
  /// 20000+, while server-assigned sequences start from 1.
  static bool isLocallyGenerated(String invoiceNumber) {
    final parts = invoiceNumber.split('-');
    if (parts.length == 3) {
      final seq = int.tryParse(parts[2]);
      if (seq != null) return seq >= _offlineRangeStart;
    }
    return false;
  }

  /// Offline numbers start from this value to avoid collisions with
  /// server-assigned sequential numbers (which start from 1).
  static const _offlineRangeStart = 20000;

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

  // ── Local fallback (device-scoped to prevent multi-device collisions) ───

  Future<String> _localInvoiceNumber(int year) async {
    final prefs = await SharedPreferences.getInstance();
    final deviceOffset = _getDeviceOffset(prefs);
    final key = 'offline_invoice_count_$year';
    final last = prefs.getInt(key) ?? 0;
    final next = last + 1;
    await prefs.setInt(key, next);
    // Combine device offset + local counter to form a unique sequence.
    // Device A (offset 0) → 20001, 20002, ...
    // Device B (offset 200) → 20201, 20202, ...
    final sequence = _offlineRangeStart + deviceOffset + next;
    return 'BR-$year-${sequence.toString().padLeft(5, '0')}';
  }

  /// Returns a stable device-specific offset (0–49800 in steps of 200).
  /// Generated once per install, persisted in SharedPreferences.
  /// Each device gets a 200-number "lane" to avoid collisions.
  static int _getDeviceOffset(SharedPreferences prefs) {
    const key = 'device_invoice_offset';
    final existing = prefs.getInt(key);
    if (existing != null) return existing;
    // Random offset: 0–249 * 200 = 0–49800
    final offset = Random().nextInt(250) * 200;
    prefs.setInt(key, offset);
    return offset;
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
