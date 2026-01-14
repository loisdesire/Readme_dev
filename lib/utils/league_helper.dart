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
  /// Get league for a given total points amount
  static League getLeague(int totalPoints) {
    if (totalPoints >= 10001) {
      return League.diamond;
    } else if (totalPoints >= 5001) {
      return League.platinum;
    } else if (totalPoints >= 2001) {
      return League.gold;
    } else if (totalPoints >= 501) {
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
        return 501 - currentPoints;
      case League.silver:
        return 2001 - currentPoints;
      case League.gold:
        return 5001 - currentPoints;
      case League.platinum:
        return 10001 - currentPoints;
      case League.diamond:
        return 0; // Max league
    }
  }

  /// Get league range description
  static String getLeagueRange(League league) {
    switch (league) {
      case League.bronze:
        return '0 - 500 points';
      case League.silver:
        return '501 - 2,000 points';
      case League.gold:
        return '2,001 - 5,000 points';
      case League.platinum:
        return '5,001 - 10,000 points';
      case League.diamond:
        return '10,001+ points';
    }
  }

  /// Get progress percentage to next league
  static double getProgressToNextLeague(int currentPoints) {
    final league = getLeague(currentPoints);
    
    switch (league) {
      case League.bronze:
        return currentPoints / 500.0; // 0-500
      case League.silver:
        return (currentPoints - 501) / 1499.0; // 501-2000
      case League.gold:
        return (currentPoints - 2001) / 2999.0; // 2001-5000
      case League.platinum:
        return (currentPoints - 5001) / 4999.0; // 5001-10000
      case League.diamond:
        return 1.0; // Max league
    }
  }
}
