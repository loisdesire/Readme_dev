import 'package:flutter/material.dart';

/// Type of status badge
enum StatusBadgeType {
  notStarted,
  inProgress,
  completed,
  custom,
}

/// A reusable status badge widget with predefined styles
class StatusBadge extends StatelessWidget {
  final String text;
  final StatusBadgeType type;
  final Color? customColor;
  final Color? customTextColor;
  final double? fontSize;

  const StatusBadge({
    super.key,
    required this.text,
    required this.type,
    this.customColor,
    this.customTextColor,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;

    switch (type) {
      case StatusBadgeType.notStarted:
        backgroundColor = Colors.grey[200]!;
        textColor = Colors.grey[700]!;
        break;
      case StatusBadgeType.inProgress:
        backgroundColor = const Color(0xFFFFF3E0);
        textColor = const Color(0xFFF57C00);
        break;
      case StatusBadgeType.completed:
        backgroundColor = const Color(0xFFE8F5E9);
        textColor = const Color(0xFF2E7D32);
        break;
      case StatusBadgeType.custom:
        backgroundColor = customColor ?? Colors.grey[200]!;
        textColor = customTextColor ?? Colors.black87;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize ?? 12,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
