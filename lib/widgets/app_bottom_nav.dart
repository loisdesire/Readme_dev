import 'package:flutter/material.dart';
import '../widgets/pressable_card.dart';
import '../services/feedback_service.dart';

/// A small global bottom navigation bar used across child screens.
/// - `activeIndex` controls which tab is highlighted (0: Home, 1: Library, 2: Settings)
/// - `onTap` is called with the tapped index.
class AppBottomNav extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int>? onTap;

  const AppBottomNav({super.key, this.activeIndex = 0, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80, // Ensure minimum height
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F5),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _navItem(context, 0, Icons.home, 'Home'),
          _navItem(context, 1, Icons.library_books, 'Library'),
          _navItem(context, 2, Icons.settings, 'Settings'),
        ],
      ),
    );
  }

  Widget _navItem(BuildContext context, int idx, IconData icon, String label) {
    final isActive = idx == activeIndex;
    final color = isActive ? const Color(0xFF8E44AD) : Colors.grey;

    return PressableCard(
      onTap: () {
        FeedbackService.instance.playTap();
        onTap?.call(idx);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}
