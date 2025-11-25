import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Reusable button for book progress actions (Start, Continue, Re-read)
/// Uses filled styling with consistent colors based on progress state
class ProgressButton extends StatelessWidget {
  final String text;
  final ProgressButtonType type;
  final double? fontSize;
  final FontWeight? fontWeight;

  const ProgressButton({
    super.key,
    required this.text,
    required this.type,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w600,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: AppTheme.bodyMedium.copyWith(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: Colors.white,
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (type) {
      case ProgressButtonType.completed:
        return AppTheme.primaryPurple;
      case ProgressButtonType.inProgress:
        return AppTheme.primaryPurple;
      case ProgressButtonType.notStarted:
        return AppTheme.primaryPurple;
    }
  }
}

enum ProgressButtonType {
  completed,    // Re-read (purple)
  inProgress,   // Continue (purple)
  notStarted,   // Start (purple)
}
