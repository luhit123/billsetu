import 'dart:math';
import 'package:flutter/material.dart';
import '../services/remote_config_service.dart';

/// Full-screen celebration shown on every login.
/// Showcases all Enterprise-level features included free with BillRaja.
/// On first login, tapping "Start Billing" activates the plan (writes createdAt).
class TrialCelebrationScreen extends StatefulWidget {
  final VoidCallback onContinue;
  /// Whether this is the very first time (plan not yet activated).
  final bool isFirstTime;
  const TrialCelebrationScreen({
    super.key,
    required this.onContinue,
    this.isFirstTime = false,
  });

  @override
  State<TrialCelebrationScreen> createState() => _TrialCelebrationScreenState();
}

class _TrialCelebrationScreenState extends State<TrialCelebrationScreen>
    with TickerProviderStateMixin {
  late final AnimationController _confettiController;
  late final AnimationController _contentController;
  late final AnimationController _pulseController;
  late final AnimationController _featureController;
  late final Animation<double> _fadeIn;
  late final Animation<double> _slideUp;
  late final Animation<double> _scaleIn;
  late final Animation<double> _pulse;
  late final List<_ConfettiParticle> _particles;

  @override
  void initState() {
    super.initState();

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _featureController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _fadeIn = CurvedAnimation(
      parent: _contentController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );

    _slideUp = Tween<double>(begin: 60, end: 0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.1, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _scaleIn = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    _pulse = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    final rng = Random();
    _particles = List.generate(80, (_) => _ConfettiParticle(rng));

    _confettiController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _contentController.forward();
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _featureController.forward();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _contentController.dispose();
    _pulseController.dispose();
    _featureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background gradient — deep purple-blue enterprise feel
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A0E27),
                  Color(0xFF1A1040),
                  Color(0xFF0D1B3E),
                  Color(0xFF0A0E27),
                ],
                stops: [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),

          // Subtle radial glow behind badge
          Positioned(
            top: MediaQuery.of(context).size.height * 0.15,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFFD700).withAlpha(25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Confetti layer
          AnimatedBuilder(
            animation: _confettiController,
            builder: (context, _) {
              return CustomPaint(
                painter: _ConfettiPainter(
                  particles: _particles,
                  progress: _confettiController.value,
                ),
                size: Size.infinite,
              );
            },
          ),

          // Content
          SafeArea(
            child: AnimatedBuilder(
              animation: _contentController,
              builder: (context, _) {
                return Opacity(
                  opacity: _fadeIn.value,
                  child: Transform.translate(
                    offset: Offset(0, _slideUp.value),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: MediaQuery.of(context).size.height -
                              MediaQuery.of(context).padding.top -
                              MediaQuery.of(context).padding.bottom,
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 40),

                            // Diamond badge with pulse
                            ScaleTransition(
                              scale: _pulse,
                              child: ScaleTransition(
                                scale: _scaleIn,
                                child: Container(
                                  width: 110,
                                  height: 110,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFFFFD700),
                                        Color(0xFFFFA500),
                                        Color(0xFFFFD700),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFFD700).withAlpha(60),
                                        blurRadius: 50,
                                        spreadRadius: 15,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.diamond_rounded,
                                    size: 52,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 28),

                            // Enterprise badge pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'ENTERPRISE',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1A1040),
                                  letterSpacing: 2.0,
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Title
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                              ).createShader(bounds),
                              child: Text(
                                widget.isFirstTime
                                    ? '${RemoteConfigService.instance.trialDurationMonths} Months Free'
                                    : 'Welcome Back!',
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            Text(
                              widget.isFirstTime
                                  ? 'Every feature. Zero payment. No credit card.'
                                  : 'Your Enterprise plan is active.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withAlpha(210),
                              ),
                            ),

                            const SizedBox(height: 36),

                            // Feature categories
                            AnimatedBuilder(
                              animation: _featureController,
                              builder: (context, _) {
                                return Opacity(
                                  opacity: _featureController.value.clamp(0.0, 1.0),
                                  child: _buildFeatureSections(),
                                );
                              },
                            ),

                            const SizedBox(height: 36),

                            // CTA button
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 40),
                              child: SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: widget.onContinue,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFFD700),
                                    foregroundColor: const Color(0xFF1A1040),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        widget.isFirstTime
                                            ? 'Start Free'
                                            : 'Continue',
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward_rounded, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Trust line
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.verified_rounded,
                                    size: 14, color: Colors.white.withAlpha(100)),
                                const SizedBox(width: 4),
                                Text(
                                  'Trusted by Indian businesses',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withAlpha(100),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 32),
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

  Widget _buildFeatureSections() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // ── Billing & Invoicing
          _buildFeatureCategory(
            'Billing & Invoicing',
            Icons.receipt_long_rounded,
            const Color(0xFF4FC3F7),
            [
              'Unlimited invoices & customers',
              'All 20+ PDF templates',
              'GST/non-GST invoicing',
              'UPI payment links & QR codes',
            ],
          ),

          const SizedBox(height: 16),

          // ── Business Tools
          _buildFeatureCategory(
            'Business Tools',
            Icons.business_center_rounded,
            const Color(0xFF81C784),
            [
              'Purchase orders & inventory',
              'Reports, analytics & GSTR-3B',
              'WhatsApp sharing & data export',
              'Custom branding & logo',
            ],
          ),

          const SizedBox(height: 16),

          // ── Team & Attendance
          _buildFeatureCategory(
            'Team & Attendance',
            Icons.groups_rounded,
            const Color(0xFFBA68C8),
            [
              'Unlimited team members',
              'GPS attendance with geofencing',
              'Team performance tracking',
              'Role-based permissions',
            ],
          ),

          const SizedBox(height: 16),

          // ── Platform
          _buildFeatureCategory(
            'Always Available',
            Icons.cloud_done_rounded,
            const Color(0xFFFFB74D),
            [
              'Works offline — sync when online',
              'Multi-language support',
              'Digital business card',
              'Membership management',
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCategory(
    String title,
    IconData icon,
    Color accentColor,
    List<String> features,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 15,
                    color: Color(0xFFFFD700),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      f,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withAlpha(200),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Confetti system — lightweight custom painter, no external packages
// ═════════════════════════════════════════════════════════════════════════════

class _ConfettiParticle {
  final double x; // 0..1 horizontal start
  final double delay; // 0..0.4 stagger
  final double speed; // fall speed multiplier
  final double size;
  final double drift; // horizontal sway
  final double rotation;
  final Color color;
  final int shape; // 0=circle, 1=rect, 2=star

  _ConfettiParticle(Random rng)
      : x = rng.nextDouble(),
        delay = rng.nextDouble() * 0.35,
        speed = 0.6 + rng.nextDouble() * 0.8,
        size = 4.0 + rng.nextDouble() * 6.0,
        drift = (rng.nextDouble() - 0.5) * 80,
        rotation = rng.nextDouble() * pi * 2,
        shape = rng.nextInt(3),
        color = [
          const Color(0xFFFFD700), // gold
          const Color(0xFFFFA500), // orange
          const Color(0xFF0057FF), // blue
          const Color(0xFF00C853), // green
          const Color(0xFFFF4081), // pink
          const Color(0xFFE040FB), // purple
          const Color(0xFF00E5FF), // cyan
          const Color(0xFFFFFFFF), // white
        ][rng.nextInt(8)];
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = ((progress - p.delay) / (1.0 - p.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;

      // Fade out in the last 30%
      final opacity = t > 0.7 ? ((1.0 - t) / 0.3).clamp(0.0, 1.0) : 1.0;
      final paint = Paint()..color = p.color.withAlpha((opacity * 200).round());

      final dx = p.x * size.width + sin(t * pi * 3) * p.drift;
      final dy = -20 + t * (size.height + 40) * p.speed;

      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(p.rotation + t * pi * 4);

      if (p.shape == 0) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else if (p.shape == 1) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
            const Radius.circular(1),
          ),
          paint,
        );
      } else {
        // Small 4-point star
        final path = Path();
        final s = p.size / 2;
        path.moveTo(0, -s);
        path.lineTo(s * 0.3, -s * 0.3);
        path.lineTo(s, 0);
        path.lineTo(s * 0.3, s * 0.3);
        path.lineTo(0, s);
        path.lineTo(-s * 0.3, s * 0.3);
        path.lineTo(-s, 0);
        path.lineTo(-s * 0.3, -s * 0.3);
        path.close();
        canvas.drawPath(path, paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
