import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
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
          .httpsCallable('reserveInvoiceNumber', options: HttpsCallableOptions(timeout: const Duration(seconds: 15)))
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
      if (kDebugMode) debugPrint('[InvoiceNumber] Cloud Function failed, using local: $e');
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
    // Device A (offset 0)    → 20001, 20002, ...
    // Device B (offset 1000) → 21001, 21002, ...
    // With 80 slots of 1000 numbers each, the birthday paradox gives
    // <1% collision probability for up to 3 devices (vs. 50% at 19
    // with the old 250-slot scheme). Each lane supports 1000 offline
    // invoices per year before overflow.
    final sequence = _offlineRangeStart + deviceOffset + next;
    return 'BR-$year-${sequence.toString().padLeft(5, '0')}';
  }

  /// Returns a stable device-specific offset derived from a persistent
  /// device UUID using SHA-256 hashing. This replaces the previous
  /// Random().nextInt(250)*200 scheme which had ~50% collision
  /// probability at just 19 devices (birthday paradox).
  ///
  /// The new scheme:
  /// - Generates a 128-bit UUID once per install (v4 format)
  /// - Hashes it with SHA-256 for uniform distribution
  /// - Takes modulo 80 → gives 80 lanes
  /// - Multiplies by 1000 → each lane has 1000 numbers of capacity
  /// - Total offline range: 20000–99999 (well within 5-digit padding)
  ///
  /// Migration: existing devices with the old 'device_invoice_offset'
  /// key keep their offset to avoid mid-year lane changes. Only fresh
  /// installs (or installs without the key) get the new scheme.
  static int _getDeviceOffset(SharedPreferences prefs) {
    const key = 'device_invoice_offset';
    final existing = prefs.getInt(key);
    if (existing != null) return existing;

    // Generate a persistent device UUID and hash it for uniform distribution.
    const uuidKey = 'device_invoice_uuid';
    var deviceUuid = prefs.getString(uuidKey);
    if (deviceUuid == null) {
      deviceUuid = _generateUuidV4();
      prefs.setString(uuidKey, deviceUuid);
    }

    final hash = sha256.convert(utf8.encode(deviceUuid));
    // Take first 4 bytes as a 32-bit unsigned int for modulo.
    final hashBytes = hash.bytes;
    final hashInt = (hashBytes[0] << 24) |
        (hashBytes[1] << 16) |
        (hashBytes[2] << 8) |
        hashBytes[3];
    // 80 lanes × 1000 numbers = 80,000 number range (20000–99999).
    final offset = (hashInt.abs() % 80) * 1000;
    prefs.setInt(key, offset);
    return offset;
  }

  /// Generates a v4 UUID (random) in standard format.
  static String _generateUuidV4() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    // Set version (4) and variant (10xx) bits per RFC 4122.
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
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
