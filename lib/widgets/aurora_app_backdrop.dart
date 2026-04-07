import 'package:billeasy/theme/app_colors.dart';
import 'package:flutter/material.dart';

class AuroraAppBackdrop extends StatelessWidget {
  const AuroraAppBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _AuroraBackdropPainter(isDark: isDark),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _AuroraBackdropPainter extends CustomPainter {
  const _AuroraBackdropPainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;

    final basePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const [
                Color(0xFF06101D),
                Color(0xFF0A1424),
                Color(0xFF111827),
              ]
            : const [
                Color(0xFFF8FBFF),
                kSurface,
                Color(0xFFFDF8F0),
              ],
      ).createShader(bounds);
    canvas.drawRect(bounds, basePaint);

    final specs = isDark ? _darkSpecs : _lightSpecs;
    for (final spec in specs) {
      _paintAura(canvas, size, spec);
    }

    final glazePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? const [
                Color(0x14FFFFFF),
                Color(0x12050A12),
                Color(0x5C050A12),
              ]
            : const [
                Color(0x8CFFFFFF),
                Color(0x40FFFFFF),
                Color(0xB8F8FAFC),
              ],
        stops: const [0, 0.42, 1],
      ).createShader(bounds);
    canvas.drawRect(bounds, glazePaint);
  }

  void _paintAura(Canvas canvas, Size size, _AuroraSpec spec) {
    final center = Offset(
      ((spec.alignment.x + 1) / 2) * size.width,
      ((spec.alignment.y + 1) / 2) * size.height,
    );

    final auraSize = Size(
      size.width * spec.widthFactor,
      size.height * spec.heightFactor,
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(spec.angle);

    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: auraSize.width,
      height: auraSize.height,
    );

    final paint = Paint()
      ..shader = RadialGradient(
        radius: 0.82,
        colors: [
          spec.color.withValues(alpha: spec.opacity),
          spec.color.withValues(alpha: spec.opacity * 0.42),
          spec.color.withValues(alpha: 0),
        ],
        stops: const [0, 0.56, 1],
      ).createShader(rect);

    canvas.drawOval(rect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AuroraBackdropPainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}

class _AuroraSpec {
  const _AuroraSpec({
    required this.alignment,
    required this.widthFactor,
    required this.heightFactor,
    required this.angle,
    required this.color,
    required this.opacity,
  });

  final Alignment alignment;
  final double widthFactor;
  final double heightFactor;
  final double angle;
  final Color color;
  final double opacity;
}

const List<_AuroraSpec> _lightSpecs = [
  _AuroraSpec(
    alignment: Alignment(-1.1, -1.0),
    widthFactor: 1.1,
    heightFactor: 0.42,
    angle: -0.52,
    color: Color(0xFF4CC9F0),
    opacity: 0.28,
  ),
  _AuroraSpec(
    alignment: Alignment(1.0, -0.58),
    widthFactor: 0.84,
    heightFactor: 0.34,
    angle: 0.64,
    color: Color(0xFF7C9BFF),
    opacity: 0.22,
  ),
  _AuroraSpec(
    alignment: Alignment(0.25, 0.92),
    widthFactor: 1.0,
    heightFactor: 0.36,
    angle: -0.24,
    color: Color(0xFFFFD28F),
    opacity: 0.18,
  ),
  _AuroraSpec(
    alignment: Alignment(-0.18, 0.1),
    widthFactor: 0.74,
    heightFactor: 0.26,
    angle: 0.18,
    color: kPrimary,
    opacity: 0.1,
  ),
];

const List<_AuroraSpec> _darkSpecs = [
  _AuroraSpec(
    alignment: Alignment(-1.0, -0.92),
    widthFactor: 1.18,
    heightFactor: 0.44,
    angle: -0.48,
    color: Color(0xFF1D9BF0),
    opacity: 0.34,
  ),
  _AuroraSpec(
    alignment: Alignment(1.04, -0.38),
    widthFactor: 0.9,
    heightFactor: 0.34,
    angle: 0.72,
    color: Color(0xFF19C9B6),
    opacity: 0.26,
  ),
  _AuroraSpec(
    alignment: Alignment(0.28, 0.94),
    widthFactor: 1.0,
    heightFactor: 0.38,
    angle: -0.22,
    color: Color(0xFF2B6BFF),
    opacity: 0.24,
  ),
  _AuroraSpec(
    alignment: Alignment(-0.25, 0.06),
    widthFactor: 0.82,
    heightFactor: 0.28,
    angle: 0.14,
    color: Color(0xFF8AD7FF),
    opacity: 0.12,
  ),
];
