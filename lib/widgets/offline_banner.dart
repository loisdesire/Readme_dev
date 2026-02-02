import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/offline_service.dart';
import '../theme/app_theme.dart';

/// Global offline banner that appears at the top of any screen when offline
class OfflineBanner extends StatelessWidget {
  final Widget child;

  const OfflineBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineService>(
      builder: (context, offlineService, _) {
        return Column(
          children: [
            // Offline banner
            if (offlineService.isOffline)
              Material(
                elevation: 4,
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  color: AppTheme.warningOrange.withValues(alpha: 0.15),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_off,
                          size: 20, color: AppTheme.warningOrange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You\'re offline. Some features may not work.',
                          style: AppTheme.bodyMedium.copyWith(
                            fontSize: 13,
                            color: AppTheme.warningOrange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Main content
            Expanded(child: child),
          ],
        );
      },
    );
  }
}
