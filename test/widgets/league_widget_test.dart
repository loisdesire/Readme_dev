import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/widgets/league_widget.dart';

// NOTE: LeagueWidget isn't imported/used anywhere in lib/ today (confirmed
// via grep) — dead code, same as BookCard. Covered anyway per the same
// reasoning: correctness matters if it's ever wired up.

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('LeagueWidget — full mode', () {
    testWidgets('bronze with points remaining shows a progress bar toward '
        'Silver', (tester) async {
      await tester.pumpWidget(wrap(const LeagueWidget(totalPoints: 3)));

      expect(find.text('Bronze League'), findsOneWidget);
      expect(find.text('3 points'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.textContaining('to Silver League'), findsOneWidget);
    });

    testWidgets('diamond (max league) shows "Maximum League Reached!" '
        'instead of a progress bar', (tester) async {
      await tester.pumpWidget(wrap(const LeagueWidget(totalPoints: 1500)));

      expect(find.text('Diamond League'), findsOneWidget);
      expect(find.text('Maximum League Reached!'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('showProgress: false hides the progress bar even below max '
        'league', (tester) async {
      await tester.pumpWidget(
        wrap(const LeagueWidget(totalPoints: 3, showProgress: false)),
      );

      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.textContaining('to Silver League'), findsNothing);
    });

    testWidgets(
        'regression: the restored Platinum tier renders correctly, between '
        "Gold and Diamond (an earlier commit deleted it entirely while "
        'reducing league thresholds "for local testing")', (tester) async {
      await tester.pumpWidget(wrap(const LeagueWidget(totalPoints: 800)));

      expect(find.text('Platinum League'), findsOneWidget);
      expect(find.textContaining('to Diamond League'), findsOneWidget);
    });
  });

  group('LeagueWidget — compact mode', () {
    testWidgets('shows just the league name and emoji, no points/progress',
        (tester) async {
      await tester.pumpWidget(
        wrap(const LeagueWidget(totalPoints: 400, compact: true)),
      );

      expect(find.text('Gold'), findsOneWidget);
      expect(find.textContaining('points'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });
}
