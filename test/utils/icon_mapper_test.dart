import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/utils/icon_mapper.dart';

void main() {
  group('IconMapper.getEmoji', () {
    test('maps every weekly-challenge identifier to a distinct emoji', () {
      // One per WeeklyChallengeService.challengeRotation key — distinct
      // so the weekly challenge card's 12 challenge types still read as
      // visually different from each other, the same intent
      // getChallengeColor's varied tints served before this card moved
      // back to emoji (see SECURITY.md).
      const keys = [
        'menu_book',
        'calendar_today',
        'timer',
        'track_changes',
        'local_fire_department',
        'auto_stories',
        'school',
        'bolt',
        'star',
        'library_books',
        'palette',
        'fitness_center',
      ];

      final emoji = keys.map(IconMapper.getEmoji).toList();

      for (final e in emoji) {
        expect(e, isNotEmpty);
      }
      expect(emoji.toSet().length, keys.length,
          reason: 'every known challenge key should map to its own emoji');
    });

    test('falls back to 🏆 for an unrecognized identifier', () {
      expect(IconMapper.getEmoji('not_a_real_key'), '🏆');
      expect(IconMapper.getEmoji(''), '🏆');
    });
  });
}
