import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Reusable status badge widget for progress, completion, and status indicators
class StatusBadge extends StatelessWidget {
  final String text;
  final StatusBadgeType type;
  final double? fontSize;
  final FontWeight? fontWeight;

  const StatusBadge({
    super.key,
    required this.text,
    required this.type,
    this.fontSize = 12,
    this.fontWeight = FontWeight.w500,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: _getTextColor(),
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (type) {
      case StatusBadgeType.completed:
        return AppTheme.greenOpaque10;
      case StatusBadgeType.inProgress:
        return AppTheme.primaryPurpleOpaque10;
      case StatusBadgeType.notStarted:
        return AppTheme.primaryPurpleOpaque10;
      case StatusBadgeType.neutral:
        return Colors.grey[100]!;
    }
  }

  Color _getTextColor() {
    switch (type) {
      case StatusBadgeType.completed:
        return AppTheme.green;
      case StatusBadgeType.inProgress:
        return AppTheme.primaryPurple;
      case StatusBadgeType.notStarted:
        return AppTheme.primaryPurple;
      case StatusBadgeType.neutral:
        return Colors.grey[600]!;
    }
  }
}

enum StatusBadgeType {
  completed,
  inProgress, 
  notStarted,
  neutral,
}