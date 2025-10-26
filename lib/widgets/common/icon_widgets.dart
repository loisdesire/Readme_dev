import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Reusable icon container with consistent purple theming
class IconContainer extends StatelessWidget {
  final IconData icon;
  final double size;
  final double padding;
  final IconContainerStyle style;
  final Color? customColor;
  final Color? customBackgroundColor;

  const IconContainer({
    super.key,
    required this.icon,
    this.size = 24,
    this.padding = 12,
    this.style = IconContainerStyle.circular,
    this.customColor,
    this.customBackgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = customColor ?? AppTheme.primaryPurple;
    final effectiveBackgroundColor = customBackgroundColor ?? AppTheme.primaryPurpleOpaque10;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: effectiveBackgroundColor,
        shape: style == IconContainerStyle.circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: style == IconContainerStyle.rounded 
          ? BorderRadius.circular(8) 
          : null,
      ),
      child: Icon(
        icon,
        size: size,
        color: effectiveIconColor,
      ),
    );
  }
}

enum IconContainerStyle {
  circular,
  rounded,
}

/// Widget for stat display with icon, value and label
class StatDisplay extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool isColumn;

  const StatDisplay({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.isColumn = true,
  });

  @override
  Widget build(BuildContext context) {
    if (isColumn) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconContainer(icon: icon, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTheme.heading.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(color: Colors.grey),
          ),
        ],
      );
    }

    return Row(
      children: [
        IconContainer(icon: icon, size: 20, padding: 8),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: AppTheme.bodyMedium),
              Text(label, style: AppTheme.bodySmall.copyWith(color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }
}