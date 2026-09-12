import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/utils/league_helper.dart';

void main() {
  group('LeagueHelper.getLeague — boundaries', () {
    test('bronze: 0 up to (but not including) 100', () {
      expect(LeagueHelper.getLeague(0), League.bronze);
      expect(LeagueHelper.getLeague(99), League.bronze);
    });

    test('silver: 100 up to 299', () {
      expect(LeagueHelper.getLeague(100), League.silver);
      expect(LeagueHelper.getLeague(299), League.silver);
    });

    test('gold: 300 up to 699', () {
      expect(LeagueHelper.getLeague(300), League.gold);
      expect(LeagueHelper.getLeague(699), League.gold);
    });

    test('platinum: 700 up to 1499 — the tier an earlier "reduced for local '
        'testing" commit deleted entirely', () {
      expect(LeagueHelper.getLeague(700), League.platinum);
      expect(LeagueHelper.getLeague(1499), League.platinum);
    });

    test('diamond: 1500+, with no upper bound', () {
      expect(LeagueHelper.getLeague(1500), League.diamond);
      expect(LeagueHelper.getLeague(999999), League.diamond);
    });
  });

  group('LeagueHelper.getPointsToNextLeague', () {
    test('counts down correctly within each league', () {
      expect(LeagueHelper.getPointsToNextLeague(0), 100);
      expect(LeagueHelper.getPointsToNextLeague(90), 10);
      expect(LeagueHelper.getPointsToNextLeague(100), 200); // to gold (300)
      expect(LeagueHelper.getPointsToNextLeague(300), 400); // to platinum (700)
      expect(LeagueHelper.getPointsToNextLeague(700), 800); // to diamond (1500)
    });

    test('diamond (max league) needs 0 more points', () {
      expect(LeagueHelper.getPointsToNextLeague(1500), 0);
      expect(LeagueHelper.getPointsToNextLeague(5000), 0);
    });
  });

  group('LeagueHelper.getCurrentLeagueProgress', () {
    test('reports (current, total) within the league\'s own range', () {
      final progress = LeagueHelper.getCurrentLeagueProgress(40);
      expect(progress.current, 40);
      expect(progress.total, 99); // bronze spans 0-99
    });

    test('clamps current to the league\'s total, never exceeding it', () {
      // getLeague(150) is silver, but pass a point value inconsistent with
      // that on purpose isn't representable here — instead verify the
      // clamp at the top edge of a league.
      final progress = LeagueHelper.getCurrentLeagueProgress(299);
      expect(progress.current, lessThanOrEqualTo(progress.total));
    });

    test('diamond (max league) reports as fully complete', () {
      final progress = LeagueHelper.getCurrentLeagueProgress(2000);
      expect(progress.current, 1);
      expect(progress.total, 1);
    });
  });

  group('LeagueHelper.getProgressToNextLeague', () {
    test('0.0 at the start of a league, approaching 1.0 near the next',
        () {
      expect(LeagueHelper.getProgressToNextLeague(0), 0.0);
      expect(LeagueHelper.getProgressToNextLeague(300), 0.0); // start of gold
      expect(LeagueHelper.getProgressToNextLeague(699), closeTo(1.0, 0.01));
    });

    test('diamond (max league) is always 1.0', () {
      expect(LeagueHelper.getProgressToNextLeague(1500), 1.0);
      expect(LeagueHelper.getProgressToNextLeague(999999), 1.0);
    });
  });

  group('LeagueHelper.getLeagueRange', () {
    test('describes each tier\'s point span, including the restored '
        'Platinum tier', () {
      expect(LeagueHelper.getLeagueRange(League.bronze), '0 - 99 points');
      expect(LeagueHelper.getLeagueRange(League.silver), '100 - 299 points');
      expect(LeagueHelper.getLeagueRange(League.gold), '300 - 699 points');
      expect(LeagueHelper.getLeagueRange(League.platinum), '700 - 1499 points');
      expect(LeagueHelper.getLeagueRange(League.diamond), '1500+ points');
    });
  });

  group('LeagueHelper.getLeagueName/getLeagueIcon/getLeagueColor', () {
    test('every league (including platinum) has a name, icon, and color',
        () {
      for (final league in League.values) {
        expect(LeagueHelper.getLeagueName(league), isNotEmpty);
        expect(LeagueHelper.getLeagueIcon(league), isNotNull);
        expect(LeagueHelper.getLeagueColor(league), greaterThan(0));
      }
    });
  });
}
