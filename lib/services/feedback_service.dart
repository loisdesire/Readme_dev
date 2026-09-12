import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:math';

/// Centralized lightweight FeedbackService for sounds, haptics and event
/// notifications. Converted to a ChangeNotifier so UI can listen reactively.
class FeedbackService extends ChangeNotifier {
  FeedbackService._internal();
  static final FeedbackService instance = FeedbackService._internal();

  /// Whether feedback (sounds/haptics/visuals) is enabled.
  bool enabled = true;

  static const String _prefsKey = 'feedback_enabled_v1';

  /// Load persisted preference. Call once during app initialization.
  Future<void> loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey(_prefsKey)) {
        enabled = prefs.getBool(_prefsKey) ?? true;
      }
    } catch (_) {
      // ignore errors and keep default
    }
    notifyListeners();
  }

  /// Notifier UI can listen to for visual events (confetti, chime, etc.)
  final ValueNotifier<FeedbackEvent> event = ValueNotifier(FeedbackEvent.none);

  // Lazy: constructing an AudioPlayer triggers the plugin's own async
  // platform-channel initialization as a side effect. FeedbackService is
  // touched from ~20 screens for .enabled/.playTap()/.setEnabled() alone,
  // none of which need audio — deferring construction to the first actual
  // chime means those call sites don't pay for (or risk an error from)
  // audio plugin init they never asked for.
  AudioPlayer? _audioPlayerInstance;
  AudioPlayer get _audioPlayer => _audioPlayerInstance ??= AudioPlayer();
  final _rand = Random();
  final List<String> _chimeAssets = [
    'sounds/chime_short.mp3',
    'sounds/chime_short_2.mp3',
    'sounds/chime_short_3.mp3',
  ];

  /// Attempt to play a bundled chime chosen randomly. If playback fails,
  /// fall back to system sound.
  Future<void> _playChimeAsset() async {
    try {
      final idx = _rand.nextInt(_chimeAssets.length);
      final assetPath = _chimeAssets[idx];
  await _audioPlayer.play(AssetSource(assetPath));
    } catch (_) {
      try {
        SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  void setEnabled(bool v) {
    enabled = v;
    // persist (fire-and-forget; catchError covers the async failure path
    // that a synchronous try/catch here never would)
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setBool(_prefsKey, v))
        .catchError((_) => false);
    notifyListeners();
  }

  void playTap() {
    if (!enabled) return;
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  void playChime() {
    if (!enabled) return;
    _playChimeAsset();
    event.value = FeedbackEvent.chime;
  }

  void playSuccess() {
    if (!enabled) return;
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
    event.value = FeedbackEvent.success;
  }

  /// Notifies listeners that UI should show confetti. UI must subscribe to
  /// [event] and clear the event after handling if desired.
  void showConfetti() {
    if (!enabled) return;
    event.value = FeedbackEvent.confetti;
  }
}

enum FeedbackEvent { none, chime, success, confetti }
