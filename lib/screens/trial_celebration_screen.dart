import 'dart:math';
import 'package:flutter/material.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:billeasy/services/plan_service.dart';
import 'package:billeasy/services/remote_config_service.dart';

/// Full-screen celebration shown once after first login + onboarding.
class TrialCelebrationScreen extends StatefulWidget {
  final VoidCallback onContinue;
  const TrialCelebrationScreen({super.key, required this.onContinue});

  @override
  State<TrialCelebrationScreen> createState() => _TrialCelebrationScreenState();
}

class _TrialCelebrationScreenState extends State<TrialCelebrationScreen>
    with TickerProviderStateMixin {
  late final AnimationController _confettiController;
  late final AnimationController _contentController;
  late final AnimationController _pulseController;
  late final Animation<double> _fadeIn;
  late final Animation<double> _slideUp;
  late final Animation<double> _scaleIn;
  late final Animation<double> _pulse;
  late final List<_ConfettiParticle> _particles;

  @override
  void initState() {
    super.initState();

    // Confetti runs for 3 seconds
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    // Content animates in
    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Pulsing glow on the badge
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

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

    // Generate confetti particles
    final rng = Random();
    _particles = List.generate(80, (_) => _ConfettiParticle(rng));

    // Start animations
    _confettiController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _contentController.forward();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _contentController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trialMonths = RemoteConfigService.instance.trialDurationMonths;
    final daysLeft = PlanService.instance.trialDaysLeft;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0A1628), Color(0xFF0D2137), Color(0xFF0A1628)],
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
                    child: Column(
                      children: [
                        const Spacer(flex: 2),

                        // Pulsing crown/star badge
                        ScaleTransition(
                          scale: _pulse,
                          child: ScaleTransition(
                            scale: _scaleIn,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFFD700).withAlpha(80),
                                    blurRadius: 40,
                                    spreadRadius: 10,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.workspace_premium_rounded,
                                size: 60,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Title
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                          ).createShader(bounds),
                          child: const Text(
                            'Welcome to Pro!',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        Text(
                          'Your $trialMonths-month free trial is active',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withAlpha(200),
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          '$daysLeft days of full access remaining',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withAlpha(140),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Feature highlights
                        _buildFeatureChips(),

                        const Spacer(flex: 3),

                        // CTA button
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: widget.onContinue,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Start Billing',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),
                      ],
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

  Widget _buildFeatureChips() {
    const features = [
      ('receipt_long', 'Unlimited Invoices'),
      ('people', 'Unlimited Customers'),
      ('chat', 'WhatsApp Sharing'),
      ('bar_chart', 'Reports & Analytics'),
      ('picture_as_pdf', 'All PDF Templates'),
      ('palette', 'Custom Branding'),
    ];

    const iconMap = <String, IconData>{
      'receipt_long': Icons.receipt_long_rounded,
      'people': Icons.people_rounded,
      'chat': Icons.chat_rounded,
      'bar_chart': Icons.bar_chart_rounded,
      'picture_as_pdf': Icons.picture_as_pdf_rounded,
      'palette': Icons.palette_rounded,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: features.map((f) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withAlpha(30)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(iconMap[f.$1] ?? Icons.check_circle_rounded,
                    size: 16, color: const Color(0xFFFFD700)),
                const SizedBox(width: 6),
                Text(
                  f.$2,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withAlpha(220),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
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
