import 'package:flutter/material.dart';
import 'child_home_screen.dart';
import 'library_screen.dart';
import 'settings_screen.dart';
import '../../widgets/app_bottom_nav.dart';

/// Root container for the child experience. Uses an IndexedStack so each
/// tab preserves its state when switching.

/// A global key and static helper to allow switching tabs in ChildRoot from anywhere.
class ChildRootNav {
  static final GlobalKey<ChildRootState> rootKey = GlobalKey<ChildRootState>();
  static ChildRootState? _currentState;

  static void switchTab(int idx) {
    _currentState?.switchTab(idx);
  }

  static void _registerState(ChildRootState state) {
    _currentState = state;
  }

  static void _unregisterState() {
    _currentState = null;
  }
}

class ChildRoot extends StatefulWidget {
  const ChildRoot({super.key});

  @override
  State<ChildRoot> createState() => ChildRootState();
}

class ChildRootState extends State<ChildRoot> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    ChildHomeScreen(),
    LibraryScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    ChildRootNav._registerState(this);
  }

  @override
  void dispose() {
    ChildRootNav._unregisterState();
    super.dispose();
  }

  void _onTap(int idx) {
    if (idx == _currentIndex) return;
    setState(() => _currentIndex = idx);
  }

  void switchTab(int idx) {
    if (idx == _currentIndex) return;
    setState(() => _currentIndex = idx);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: SafeArea(
        child: AppBottomNav(
          activeIndex: _currentIndex,
          onTap: _onTap,
        ),
      ),
    );
  }
}
