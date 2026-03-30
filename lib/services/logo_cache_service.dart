import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's business logo as base64 in SharedPreferences.
/// Caches in memory after first load — no repeated disk reads.
/// Mirrors SignatureService pattern for offline-first logo access.
class LogoCacheService {
  static const _key = 'user_logo_png';
  static Uint8List? _cached;
  static bool _loaded = false;

  static Future<void> save(Uint8List pngBytes) async {
    _cached = pngBytes;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, base64Encode(pngBytes));
  }

  static Future<Uint8List?> load() async {
    if (_loaded) return _cached;
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_key);
    _loaded = true;
    if (encoded == null || encoded.isEmpty) return null;
    try {
      _cached = base64Decode(encoded);
      return _cached;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    _cached = null;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
