import 'package:flutter/material.dart';
import '../screens/upgrade_screen.dart';
import '../services/plan_service.dart';

class LimitReachedDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? featureName;

  const LimitReachedDialog({
    super.key,
    required this.title,
    required this.message,
    this.featureName,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    String? featureName,
  }) {
    return showDialog(
      context: context,
      builder: (_) => LimitReachedDialog(
        title: title,
        message: message,
        featureName: featureName,
      ),
    );
  }

  /// Tries to extract a usage fraction from the message (e.g. "5/20").
  /// Returns null if no fraction is found.
  double? _parseUsageFraction() {
    final regex = RegExp(r'(\d+)\s*/\s*(\d+)');
    final match = regex.firstMatch(message);
    if (match == null) return null;
    final used = int.tryParse(match.group(1)!) ?? 0;
    final max = int.tryParse(match.group(2)!) ?? 1;
    if (max <= 0) return null;
    return (used / max).clamp(0.0, 1.0);
  }

  String _unlockPlanLabel() {
    if (featureName == null) return 'a paid plan';
    final plan = PlanService.cheapestPlanFor(
      featureName!.toLowerCase().replaceAll(' ', '_'),
    );
    return PlanService.limits[plan]!.displayName;
  }

  @override
  Widget build(BuildContext context) {
    final usageFraction = _parseUsageFraction();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.lock_outline, color: Colors.amber),
          const SizedBox(width: 8),
          Expanded(child: Text(title)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          if (usageFraction != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: usageFraction,
                minHeight: 8,
                backgroundColor: const Color(0xFFE5E7EB),
                valueColor: AlwaysStoppedAnimation(
                  usageFraction >= 1.0 ? const Color(0xFFEF4444) : const Color(0xFF4361EE),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(usageFraction * 100).toStringAsFixed(0)}% used',
              style: const TextStyle(fontSize: 12, color: Color(0xFF5B7A9A)),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Unlock with ${_unlockPlanLabel()} plan',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6366F1),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UpgradeScreen(featureName: featureName),
              ),
            );
          },
          child: const Text('Upgrade'),
        ),
      ],
    );
  }
}
