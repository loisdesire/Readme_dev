import 'package:flutter/foundation.dart';

/// Tracks whether the initial [SplashScreen] is still on screen.
///
/// App-wide overlays that navigate on their own — currently
/// `AchievementListener`'s celebration popups — need to defer until the
/// user has actually reached a real screen. Without this, a celebration
/// for an achievement earned last session (or completed the instant
/// this session's Firestore listeners attach) gets pushed via the global
/// navigator key straight on top of the splash screen: it looks like a
/// rendering glitch, and can happen before the app has even finished
/// deciding which account/screen to show. See SECURITY.md.
class AppReadinessTracker {
  static final ValueNotifier<bool> _isSplashActive = ValueNotifier<bool>(true);

  static ValueListenable<bool> get isSplashActiveListenable => _isSplashActive;

  static bool get isSplashActive => _isSplashActive.value;

  /// Called once the splash screen has handed off to a real screen
  /// (whichever branch it took) — see `SplashScreen`'s dispose().
  static void splashFinished() {
    _isSplashActive.value = false;
  }

  /// Test-only: this is process-global state, so tests that exercise
  /// splash's dispose() (and therefore flip this permanently within the
  /// test process) need a way back to the real startup default.
  @visibleForTesting
  static void resetForTesting() {
    _isSplashActive.value = true;
  }
}
