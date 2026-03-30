import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'remote_config_service.dart';

class ReviewService {
  ReviewService._();
  static final ReviewService instance = ReviewService._();

  static const _kSessionCount = 'session_count';
  static const _kReviewRequested = 'review_requested';
  static const _kInvoiceCount = 'review_invoice_trigger';

  /// TEMPORARY: Reset the review flag so it can be triggered again.
  /// Call this once for testing, then remove.
  Future<void> resetForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kReviewRequested, false);
    await prefs.setInt(_kSessionCount, 0);
    await prefs.setInt(_kInvoiceCount, 0);
    debugPrint('[Review] Reset all review counters for testing');
  }

  Future<void> onAppOpen() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyRequested = prefs.getBool(_kReviewRequested) ?? false;
    if (alreadyRequested) return;

    final sessions = (prefs.getInt(_kSessionCount) ?? 0) + 1;
    await prefs.setInt(_kSessionCount, sessions);

    final threshold = RemoteConfigService.instance.reviewSessionThreshold;
    debugPrint('[Review] Session $sessions / threshold $threshold');
    if (sessions >= threshold) {
      await _requestReview(prefs);
    }
  }

  Future<void> onInvoiceCreated() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyRequested = prefs.getBool(_kReviewRequested) ?? false;
    if (alreadyRequested) return;

    final count = (prefs.getInt(_kInvoiceCount) ?? 0) + 1;
    await prefs.setInt(_kInvoiceCount, count);

    final threshold = RemoteConfigService.instance.reviewInvoiceThreshold;
    debugPrint('[Review] Invoices $count / threshold $threshold');
    if (count >= threshold) {
      await _requestReview(prefs);
    }
  }

  Future<void> _requestReview(SharedPreferences prefs) async {
    final review = InAppReview.instance;
    final available = await review.isAvailable();
    debugPrint('[Review] isAvailable: $available');
    if (available) {
      await review.requestReview();
      await prefs.setBool(_kReviewRequested, true);
    } else {
      debugPrint('[Review] Not available — debug build or not installed from Play Store');
    }
  }
}
