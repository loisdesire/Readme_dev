import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Reusable progress bar widget for reading progress display
class ProgressBar extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double height;
  final Color? progressColor;
  final Color? backgroundColor;
  final bool showPercentage;
  final double? percentageFontSize;

  const ProgressBar({
    super.key,
    required this.progress,
    this.height = 4,
    this.progressColor,
    this.backgroundColor,
    this.showPercentage = false,
    this.percentageFontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveProgressColor = progressColor ?? AppTheme.primaryPurple;
    final effectiveBackgroundColor = backgroundColor ?? Colors.grey[300]!;

    if (!showPercentage) {
      return _buildProgressBar(effectiveProgressColor, effectiveBackgroundColor);
    }

    return Row(
      children: [
        Expanded(
          child: _buildProgressBar(effectiveProgressColor, effectiveBackgroundColor),
        ),
        const SizedBox(width: 8),
        Text(
          '${(progress * 100).round()}%',
          style: TextStyle(
            fontSize: percentageFontSize,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(Color progressColor, Color backgroundColor) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: progressColor,
            borderRadius: BorderRadius.circular(height / 2),
          ),
        ),
      ),
    );
  }
}