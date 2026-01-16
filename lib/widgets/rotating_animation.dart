import 'package:flutter/material.dart';

/// Rotation animation for loading spinners and refresh icons
/// Continuously rotates 360 degrees
class RotatingAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final bool autoStart;

  const RotatingAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(seconds: 2),
    this.autoStart = true,
  });

  @override
  State<RotatingAnimation> createState() => _RotatingAnimationState();
}

class _RotatingAnimationState extends State<RotatingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    if (widget.autoStart) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: widget.child,
    );
  }
}
