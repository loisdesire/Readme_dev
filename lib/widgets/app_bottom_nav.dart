import 'package:flutter/material.dart';
import '../screens/child/child_home_screen.dart';
import '../screens/child/library_screen.dart';
import '../screens/child/settings_screen.dart';
import '../services/feedback_service.dart';
import 'pressable_card.dart';

enum NavTab { home, library, settings }

class AppBottomNav extends StatelessWidget {
  final NavTab currentTab;
  
  const AppBottomNav({
    super.key,
    required this.currentTab,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
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
          _buildNavItem(
            Icons.home,
            'Home',
            currentTab == NavTab.home,
            () => _navigateToHome(context),
          ),
          _buildNavItem(
            Icons.library_books,
            'Library',
            currentTab == NavTab.library,
            () => _navigateToLibrary(context),
          ),
          _buildNavItem(
            Icons.settings,
            'Settings',
            currentTab == NavTab.settings,
            () => _navigateToSettings(context),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return PressableCard(
      onTap: () {
        FeedbackService.instance.playTap();
        if (!isActive) {
          onTap();
        }
      },
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? const Color(0xFF8E44AD) : Colors.grey,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? const Color(0xFF8E44AD) : Colors.grey,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToHome(BuildContext context) {
    if (currentTab != NavTab.home) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const ChildHomeScreen(),
        ),
      );
    }
  }

  void _navigateToLibrary(BuildContext context) {
    if (currentTab != NavTab.library) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const LibraryScreen(),
        ),
      );
    }
  }

  void _navigateToSettings(BuildContext context) {
    if (currentTab != NavTab.settings) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const SettingsScreen(),
        ),
      );
    }
  }
}
