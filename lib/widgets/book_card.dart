import 'package:flutter/material.dart';
import '../providers/book_provider.dart';
import '../theme/app_theme.dart';
import 'book_cover.dart';
import 'common/progress_button.dart';

/// The book-card row (cover + title/author/time/age + optional progress bar
/// + action button) used across the child-facing UI.
///
/// This one design used to be copy-pasted inline in 6 places — ChildHomeScreen's
/// "Recommended for you" list plus all 5 tabs of LibraryScreen — each with its
/// own near-identical Container/Row/Column and its own duplicate cover-image
/// widget. Consolidated here so a future tweak (spacing, the action button's
/// states, etc.) only needs to happen once. See SECURITY.md's cleanup-pass
/// entry for the history.
class BookCard extends StatelessWidget {
  final Book book;
  final ReadingProgress? progress;

  /// Invoked both when the action button is pressed. Callers typically wrap
  /// this whole card in a `PressableCard`/gesture detector with the same
  /// navigation so tapping anywhere on the card and tapping the button do
  /// the same thing.
  final VoidCallback? onTap;

  /// Library tabs render several of these in the same TabBarView at once;
  /// disable the Hero (default on for ChildHomeScreen's single list) to
  /// avoid duplicate-hero-tag collisions across tabs sharing a book.
  final bool enableHero;

  /// Overrides the derived button label/state. Used by tabs that already
  /// know a book's bucket from the list it came from (e.g. the "Ongoing"
  /// tab always shows "Resume" even for a book whose progress doc hasn't
  /// caught up to a positive percentage yet).
  final String? buttonTextOverride;
  final ProgressButtonType? buttonTypeOverride;

  /// Shows the progress row even at 0%/no progress doc, treating that as
  /// 100% complete. Used by the "Completed" tab, where a book can be listed
  /// as completed without (yet) having its own progress document.
  final bool alwaysShowProgress;

  const BookCard({
    super.key,
    required this.book,
    this.progress,
    this.onTap,
    this.enableHero = true,
    this.buttonTextOverride,
    this.buttonTypeOverride,
    this.alwaysShowProgress = false,
  });

  bool get _isCompleted => progress?.isCompleted == true;
  bool get _isStarted => progress != null && progress!.progressPercentage > 0;

  String get _buttonText =>
      buttonTextOverride ??
      (_isCompleted
          ? 'Re-read'
          : _isStarted
              ? 'Resume'
              : 'Start');

  ProgressButtonType get _buttonType =>
      buttonTypeOverride ??
      (_isCompleted
          ? ProgressButtonType.completed
          : _isStarted
              ? ProgressButtonType.inProgress
              : ProgressButtonType.notStarted);

  @override
  Widget build(BuildContext context) {
    final showProgressRow = alwaysShowProgress || _isStarted;
    final progressValue =
        progress?.progressPercentage ?? (alwaysShowProgress ? 1.0 : 0.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: AppTheme.greyOpaque10,
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          BookCover(book: book, enableHero: enableHero),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_stories,
                        size: 16, color: Color(0xFF8E44AD)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        book.title,
                        style:
                            AppTheme.body.copyWith(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.person,
                        size: 16, color: Color(0xFF8E44AD)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        book.author,
                        style: AppTheme.bodyMedium.copyWith(color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.schedule,
                        size: 16, color: Color(0xFF8E44AD)),
                    const SizedBox(width: 5),
                    Text(
                      '${book.estimatedReadingTime} min',
                      style: AppTheme.bodyMedium.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.child_care,
                        size: 16, color: Color(0xFF8E44AD)),
                    const SizedBox(width: 5),
                    Text(
                      book.ageRating,
                      style: AppTheme.bodyMedium.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
                if (showProgressRow) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progressValue,
                            backgroundColor: Colors.grey[200],
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF8E44AD)),
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(progressValue * 100).round()}%',
                        style: AppTheme.bodySmall.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          ProgressButton(
            text: _buttonText,
            type: _buttonType,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}
