import 'package:billeasy/services/team_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Small chip/badge that shows the user's team role.
/// Only visible when the user is on a team (not solo).
class TeamBadge extends StatelessWidget {
  const TeamBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final service = TeamService.instance;
    if (service.isSolo) return const SizedBox.shrink();

    final role = service.currentRole;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        role.displayName,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: kPrimary,
        ),
      ),
    );
  }
}
