import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:billeasy/widgets/connectivity_banner.dart';

/// Fetches a Firestore document with offline resilience.
///
/// If the device is offline, reads directly from cache.
/// If online, tries the server with a short timeout, falling back to cache.
Future<DocumentSnapshot<Map<String, dynamic>>> resilientGet(
  DocumentReference<Map<String, dynamic>> ref, {
  Duration timeout = const Duration(seconds: 4),
}) async {
  if (ConnectivityService.instance.isOffline) {
    return ref.get(const GetOptions(source: Source.cache));
  }
  try {
    return await ref.get().timeout(timeout);
  } catch (_) {
    return ref.get(const GetOptions(source: Source.cache));
  }
}
