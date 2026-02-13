import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String avatar;
  final String fallbackAvatar;
  final double size;
  final double fontSize;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;

  const UserAvatar({
    super.key,
    required this.avatar,
    this.fallbackAvatar = '🧒',
    this.size = 50,
    this.fontSize = 24,
    this.backgroundColor = const Color(0x1A8E44AD),
    this.borderColor = const Color(0xFF8E44AD),
    this.borderWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    final displayAvatar = avatar.trim().isEmpty ? fallbackAvatar : avatar;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
      ),
      child: Center(
        child: Text(
          displayAvatar,
          style: TextStyle(fontSize: fontSize),
        ),
      ),
    );
  }
}
