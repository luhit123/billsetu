import 'package:flutter/material.dart';

// ── Gradient (matches onboarding page 1: navy → deep blue → teal) ─────────────
const kGradientColors = [
  Color(0xFF1E3A8A), // Deep navy
  Color(0xFF4361EE), // Deep blue
  Color(0xFF6366F1), // Teal
];

const kGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: kGradientColors,
);

// ── Primary ───────────────────────────────────────────────────────────────────
const kPrimary = Color(0xFF4361EE);   // Deep blue (mid-gradient)
const kTeal    = Color(0xFF6366F1);   // Teal (end of gradient)
const kNavy    = Color(0xFF1E3A8A);   // Deep navy (start of gradient)

// ── Backgrounds ───────────────────────────────────────────────────────────────
const kBackground = Color(0xFFEFF6FF); // Very light blue
const kCardBg     = Colors.white;

// ── Text ──────────────────────────────────────────────────────────────────────
const kTextPrimary   = Color(0xFF1E3A8A); // Deep navy
const kTextSecondary = Color(0xFF5B7A9A); // Blue-gray

// ── Borders ───────────────────────────────────────────────────────────────────
const kBorder = Color(0xFFBDD5F0); // Blue-tinted border

// ── Status colours (unchanged — semantic) ─────────────────────────────────────
const kPaid       = Color(0xFF22C55E);
const kPaidBg     = Color(0xFFDCFCE7);
const kPending    = Color(0xFFF59E0B);
const kPendingBg  = Color(0xFFFEF3C7);
const kOverdue    = Color(0xFFEF4444);
const kOverdueBg  = Color(0xFFFEE2E2);

// ── Gradient AppBar builder ───────────────────────────────────────────────────
/// Returns an AppBar with the onboarding gradient as background.
/// Use this in every screen to get visual consistency.
PreferredSizeWidget kBuildGradientAppBar({
  Widget? title,
  String? titleText,
  List<Widget>? actions,
  Widget? leading,
  bool automaticallyImplyLeading = true,
  double scrolledUnderElevation = 2,
  PreferredSizeWidget? bottom,
}) {
  return AppBar(
    backgroundColor: Colors.transparent,
    foregroundColor: Colors.white,
    elevation: 0,
    scrolledUnderElevation: scrolledUnderElevation,
    shadowColor: Colors.black26,
    surfaceTintColor: Colors.transparent,
    automaticallyImplyLeading: automaticallyImplyLeading,
    leading: leading,
    title: title ??
        (titleText != null
            ? Text(
                titleText,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              )
            : null),
    actions: actions,
    bottom: bottom,
    iconTheme: const IconThemeData(color: Colors.white),
    actionsIconTheme: const IconThemeData(color: Colors.white),
    flexibleSpace: Container(
      decoration: const BoxDecoration(gradient: kGradient),
    ),
  );
}
