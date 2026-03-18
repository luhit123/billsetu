/// Normalizes a numeric string that may contain regional-script digits
/// (Devanagari / Hindi, Bengali / Assamese) or a mix of regional and ASCII
/// digits, then parses it as a double or int.
///
/// Supported scripts:
///   Devanagari  ०१२३४५६७८९  (U+0966–U+096F)  — Hindi
///   Bengali     ০১২৩৪৫৬৭৮৯  (U+09E6–U+09EF)  — Assamese & Bengali
library;

/// Converts any Devanagari or Bengali/Assamese digit characters in [input]
/// to their ASCII equivalents (0–9), strips leading/trailing whitespace, and
/// replaces a locale-style decimal comma with a period.
String normalizeDigits(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= 0x0966 && rune <= 0x096F) {
      // Devanagari digits ०–९
      buffer.write(rune - 0x0966);
    } else if (rune >= 0x09E6 && rune <= 0x09EF) {
      // Bengali/Assamese digits ০–৯
      buffer.write(rune - 0x09E6);
    } else if (rune == 0x066B || rune == 0x066C) {
      // Arabic decimal separator / thousands mark → period/nothing
      buffer.write('.');
    } else if (rune == 0x002C) {
      // ASCII comma — treat as decimal separator
      buffer.write('.');
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString().trim();
}

/// Parses [text] as a double, understanding regional-script digits.
/// Returns null if parsing fails.
double? parseDouble(String? text) {
  if (text == null || text.trim().isEmpty) return null;
  return double.tryParse(normalizeDigits(text));
}

/// Parses [text] as an int, understanding regional-script digits.
/// Returns null if parsing fails.
int? parseInt(String? text) {
  if (text == null || text.trim().isEmpty) return null;
  // Allow "3.0" → 3 by truncating after decimal normalisation
  final normalized = normalizeDigits(text);
  return int.tryParse(normalized) ??
      double.tryParse(normalized)?.truncate();
}
