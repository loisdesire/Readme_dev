import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/screens/child/league_promotion_screen.dart';
import 'package:readme_app/utils/league_helper.dart';

Widget wrap(Widget child) => MaterialApp(home: child);

// Same confetti-related pumping caveat as
// weekly_challenge_celebration_screen_test.dart: only a small, fixed
// number of short pumps, never pumpAndSettle() or a long bounded-pump
// loop.
Future<void> pumpFew(WidgetTester tester, [int times = 12]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('shows the league name and point total', (tester) async {
    await tester.pumpWidget(wrap(const LeaguePromotionScreen(
      newLeague: League.gold,
      totalPoints: 350,
    )));
    await pumpFew(tester);

    expect(find.text('League Promotion!'), findsOneWidget);
    expect(find.text('Gold League'), findsOneWidget);
    expect(find.text('350 points'), findsOneWidget);
    expect(find.text('You\'ve been promoted to Gold League!'), findsOneWidget);
  });

  testWidgets('every league renders its own icon without crashing',
      (tester) async {
    for (final league in League.values) {
      await tester.pumpWidget(wrap(LeaguePromotionScreen(
        newLeague: league,
        totalPoints: 100,
      )));
      await pumpFew(tester);

      expect(find.byIcon(LeagueHelper.getLeagueIcon(league)), findsWidgets);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('tapping "Continue" pops the screen', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LeaguePromotionScreen(
                  newLeague: League.silver,
                  totalPoints: 150,
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await pumpFew(tester);

    // The button sits below the fold at the default 800x600 test
    // viewport (this whole card is inside a SingleChildScrollView) — a
    // bare tap() would silently miss it.
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await pumpFew(tester);

    expect(find.text('open'), findsOneWidget);
    expect(find.byType(LeaguePromotionScreen), findsNothing);
  });

  testWidgets('does not overflow on a narrow phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(wrap(const LeaguePromotionScreen(
      newLeague: League.diamond,
      totalPoints: 999999,
    )));
    await pumpFew(tester);

    expect(tester.takeException(), isNull);
  });
}
