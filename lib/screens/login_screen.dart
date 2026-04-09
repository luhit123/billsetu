import 'dart:async';

import 'package:billeasy/l10n/app_strings.dart';
import 'package:billeasy/screens/privacy_policy_screen.dart';
import 'package:billeasy/screens/terms_conditions_screen.dart';
import 'package:billeasy/services/auth_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:billeasy/utils/responsive.dart';
import 'package:billeasy/utils/public_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sms_autofill/sms_autofill.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with CodeAutoFill {
  final AuthService _authService = AuthService();

  // ── Phone auth state ────────────────────────────────────────────────────────
  final TextEditingController _phoneController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  bool _otpSent = false;
  String? _verificationId;

  // ── Resend timer ────────────────────────────────────────────────────────────
  Timer? _resendTimer;
  int _resendSeconds = 0;

  // ── Google sign-in state ────────────────────────────────────────────────────
  bool _isSigningInGoogle = false;

  bool _hintShown = false;

  Future<void> _requestPhoneHint() async {
    try {
      final hint = await SmsAutoFill().hint;
      if (hint != null && hint.isNotEmpty && mounted) {
        // Extract last 10 digits (remove country code like +91)
        final digits = hint.replaceAll(RegExp(r'[^0-9]'), '');
        final phone = digits.length > 10
            ? digits.substring(digits.length - 10)
            : digits;
        if (phone.length == 10) {
          _phoneController.text = phone;
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('[Login] Phone hint error: $e');
    }
  }

  @override
  void codeUpdated() {
    // Called by CodeAutoFill (sms_autofill) when an OTP is detected from SMS
    final smsCode = code ?? '';
    if (smsCode.isNotEmpty && mounted) {
      _distributeOtp(smsCode);
    }
  }

  @override
  void dispose() {
    cancel(); // Stop SMS listener from CodeAutoFill
    unregisterListener();
    _phoneController.dispose();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final n in _otpFocusNodes) {
      n.dispose();
    }
    _resendTimer?.cancel();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String get _fullPhoneNumber => '+91${_phoneController.text.trim()}';

  bool get _isPhoneValid => _phoneController.text.trim().length == 10;

  String get _otpCode => _otpControllers.map((c) => c.text).join();

  void _startResendTimer() {
    _resendSeconds = 30;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendSeconds--;
        if (_resendSeconds <= 0) {
          timer.cancel();
        }
      });
    });
  }

  void _clearOtpFields() {
    for (final c in _otpControllers) {
      c.clear();
    }
  }

  /// Distributes a 6-digit code across the individual OTP boxes and
  /// auto-submits when all 6 digits are filled.
  void _distributeOtp(String rawCode) {
    final digits = rawCode.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    for (int i = 0; i < 6; i++) {
      _otpControllers[i].text = i < digits.length ? digits[i] : '';
    }
    setState(() {});
    if (digits.length >= 6) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) _handleVerifyOtp();
      });
    } else {
      _otpFocusNodes[digits.length].requestFocus();
    }
  }

  // ── Phone auth actions ──────────────────────────────────────────────────────

  Future<void> _handleSendOtp() async {
    if (!_isPhoneValid) return;
    FocusScope.of(context).unfocus();

    // Log app signature so you can verify it matches Firebase Console.
    // Remove this after confirming OTP auto-fill works.
    if (!kIsWeb) {
      final sig = await SmsAutoFill().getAppSignature;
      debugPrint('[Login] SMS Retriever app signature: $sig');
    }

    setState(() => _isSendingOtp = true);

    try {
      await _authService.sendOtp(
        _fullPhoneNumber,
        onCodeSent: (verificationId) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _otpSent = true;
            _isSendingOtp = false;
          });
          _startResendTimer();
          // Start listening for SMS auto-detection (Android only)
          if (!kIsWeb) {
            listenForCode();
          }
          // Focus the first OTP field after frame renders.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _otpFocusNodes[0].requestFocus();
          });
        },
        onError: (error) {
          if (!mounted) return;
          setState(() => _isSendingOtp = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error)));
        },
        onAutoVerified: (credential) async {
          if (!mounted) return;
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
          } catch (e) {
            debugPrint('[LoginScreen] Auto-verify sign-in error: $e');
          }
        },
      );
    } catch (e) {
      debugPrint('[LoginScreen] sendOtp threw: $e');
      if (mounted) {
        setState(() => _isSendingOtp = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send OTP. Please try again.')),
        );
      }
    }
  }

  Future<void> _handleVerifyOtp() async {
    final code = _otpCode;
    if (code.length != 6 || _verificationId == null) return;
    FocusScope.of(context).unfocus();

    setState(() => _isVerifyingOtp = true);

    try {
      final user = await _authService.verifyOtp(_verificationId!, code);
      if (!mounted) return;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification failed. Please try again.'),
          ),
        );
      }
      // Auth state listener in main.dart handles navigation.
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message;
      switch (e.code) {
        case 'invalid-verification-code':
        case 'session-expired':
          message = 'Invalid or expired OTP. Please try again.';
          break;
        default:
          message = 'Verification failed. Please try again.';
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      _clearOtpFields();
      setState(() {});
      _otpFocusNodes[0].requestFocus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification failed. Please try again.')),
      );
      _clearOtpFields();
      setState(() {});
      _otpFocusNodes[0].requestFocus();
    } finally {
      if (mounted) setState(() => _isVerifyingOtp = false);
    }
  }

  void _handleChangeNumber() {
    _resendTimer?.cancel();
    _clearOtpFields();
    setState(() {
      _otpSent = false;
      _verificationId = null;
      _resendSeconds = 0;
    });
  }

  Future<void> _handleResendOtp() async {
    if (_resendSeconds > 0) return;
    _clearOtpFields();
    await _handleSendOtp();
  }

  // ── Google sign-in ──────────────────────────────────────────────────────────

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isSigningInGoogle = true);

    try {
      final user = await _authService.signInWithGoogle();
      if (!mounted) return;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(context).loginCancelled)),
        );
      }
    } on FirebaseAuthException catch (error) {
      debugPrint(
        '[LoginScreen] FirebaseAuthException: ${error.code} — ${error.message}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AuthService.friendlyErrorMessage(
              error,
              fallback: 'Could not sign in with Google. Please try again.',
            ),
          ),
        ),
      );
    } catch (error, stack) {
      debugPrint('[LoginScreen] Exception: ${error.runtimeType} — $error');
      debugPrint('[LoginScreen] Stack: $stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AuthService.friendlyErrorMessage(
              error,
              fallback: 'Could not sign in with Google. Please try again.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSigningInGoogle = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final isDark = context.cs.brightness == Brightness.dark;
    final windowSize = windowSizeOf(context);
    final isWideWeb = kIsWeb && windowSize == WindowSize.expanded;
    final isMediumWeb = kIsWeb && windowSize == WindowSize.medium;
    final maxWidth = isWideWeb ? 1180.0 : (isMediumWeb ? 760.0 : 420.0);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackground(isDark),

          // ── Content ──────────────────────────────────────────────────
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isShortViewport = constraints.maxHeight < 780;
                final horizontalPadding = isWideWeb
                    ? 32.0
                    : (isMediumWeb ? 24.0 : 18.0);
                final verticalPadding = isWideWeb
                    ? 24.0
                    : (isShortViewport ? 12.0 : 16.0);
                final minContentHeight =
                    (constraints.maxHeight - (verticalPadding * 2))
                        .clamp(0.0, double.infinity)
                        .toDouble();

                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: verticalPadding,
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: maxWidth,
                        minHeight: minContentHeight,
                      ),
                      child: Center(
                        child: isWideWeb
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 28),
                                      child: _buildHeroPanel(
                                        context,
                                        s,
                                        isDark,
                                        compact: false,
                                        condensed: isShortViewport,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 430,
                                    child: _buildAuthPanel(
                                      context,
                                      s,
                                      isDark,
                                      compact: isShortViewport,
                                      showFooterTagline: !isShortViewport,
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isMediumWeb) ...[
                                    _buildHeroPanel(
                                      context,
                                      s,
                                      isDark,
                                      compact: true,
                                      wideCard: true,
                                      condensed: true,
                                    ),
                                    const SizedBox(height: 18),
                                  ] else ...[
                                    _buildCompactIntro(context, s, isDark),
                                    const SizedBox(height: 18),
                                  ],
                                  _buildAuthPanel(
                                    context,
                                    s,
                                    isDark,
                                    compact: true,
                                    showFooterTagline: false,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(bool isDark) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [
                      Color(0xFF060E18),
                      Color(0xFF0F1B32),
                      Color(0xFF13203A),
                    ]
                  : const [
                      Color(0xFFF8FBFF),
                      Color(0xFFF1F6FF),
                      Color(0xFFF8F2FF),
                    ],
            ),
          ),
        ),
        Positioned(
          top: -90,
          left: -50,
          child: _buildAuraBlob(
            size: 250,
            color: const Color(0xFF4CC9F0),
            opacity: isDark ? 0.18 : 0.22,
          ),
        ),
        Positioned(
          top: 80,
          right: -80,
          child: _buildAuraBlob(
            size: 320,
            color: kPrimary,
            opacity: isDark ? 0.16 : 0.18,
          ),
        ),
        Positioned(
          bottom: -100,
          left: 80,
          child: _buildAuraBlob(
            size: 340,
            color: const Color(0xFFFFC56B),
            opacity: isDark ? 0.08 : 0.12,
          ),
        ),
        IgnorePointer(
          child: CustomPaint(
            painter: _LoginGridPainter(
              lineColor: isDark
                  ? Colors.white.withAlpha(10)
                  : kPrimary.withAlpha(16),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }

  Widget _buildAuraBlob({
    required double size,
    required Color color,
    required double opacity,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildHeroPanel(
    BuildContext context,
    AppStrings s,
    bool isDark, {
    required bool compact,
    bool wideCard = false,
    bool condensed = false,
  }) {
    final titleSize = condensed
        ? (compact ? (wideCard ? 34.0 : 30.0) : 50.0)
        : (compact ? (wideCard ? 42.0 : 34.0) : 62.0);
    final bodyColor = isDark
        ? Colors.white.withAlpha(168)
        : context.cs.onSurfaceVariant;
    final panelPadding = condensed
        ? EdgeInsets.all(compact ? 20 : 28)
        : EdgeInsets.all(compact ? 24 : 34);
    final heroSpacing = condensed ? 16.0 : (compact ? 22.0 : 28.0);

    return Container(
      width: double.infinity,
      padding: panelPadding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 30 : 36),
        color: isDark
            ? Colors.white.withAlpha(10)
            : Colors.white.withAlpha(186),
        border: Border.all(
          color: isDark
              ? Colors.white.withAlpha(18)
              : Colors.white.withAlpha(160),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withAlpha(22) : kPrimary.withAlpha(14),
            blurRadius: compact ? 28 : 42,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBrandHeader(context, isDark, compact: compact),
          SizedBox(height: heroSpacing),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildHeroChip(
                context,
                icon: Icons.auto_awesome_rounded,
                label: s.loginBadgeLabel,
                isDark: isDark,
              ),
              _buildHeroChip(
                context,
                icon: Icons.bolt_rounded,
                label: condensed ? 'Faster daily ops' : 'Web-ready workspace',
                isDark: isDark,
              ),
            ],
          ),
          SizedBox(height: condensed ? 14 : (compact ? 20 : 24)),
          Text(
            'Modern billing for teams, collections, and daily operations.',
            style: TextStyle(
              color: isDark ? Colors.white : context.cs.onSurface,
              fontSize: titleSize,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.6,
              height: 0.98,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '${s.loginTagline} Move from invoices to team workflows, attendance, and member operations without switching systems.',
            style: TextStyle(
              color: bodyColor,
              fontSize: condensed ? 14 : (compact ? 15 : 18),
              height: condensed ? 1.45 : 1.55,
            ),
          ),
          SizedBox(height: condensed ? 16 : (compact ? 22 : 28)),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildFeaturePill(
                context,
                Icons.receipt_long_rounded,
                'GST invoicing',
                isDark,
              ),
              _buildFeaturePill(
                context,
                Icons.groups_rounded,
                'Team permissions',
                isDark,
              ),
              _buildFeaturePill(
                context,
                Icons.card_membership_rounded,
                'Membership ops',
                isDark,
              ),
              if (!condensed)
                _buildFeaturePill(
                  context,
                  Icons.pin_drop_rounded,
                  'Geo attendance',
                  isDark,
                ),
            ],
          ),
          if (condensed) ...[
            const SizedBox(height: 16),
            Text(
              'Invoices, payments, attendance, and member operations stay in one connected workspace.',
              style: TextStyle(color: bodyColor, fontSize: 13, height: 1.5),
            ),
          ] else ...[
            SizedBox(height: compact ? 22 : 30),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _buildInsightCard(
                  context,
                  title: 'Calm workspace',
                  subtitle:
                      'Fast billing, cleaner screens, less operational clutter',
                  icon: Icons.space_dashboard_rounded,
                  isDark: isDark,
                  compact: compact,
                ),
                _buildInsightCard(
                  context,
                  title: 'Built for scale',
                  subtitle:
                      'Payments, sharing, teams, and workflows in one stack',
                  icon: Icons.bolt_rounded,
                  isDark: isDark,
                  compact: compact,
                ),
              ],
            ),
            SizedBox(height: compact ? 22 : 30),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: isDark
                    ? Colors.white.withAlpha(10)
                    : kPrimary.withAlpha(8),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withAlpha(14)
                      : kPrimary.withAlpha(18),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: kSignatureGradient,
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Web entry, mobile depth',
                          style: TextStyle(
                            color: isDark ? Colors.white : context.cs.onSurface,
                            fontSize: compact ? 15 : 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Open BillRaja on a desktop for a cleaner command-center feel, then keep using the same workflows across mobile without losing continuity.',
                          style: TextStyle(
                            color: bodyColor,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactIntro(BuildContext context, AppStrings s, bool isDark) {
    final bodyColor = isDark
        ? Colors.white.withAlpha(165)
        : context.cs.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBrandHeader(context, isDark, compact: true),
        const SizedBox(height: 14),
        Text(
          'Login and get straight to billing, collections, and team work.',
          style: TextStyle(
            color: isDark ? Colors.white : context.cs.onSurface,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '${s.loginTagline} Sign in without digging through a long landing page.',
          style: TextStyle(color: bodyColor, fontSize: 14, height: 1.45),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildHeroChip(
              context,
              icon: Icons.auto_awesome_rounded,
              label: s.loginBadgeLabel,
              isDark: isDark,
            ),
            _buildFeaturePill(
              context,
              Icons.receipt_long_rounded,
              'GST invoicing',
              isDark,
            ),
            _buildFeaturePill(
              context,
              Icons.groups_rounded,
              'Team ops',
              isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBrandHeader(
    BuildContext context,
    bool isDark, {
    required bool compact,
  }) {
    return Row(
      children: [
        Container(
          width: compact ? 58 : 66,
          height: compact ? 58 : 66,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 18 : 22),
            boxShadow: [
              BoxShadow(
                color: kPrimary.withAlpha(isDark ? 80 : 60),
                blurRadius: compact ? 22 : 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(compact ? 18 : 22),
            child: Image.asset(
              'assets/icon/logo.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BillRaja',
                style: TextStyle(
                  color: isDark ? Colors.white : context.cs.onSurface,
                  fontSize: compact ? 30 : 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Billing workspace for Indian businesses',
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withAlpha(150)
                      : context.cs.onSurfaceVariant,
                  fontSize: compact ? 13 : 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withAlpha(10)
            : Colors.white.withAlpha(200),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark ? Colors.white.withAlpha(14) : kPrimary.withAlpha(18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isDark ? const Color(0xFF9FD1FF) : kPrimary,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isDark
                  ? Colors.white.withAlpha(210)
                  : context.cs.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDark,
    required bool compact,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: compact ? 0 : 240, maxWidth: 320),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: isDark
              ? Colors.white.withAlpha(10)
              : Colors.white.withAlpha(192),
          border: Border.all(
            color: isDark
                ? Colors.white.withAlpha(14)
                : Colors.white.withAlpha(170),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isDark
                    ? Colors.white.withAlpha(12)
                    : kPrimary.withAlpha(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: isDark ? Colors.white : kPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDark ? Colors.white : context.cs.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withAlpha(150)
                          : context.cs.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthPanel(
    BuildContext context,
    AppStrings s,
    bool isDark, {
    bool compact = false,
    bool showFooterTagline = true,
  }) {
    final cardPadding = compact ? 22.0 : 26.0;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(cardPadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            color: isDark
                ? Colors.white.withAlpha(10)
                : context.cs.surfaceContainerLowest,
            border: Border.all(
              color: isDark
                  ? Colors.white.withAlpha(16)
                  : context.cs.outlineVariant.withAlpha(44),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withAlpha(24)
                    : Colors.black.withAlpha(8),
                blurRadius: 34,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.loginWelcome,
                style: TextStyle(
                  color: isDark ? Colors.white : context.cs.onSurface,
                  fontSize: compact ? 24 : 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              SizedBox(height: compact ? 4 : 6),
              Text(
                s.loginSubtitle,
                style: TextStyle(
                  color: isDark
                      ? Colors.white.withAlpha(150)
                      : context.cs.onSurfaceVariant,
                  fontSize: compact ? 13 : 14,
                  height: 1.45,
                ),
              ),
              SizedBox(height: compact ? 20 : 24),
              if (!_otpSent)
                _buildPhoneInput(compact: compact)
              else
                _buildOtpView(compact: compact),
              SizedBox(height: compact ? 16 : 20),
              _buildDivider(compact: compact),
              SizedBox(height: compact ? 16 : 20),
              _GoogleSignInButton(
                isLoading: _isSigningInGoogle,
                onPressed: _isSigningInGoogle ? null : _handleGoogleSignIn,
                isSecondary: true,
                compact: compact,
              ),
            ],
          ),
        ),
        SizedBox(height: compact ? 14 : 18),
        _LegalConsentText(compact: compact),
        SizedBox(height: compact ? 10 : 12),
        _TrustLinksText(compact: compact),
        if (showFooterTagline) ...[
          SizedBox(height: compact ? 10 : 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.verified_rounded,
                size: 14,
                color: isDark ? const Color(0xFFFFD700) : kPrimary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Start free. Upgrade as your business grows.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? Colors.white.withAlpha(108)
                        : context.cs.onSurfaceVariant.withAlpha(170),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildFeaturePill(
    BuildContext context,
    IconData icon,
    String label,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withAlpha(10)
            : Colors.white.withAlpha(196),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark ? Colors.white.withAlpha(15) : kPrimary.withAlpha(18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isDark ? const Color(0xFF9FD1FF) : kPrimary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? Colors.white.withAlpha(210)
                  : context.cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  // ── Phone number input view ─────────────────────────────────────────────────

  Widget _buildPhoneInput({bool compact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Phone number',
          style: TextStyle(
            color: context.cs.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: context.cs.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: context.cs.surfaceContainerLow,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
                child: Text(
                  '+91',
                  style: TextStyle(
                    color: context.cs.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  onTap: () {
                    if (!kIsWeb &&
                        !_hintShown &&
                        _phoneController.text.isEmpty) {
                      _hintShown = true;
                      _requestPhoneHint();
                    }
                  },
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  style: TextStyle(
                    color: context.cs.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter 10-digit number',
                    hintStyle: TextStyle(
                      color: context.cs.onSurfaceVariant.withAlpha(153),
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    counterText: '',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: compact ? 14 : 16),
        _GradientButton(
          label: 'Send OTP',
          isLoading: _isSendingOtp,
          onPressed: _isPhoneValid && !_isSendingOtp ? _handleSendOtp : null,
          compact: compact,
        ),
      ],
    );
  }

  // ── OTP entry view ──────────────────────────────────────────────────────────

  Widget _buildOtpView({bool compact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Enter OTP sent to $_fullPhoneNumber',
                style: TextStyle(
                  color: context.cs.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            GestureDetector(
              onTap: _handleChangeNumber,
              child: const Text(
                'Change',
                style: TextStyle(
                  color: kPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 14 : 16),

        // 6-digit OTP boxes
        // Wrapped in AutofillGroup so the OS keyboard can suggest the OTP
        // from the arriving SMS notification.
        AutofillGroup(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) {
              return SizedBox(
                width: compact ? 44 : 46,
                height: compact ? 52 : 54,
                child: Focus(
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.backspace &&
                        _otpControllers[i].text.isEmpty &&
                        i > 0) {
                      _otpControllers[i - 1].clear();
                      _otpFocusNodes[i - 1].requestFocus();
                      setState(() {});
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: TextField(
                    controller: _otpControllers[i],
                    focusNode: _otpFocusNodes[i],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    // autofillHints on the first box lets Android/iOS surface
                    // the OTP from the SMS notification via the keyboard chip.
                    autofillHints: i == 0
                        ? const [AutofillHints.oneTimeCode]
                        : null,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(
                      color: context.cs.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      contentPadding: EdgeInsets.zero,
                      filled: true,
                      fillColor: context.cs.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: kPrimary,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onChanged: (value) {
                      if (value.length > 1) {
                        // Paste or autofill — distribute across all boxes
                        _distributeOtp(value);
                        return;
                      }
                      if (value.isNotEmpty && i < 5) {
                        _otpFocusNodes[i + 1].requestFocus();
                      }
                      // Auto-submit when all 6 digits entered
                      if (i == 5 && value.isNotEmpty && _otpCode.length == 6) {
                        _handleVerifyOtp();
                      }
                      setState(() {});
                    },
                  ),
                ),
              );
            }),
          ),
        ),
        SizedBox(height: compact ? 14 : 16),

        // Resend timer / button
        Center(
          child: _resendSeconds > 0
              ? Text(
                  'Resend OTP in ${_resendSeconds}s',
                  style: TextStyle(
                    color: context.cs.onSurfaceVariant.withAlpha(153),
                    fontSize: 13,
                  ),
                )
              : GestureDetector(
                  onTap: _handleResendOtp,
                  child: const Text(
                    'Resend OTP',
                    style: TextStyle(
                      color: kPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        ),
        SizedBox(height: compact ? 14 : 16),

        _GradientButton(
          label: 'Verify OTP',
          isLoading: _isVerifyingOtp,
          onPressed: _otpCode.length == 6 && !_isVerifyingOtp
              ? _handleVerifyOtp
              : null,
          compact: compact,
        ),
      ],
    );
  }

  // ── Divider ─────────────────────────────────────────────────────────────────

  Widget _buildDivider({bool compact = false}) {
    return Row(
      children: [
        Expanded(child: Divider(color: context.cs.surfaceContainerHighest)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14),
          child: Text(
            'or continue with',
            style: TextStyle(
              color: context.cs.onSurfaceVariant.withAlpha(153),
              fontSize: compact ? 12 : 13,
            ),
          ),
        ),
        Expanded(child: Divider(color: context.cs.surfaceContainerHighest)),
      ],
    );
  }
}

class _LoginGridPainter extends CustomPainter {
  const _LoginGridPainter({required this.lineColor});

  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;

    const spacing = 48.0;

    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LoginGridPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Reusable private widgets
// ═══════════════════════════════════════════════════════════════════════════════

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
    this.compact = false,
  });

  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: enabled ? kSignatureGradient : null,
          color: enabled ? null : context.cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 18,
                vertical: compact ? 14 : 16,
              ),
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        label,
                        style: TextStyle(
                          color: enabled
                              ? Colors.white
                              : context.cs.onSurfaceVariant.withAlpha(153),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({
    required this.isLoading,
    required this.onPressed,
    this.isSecondary = false,
    this.compact = false,
  });

  final bool isLoading;
  final VoidCallback? onPressed;
  final bool isSecondary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    // When secondary (phone auth is primary), show an outlined button.
    if (isSecondary) {
      return SizedBox(
        width: double.infinity,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.cs.outlineVariant.withAlpha(77)),
            color: context.cs.surfaceContainerLowest,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: compact ? 12 : 14,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isLoading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: kPrimary,
                        ),
                      )
                    else
                      const _GoogleLogo(size: 20),
                    const SizedBox(width: 10),
                    Text(
                      isLoading ? s.loginSigningIn : s.loginContinueGoogle,
                      style: TextStyle(
                        color: context.cs.onSurface,
                        fontSize: compact ? 13 : 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Primary style (used on web where phone auth is hidden).
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: kSignatureGradient,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  else
                    const _GoogleLogo(size: 22),
                  const SizedBox(width: 12),
                  Text(
                    isLoading ? s.loginSigningIn : s.loginContinueGoogle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _GoogleLogoPainter());
  }
}

class _LegalConsentText extends StatelessWidget {
  const _LegalConsentText({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TextStyle(
          fontSize: compact ? 11.5 : 12,
          color: context.cs.onSurfaceVariant.withAlpha(153),
          height: 1.5,
        ),
        children: [
          const TextSpan(text: 'By continuing, you agree to our '),
          TextSpan(
            text: 'Terms & Conditions',
            style: const TextStyle(
              color: kPrimary,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const TermsConditionsScreen(),
                ),
              ),
          ),
          const TextSpan(text: ' and '),
          TextSpan(
            text: 'Privacy Policy',
            style: const TextStyle(
              color: kPrimary,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
              ),
          ),
        ],
      ),
    );
  }
}

class _TrustLinksText extends StatelessWidget {
  const _TrustLinksText({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: compact ? 6 : 8,
      runSpacing: compact ? 6 : 8,
      children: [
        _TrustLinkChip(
          label: 'Pricing',
          url: PublicLinks.pricing,
          compact: compact,
        ),
        _TrustLinkChip(
          label: 'Security',
          url: PublicLinks.security,
          compact: compact,
        ),
        _TrustLinkChip(
          label: 'Support',
          url: PublicLinks.support,
          compact: compact,
        ),
      ],
    );
  }
}

class _TrustLinkChip extends StatelessWidget {
  const _TrustLinkChip({
    required this.label,
    required this.url,
    this.compact = false,
  });

  final String label;
  final String url;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () async {
        try {
          await PublicLinks.open(url);
        } catch (error) {
          debugPrint('[Login] Failed to open trust page: $error');
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 7 : 8,
        ),
        decoration: BoxDecoration(
          color: context.cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w600,
            color: context.cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.18;
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: radius,
    );

    void drawArc(Color color, double startAngle, double sweepAngle) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
    }

    drawArc(const Color(0xFF4285F4), -0.15, 1.15);
    drawArc(const Color(0xFFEA4335), 1.05, 1.05);
    drawArc(const Color(0xFFFBBC05), 2.10, 0.95);
    drawArc(const Color(0xFF34A853), 2.95, 1.15);

    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.square;

    final centerY = size.height / 2;
    final startX = size.width * 0.54;
    final endX = size.width * 0.88;
    canvas.drawLine(Offset(startX, centerY), Offset(endX, centerY), barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
