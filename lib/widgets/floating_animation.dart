import 'package:flutter/material.dart';

/// Floating/bobbing animation for elements that should appear to float
/// Moves up and down smoothly for a floating effect
class FloatingAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double offset;

  const FloatingAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 2000),
    this.offset = 0.5,
  });

  @override
  State<FloatingAnimation> createState() => _FloatingAnimationState();
}

class _FloatingAnimationState extends State<FloatingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();

    _floatAnimation = TweenSequence<Offset>([
      TweenSequenceItem<Offset>(
        tween: Tween<Offset>(begin: Offset.zero, end: Offset(0, -widget.offset)),
        weight: 50.0,
      ),
      TweenSequenceItem<Offset>(
        tween: Tween<Offset>(begin: Offset(0, -widget.offset), end: Offset.zero),
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
    return SlideTransition(
      position: _floatAnimation,
      child: widget.child,
    );
  }
}
