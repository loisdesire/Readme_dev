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
      case 'import_contacts':
        return Icons.import_contacts;

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
      case 'grade':
        return Icons.grade;

      // Streak/Fire icons
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'whatshot':
        return Icons.whatshot;
      case 'done_outline':
        return Icons.done_outline;
      case 'bolt':
        return Icons.bolt;
      case 'flame':
        return Icons.whatshot;
      case 'electric_bolt':
        return Icons.power_settings_new;
      case 'flash_auto':
        return Icons.flash_on;
      case 'star_outline':
        return Icons.star_outline;

      // Time-related icons
      case 'schedule':
        return Icons.schedule;
      case 'access_time':
        return Icons.access_time;
      case 'timer':
        return Icons.timer;
      case 'flash_on':
        return Icons.flash_on;
      case 'rocket_launch':
        return Icons.rocket_launch;
      case 'wb_sunny':
        return Icons.wb_sunny;
      case 'sunny':
        return Icons.sunny;
      case 'brightness_7':
        return Icons.brightness_7;
      case 'nights_stay':
        return Icons.nights_stay;
      case 'celebration':
        return Icons.celebration;

      // Session-related icons
      case 'play_circle':
        return Icons.play_circle;
      case 'play_arrow':
        return Icons.play_arrow;
      case 'verified':
        return Icons.verified;
      case 'verified_user':
        return Icons.verified_user;
      case 'favorite':
        return Icons.favorite;
      case 'favorite_border':
        return Icons.favorite_border;
      case 'badge':
        return Icons.badge;
      case 'card_giftcard':
        return Icons.card_giftcard;
      case 'star_rate':
        return Icons.star_rate;

      // Other icons
      case 'psychology':
        return Icons.psychology;

      // Default fallback
      default:
        return Icons.emoji_events;
    }
  }
}
