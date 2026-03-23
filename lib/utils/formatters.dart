/// Centralised formatters for currency and dates used across screens.
library;

import 'package:intl/intl.dart';

// ── Currency ────────────────────────────────────────────────────────────────
final kCurrencyFormat = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '\u20B9',
  decimalDigits: 0,
);

/// GST report variant that uses "Rs. " prefix.
final kRsCurrencyFormat = NumberFormat.currency(
  locale: 'en_IN',
  symbol: 'Rs. ',
  decimalDigits: 0,
);

// ── Dates ───────────────────────────────────────────────────────────────────
final kDateFormat = DateFormat('dd MMM yyyy');
final kMonthYearFormat = DateFormat('MMMM yyyy');
final kDateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');
