import 'package:billeasy/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Shimmer-animated skeleton placeholder.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _animation = Tween(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final shimmerColor = isDark ? Colors.grey.shade700 : Colors.grey.shade100;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [baseColor, shimmerColor, baseColor],
            stops: [
              (_animation.value - 0.3).clamp(0.0, 1.0),
              _animation.value.clamp(0.0, 1.0),
              (_animation.value + 0.3).clamp(0.0, 1.0),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton version of the login screen — shown while auth state is loading.
class LoginSkeleton extends StatelessWidget {
  const LoginSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cs.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo placeholder
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: kPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: Text(
                        'B',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: kPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Title
                  const SkeletonBox(width: 180, height: 28),
                  const SizedBox(height: 8),
                  const SkeletonBox(width: 240, height: 14),
                  const SizedBox(height: 40),
                  // Phone input field placeholder
                  const SkeletonBox(height: 52, borderRadius: 12),
                  const SizedBox(height: 16),
                  // Button placeholder
                  const SkeletonBox(height: 52, borderRadius: 12),
                  const SizedBox(height: 24),
                  // OR divider
                  const SkeletonBox(width: 160, height: 12),
                  const SizedBox(height: 24),
                  // Google button placeholder
                  const SkeletonBox(height: 48, borderRadius: 12),
                  const SizedBox(height: 32),
                  // Terms text
                  const SkeletonBox(width: 260, height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton version of the home screen — shown while data is loading.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cs.surface,
      appBar: AppBar(
        backgroundColor: context.cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: kPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text('B', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kPrimary)),
              ),
            ),
            const SizedBox(width: 10),
            const SkeletonBox(width: 100, height: 18),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            // Revenue banner skeleton
            Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [kPrimary.withValues(alpha: 0.15), kPrimary.withValues(alpha: 0.05)],
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 120, height: 12),
                  SizedBox(height: 12),
                  SkeletonBox(width: 180, height: 28),
                  Spacer(),
                  SkeletonBox(width: 200, height: 10),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Quick actions
            const SkeletonBox(width: 120, height: 14),
            const SizedBox(height: 12),
            Row(
              children: List.generate(
                4,
                (i) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 3 ? 10 : 0),
                    child: const SkeletonBox(height: 72, borderRadius: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Recent invoices
            const SkeletonBox(width: 140, height: 14),
            const SizedBox(height: 12),
            ...List.generate(
              4,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SkeletonBox(height: 72, borderRadius: 14),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        height: 64,
        decoration: BoxDecoration(
          color: context.cs.surface,
          border: Border(top: BorderSide(color: Colors.grey.shade200, width: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(
            4,
            (i) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: i == 0 ? kPrimary.withValues(alpha: 0.15) : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 4),
                SkeletonBox(width: 36, height: 8, borderRadius: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
