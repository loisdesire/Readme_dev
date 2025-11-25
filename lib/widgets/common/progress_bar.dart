import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// A reusable progress bar widget with customizable styling
class ProgressBar extends StatelessWidget {
  final double progress; // 0.0 to 100.0
  final Color? progressColor;
  final Color? backgroundColor;
  final double height;
  final bool showPercentage;
  final double? percentageFontSize;

  const ProgressBar({
    super.key,
    required this.progress,
    this.progressColor,
    this.backgroundColor,
    this.height = 6,
    this.showPercentage = false,
    this.percentageFontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: LinearProgressIndicator(
            value: progress / 100,
            minHeight: height,
            backgroundColor: backgroundColor ?? Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              progressColor ?? const Color(0xFF8E44AD),
            ),
          ),
        ),
        if (showPercentage) ...[
          const SizedBox(height: 4),
          Text(
            '${progress.toInt()}%',
            style: AppTheme.bodySmall.copyWith(
              fontSize: percentageFontSize,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
