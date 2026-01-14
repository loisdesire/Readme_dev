import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Reusable button for book progress actions (Start, Continue, Re-read)
/// Uses filled styling with consistent colors based on progress state
class ProgressButton extends StatefulWidget {
  final String text;
  final ProgressButtonType type;
  final VoidCallback? onPressed;
  final double? fontSize;
  final FontWeight? fontWeight;

  const ProgressButton({
    super.key,
    required this.text,
    required this.type,
    this.onPressed,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w600,
  });

  @override
  State<ProgressButton> createState() => _ProgressButtonState();
}

class _ProgressButtonState extends State<ProgressButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getBackgroundColor() {
    switch (widget.type) {
      case ProgressButtonType.completed:
        return AppTheme.primaryPurple;
      case ProgressButtonType.inProgress:
        return AppTheme.primaryPurple;
      case ProgressButtonType.notStarted:
        return AppTheme.primaryPurple;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onPressed,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _getBackgroundColor(),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Center(
            child: Text(
              widget.text,
              style: AppTheme.buttonText.copyWith(
                fontSize: widget.fontSize,
                fontWeight: widget.fontWeight,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum ProgressButtonType {
  completed,    // Re-read (purple)
  inProgress,   // Continue (purple)
  notStarted,   // Start (purple)
}
