import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Regression coverage for a real bug found while screenshotting
// LeaguePromotionScreen: it referenced 'assets/animations/trophy.json',
// which never existed (the actual file is
// 'assets/animations/trophy_badge_animation.json'). Lottie.asset() throws
// when the asset is missing, so this would have broken that screen for
// every user reaching a league promotion — not just cosmetically.
//
// Rather than only fixing that one call site, this scans every asset path
// literal referenced anywhere in lib/ and confirms the file actually
// exists, so the same class of typo/rename mismatch can't silently ship
// again for any asset (Lottie animation, image, SVG, sound, ...).
void main() {
  test('every asset path referenced in lib/ exists on disk', () {
    final libDir = Directory('lib');
    // Allows spaces: several real illustration filenames have them (e.g.
    // 'assets/illustrations/question page_wormies.svg') and were silently
    // skipped by an earlier version of this pattern that didn't.
    final pattern = RegExp(
        r'''assets/[A-Za-z0-9_. /-]+\.(?:json|png|jpg|jpeg|svg|mp3|gif|webp)''');
    final referenced = <String, String>{}; // path -> first file that used it

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final content = entity.readAsStringSync();
      for (final match in pattern.allMatches(content)) {
        referenced.putIfAbsent(match.group(0)!, () => entity.path);
      }
    }

    expect(referenced, isNotEmpty,
        reason: 'sanity check: the scan itself should find some assets');

    final missing = referenced.entries
        .where((e) => !File(e.key).existsSync())
        .map((e) => '${e.key} (referenced in ${e.value})')
        .toList();

    expect(missing, isEmpty,
        reason: 'these referenced asset files do not exist on disk:\n'
            '${missing.join('\n')}');
  });
}
