import 'dart:math';
import 'package:flutter/material.dart';
import 'package:billeasy/theme/app_colors.dart';

/// Full-screen notification shown when a team member is removed or leaves.
/// After the user taps "Sign Out", they're signed out and returned to login.
class TeamRemovedScreen extends StatefulWidget {
  const TeamRemovedScreen({
    super.key,
    required this.teamName,
    required this.wasRemoved,
    required this.onSignOut,
  });

  /// The team business name (shown in the message).
  final String teamName;

  /// True if removed by owner, false if the user left voluntarily.
  final bool wasRemoved;

  /// Called when the user taps the sign-out button.
  final VoidCallback onSignOut;

  @override
  State<TeamRemovedScreen> createState() => _TeamRemovedScreenState();
}

class _TeamRemovedScreenState extends State<TeamRemovedScreen>
    with TickerProviderStateMixin {
  late final AnimationController _contentController;
  late final AnimationController _iconController;
  late final Animation<double> _fadeIn;
  late final Animation<double> _slideUp;
  late final Animation<double> _iconScale;
  late final List<_FloatingDot> _dots;

  @override
  void initState() {
    super.initState();

    _contentController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeIn = CurvedAnimation(
      parent: _contentController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _slideUp = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(
        parent: _contentController,
        curve: const Interval(0.1, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconController,
        curve: Curves.elasticOut,
      ),
    );

    final rng = Random();
    _dots = List.generate(20, (_) => _FloatingDot(rng));

    _iconController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _contentController.forward();
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.wasRemoved
        ? 'You\'ve been removed'
        : 'You left the team';

    final message = widget.wasRemoved
        ? 'The team owner has removed you from "${widget.teamName}". '
          'Please sign in again to continue with your own workspace.'
        : 'You\'ve left "${widget.teamName}". '
          'Please sign in again to continue with your own workspace.';

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  context.cs.surface,
                  context.cs.surfaceContainerLow,
                  context.cs.surface,
                ],
              ),
            ),
          ),

          // Floating dots (subtle background animation)
          AnimatedBuilder(
            animation: _contentController,
            builder: (context, _) => CustomPaint(
              painter: _DotsPainter(
                dots: _dots,
                color: context.cs.primary.withAlpha(30),
              ),
              size: Size.infinite,
            ),
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
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: [
                          const Spacer(flex: 3),

                          // Icon
                          ScaleTransition(
                            scale: _iconScale,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (widget.wasRemoved ? kOverdue : kPrimary)
                                    .withAlpha(24),
                              ),
                              child: Icon(
                                widget.wasRemoved
                                    ? Icons.person_remove_rounded
                                    : Icons.waving_hand_rounded,
                                size: 48,
                                color: widget.wasRemoved ? kOverdue : kPrimary,
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Title
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: context.cs.onSurface,
                              letterSpacing: -0.5,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Message
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.6,
                              color: context.cs.onSurfaceVariant,
                            ),
                          ),

                          const Spacer(flex: 4),

                          // Sign out button
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: FilledButton.icon(
                              onPressed: widget.onSignOut,
                              icon: const Icon(Icons.logout_rounded, size: 20),
                              label: const Text(
                                'Sign Out',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: context.cs.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),
                        ],
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
}

// Subtle floating dots for background
class _FloatingDot {
  final double x;
  final double y;
  final double radius;

  _FloatingDot(Random rng)
      : x = rng.nextDouble(),
        y = rng.nextDouble(),
        radius = 3 + rng.nextDouble() * 8;
}

class _DotsPainter extends CustomPainter {
  final List<_FloatingDot> dots;
  final Color color;

  _DotsPainter({required this.dots, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final d in dots) {
      canvas.drawCircle(
        Offset(d.x * size.width, d.y * size.height),
        d.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DotsPainter old) => false;
}
