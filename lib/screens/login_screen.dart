import 'dart:async';

import 'package:billeasy/l10n/app_strings.dart';
import 'package:billeasy/screens/privacy_policy_screen.dart';
import 'package:billeasy/screens/terms_conditions_screen.dart';
import 'package:billeasy/services/auth_service.dart';
import 'package:billeasy/theme/app_colors.dart';
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
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
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

  @override
  void codeUpdated() {
    // Called by CodeAutoFill when an OTP is detected from SMS
    final smsCode = code ?? '';
    if (smsCode.length >= 6 && mounted) {
      final digits = smsCode.replaceAll(RegExp(r'\D'), '');
      final otp = digits.length >= 6 ? digits.substring(0, 6) : digits;
      if (otp.length == 6) {
        for (int i = 0; i < 6; i++) {
          _otpControllers[i].text = otp[i];
        }
        setState(() {});
        // Auto-submit after a short delay for visual feedback
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _handleVerifyOtp();
        });
      }
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

  String get _otpCode =>
      _otpControllers.map((c) => c.text).join();

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

  // ── Phone auth actions ──────────────────────────────────────────────────────

  Future<void> _handleSendOtp() async {
    if (!_isPhoneValid) return;
    FocusScope.of(context).unfocus();

    setState(() => _isSendingOtp = true);

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
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
          const SnackBar(content: Text('Verification failed. Please try again.')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification failed. Please try again.')),
      );
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
            'Firebase error [${error.code}]: ${error.message ?? 'Sign-in failed.'}',
          ),
        ),
      );
    } catch (error, stack) {
      debugPrint('[LoginScreen] Exception: ${error.runtimeType} — $error');
      debugPrint('[LoginScreen] Stack: $stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign-in failed [${error.runtimeType}]: $error'),
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
    return Scaffold(
      backgroundColor: kSurface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Branding ────────────────────────────────────────────
                  const Text(
                    'BillEasy',
                    style: TextStyle(
                      color: kOnSurface,
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    s.loginTagline,
                    style: const TextStyle(
                      color: kOnSurfaceVariant,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Card ────────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      color: kSurfaceLowest,
                      boxShadow: const [kWhisperShadow],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: kPrimaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            s.loginBadgeLabel,
                            style: const TextStyle(
                              color: kPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          s.loginWelcome,
                          style: const TextStyle(
                            color: kOnSurface,
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          s.loginSubtitle,
                          style: const TextStyle(
                            color: kOnSurfaceVariant,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Phone auth (skip on web)
                        if (!kIsWeb) ...[
                          if (!_otpSent) _buildPhoneInput() else _buildOtpView(),
                          const SizedBox(height: 24),
                          _buildDivider(),
                          const SizedBox(height: 24),
                        ],

                        // Google sign-in (secondary when phone is available)
                        _GoogleSignInButton(
                          isLoading: _isSigningInGoogle,
                          onPressed: _isSigningInGoogle
                              ? null
                              : _handleGoogleSignIn,
                          isSecondary: !kIsWeb,
                        ),
                        const SizedBox(height: 16),
                        _LegalConsentText(),
                      ],
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

  // ── Phone number input view ─────────────────────────────────────────────────

  Widget _buildPhoneInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Phone number',
          style: TextStyle(
            color: kOnSurface,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: kSurfaceContainerLow,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
                child: const Text(
                  '+91',
                  style: TextStyle(
                    color: kOnSurface,
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
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  style: const TextStyle(
                    color: kOnSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Enter 10-digit number',
                    hintStyle: TextStyle(color: kTextTertiary, fontSize: 15),
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
        const SizedBox(height: 16),
        _GradientButton(
          label: 'Send OTP',
          isLoading: _isSendingOtp,
          onPressed: _isPhoneValid && !_isSendingOtp ? _handleSendOtp : null,
        ),
      ],
    );
  }

  // ── OTP entry view ──────────────────────────────────────────────────────────

  Widget _buildOtpView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Enter OTP sent to $_fullPhoneNumber',
                style: const TextStyle(
                  color: kOnSurface,
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
        const SizedBox(height: 16),

        // 6-digit OTP boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) {
            return SizedBox(
              width: 46,
              height: 54,
              child: TextField(
                controller: _otpControllers[i],
                focusNode: _otpFocusNodes[i],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(1),
                ],
                style: const TextStyle(
                  color: kOnSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                  filled: true,
                  fillColor: kSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kPrimary, width: 1.5),
                  ),
                ),
                onChanged: (value) {
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
            );
          }),
        ),
        const SizedBox(height: 16),

        // Resend timer / button
        Center(
          child: _resendSeconds > 0
              ? Text(
                  'Resend OTP in ${_resendSeconds}s',
                  style: const TextStyle(
                    color: kTextTertiary,
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
        const SizedBox(height: 16),

        _GradientButton(
          label: 'Verify OTP',
          isLoading: _isVerifyingOtp,
          onPressed:
              _otpCode.length == 6 && !_isVerifyingOtp ? _handleVerifyOtp : null,
        ),
      ],
    );
  }

  // ── Divider ─────────────────────────────────────────────────────────────────

  Widget _buildDivider() {
    return Row(
      children: const [
        Expanded(child: Divider(color: kSurfaceDim)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'or continue with',
            style: TextStyle(
              color: kTextTertiary,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(child: Divider(color: kSurfaceDim)),
      ],
    );
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
  });

  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: enabled ? kSignatureGradient : null,
          color: enabled ? null : kSurfaceDim,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
                          color: enabled ? Colors.white : kTextTertiary,
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
  });

  final bool isLoading;
  final VoidCallback? onPressed;
  final bool isSecondary;

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
            border: Border.all(color: kOutlineVariant.withOpacity(0.3)),
            color: kSurfaceLowest,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
                      style: const TextStyle(
                        color: kOnSurface,
                        fontSize: 14,
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          fontSize: 12,
          color: kTextTertiary,
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
                        builder: (_) => const TermsConditionsScreen()),
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
                    MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyScreen()),
                  ),
          ),
        ],
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
