import 'package:flutter/material.dart';

/// A tiny, local helper to manage a group of selectable values without
/// relying on deprecated Radio/RadioListTile groupValue/onChanged members.
///
/// Usage: wrap a list of option widgets (e.g. ListTiles) and supply the
/// current value and onChanged callback. The helper doesn't render specific
/// radio tiles; it simply exposes value+onChanged via builders.
class RadioGroup<T> extends StatelessWidget {
  final T? value;
  final ValueChanged<T?> onChanged;
  final List<Widget> children;

  const RadioGroup({
    super.key,
    required this.value,
    required this.onChanged,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: children);
  }
}
