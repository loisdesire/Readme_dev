import 'package:flutter/material.dart';
import '../providers/book_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_utils.dart';
import 'common/common_widgets.dart';

class BookCard extends StatelessWidget {
  final Book book;
  final ReadingProgress? progress;
  final VoidCallback? onTap;
  final bool showAgeRating; // Whether to show age rating badge
  final bool truncateAuthor; // Whether to truncate long author names

  const BookCard({
    super.key,
    required this.book,
    this.progress,
    this.onTap,
    this.showAgeRating = true, // Default to true for library cards
    this.truncateAuthor = true, // Default to true to prevent layout issues
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enhanced Book Cover with Real Images (increased size)
              Container(
                width: 80,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: AppTheme.primaryPurpleOpaque10,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: book.hasRealCover
                      ? Image.network(
                          book.coverImageUrl!,
                          fit: BoxFit.cover,
                          width: 80,
                          height: 120,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) {
                              return child;
                            }
                            return Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF8E44AD),
                                  ),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            // Removed debug image error prints
                            return _buildEmojiCover();
                          },
                        )
                      : _buildEmojiCover(),
                ),
              ),
              const SizedBox(width: 12),
              // Book Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'by ${truncateAuthor ? AppUtils.truncateAuthor(book.author) : book.author}',
                      style: AppTheme.bodyMedium.copyWith(color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Reading time and age rating
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${book.estimatedReadingTime} min',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (showAgeRating)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryPurpleOpaque10,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              book.ageRating,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF8E44AD),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Progress indicator
                    if (progress != null && progress!.progressPercentage > 0) ...[
                      ProgressBar(
                        progress: progress!.progressPercentage,
                        progressColor: progress!.isCompleted ? Colors.green : AppTheme.primaryPurple,
                        showPercentage: true,
                        percentageFontSize: 11,
                      ),
                      const SizedBox(height: 8),
                    ] else ...[
                      StatusBadge(
                        text: 'Not started',
                        type: StatusBadgeType.notStarted,
                        fontSize: 11,
                      ),
                      const SizedBox(height: 8),
                    ],
                    // Traits
                    if (book.traits.isNotEmpty)
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: book.traits.take(2).map((trait) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            trait,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black54,
                            ),
                          ),
                        )).toList(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmojiCover() {
    return Container(
      width: 80,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: AppTheme.primaryPurpleOpaque10,
      ),
      child: Center(
        child: Text(
          book.displayCover,
          style: const TextStyle(fontSize: 32),
        ),
      ),
    );
  }


}
