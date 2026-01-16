import 'package:flutter/material.dart';

/// Pulse/breathing animation for badges, notifications, and important elements
/// Opacity gently pulses 1.0 -> 0.6 -> 1.0
class PulseAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double minOpacity;

  const PulseAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
    this.minOpacity = 0.6,
  });

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();

    _opacityAnimation = Tween<double>(begin: 1.0, end: widget.minOpacity)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeInOut,
          ),
        )
        .drive(
          Tween<double>(begin: 1.0, end: widget.minOpacity),
        );

    // Make it pulse properly (1.0 -> 0.6 -> 1.0)
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.0, end: widget.minOpacity),
        weight: 50.0,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: widget.minOpacity, end: 1.0),
        weight: 50.0,
      ),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: widget.child,
    );
  }
}
