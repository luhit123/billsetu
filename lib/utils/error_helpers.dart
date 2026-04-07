import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Returns a user-friendly error message from any exception.
///
/// - Network errors → "Please check your internet connection and try again."
/// - Cloud Function known codes → the function's message (already user-facing)
/// - Everything else → the provided [fallback] or a generic message.
///
/// Raw exception details are never exposed to users — they are logged via
/// [debugPrint] for developer debugging only.
String userFriendlyError(Object error, {String? fallback}) {
  // Always log the raw error for debugging
  debugPrint('[Error] $error');

  // Network / connectivity errors
  if (_isNetworkError(error)) {
    return 'Unable to connect. Please check your internet connection and try again.';
  }

  // Firebase Cloud Function errors — some have user-facing messages
  if (error is FirebaseFunctionsException) {
    // These codes have user-readable messages from our Cloud Functions
    const userFacingCodes = {
      'invalid-argument',
      'not-found',
      'already-exists',
      'permission-denied',
      'resource-exhausted',
      'failed-precondition',
    };
    if (userFacingCodes.contains(error.code) &&
        error.message != null &&
        error.message!.isNotEmpty) {
      return error.message!;
    }
    // Server / internal errors — don't expose details
    return fallback ?? 'Something went wrong. Please try again.';
  }

  return fallback ?? 'Something went wrong. Please try again.';
}

bool _isNetworkError(Object error) {
  final msg = error.toString().toLowerCase();
  if (error is SocketException) return true;
  if (msg.contains('socketexception')) return true;
  if (msg.contains('host unreachable')) return true;
  if (msg.contains('network is unreachable')) return true;
  if (msg.contains('connection failed')) return true;
  if (msg.contains('connection refused')) return true;
  if (msg.contains('no address associated')) return true;
  if (msg.contains('failed host lookup')) return true;
  if (msg.contains('unavailable')) return true;
  if (msg.contains('clientexception')) return true;
  if (msg.contains('handshake')) return true;
  return false;
}
