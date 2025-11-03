import 'package:flutter/material.dart';

/// Utility class for mapping achievement emoji strings to Material Icons
class IconMapper {
  /// Maps emoji identifier strings to Material Icons for achievements
  ///
  /// Used by achievement celebration screens and badge displays.
  /// Falls back to Icons.emoji_events if emoji string is not recognized.
  static IconData getAchievementIcon(String emoji) {
    switch (emoji) {
      // Book-related icons
      case 'book':
        return Icons.book;
      case 'menu_book':
        return Icons.menu_book;
      case 'auto_stories':
        return Icons.auto_stories;
      case 'library_books':
        return Icons.library_books;

      // Achievement icons
      case 'emoji_events':
        return Icons.emoji_events;
      case 'star':
        return Icons.star;
      case 'stars':
        return Icons.stars;
      case 'workspace_premium':
        return Icons.workspace_premium;
      case 'military_tech':
        return Icons.military_tech;
      case 'diamond':
        return Icons.diamond;
      case 'crown':
        return Icons.workspace_premium; // Crown not available, use premium
      case 'verified':
        return Icons.verified;

      // Streak/Fire icons
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'whatshot':
        return Icons.whatshot;
      case 'bolt':
        return Icons.bolt;

      // Time-related icons
      case 'schedule':
        return Icons.schedule;
      case 'access_time':
        return Icons.access_time;
      case 'timer':
        return Icons.timer;

      // Other icons
      case 'favorite':
        return Icons.favorite;
      case 'psychology':
        return Icons.psychology;
      case 'play_circle':
        return Icons.play_circle;

      // Default fallback
      default:
        return Icons.emoji_events;
    }
  }
}
