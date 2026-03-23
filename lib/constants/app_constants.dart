/// Centralised application constants shared across the codebase.
library;

// ── Item / product unit options ─────────────────────────────────────────────
const kItemUnits = <String>[
  'pcs', 'kg', 'g', 'ltr', 'ml',
  'box', 'pack', 'dozen', 'meter',
];

const kDefaultItemUnit = 'pcs';

// ── Payment terms ───────────────────────────────────────────────────────────
const kDefaultPaymentTerm = Duration(days: 14);

// ── GST ─────────────────────────────────────────────────────────────────────
const kAllowedGstRates = <double>[0, 5, 12, 18, 28];

// ── Pagination ──────────────────────────────────────────────────────────────
const kDefaultPageSize = 25;
