import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:billeasy/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// A full-screen modal signature pad.
/// Returns the signature as PNG [Uint8List] on save, or null on cancel.
class SignaturePadSheet extends StatefulWidget {
  const SignaturePadSheet({super.key, this.existingSignature});

  /// If non-null, shows a "Clear existing" option.
  final Uint8List? existingSignature;

  /// Opens the signature pad as a modal bottom sheet.
  /// Returns the drawn signature as PNG bytes, or null if cancelled.
  static Future<Uint8List?> show(
    BuildContext context, {
    Uint8List? existingSignature,
  }) {
    return showModalBottomSheet<Uint8List>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: false, // Prevent drag-to-dismiss — conflicts with signature drawing
      backgroundColor: Colors.transparent,
      builder: (_) => SignaturePadSheet(existingSignature: existingSignature),
    );
  }

  @override
  State<SignaturePadSheet> createState() => _SignaturePadSheetState();
}

class _SignaturePadSheetState extends State<SignaturePadSheet> {
  // Use a notifier to repaint without rebuilding widget tree — smooth drawing
  final _strokesNotifier = _StrokesNotifier();
  bool _hasDrawn = false;

  void _clear() {
    _strokesNotifier.clear();
    setState(() => _hasDrawn = false);
  }

  Future<void> _save() async {
    if (!_hasDrawn) {
      Navigator.pop(context);
      return;
    }

    final strokes = _strokesNotifier.strokes;

    // Find bounding box of all points
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final stroke in strokes) {
      for (final pt in stroke) {
        if (pt.dx < minX) minX = pt.dx;
        if (pt.dy < minY) minY = pt.dy;
        if (pt.dx > maxX) maxX = pt.dx;
        if (pt.dy > maxY) maxY = pt.dy;
      }
    }

    const pad = 20.0;
    minX -= pad;
    minY -= pad;
    maxX += pad;
    maxY += pad;

    final width = (maxX - minX).ceil();
    final height = (maxY - minY).ceil();
    if (width <= 0 || height <= 0) {
      Navigator.pop(context);
      return;
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));

    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = const Color(0x00000000),
    );

    final paint = Paint()
      ..color = const Color(0xFF1A1A2E)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path();
      path.moveTo(stroke.first.dx - minX, stroke.first.dy - minY);
      for (var i = 1; i < stroke.length; i++) {
        // Use quadratic bezier for smooth curves
        if (i + 1 < stroke.length) {
          final mid = Offset(
            (stroke[i].dx + stroke[i + 1].dx) / 2 - minX,
            (stroke[i].dy + stroke[i + 1].dy) / 2 - minY,
          );
          path.quadraticBezierTo(stroke[i].dx - minX, stroke[i].dy - minY, mid.dx, mid.dy);
        } else {
          path.lineTo(stroke[i].dx - minX, stroke[i].dy - minY);
        }
      }
      canvas.drawPath(path, paint);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    if (byteData == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    if (mounted) {
      Navigator.pop(context, byteData.buffer.asUint8List());
    }
  }

  @override
  void dispose() {
    _strokesNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(color: kSurfaceContainerHigh, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
            child: Row(
              children: [
                const Icon(Icons.draw_rounded, color: kPrimary, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Draw Your Signature',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kOnSurface)),
                ),
                TextButton(
                  onPressed: _clear,
                  child: const Text('Clear', style: TextStyle(color: kOverdue, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('Sign with your finger below',
              style: TextStyle(fontSize: 13, color: kTextTertiary)),
          ),
          const SizedBox(height: 10),
          // Canvas — uses Listener for low-latency touch input
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kOutlineVariant, width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Listener(
                  onPointerDown: (e) {
                    _strokesNotifier.startStroke(e.localPosition);
                    if (!_hasDrawn) setState(() => _hasDrawn = true);
                  },
                  onPointerMove: (e) {
                    _strokesNotifier.addPoint(e.localPosition);
                  },
                  onPointerUp: (_) {
                    _strokesNotifier.endStroke();
                  },
                  child: CustomPaint(
                    painter: _SmoothSignaturePainter(notifier: _strokesNotifier),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (widget.existingSignature != null && !_hasDrawn)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 60, height: 36,
                    decoration: BoxDecoration(
                      border: Border.all(color: kOutlineVariant),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Image.memory(widget.existingSignature!, fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('Current signature',
                    style: TextStyle(fontSize: 12, color: kTextTertiary)),
                ],
              ),
            ),
          // Save button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                  label: const Text('Save Signature',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Notifier that stores strokes and notifies the painter without rebuilding the widget tree.
class _StrokesNotifier extends ChangeNotifier {
  final List<List<Offset>> _strokes = [];
  List<Offset> _current = [];

  List<List<Offset>> get strokes => _strokes;
  List<Offset> get currentStroke => _current;

  void startStroke(Offset point) {
    _current = [point];
    notifyListeners();
  }

  void addPoint(Offset point) {
    _current.add(point);
    notifyListeners();
  }

  void endStroke() {
    if (_current.isNotEmpty) {
      _strokes.add(_current);
      _current = [];
    }
  }

  void clear() {
    _strokes.clear();
    _current = [];
    notifyListeners();
  }
}

/// Smooth signature painter — uses quadratic bezier curves and repaints via notifier.
class _SmoothSignaturePainter extends CustomPainter {
  _SmoothSignaturePainter({required this.notifier}) : super(repaint: notifier);

  final _StrokesNotifier notifier;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1A1A2E)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    void drawStroke(List<Offset> points) {
      if (points.length < 2) return;
      final path = Path();
      path.moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        if (i + 1 < points.length) {
          final mid = Offset(
            (points[i].dx + points[i + 1].dx) / 2,
            (points[i].dy + points[i + 1].dy) / 2,
          );
          path.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
        } else {
          path.lineTo(points[i].dx, points[i].dy);
        }
      }
      canvas.drawPath(path, paint);
    }

    for (final stroke in notifier.strokes) {
      drawStroke(stroke);
    }
    if (notifier.currentStroke.isNotEmpty) {
      drawStroke(notifier.currentStroke);
    }
  }

  @override
  bool shouldRepaint(covariant _SmoothSignaturePainter old) => true;
}
