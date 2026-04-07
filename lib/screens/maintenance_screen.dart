import 'package:flutter/material.dart';

import '../services/remote_config_service.dart';
import '../theme/app_colors.dart';

/// Full-screen blocker shown when maintenance mode is enabled via Remote Config.
class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rc = RemoteConfigService.instance;

    return Scaffold(
      backgroundColor: context.cs.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amber.shade50,
                  border: Border.all(color: Colors.amber.shade200, width: 2),
                ),
                child: Icon(
                  Icons.construction_rounded,
                  color: Colors.amber.shade800,
                  size: 48,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                rc.maintenanceTitle,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: context.cs.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Text(
                rc.maintenanceMessage,
                style: TextStyle(
                  fontSize: 15,
                  color: context.cs.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text(
                    'Try Again',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.cs.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: const BorderSide(color: kPrimary),
                  ),
                  onPressed: () async {
                    await RemoteConfigService.instance.refetch();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
