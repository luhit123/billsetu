import 'dart:math';
import 'package:flutter/material.dart';
import 'package:billeasy/theme/app_colors.dart';

/// Full-screen celebration shown when a team member accepts an invite.
class TeamJoinCelebrationScreen extends StatefulWidget {
  final String memberName;
  final String roleName;
  final String teamName;
  final VoidCallback onContinue;

  const TeamJoinCelebrationScreen({
    super.key,
    required this.memberName,
    required this.roleName,
    required this.teamName,
    required this.onContinue,
  });

  @override
  State<TeamJoinCelebrationScreen> createState() =>
      _TeamJoinCelebrationScreenState();
}

class _TeamJoinCelebrationScreenState extends State<TeamJoinCelebrationScreen>
    with TickerProviderStateMixin {
  late final AnimationController _confettiController;
  late final AnimationController _contentController;
  late final AnimationController _pulseController;
  late final Animation<double> _fadeIn;
  late final Animation<double> _slideUp;
  late final Animation<double> _scaleIn;
  late final Animation<double> _pulse;
  late final List<_FlowerParticle> _particles;

  @override
  void initState() {
    super.initState();

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

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

    final rng = Random();
    _particles = List.generate(60, (_) => _FlowerParticle(rng));

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
                colors: [Color(0xFF0A1628), Color(0xFF1A1040), Color(0xFF0A1628)],
              ),
            ),
          ),

          // Flower particle layer
          AnimatedBuilder(
            animation: _confettiController,
            builder: (context, _) {
              return CustomPaint(
                painter: _FlowerPainter(
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

                        // Pulsing badge
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
                                  colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF7C3AED).withAlpha(80),
                                    blurRadius: 40,
                                    spreadRadius: 10,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.groups_rounded,
                                size: 56,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Title with name
                        if (widget.memberName.isNotEmpty) ...[
                          Text(
                            'Welcome,',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withAlpha(180),
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                          ).createShader(bounds),
                          child: Text(
                            widget.memberName.isNotEmpty
                                ? widget.memberName
                                : 'Welcome to the Team!',
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Team name
                        if (widget.teamName.isNotEmpty)
                          Text(
                            widget.teamName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withAlpha(220),
                            ),
                          ),

                        const SizedBox(height: 12),

                        // Role badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withAlpha(60),
                            ),
                            color: Colors.white.withAlpha(15),
                          ),
                          child: Text(
                            'Your role: ${widget.roleName}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withAlpha(200),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            'You now have access to the team workspace. '
                            'Start billing together!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withAlpha(140),
                              height: 1.5,
                            ),
                          ),
                        ),

                        const Spacer(flex: 3),

                        // CTA
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
                                'Let\'s Go!',
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
}

// ── Flower/petal particle system ────────────────────────────────────────────

class _FlowerParticle {
  final double x; // 0..1
  final double startY; // negative start
  final double size;
  final double drift;
  final double rotationSpeed;
  final double rotation;
  final Color color;
  final int petalCount; // 4, 5, or 6

  _FlowerParticle(Random rng)
      : x = rng.nextDouble(),
        startY = -0.1 - rng.nextDouble() * 0.3,
        size = 6 + rng.nextDouble() * 12,
        drift = (rng.nextDouble() - 0.5) * 0.15,
        rotationSpeed = (rng.nextDouble() - 0.5) * 6,
        rotation = rng.nextDouble() * 2 * pi,
        color = _flowerColors[rng.nextInt(_flowerColors.length)],
        petalCount = 4 + rng.nextInt(3);

  static const _flowerColors = [
    Color(0xFFFF69B4), // hot pink
    Color(0xFFFF1493), // deep pink
    Color(0xFFDA70D6), // orchid
    Color(0xFFBA55D3), // medium orchid
    Color(0xFFFF6347), // tomato
    Color(0xFFFFA07A), // light salmon
    Color(0xFFFFD700), // gold
    Color(0xFF98FB98), // pale green
    Color(0xFF87CEEB), // sky blue
    Color(0xFFDDA0DD), // plum
  ];
}

class _FlowerPainter extends CustomPainter {
  final List<_FlowerParticle> particles;
  final double progress;

  _FlowerPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = progress;
      final y = p.startY + t * 1.4;
      if (y < -0.1 || y > 1.1) continue;

      final x = p.x + sin(t * pi * 2 + p.drift * 10) * p.drift;
      final opacity = (1.0 - t).clamp(0.0, 1.0) * 0.8;

      final cx = x * size.width;
      final cy = y * size.height;
      final angle = p.rotation + t * p.rotationSpeed;

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(angle);

      final paint = Paint()
        ..color = p.color.withAlpha((opacity * 255).toInt())
        ..style = PaintingStyle.fill;

      // Draw flower petals
      for (int i = 0; i < p.petalCount; i++) {
        final petalAngle = (2 * pi / p.petalCount) * i;
        final px = cos(petalAngle) * p.size * 0.5;
        final py = sin(petalAngle) * p.size * 0.5;
        canvas.drawCircle(Offset(px, py), p.size * 0.3, paint);
      }
      // Center dot
      canvas.drawCircle(
        Offset.zero,
        p.size * 0.2,
        Paint()..color = Colors.white.withAlpha((opacity * 200).toInt()),
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _FlowerPainter old) => old.progress != progress;
}
