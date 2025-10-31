// File: lib/utils/date_utils.dart

/// Date range model for queries
class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange({required this.start, required this.end});

  @override
  String toString() => 'DateRange(start: $start, end: $end)';
}

/// Utility class for common date operations.
///
/// Provides consistent date manipulation across the app, particularly
/// useful for Firestore queries that need date ranges.
///
/// Usage:
/// ```dart
/// // Get today's date range for queries
/// final range = AppDateUtils.getDayRange(DateTime.now());
/// final query = firestore
///     .collection('sessions')
///     .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
///     .where('timestamp', isLessThan: Timestamp.fromDate(range.end));
///
/// // Format a date key
/// final dateKey = AppDateUtils.formatDateKey(DateTime.now()); // "2025-10-28"
/// ```
class AppDateUtils {
  /// Get start of day (00:00:00.000)
  ///
  /// Example:
  /// ```dart
  /// final start = AppDateUtils.startOfDay(DateTime(2025, 10, 28, 15, 30));
  /// // Returns: DateTime(2025, 10, 28, 0, 0, 0, 0)
  /// ```
  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Get end of day (23:59:59.999)
  ///
  /// Example:
  /// ```dart
  /// final end = AppDateUtils.endOfDay(DateTime(2025, 10, 28, 10, 30));
  /// // Returns: DateTime(2025, 10, 28, 23, 59, 59, 999)
  /// ```
  static DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  /// Get date range for a specific day (00:00:00 to next day 00:00:00)
  ///
  /// This is particularly useful for Firestore queries where you want
  /// to query all data for a specific day using:
  /// - `where('timestamp', isGreaterThanOrEqualTo: range.start)`
  /// - `where('timestamp', isLessThan: range.end)`
  ///
  /// Example:
  /// ```dart
  /// final range = AppDateUtils.getDayRange(DateTime(2025, 10, 28));
  /// // range.start: DateTime(2025, 10, 28, 0, 0, 0)
  /// // range.end: DateTime(2025, 10, 29, 0, 0, 0)
  /// ```
  static DateRange getDayRange(DateTime date) {
    final start = startOfDay(date);
    final end = start.add(const Duration(days: 1));
    return DateRange(start: start, end: end);
  }

  /// Format date as YYYY-MM-DD string
  ///
  /// Useful for creating consistent date keys for Firestore documents
  /// or for displaying dates in a standard format.
  ///
  /// Example:
  /// ```dart
  /// final key = AppDateUtils.formatDateKey(DateTime(2025, 10, 28));
  /// // Returns: "2025-10-28"
  /// ```
  static String formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Get start of week (Monday at 00:00:00)
  ///
  /// Returns the Monday of the week containing the given date.
  ///
  /// Example:
  /// ```dart
  /// // If today is Wednesday, October 30, 2025
  /// final weekStart = AppDateUtils.startOfWeek(DateTime.now());
  /// // Returns: Monday, October 28, 2025 at 00:00:00
  /// ```
  static DateTime startOfWeek(DateTime date) {
    final daysFromMonday = date.weekday - 1;
    return startOfDay(date.subtract(Duration(days: daysFromMonday)));
  }

  /// Get end of week (Sunday at 23:59:59.999)
  ///
  /// Returns the Sunday of the week containing the given date.
  ///
  /// Example:
  /// ```dart
  /// // If today is Wednesday, October 30, 2025
  /// final weekEnd = AppDateUtils.endOfWeek(DateTime.now());
  /// // Returns: Sunday, November 3, 2025 at 23:59:59.999
  /// ```
  static DateTime endOfWeek(DateTime date) {
    final daysToSunday = 7 - date.weekday;
    return endOfDay(date.add(Duration(days: daysToSunday)));
  }

  /// Get date range for a specific week (Monday to next Monday)
  ///
  /// Similar to getDayRange but for a full week.
  ///
  /// Example:
  /// ```dart
  /// final range = AppDateUtils.getWeekRange(DateTime.now());
  /// // range.start: Monday of this week at 00:00:00
  /// // range.end: Monday of next week at 00:00:00
  /// ```
  static DateRange getWeekRange(DateTime date) {
    final start = startOfWeek(date);
    final end = start.add(const Duration(days: 7));
    return DateRange(start: start, end: end);
  }

  /// Get start of month (first day at 00:00:00)
  ///
  /// Example:
  /// ```dart
  /// final monthStart = AppDateUtils.startOfMonth(DateTime(2025, 10, 28));
  /// // Returns: DateTime(2025, 10, 1, 0, 0, 0)
  /// ```
  static DateTime startOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  /// Get end of month (last day at 23:59:59.999)
  ///
  /// Example:
  /// ```dart
  /// final monthEnd = AppDateUtils.endOfMonth(DateTime(2025, 10, 28));
  /// // Returns: DateTime(2025, 10, 31, 23, 59, 59, 999)
  /// ```
  static DateTime endOfMonth(DateTime date) {
    // Get the first day of next month, then subtract 1 millisecond
    final nextMonth = (date.month < 12)
        ? DateTime(date.year, date.month + 1, 1)
        : DateTime(date.year + 1, 1, 1);
    return nextMonth.subtract(const Duration(milliseconds: 1));
  }

  /// Get the day key for a given DateTime (Mon, Tue, etc.)
  ///
  /// Example:
  /// ```dart
  /// final key = AppDateUtils.getDayKey(DateTime(2025, 10, 28)); // Tuesday
  /// // Returns: "Tue"
  /// ```
  static String getDayKey(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  /// Get the full day name for a given DateTime
  ///
  /// Example:
  /// ```dart
  /// final name = AppDateUtils.getDayName(DateTime(2025, 10, 28));
  /// // Returns: "Tuesday"
  /// ```
  static String getDayName(DateTime date) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[date.weekday - 1];
  }

  /// Check if two dates are on the same day
  ///
  /// Example:
  /// ```dart
  /// final date1 = DateTime(2025, 10, 28, 10, 30);
  /// final date2 = DateTime(2025, 10, 28, 15, 45);
  /// final same = AppDateUtils.isSameDay(date1, date2); // true
  /// ```
  static bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// Get the number of days between two dates
  ///
  /// Example:
  /// ```dart
  /// final days = AppDateUtils.daysBetween(
  ///   DateTime(2025, 10, 28),
  ///   DateTime(2025, 11, 1),
  /// ); // Returns: 4
  /// ```
  static int daysBetween(DateTime start, DateTime end) {
    final startDate = startOfDay(start);
    final endDate = startOfDay(end);
    return endDate.difference(startDate).inDays;
  }

  /// Check if a date is today
  ///
  /// Example:
  /// ```dart
  /// final isToday = AppDateUtils.isToday(DateTime.now()); // true
  /// ```
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return isSameDay(date, now);
  }

  /// Check if a date is yesterday
  ///
  /// Example:
  /// ```dart
  /// final yesterday = DateTime.now().subtract(Duration(days: 1));
  /// final isYesterday = AppDateUtils.isYesterday(yesterday); // true
  /// ```
  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return isSameDay(date, yesterday);
  }

  /// Format a date relative to today (Today, Yesterday, or date)
  ///
  /// Example:
  /// ```dart
  /// final text = AppDateUtils.formatRelative(DateTime.now());
  /// // Returns: "Today"
  ///
  /// final text2 = AppDateUtils.formatRelative(
  ///   DateTime.now().subtract(Duration(days: 1))
  /// );
  /// // Returns: "Yesterday"
  ///
  /// final text3 = AppDateUtils.formatRelative(DateTime(2025, 10, 28));
  /// // Returns: "2025-10-28"
  /// ```
  static String formatRelative(DateTime date) {
    if (isToday(date)) return 'Today';
    if (isYesterday(date)) return 'Yesterday';
    return formatDateKey(date);
  }
}
