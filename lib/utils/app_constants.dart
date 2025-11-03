/// Application-wide constants for sizes, durations, thresholds, and other magic numbers
///
/// Centralizes all hardcoded values to improve maintainability and consistency.
/// Instead of scattering magic numbers throughout the codebase, they're defined
/// here with descriptive names and documentation.
class AppConstants {
  // Private constructor to prevent instantiation
  AppConstants._();

  // =============================================================================
  // ANIMATION DURATIONS
  // =============================================================================

  /// Standard animation duration for most UI transitions
  static const standardAnimationDuration = Duration(milliseconds: 600);

  /// Fast animation for subtle effects
  static const fastAnimationDuration = Duration(milliseconds: 300);

  /// Slow animation for emphasis
  static const slowAnimationDuration = Duration(milliseconds: 1000);

  /// Confetti animation duration
  static const confettiDuration = Duration(seconds: 3);

  // =============================================================================
  // UI SIZES
  // =============================================================================

  /// Standard illustration size for auth screens (login, signup, onboarding)
  static const illustrationSize = 150.0;

  /// Large illustration size (deprecated, use illustrationSize instead)
  @Deprecated('Use illustrationSize instead')
  static const largeIllustrationSize = 200.0;

  /// Badge icon radius in settings/profile screens
  static const badgeIconRadius = 40.0;

  /// Small badge icon radius in grid views
  static const smallBadgeIconRadius = 28.0;

  /// Day circle size in streak calendar
  static const dayCircleSize = 32.0;

  /// Standard border radius for cards and buttons
  static const standardBorderRadius = 20.0;

  /// Small border radius for compact elements
  static const smallBorderRadius = 15.0;

  /// Standard vertical button padding
  static const buttonVerticalPadding = 16.0;

  /// Standard horizontal button padding
  static const buttonHorizontalPadding = 20.0;

  // =============================================================================
  // COMPLETION & PROGRESS THRESHOLDS
  // =============================================================================

  /// Book is considered completed at 98% to account for page numbering quirks
  /// (Some PDFs have cover pages, blank pages, or non-standard numbering)
  static const bookCompletionThreshold = 0.98;

  /// Minimum progress to count as "actual reading" (not just opening the book)
  static const minimalProgressThreshold = 0.01;

  /// Minimum page number to count as progress
  static const minimalPageThreshold = 1;

  // =============================================================================
  // PERSONALITY QUIZ THRESHOLDS
  // =============================================================================

  /// Domain must represent at least 20% of responses to be selected
  /// (Ensures only dominant personality traits are chosen)
  static const domainSelectionThreshold = 0.2;

  /// Minimum number of traits to select from quiz
  static const minTraitsSelected = 3;

  /// Maximum number of traits to select from quiz
  static const maxTraitsSelected = 5;

  // =============================================================================
  // READING SESSION THRESHOLDS
  // =============================================================================

  /// Session duration (in seconds) to count as "long session" for weighting
  /// 30 minutes = 1800 seconds
  static const longSessionThresholdSeconds = 1800;

  /// Minutes to display as "long session"
  static const longSessionThresholdMinutes = 30;

  /// Progress update throttle duration (don't update more frequently than this)
  static const progressUpdateThrottleDuration = Duration(seconds: 30);

  // =============================================================================
  // API & NETWORK TIMEOUTS
  // =============================================================================

  /// Default API request timeout
  static const apiTimeout = Duration(seconds: 30);

  /// Firebase Cloud Functions timeout
  static const cloudFunctionTimeout = Duration(minutes: 9);

  /// PDF download timeout
  static const pdfDownloadTimeout = Duration(minutes: 5);

  // =============================================================================
  // PAGINATION & LIMITS
  // =============================================================================

  /// Maximum books to show in recommendation list
  static const maxRecommendations = 15;

  /// Maximum badges to show in profile widget
  static const maxBadgesInProfile = 4;

  /// Grid columns for book grid (mobile)
  static const bookGridColumnsMobile = 2;

  /// Grid columns for book grid (tablet/desktop)
  static const bookGridColumnsTablet = 4;

  /// Responsive breakpoint for mobile/tablet
  static const mobileBreakpoint = 600.0;

  /// Responsive breakpoint for tablet/desktop
  static const tabletBreakpoint = 900.0;

  // =============================================================================
  // ACHIEVEMENT WEIGHTS (for recommendation algorithm)
  // =============================================================================

  /// Weight for quiz dominant traits
  static const quizTraitWeight = 1.5;

  /// Weight for favorited books
  static const favoriteBookWeight = 2.0;

  /// Weight for completed books
  static const completedBookWeight = 2.0;

  /// Weight for long reading sessions
  static const longSessionWeight = 1.0;

  // =============================================================================
  // STREAK & ANALYTICS
  // =============================================================================

  /// Default lookback days for streak calculation
  static const streakLookbackDays = 365;

  /// Default lookback days for analytics
  static const analyticsLookbackDays = 30;

  /// Days in a week
  static const daysInWeek = 7;

  // =============================================================================
  // PDF & FILE PROCESSING
  // =============================================================================

  /// Maximum PDF text length to send to OpenAI (characters)
  /// Approximately first 15,000 characters to stay within token limits
  static const maxPdfTextLength = 15000;

  /// Minimum PDF file size to be considered valid (bytes)
  static const minPdfFileSize = 1024; // 1 KB

  // =============================================================================
  // DELAYS & DEBOUNCES
  // =============================================================================

  /// Delay before navigation after successful auth
  static const postAuthNavigationDelay = Duration(seconds: 1);

  /// Debounce duration for search input
  static const searchDebounceDuration = Duration(milliseconds: 500);

  // =============================================================================
  // TEXT LIMITS
  // =============================================================================

  /// Maximum username length
  static const maxUsernameLength = 50;

  /// Maximum book title length for display
  static const maxBookTitleLength = 100;

  /// Maximum description length for preview
  static const maxDescriptionPreviewLength = 200;

  // =============================================================================
  // CACHE DURATIONS
  // =============================================================================

  /// Image cache duration
  static const imageCacheDuration = Duration(days: 7);

  /// PDF cache duration
  static const pdfCacheDuration = Duration(days: 30);
}
