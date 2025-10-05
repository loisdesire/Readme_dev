import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'reading_screen.dart';
import 'pdf_reading_screen_syncfusion.dart';
import '../../providers/book_provider.dart';
import '../../providers/auth_provider.dart';

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
  ReadingProgress? _readingProgress;

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
      
      // Get reading progress if user is authenticated
      if (authProvider.userId != null) {
        _readingProgress = bookProvider.getProgressForBook(widget.bookId);
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
      final bookProvider = Provider.of<BookProvider>(context, listen: false);
      
      setState(() {
        _isFavorite = !_isFavorite;
      });

      // Track favorite action
      await bookProvider.trackBookInteraction(
        bookId: widget.bookId,
        action: _isFavorite ? 'add_favorite' : 'remove_favorite',
        metadata: {
          'title': widget.title,
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isFavorite ? 'Added to favorites! ❤️' : 'Removed from favorites'),
          backgroundColor: const Color(0xFF8E44AD),
        ),
      );
    } catch (e) {
      // Revert the state if there's an error
      setState(() {
        _isFavorite = !_isFavorite;
      });
      
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
    final book = _fullBookData;
    final displayTitle = book?.title ?? widget.title;
    final displayAuthor = book?.author ?? widget.author;
    final displayDescription = book?.description ?? widget.description;
    final displayAgeRating = book?.ageRating ?? widget.ageRating;
    final displayEmoji = book?.coverEmoji ?? widget.emoji;
    final estimatedTime = book?.estimatedReadingTime ?? 15;

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
                  const Expanded(
                    child: Text(
                      'Book Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    onPressed: _toggleFavorite,
                    icon: Icon(
                      _isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: const Color(0xFF8E44AD),
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
                                  color: const Color(0xFF8E44AD).withOpacity(0.3),
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
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          const SizedBox(height: 8),
                          
                          Text(
                            'by $displayAuthor',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Reading progress (if available)
                          if (_readingProgress != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8E44AD).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    _readingProgress!.isCompleted 
                                        ? 'Completed! 🎉'
                                        : 'Progress: ${(_readingProgress!.progressPercentage * 100).round()}%',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF8E44AD),
                                    ),
                                  ),
                                  if (!_readingProgress!.isCompleted) ...[
                                    const SizedBox(height: 10),
                                    LinearProgressIndicator(
                                      value: _readingProgress!.progressPercentage,
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
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9F9F9),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'About this book',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF8E44AD),
                                  ),
                                ),
                                const SizedBox(height: 15),
                                Text(
                                  displayDescription,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    height: 1.6,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 25),
                          
                          // Features
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9F9F9),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Features',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF8E44AD),
                                  ),
                                ),
                                const SizedBox(height: 15),
                                _buildFeature(Icons.record_voice_over, 'Read Aloud', 'Listen while you read'),
                                const SizedBox(height: 12),
                                _buildFeature(Icons.bookmark, 'Auto Bookmark', 'Never lose your place'),
                                const SizedBox(height: 12),
                                _buildFeature(Icons.quiz, 'Fun Quiz', 'Test your understanding'),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 100), // Space for button
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
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Preview button
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF8E44AD)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Preview coming soon! 👀'),
                            backgroundColor: Color(0xFF8E44AD),
                          ),
                        );
                      },
                      child: const Text(
                        'Preview',
                        style: TextStyle(
                          color: Color(0xFF8E44AD),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 15),
                  
                  // Start reading button
                  Expanded(
                    flex: 2,
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
                            'has_progress': _readingProgress != null,
                          },
                        );

                          // Debug image logging removed
                        print('📖 Book Title: $displayTitle');
                        print('📖 Book ID: ${widget.bookId}');
                        print('📖 Full Book Data Available: ${_fullBookData != null}');
                        if (_fullBookData != null) {
                          print('📖 Has PDF: ${_fullBookData!.hasPdf}');
                          print('📖 PDF URL: ${_fullBookData!.pdfUrl}');
                          print('📖 PDF URL Length: ${_fullBookData!.pdfUrl?.length ?? 0}');
                        }
                        print('📖 ==========================================');

                        if (_fullBookData != null && _fullBookData!.hasPdf && _fullBookData!.pdfUrl != null) {
                          print('✅ Navigating to Syncfusion PDF reader');
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
                          print('⚠️ No PDF available, showing error message');
                          print('⚠️ Reason: ${_fullBookData == null ? "No book data" : !_fullBookData!.hasPdf ? "hasPdf is false" : "pdfUrl is null"}');
                          
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('This book is not available for reading yet. Please try another book.'),
                                backgroundColor: Colors.orange,
                                duration: Duration(seconds: 3),
                              ),
                            );
                          }
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _readingProgress != null && _readingProgress!.progressPercentage > 0
                                ? Icons.play_arrow
                                : Icons.play_arrow,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _readingProgress != null && _readingProgress!.progressPercentage > 0
                                ? 'Continue Reading'
                                : 'Start Reading',
                            style: const TextStyle(
                              fontSize: 16,
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
  }

  Widget _buildStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF8E44AD).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: const Color(0xFF8E44AD),
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildFeature(IconData icon, String title, String description) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF8E44AD).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: const Color(0xFF8E44AD),
            size: 20,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
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
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
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
