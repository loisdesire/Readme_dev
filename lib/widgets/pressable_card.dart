import 'package:flutter/material.dart';

/// A small reusable widget that provides a Material ripple and a tiny
/// scale-on-press animation. Use this to wrap tappable cards, list items,
/// or quiz options to give consistent child-friendly feedback.
class PressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final EdgeInsets? padding;

  const PressableCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
    this.padding,
  });

  @override
  State<PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<PressableCard> with SingleTickerProviderStateMixin {
  double _scale = 1.0;
  static const double _pressedScale = 0.98;
  static const Duration _duration = Duration(milliseconds: 110);

  void _onTapDown(TapDownDetails _) {
    setState(() => _scale = _pressedScale);
  }

  void _onTapUp(TapUpDetails _) {
    setState(() => _scale = 1.0);
  }

  void _onTapCancel() {
    setState(() => _scale = 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = widget.borderRadius ?? BorderRadius.circular(12);

    return AnimatedScale(
      scale: _scale,
      duration: _duration,
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: widget.onTap,
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          child: widget.padding != null
              ? Padding(padding: widget.padding!, child: widget.child)
              : widget.child,
        ),
      ),
    );
  }
}
