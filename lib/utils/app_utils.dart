/// Common utility functions extracted from duplicate code across the app
class AppUtils {
  /// Truncates text to specified length with ellipsis
  static String truncateText(String text, int maxLength, {String suffix = '...'}) {
    if (text.length <= maxLength) {
      return text;
    }
    return '${text.substring(0, maxLength - suffix.length)}$suffix';
  }
  
  /// Truncates author names that are too long (commonly used across book widgets)
  static String truncateAuthor(String author) {
    return truncateText(author, 20);
  }
  
  /// Formats reading progress percentage for display
  static String formatProgressPercentage(double progressPercentage) {
    return '${(progressPercentage * 100).round()}%';
  }
  
  /// Determines the status text based on reading progress
  static String getReadingStatusText(double? progressPercentage, bool isCompleted) {
    if (isCompleted) return 'Completed';
    if (progressPercentage == null || progressPercentage == 0) return 'Not started';
    return 'Continue';
  }
  
  /// Formats reading time in a human-readable format
  static String formatReadingTime(int minutes) {
    if (minutes < 60) {
      return '${minutes}min';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) {
      return '${hours}h';
    }
    return '${hours}h ${remainingMinutes}m';
  }
  
  /// Formats book count for display
  static String formatBookCount(int count) {
    if (count == 0) return 'No books';
    if (count == 1) return '1 book';
    return '$count books';
  }
  
  /// Validates if a string is a valid emoji
  static bool isValidEmoji(String? text) {
    if (text == null || text.isEmpty) return false;
    // Simple emoji validation - check if it's a single character with high unicode value
    return text.length == 1 && text.codeUnitAt(0) > 255;
  }
}