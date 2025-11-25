import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// A reusable stat display widget for showing metrics with icon, value, and label
class StatDisplay extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool isColumn;
  final Color? iconColor;
  final Color? valueColor;
  final Color? labelColor;

  const StatDisplay({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.isColumn = false,
    this.iconColor,
    this.valueColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    if (isColumn) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: iconColor ?? const Color(0xFF8E44AD),
            size: 20,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTheme.body.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(
              color: labelColor ?? Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: iconColor ?? const Color(0xFF8E44AD),
          size: 20,
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: AppTheme.body.copyWith(
                fontWeight: FontWeight.bold,
                color: valueColor ?? Colors.black,
              ),
            ),
            Text(
              label,
              style: AppTheme.bodySmall.copyWith(
                color: labelColor ?? Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
