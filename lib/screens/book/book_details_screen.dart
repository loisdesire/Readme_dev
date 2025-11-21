import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/logger.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'pdf_reading_screen_syncfusion.dart';
import '../../providers/book_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/feedback_service.dart';
import '../../widgets/pressable_card.dart';
import '../../widgets/common/common_widgets.dart';
import '../../theme/app_theme.dart';

class BookDetailsScreen extends StatefulWidget {
  final String bookId;
  final String title;
  final String author;
  final String description;
  final String ageRating;
  final String emoji;

  const BookDetailsScreen({
    super.key,
    required this.bookId,
    this.title = 'The Enchanted Monkey',
    this.author = 'Maya Adventure',
    this.description = 'Join Koko the monkey on an amazing adventure through the magical jungle! Discover hidden treasures, make new friends, and learn about courage and friendship along the way.',
    this.ageRating = '6+',
    this.emoji = '🐒✨',
  });

  @override
  State<BookDetailsScreen> createState() => _BookDetailsScreenState();
}

class _BookDetailsScreenState extends State<BookDetailsScreen> {
  bool _isFavorite = false;
  bool _isLoading = false;
  Book? _fullBookData;

  @override
  void initState() {
    super.initState();
    _loadBookDetails();
  }

  Future<void> _loadBookDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final bookProvider = Provider.of<BookProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Get full book data
      _fullBookData = bookProvider.getBookById(widget.bookId);

      // Get favorite status if user is authenticated
      if (authProvider.userId != null) {
        _isFavorite = bookProvider.isFavorite(widget.bookId);
      }

      // Track book interaction
      await bookProvider.trackBookInteraction(
        bookId: widget.bookId,
        action: 'view_details',
        metadata: {
          'title': widget.title,
          'author': widget.author,
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading book details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      FeedbackService.instance.playTap();
      final bookProvider = Provider.of<BookProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (authProvider.userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to add favorites'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Optimistically update UI
      setState(() {
        _isFavorite = !_isFavorite;
      });

      // Toggle favorite in BookProvider (this handles Firestore and analytics)
      await bookProvider.toggleFavorite(authProvider.userId!, widget.bookId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isFavorite ? 'Added to favorites' : 'Removed from favorites'),
          backgroundColor: const Color(0xFF8E44AD),
        ),
      );
      // Play success feedback
      FeedbackService.instance.playSuccess();
    } catch (e) {
      // Revert the state if there's an error
      setState(() {
        _isFavorite = !_isFavorite;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating favorites: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<BookProvider, AuthProvider>(
      builder: (context, bookProvider, authProvider, child) {
        // Get fresh data from provider on every rebuild
        final book = _fullBookData ?? bookProvider.getBookById(widget.bookId);
        final displayTitle = book?.title ?? widget.title;
        final displayAuthor = book?.author ?? widget.author;
        final displayDescription = book?.description ?? widget.description;
        final displayAgeRating = book?.ageRating ?? widget.ageRating;
        final displayEmoji = book?.coverEmoji ?? widget.emoji;
        final estimatedTime = book?.estimatedReadingTime ?? 15;
        final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

        // CRITICAL: Get fresh progress from provider, not stale state
        final freshProgress = authProvider.userId != null
            ? bookProvider.getProgressForBook(widget.bookId)
            : null;

        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Column(
              children: [
            // Header with back button
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFF8E44AD),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Book Details',
                      style: AppTheme.heading,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // Animated favorite toggle (uses PressableCard for consistent ripple + scale)
                  PressableCard(
                    onTap: _toggleFavorite,
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      transitionBuilder: (child, anim) {
                        return ScaleTransition(scale: anim, child: child);
                      },
                      child: _isFavorite
                          ? const Icon(Icons.favorite, key: ValueKey('fav_fill'), color: Color(0xFF8E44AD))
                          : const Icon(Icons.favorite_border, key: ValueKey('fav_border'), color: Color(0xFF8E44AD)),
                    ),
                  ),
                ],
              ),
            ),
            
            // Book content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF8E44AD),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Enhanced Book cover with real images
                          Container(
                            width: 200,
                            height: 280,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0x4D8E44AD),
                                  spreadRadius: 2,
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: book != null && book.hasRealCover
                                  ? CachedNetworkImage(
                                      imageUrl: book.coverImageUrl!,
                                      width: 200,
                                      height: 280,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Color(0xFF8E44AD),
                                              Color(0xFFA062BA),
                                              Color(0xFFB280C7),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => _buildFallbackCover(displayTitle, displayEmoji),
                                      fadeInDuration: const Duration(milliseconds: 500),
                                    )
                                  : _buildFallbackCover(displayTitle, displayEmoji),
                            ),
                          ),
                          
                          const SizedBox(height: 30),
                          
                          // Book title and author
                          Text(
                            displayTitle,
                            style: AppTheme.heading.copyWith(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          const SizedBox(height: 8),
                          
                          Text(
                            'by $displayAuthor',
                            style: AppTheme.body.copyWith(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Reading progress (if available)
                          if (freshProgress != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: const Color(0x1A8E44AD),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    freshProgress.isCompleted
                                        ? 'Completed! 🎉'
                                        : 'Progress: ${(freshProgress.progressPercentage * 100).round()}%',
                                    style: AppTheme.body.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF8E44AD),
                                    ),
                                  ),
                                  if (!freshProgress.isCompleted) ...[
                                    const SizedBox(height: 10),
                                    LinearProgressIndicator(
                                      value: freshProgress.progressPercentage,
                                      backgroundColor: Colors.grey[300],
                                      valueColor: const AlwaysStoppedAnimation<Color>(
                                        Color(0xFF8E44AD),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          
                          // Book stats
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStat(Icons.schedule, '$estimatedTime min', 'Reading time'),
                              _buildStat(Icons.person, displayAgeRating, 'Age rating'),
                              _buildStat(Icons.star, '4.8', 'Rating'),
                            ],
                          ),
                          
                          const SizedBox(height: 30),
                          
                          // Description
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: const Color(0x1A8E44AD),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'About this book',
                                  style: AppTheme.heading.copyWith(
                                    color: Color(0xFF8E44AD),
                                  ),
                                ),
                                const SizedBox(height: 15),
                                Text(
                                  displayDescription,
                                  style: AppTheme.body.copyWith(
                                    height: 1.6,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 100 + bottomPadding), // Space for button
                        ],
                      ),
                    ),
            ),
            
            // Bottom action buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x1A9E9E9E),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Start reading button (full width)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8E44AD),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () async {
                        // Track reading start
                        final bookProvider = Provider.of<BookProvider>(context, listen: false);
                        await bookProvider.trackBookInteraction(
                          bookId: widget.bookId,
                          action: 'start_reading',
                          metadata: {
                            'title': displayTitle,
                            'has_progress': freshProgress != null,
                          },
                        );

                        // Debug image logging removed
                        appLog('Book Title: $displayTitle', level: 'DEBUG');
                        appLog('Book ID: ${widget.bookId}', level: 'DEBUG');
                        appLog('Full Book Data Available: ${_fullBookData != null}', level: 'DEBUG');
                        if (_fullBookData != null) {
                          appLog('Has PDF: ${_fullBookData!.hasPdf}', level: 'DEBUG');
                          appLog('PDF URL: ${_fullBookData!.pdfUrl}', level: 'DEBUG');
                          appLog('PDF URL Length: ${_fullBookData!.pdfUrl?.length ?? 0}', level: 'DEBUG');
                        }
                        appLog('==========================================', level: 'DEBUG');

                        if (_fullBookData != null && _fullBookData!.hasPdf && _fullBookData!.pdfUrl != null) {
                          appLog('Navigating to Syncfusion PDF reader', level: 'DEBUG');
                          // Ensure we're mounted before navigating after async operations
                          if (!context.mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PdfReadingScreenSyncfusion(
                                bookId: widget.bookId,
                                title: displayTitle,
                                author: displayAuthor,
                                pdfUrl: _fullBookData!.pdfUrl!,
                              ),
                            ),
                          );
                        } else {
                          appLog('⚠️ No PDF available, showing error message', level: 'WARN');
                          appLog('⚠️ Reason: ${_fullBookData == null ? "No book data" : !_fullBookData!.hasPdf ? "hasPdf is false" : "pdfUrl is null"}', level: 'WARN');

                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('This book is not available for reading yet. Please try another book.'),
                              backgroundColor: Colors.orange,
                              duration: Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            freshProgress != null && freshProgress.progressPercentage > 0
                                ? Icons.play_arrow
                                : Icons.play_arrow,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            freshProgress != null && freshProgress.progressPercentage > 0
                                ? 'Continue Reading'
                                : 'Start Reading',
                            style: AppTheme.buttonText.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStat(IconData icon, String value, String label) {
    return StatDisplay(
      icon: icon,
      value: value,
      label: label,
      isColumn: true,
    );
  }

  // Fallback cover for books without real images
  Widget _buildFallbackCover(String title, String emoji) {
    return Container(
      width: 200,
      height: 280,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF8E44AD),
            Color(0xFFA062BA),
            Color(0xFFB280C7),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 80),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                title,
                style: AppTheme.heading.copyWith(
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
