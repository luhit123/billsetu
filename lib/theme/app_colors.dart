import 'package:flutter/material.dart';
// ignore_for_file: non_constant_identifier_names

// ═══════════════════════════════════════════════════════════════════════════════
// Design System: "Metric Clarity"
// Swiss minimalism · Tonal layering · No-border philosophy
// ═══════════════════════════════════════════════════════════════════════════════

// ── Primary (Royal Blue — the ONLY accent) ───────────────────────────────────
const kPrimary          = Color(0xFF0057FF);
const kPrimaryDark      = Color(0xFF004CE1); // Gradient end / pressed state
const kPrimaryContainer = Color(0xFFDCE1FF); // Selected rows / active states
const kOnPrimary        = Colors.white;

// ── Signature Gradient (for primary CTAs & hero states) ──────────────────────
const kSignatureGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [kPrimary, kPrimaryDark],
);

// ── Surfaces (tonal layering — no borders) ───────────────────────────────────
const kSurface              = Color(0xFFF9FAFB); // Base desk (Neutral)
const kSurfaceContainerLow  = Color(0xFFF1F4F6); // Section blocks
const kSurfaceContainer     = Color(0xFFEAEFF1); // Deeper nesting
const kSurfaceContainerHigh = Color(0xFFDDE3E6); // Utility buttons
const kSurfaceLowest        = Color(0xFFFFFFFF); // Interactive cards
const kSurfaceDim           = Color(0xFFE3E7EA); // Disabled states

// ── Text (never use #000000) ────────────────────────────────────────────────
const kOnSurface        = Color(0xFF2B3437); // Primary text
const kOnSurfaceVariant = Color(0xFF586064); // Labels, metadata
const kTextTertiary     = Color(0xFF98A2B3); // Hints, placeholders
const kTextSecondary    = Color(0xFF475467); // Secondary body text

// ── Outline (ghost borders only — 20% opacity when required) ─────────────────
const kOutlineVariant = Color(0xFFABB3B7);

// ── Status (semantic only — the sole exception to single-accent rule) ────────
const kPaid       = Color(0xFF22C55E);
const kPaidBg     = Color(0xFFDCFCE7);
const kPending    = Color(0xFFF59E0B);
const kPendingBg  = Color(0xFFFEF3C7);
const kOverdue    = Color(0xFFEF4444);
const kOverdueBg  = Color(0xFFFEE2E2);
// New: Unpaid (red) & Partial (amber) for payment-derived status
const kUnpaid     = Color(0xFFEF4444);
const kUnpaidBg   = Color(0xFFFEE2E2);
const kPartial    = Color(0xFFEAB308);
const kPartialBg  = Color(0xFFFEF3C7);
const kError      = Color(0xFF9E3F4E);
const kErrorContainer = Color(0xFFFF8B9A);

// ── Purchase-order status colours ───────────────────────────────────────────
const kDraft       = Color(0xFF6B7280);
const kDraftBg     = Color(0xFFF3F4F6);
const kConfirmed   = Color(0xFFF59E0B);
const kConfirmedBg = Color(0xFFFEF3C7);
const kReceived    = Color(0xFF22C55E);
const kReceivedBg  = Color(0xFFDCFCE7);
const kCancelled   = Color(0xFFEF4444);
const kCancelledBg = Color(0xFFFEE2E2);

// ── Shadows (whisper shadow — inverse_surface at 4%) ────────────────────────
const kWhisperShadow = BoxShadow(
  color: Color(0x0A0C0F10),
  blurRadius: 20,
  offset: Offset(0, 10),
);

const kSubtleShadow = BoxShadow(
  color: Color(0x060C0F10),
  blurRadius: 8,
  offset: Offset(0, 4),
);

const kCardShadow = Color(0x0E0F4A75);

// ── Reusable card decoration ────────────────────────────────────────────────
BoxDecoration kCardDecoration({bool error = false}) => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: error ? kOverdue : kBorder,
        width: error ? 1.5 : 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: error ? const Color(0x10EF4444) : kCardShadow,
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    );

// ── Legacy aliases (for backward compat during migration) ────────────────────
const kNavy       = kOnSurface;
const kTeal       = kPrimary;
const kBackground = kSurface;
const kCardBg     = kSurfaceLowest;
const kBorder     = kOutlineVariant;
const kTextPrimary = kOnSurface;
const kGradientColors = [kPrimary, kPrimaryDark];
const kGradient = kSignatureGradient;

// ── Context-aware color accessors ────────────────────────────────────────────
// Use these in build() methods instead of the compile-time k* constants so
// widgets correctly re-color when the user switches between light and dark.
//
// Usage:  final cs = context.cs;
//         Container(color: cs.surfaceContainerLowest)
extension AppColorsX on BuildContext {
  ColorScheme get cs => Theme.of(this).colorScheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

// ── BillRaja logo widget ─────────────────────────────────────────────────────
Widget kBillRajaLogo({double fontSize = 20}) {
  return Text(
    'BillRaja',
    style: TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: fontSize,
      letterSpacing: -0.4,
    ),
  );
}

// ── App Bar builder (tonal, no borders) ──────────────────────────────────────
PreferredSizeWidget kBuildGradientAppBar({
  Widget? title,
  String? titleText,
  List<Widget>? actions,
  Widget? leading,
  bool automaticallyImplyLeading = true,
  double scrolledUnderElevation = 0,
  PreferredSizeWidget? bottom,
}) {
  return AppBar(
    elevation: 0,
    scrolledUnderElevation: scrolledUnderElevation,
    surfaceTintColor: Colors.transparent,
    automaticallyImplyLeading: automaticallyImplyLeading,
    leading: leading,
    title: title ??
        (titleText != null
            ? Text(
                titleText,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              )
            : kBillRajaLogo()),
    actions: actions,
    bottom: bottom,
  );
}
