// League System Helper
// Determines user league tier based on total achievement points

enum League {
  bronze,
  silver,
  gold,
  platinum,
  diamond,
}

class LeagueHelper {
  // Thresholds, chosen against the app's actual known point sources
  // (daily quests: up to 10/day; book quizzes: 1-5 each) so a regularly
  // engaged reader climbs the whole ladder over roughly a school year,
  // not in days (an earlier "reduced for local testing" commit shipped
  // by accident — Diamond was reachable at 31 points) and not over
  // several years (the original values before that: Diamond at 10,001).
  // Bronze: 0-99, Silver: 100-299, Gold: 300-699, Platinum: 700-1499,
  // Diamond: 1500+
  static const int _silverStart = 100;
  static const int _goldStart = 300;
  static const int _platinumStart = 700;
  static const int _diamondStart = 1500;

  /// Get league for a given total points amount
  static League getLeague(int totalPoints) {
    if (totalPoints >= _diamondStart) {
      return League.diamond;
    } else if (totalPoints >= _platinumStart) {
      return League.platinum;
    } else if (totalPoints >= _goldStart) {
      return League.gold;
    } else if (totalPoints >= _silverStart) {
      return League.silver;
    } else {
      return League.bronze;
    }
  }

  /// Get league name as string
  static String getLeagueName(League league) {
    switch (league) {
      case League.bronze:
        return 'Bronze';
      case League.silver:
        return 'Silver';
      case League.gold:
        return 'Gold';
      case League.platinum:
        return 'Platinum';
      case League.diamond:
        return 'Diamond';
    }
  }

  /// Get league emoji
  static String getLeagueEmoji(League league) {
    switch (league) {
      case League.bronze:
        return '🥉';
      case League.silver:
        return '🥈';
      case League.gold:
        return '🥇';
      case League.platinum:
        return '💎';
      case League.diamond:
        return '👑';
    }
  }

  /// Get league color
  static int getLeagueColor(League league) {
    switch (league) {
      case League.bronze:
        return 0xFFCD7F32; // Bronze color
      case League.silver:
        return 0xFFC0C0C0; // Silver color
      case League.gold:
        return 0xFFFFD700; // Gold color
      case League.platinum:
        return 0xFFE5E4E2; // Platinum color
      case League.diamond:
        return 0xFFB9F2FF; // Diamond blue
    }
  }

  /// Get points needed for next league
  static int getPointsToNextLeague(int currentPoints) {
    final league = getLeague(currentPoints);
    switch (league) {
      case League.bronze:
        return _silverStart - currentPoints;
      case League.silver:
        return _goldStart - currentPoints;
      case League.gold:
        return _platinumStart - currentPoints;
      case League.platinum:
        return _diamondStart - currentPoints;
      case League.diamond:
        return 0; // Max league
    }
  }

  static int getLeagueStartPoints(League league) {
    switch (league) {
      case League.bronze:
        return 0;
      case League.silver:
        return _silverStart;
      case League.gold:
        return _goldStart;
      case League.platinum:
        return _platinumStart;
      case League.diamond:
        return _diamondStart;
    }
  }

  static int? getNextLeagueStartPoints(League league) {
    switch (league) {
      case League.bronze:
        return _silverStart;
      case League.silver:
        return _goldStart;
      case League.gold:
        return _platinumStart;
      case League.platinum:
        return _diamondStart;
      case League.diamond:
        return null;
    }
  }

  /// Returns progress inside the current league as (current, total).
  /// Example: Bronze at 40 pts => (40, 99). Silver at 150 pts => (50, 199).
  /// This matches the denominators used in getProgressToNextLeague.
  static ({int current, int total}) getCurrentLeagueProgress(int totalPoints) {
    final league = getLeague(totalPoints);
    final start = getLeagueStartPoints(league);
    final nextStart = getNextLeagueStartPoints(league);

    if (nextStart == null) {
      return (current: 1, total: 1);
    }

    final total = (nextStart - start) - 1;
    final current = (totalPoints - start).clamp(0, total);
    return (current: current, total: total);
  }

  /// Get league range description
  static String getLeagueRange(League league) {
    switch (league) {
      case League.bronze:
        return '0 - ${_silverStart - 1} points';
      case League.silver:
        return '$_silverStart - ${_goldStart - 1} points';
      case League.gold:
        return '$_goldStart - ${_platinumStart - 1} points';
      case League.platinum:
        return '$_platinumStart - ${_diamondStart - 1} points';
      case League.diamond:
        return '$_diamondStart+ points';
    }
  }

  /// Get progress percentage to next league
  static double getProgressToNextLeague(int currentPoints) {
    final league = getLeague(currentPoints);

    switch (league) {
      case League.bronze:
        return currentPoints / _silverStart;
      case League.silver:
        return (currentPoints - _silverStart) / (_goldStart - _silverStart - 1);
      case League.gold:
        return (currentPoints - _goldStart) / (_platinumStart - _goldStart - 1);
      case League.platinum:
        return (currentPoints - _platinumStart) / (_diamondStart - _platinumStart - 1);
      case League.diamond:
        return 1.0; // Max league
    }
  }
}
