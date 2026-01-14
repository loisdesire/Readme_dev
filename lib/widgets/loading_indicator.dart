import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Centralized loading indicators to replace duplicated CircularProgressIndicator widgets
class LoadingIndicator extends StatelessWidget {
  final Color? color;
  final double size;
  final double strokeWidth;

  const LoadingIndicator({
    super.key,
    this.color,
    this.size = 40,
    this.strokeWidth = 4,
  });

  const LoadingIndicator.small({
    super.key,
    this.color,
    this.size = 20,
    this.strokeWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: strokeWidth,
          valueColor: AlwaysStoppedAnimation<Color>(
            color ?? AppTheme.primaryPurple,
          ),
        ),
      ),
    );
  }
}

/// Full-screen centered loading indicator
class LoadingScreen extends StatelessWidget {
  final String? message;

  const LoadingScreen({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const LoadingIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: AppTheme.body.copyWith(color: AppTheme.textGray),
            ),
          ],
        ],
      ),
    );
  }
}
