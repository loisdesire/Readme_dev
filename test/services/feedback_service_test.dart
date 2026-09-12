import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:readme_app/services/feedback_service.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  // FeedbackService.instance is a true singleton (no test constructor —
  // AudioPlayer/HapticFeedback/SystemSound have no fake package either),
  // so every test resets the bits of shared state it touches rather than
  // getting a fresh instance. The audioplayers plugin's own channels are
  // stubbed so playChime (the one path that actually constructs an
  // AudioPlayer) doesn't hit a real MissingPluginException.
  setUpAll(() {
    for (final channel in ['xyz.luan/audioplayers', 'xyz.luan/audioplayers.global']) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (call) async => null,
      );
    }
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FeedbackService.instance.enabled = true;
    FeedbackService.instance.event.value = FeedbackEvent.none;
  });

  group('FeedbackService — enabled gate', () {
    test('when disabled, playChime/playSuccess/showConfetti are all no-ops',
        () {
      FeedbackService.instance.enabled = false;

      FeedbackService.instance.playChime();
      expect(FeedbackService.instance.event.value, FeedbackEvent.none);

      FeedbackService.instance.playSuccess();
      expect(FeedbackService.instance.event.value, FeedbackEvent.none);

      FeedbackService.instance.showConfetti();
      expect(FeedbackService.instance.event.value, FeedbackEvent.none);
    });

    test('when enabled, each method fires its own event', () {
      FeedbackService.instance.enabled = true;

      FeedbackService.instance.playChime();
      expect(FeedbackService.instance.event.value, FeedbackEvent.chime);

      FeedbackService.instance.playSuccess();
      expect(FeedbackService.instance.event.value, FeedbackEvent.success);

      FeedbackService.instance.showConfetti();
      expect(FeedbackService.instance.event.value, FeedbackEvent.confetti);
    });

    test('playTap does not throw when disabled or enabled (haptics/system '
        'sound are platform calls with no test double, but both are '
        "wrapped so a missing plugin can't crash the caller)", () {
      FeedbackService.instance.enabled = false;
      expect(() => FeedbackService.instance.playTap(), returnsNormally);
      FeedbackService.instance.enabled = true;
      expect(() => FeedbackService.instance.playTap(), returnsNormally);
    });
  });

  group('FeedbackService.setEnabled', () {
    test('updates enabled and notifies listeners', () {
      var notified = 0;
      void listener() => notified++;
      FeedbackService.instance.addListener(listener);
      addTearDown(() => FeedbackService.instance.removeListener(listener));

      FeedbackService.instance.setEnabled(false);

      expect(FeedbackService.instance.enabled, isFalse);
      expect(notified, 1);
    });
  });

  group('FeedbackService.loadPreferences', () {
    test('respects a previously-saved disabled preference', () async {
      SharedPreferences.setMockInitialValues({'feedback_enabled_v1': false});

      await FeedbackService.instance.loadPreferences();

      expect(FeedbackService.instance.enabled, isFalse);
    });

    test('defaults to enabled when nothing has been saved before', () async {
      SharedPreferences.setMockInitialValues({});

      await FeedbackService.instance.loadPreferences();

      expect(FeedbackService.instance.enabled, isTrue);
    });
  });
}
