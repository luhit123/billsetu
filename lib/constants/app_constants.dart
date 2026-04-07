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
/// Default GST rate slabs per Indian GST Council.
/// These serve as fallback values. At runtime, prefer fetching from
/// Firebase Remote Config key `allowed_gst_rates` for OTA updates
/// without requiring an app release.
const kAllowedGstRates = <double>[0, 5, 12, 18, 28];

/// Default GST rate applied to new invoices when per-item rate is not set.
const kDefaultGstRate = 18.0;

/// Maximum allowed line items per invoice (must match firestore.rules).
const kMaxInvoiceLineItems = 200;

/// Maximum allowed search prefixes per invoice (must match firestore.rules).
const kMaxSearchPrefixes = 60;

// ── Pagination ──────────────────────────────────────────────────────────────
const kDefaultPageSize = 25;
