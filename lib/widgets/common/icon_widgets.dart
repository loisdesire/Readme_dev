import 'package:flutter/material.dart';

/// Style options for IconContainer
enum IconContainerStyle {
  circular,
  rounded,
  square,
}

/// A reusable container widget for displaying icons with consistent styling
class IconContainer extends StatelessWidget {
  final IconData icon;
  final double size;
  final double padding;
  final Color? backgroundColor;
  final Color? iconColor;
  final IconContainerStyle style;

  const IconContainer({
    super.key,
    required this.icon,
    this.size = 24,
    this.padding = 12,
    this.backgroundColor,
    this.iconColor,
    this.style = IconContainerStyle.circular,
  });

  @override
  Widget build(BuildContext context) {
    BorderRadius? borderRadius;
    switch (style) {
      case IconContainerStyle.circular:
        borderRadius = BorderRadius.circular(100);
        break;
      case IconContainerStyle.rounded:
        borderRadius = BorderRadius.circular(12);
        break;
      case IconContainerStyle.square:
        borderRadius = BorderRadius.zero;
        break;
    }

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: backgroundColor ?? const Color(0xFFF3E5F5),
        borderRadius: borderRadius,
      ),
      child: Icon(
        icon,
        size: size,
        color: iconColor ?? const Color(0xFF8E44AD),
      ),
    );
  }
}
