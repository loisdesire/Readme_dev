import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/book_provider.dart';
import '../theme/app_theme.dart';

/// Reusable book cover widget with caching, Hero animation, and fallback support
/// Replaces duplicated _buildBookCover methods across 4+ files
class BookCover extends StatelessWidget {
  final Book book;
  final double width;
  final double height;
  final bool enableHero;
  final double borderRadius;

  const BookCover({
    super.key,
    required this.book,
    this.width = 60,
    this.height = 80,
    this.enableHero = true,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final coverWidget = book.hasRealCover
        ? ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: CachedNetworkImage(
              imageUrl: book.coverImageUrl!,
              width: width,
              height: height,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryPurple),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => _buildFallback(),
              fadeInDuration: const Duration(milliseconds: 300),
              fadeOutDuration: const Duration(milliseconds: 100),
            ),
          )
        : _buildFallback();

    return enableHero
        ? Hero(
            tag: 'book-cover-${book.id}',
            child: coverWidget,
          )
        : coverWidget;
  }

  Widget _buildFallback() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.primaryPurpleOpaque10,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: Text(
          book.fallbackEmoji,
          style: TextStyle(fontSize: width * 0.4),
        ),
      ),
    );
  }
}
