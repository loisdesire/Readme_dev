// League System Helper
// Determines user league tier based on total achievement points

enum League {
  bronze,
  silver,
  gold,
  diamond,
}

class LeagueHelper {
  /// Get league for a given total points amount
  static League getLeague(int totalPoints) {
    // Reduced thresholds for local testing:
    // Bronze: 0-5, Silver: 6-15, Gold: 16-30, Diamond: 31+
    if (totalPoints >= 31) {
      return League.diamond;
    } else if (totalPoints >= 16) {
      return League.gold;
    } else if (totalPoints >= 6) {
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
      case League.diamond:
        return 0xFFB9F2FF; // Diamond blue
    }
  }

  /// Get points needed for next league
  static int getPointsToNextLeague(int currentPoints) {
    final league = getLeague(currentPoints);
    switch (league) {
      case League.bronze:
        return 6 - currentPoints; // to Silver (6)
      case League.silver:
        return 16 - currentPoints; // to Gold (16)
      case League.gold:
        return 31 - currentPoints; // to Diamond (31)
      case League.diamond:
        return 0; // Max league
    }
  }

  static int getLeagueStartPoints(League league) {
    switch (league) {
      case League.bronze:
        return 0;
      case League.silver:
        return 6;
      case League.gold:
        return 16;
      case League.diamond:
        return 31;
    }
  }

  static int? getNextLeagueStartPoints(League league) {
    switch (league) {
      case League.bronze:
        return 6;
      case League.silver:
        return 16;
      case League.gold:
        return 31;
      case League.diamond:
        return null;
    }
  }

  /// Returns progress inside the current league as (current, total).
  /// Example: Bronze at 120 pts => (120, 500). Silver at 501 pts => (0, 1499).
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
        return '0 - 5 points';
      case League.silver:
        return '6 - 15 points';
      case League.gold:
        return '16 - 30 points';
      case League.diamond:
        return '31+ points';
    }
  }

  /// Get progress percentage to next league
  static double getProgressToNextLeague(int currentPoints) {
    final league = getLeague(currentPoints);

    switch (league) {
      case League.bronze:
        return currentPoints / 5.0; // 0-5
      case League.silver:
        return (currentPoints - 6) / 9.0; // 6-15
      case League.gold:
        return (currentPoints - 16) / 14.0; // 16-30
      case League.diamond:
        return 1.0; // Max league
    }
  }
}
