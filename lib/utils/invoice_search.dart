const int _kMaxSearchPrefixLength = 20;
const int _kMaxStoredSearchPrefixes = 60;

String normalizeInvoiceSearchQuery(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

List<String> buildInvoiceSearchPrefixes({
  required String clientName,
  required String invoiceNumber,
}) {
  final prefixes = <String>{};

  void addSource(String rawValue) {
    final normalized = normalizeInvoiceSearchQuery(rawValue);
    if (normalized.isEmpty) {
      return;
    }

    _addPrefixes(prefixes, normalized);

    for (final token in normalized.split(RegExp(r'[^a-z0-9]+'))) {
      if (token.isEmpty) {
        continue;
      }

      _addPrefixes(prefixes, token);
    }
  }

  addSource(clientName);
  addSource(invoiceNumber);

  final sorted = prefixes.toList(growable: false)..sort();
  if (sorted.length <= _kMaxStoredSearchPrefixes) {
    return sorted;
  }

  return sorted.sublist(0, _kMaxStoredSearchPrefixes);
}

void _addPrefixes(Set<String> prefixes, String normalizedValue) {
  final maxLength = normalizedValue.length < _kMaxSearchPrefixLength
      ? normalizedValue.length
      : _kMaxSearchPrefixLength;

  for (var i = 1; i <= maxLength; i++) {
    prefixes.add(normalizedValue.substring(0, i));
  }
}
