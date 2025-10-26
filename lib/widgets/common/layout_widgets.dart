import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Empty state widget for when lists or content areas are empty
class EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData? icon;
  final Widget? illustration;
  final Widget? actionButton;
  final double iconSize;

  const EmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon,
    this.illustration,
    this.actionButton,
    this.iconSize = 80,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Visual element (illustration or icon)
            if (illustration != null)
              illustration!
            else if (icon != null)
              Icon(
                icon,
                size: iconSize,
                color: Colors.grey[400],
              ),
            
            const SizedBox(height: 24),
            
            // Title
            Text(
              title,
              style: AppTheme.heading.copyWith(
                fontSize: 18,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 8),
            
            // Subtitle
            Text(
              subtitle,
              style: AppTheme.bodyMedium.copyWith(
                color: Colors.grey[600],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            
            // Action button
            if (actionButton != null) ...[
              const SizedBox(height: 24),
              actionButton!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Section header widget with consistent styling
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final EdgeInsets? padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.only(bottom: 15),
  });

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: AppTheme.heading.copyWith(
            fontSize: 18,
            color: AppTheme.primaryPurple,
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );

    if (padding != null) {
      return Padding(
        padding: padding!,
        child: content,
      );
    }

    return content;
  }
}