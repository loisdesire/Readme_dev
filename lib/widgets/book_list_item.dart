import 'package:flutter/material.dart';
import '../providers/book_provider.dart';
import '../theme/app_theme.dart';
import '../screens/book/book_details_screen.dart';
import '../utils/page_transitions.dart';
import 'book_cover.dart';
import 'pressable_card.dart';
import 'common/progress_button.dart';

/// Reusable book list item widget - replaces duplicated code in library_screen.dart (5+ copies)
class BookListItem extends StatelessWidget {
  final Book book;
  final ReadingProgress? progress;
  final VoidCallback? onTap;

  const BookListItem({
    super.key,
    required this.book,
    this.progress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: PressableCard(
        onTap: onTap ??
            () {
              Navigator.push(
                context,
                SlideUpRoute(
                  page: BookDetailsScreen(
                    bookId: book.id,
                    title: book.title,
                    author: book.author,
                    emoji: book.displayCover,
                  ),
                ),
              );
            },
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: const Color(0x1A9E9E9E),
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  BookCover(book: book),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.auto_stories,
                              size: 16,
                              color: AppTheme.primaryPurple,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                book.title,
                                style: AppTheme.body.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.person,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                book.author,
                                style: AppTheme.bodySmall.copyWith(
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.schedule,
                                size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 5),
                            Text(
                              '${book.estimatedReadingTime} min',
                              style: AppTheme.bodySmall.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 15),
                            Icon(Icons.person,
                                size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 5),
                            Text(
                              book.ageRating,
                              style: AppTheme.bodySmall.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ProgressButton(
                    text: progress?.isCompleted == true
                        ? 'Re-read'
                        : progress != null && progress!.progressPercentage > 0
                            ? 'Continue'
                            : 'Start',
                    type: progress?.isCompleted == true
                        ? ProgressButtonType.completed
                        : progress != null && progress!.progressPercentage > 0
                            ? ProgressButtonType.inProgress
                            : ProgressButtonType.notStarted,
                  ),
                ],
              ),
              if (progress != null && progress!.progressPercentage > 0) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress!.progressPercentage / 100,
                    backgroundColor: const Color(0x1A8E44AD),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryPurple),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  progress!.isCompleted
                      ? 'Completed'
                      : '${progress!.progressPercentage.toStringAsFixed(0)}% complete',
                  style: AppTheme.bodySmall.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
