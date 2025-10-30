import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/logger.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../book/book_details_screen.dart';
import '../quiz/quiz_screen.dart';
import '../../providers/auth_provider.dart';
import '../../providers/book_provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_theme.dart';
import 'library_screen.dart';
import 'profile_edit_screen.dart';
import '../../widgets/pressable_card.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../services/feedback_service.dart';

class ChildHomeScreen extends StatefulWidget {
  const ChildHomeScreen({super.key});

  @override
  State<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends State<ChildHomeScreen> {
  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to avoid calling notifyListeners during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  // Enhanced book cover widget with caching and smooth loading
  Widget _buildBookCover(Book book, {double width = 60, double height = 80}) {
    if (book.hasRealCover) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
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
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8E44AD)),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
                            color: const Color(0x338E44AD),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                book.fallbackEmoji,
                style: const TextStyle(fontSize: 25),
              ),
            ),
          ),
          fadeInDuration: const Duration(milliseconds: 300),
          fadeOutDuration: const Duration(milliseconds: 100),
        ),
      );
    } else {
      // Fallback to emoji for books without real covers
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0x338E44AD),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            book.fallbackEmoji,
            style: const TextStyle(fontSize: 25),
          ),
        ),
      );
    }
  }

  Future<void> _loadData() async {
    // Load fresh data - CRITICAL: Always reload progress and user data for fresh state
    if (!mounted) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final bookProvider = Provider.of<BookProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      if (authProvider.userId != null) {
        // Load books only if we don't have them (they don't change often)
        if (bookProvider.allBooks.isEmpty) {
          await bookProvider.loadAllBooks(userId: authProvider.userId);
        }
        if (bookProvider.recommendedBooks.isEmpty) {
          await bookProvider.loadRecommendedBooks(
            authProvider.getPersonalityTraits(),
            userId: authProvider.userId,
          );
        }

        // CRITICAL FIX: Always reload progress and user data for fresh state
        await Future.wait([
          bookProvider.loadUserProgress(authProvider.userId!),
          userProvider.loadUserData(authProvider.userId!),
          bookProvider.loadFavorites(authProvider.userId!),
        ]);
      }
    } catch (e) {
      appLog('Error loading data: $e', level: 'ERROR');
      // Don't show error snackbar to avoid interrupting user experience
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: AppTheme.white,
      body: SafeArea(
        child: Consumer3<AuthProvider, BookProvider, UserProvider>(
          builder: (context, authProvider, bookProvider, userProvider, child) {
            // Show error state if there's an error (without retry to avoid refreshing)
            if (bookProvider.error != null) {
              return _buildErrorState(bookProvider.error!, () {
                bookProvider.clearError();
              });
            }

            // Show loading state
            if (bookProvider.isLoading) {
              return const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF8E44AD),
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with profile
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Welcome back,',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppTheme.textGray,
                                ),
                              ),
                              Text(
                                authProvider.userProfile?['username'] ?? 'Reader',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Profile avatar - clickable
                        GestureDetector(
                          onTap: () {
                            FeedbackService.instance.playTap();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ProfileEditScreen(),
                              ),
                            );
                          },
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primaryPurpleOpaque10,
                              border: Border.all(
                                color: const Color(0xFF8E44AD),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                authProvider.userProfile?['avatar'] ?? '👦',
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Reading streak calendar
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8E44AD),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${userProvider.dailyReadingStreak}-day reading streak! 🔥',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 15),
                          // Week calendar - use provider's currentStreakDays which is [today, yesterday, ...]
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: _buildWeekCalendarFromStreakDays(userProvider.currentStreakDays, userProvider.weeklyProgress),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Continue reading section - only show if there are ongoing books
                    () {
                      // Group progress by bookId and get the latest progress for each book
                      final progressByBook = <String, ReadingProgress>{};
                      
                      for (final progress in bookProvider.userProgress) {
                        if (!progress.isCompleted && progress.progressPercentage > 0) {
                          final existing = progressByBook[progress.bookId];
                          if (existing == null || progress.lastReadAt.isAfter(existing.lastReadAt)) {
                            progressByBook[progress.bookId] = progress;
                          }
                        }
                      }
                      
                      final ongoingBooks = progressByBook.values.toList();
                      ongoingBooks.sort((a, b) => b.lastReadAt.compareTo(a.lastReadAt)); // Most recent first
                      final recentBooks = ongoingBooks.take(3).toList();
                      
                      if (recentBooks.isEmpty) {
                        return const SizedBox.shrink(); // Don't show section if no ongoing books
                      }
                      
                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Continue Reading',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const LibraryScreen(initialTab: 2), // Ongoing tab
                                    ),
                                  );
                                },
                                child: const Text(
                                  'See all >',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF8E44AD),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 15),
                          
                          // Show ongoing books
                          ...recentBooks.map((progress) {
                            final book = bookProvider.getBookById(progress.bookId);
                            if (book == null) return const SizedBox.shrink();
                            
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 15),
                              child: _buildContinueReadingCard(book, progress),
                            );
                          }),
                          
                          const SizedBox(height: 30),
                        ],
                      );
                    }(),
                    
                    // Recommended books section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recommended for You',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LibraryScreen(initialTab: 1), // Recommended tab
                              ),
                            );
                          },
                          child: const Text(
                            'See all >',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF8E44AD),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 15),
                    
                    // Recommended books list - using combined AI + rule-based recommendations
                    if (bookProvider.combinedRecommendedBooks.isNotEmpty) ...{
                      // Filter out completed books before displaying
                      ...bookProvider.combinedRecommendedBooks
                          .where((book) {
                            final progress = bookProvider.getProgressForBook(book.id);
                            return progress?.isCompleted != true;
                          })
                          .take(5)
                          .map((book) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 15),
                          child: PressableCard(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BookDetailsScreen(
                                    bookId: book.id,
                                    title: book.title,
                                    author: book.author,
                                    description: book.description,
                                    ageRating: book.ageRating,
                                    emoji: book.displayCover,
                                  ),
                                ),
                              );
                            },
                            child: _buildBookCard(book),
                          ),
                        );
                      })
                    } else
                      _buildEmptyRecommendations(),

                    SizedBox(height: 100 + bottomPadding), // Space for bottom navigation
                  ],
                ),
            );
          },
        ),
      ),
      
      // Bottom Navigation Bar
      bottomNavigationBar: const AppBottomNav(
        currentTab: NavTab.home,
      ),
    );
  }

  Widget _buildErrorState(String error, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '😔',
              style: TextStyle(fontSize: 80),
            ),
            const SizedBox(height: 20),
            const Text(
              'Oops! Something went wrong',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              error,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8E44AD),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
                ),
              ),
              onPressed: onRetry,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Try Again',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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

  Widget _buildEmptyRecommendations() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              '📚✨',
              style: TextStyle(fontSize: 60),
            ),
            const SizedBox(height: 15),
            const Text(
              'Complete your personality quiz to get personalized recommendations!',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8E44AD),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 25,
                  vertical: 12,
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const QuizScreen(),
                  ),
                );
              },
              child: const Text(
                'Take Quiz',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build calendar from provider's streak boolean list. streakDays is expected as [today, yesterday, ...].
  List<Widget> _buildWeekCalendarFromStreakDays(List<bool> streakDays, Map<String, int> weeklyProgress) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = DateTime.now();
    final currentDayIndex = today.weekday - 1; // Monday = 0

    // ONLY show data for the CURRENT week (Mon-Sun containing today)
    // Days after today in the week should show as not read (they're in the future)
    return days.asMap().entries.map((entry) {
      final index = entry.key; // 0..6 -> Mon..Sun
      final day = entry.value;

      final isToday = index == currentDayIndex;

      // Calculate if this day is in the future (after today this week)
      final isFutureDay = index > currentDayIndex;

      bool? streakValueForThisDay;
      if (streakDays.isNotEmpty && !isFutureDay) {
        // Map streakDays which is [today, yesterday, ...] into the weekday index
        // Only look at days from Monday of this week to today
        final daysAgo = currentDayIndex - index;

        // Only use streak data if this day is this week (not last week)
        if (daysAgo >= 0 && daysAgo < streakDays.length) {
          streakValueForThisDay = streakDays[daysAgo];
        }
      }

      // Use weekly progress as fallback (but NOT for future days)
      final hasReadFallback = !isFutureDay && (weeklyProgress[day] ?? 0) > 0;

      // Render rules:
      // - Future days: always show as not completed (empty circle)
      // - If streakValueForThisDay == true => filled circle with check
      // - If isToday && streakValueForThisDay == false => outlined circle (no check)
      // - Otherwise fallback to hasReadFallback to show filled/empty
      final renderedCompleted = isFutureDay ? false : (streakValueForThisDay ?? hasReadFallback);

      return _buildDayCircle(day, renderedCompleted, isToday: isToday, outlinedTodayWhenUnread: isToday && (streakValueForThisDay == false));
    }).toList();
  }

  Widget _buildDayCircle(String day, bool isCompleted, {bool isToday = false, bool outlinedTodayWhenUnread = false}) {
    // outlinedTodayWhenUnread: when true, draw today's circle as outlined even if not completed
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? (isToday ? Colors.white : const Color(0xFFF7DC6F))
                : Colors.transparent,
            border: (isToday && outlinedTodayWhenUnread)
                ? Border.all(color: Colors.white, width: 2)
                : (isToday
                    ? null
                    : Border.all(
                        color: const Color(0x80FFFFFF),
                        width: 1,
                      )),
          ),
          child: Center(
            child: isCompleted
                ? Icon(
                    Icons.check,
                    size: 16,
                    color: isToday ? const Color(0xFF8E44AD) : Colors.white,
                  )
                : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day,
          style: TextStyle(
            fontSize: 12,
            color: const Color(0xCCFFFFFF),
          ),
        ),
      ],
    );
  }

  Widget _buildContinueReadingCard(Book book, ReadingProgress progress) {
    return PressableCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookDetailsScreen(
              bookId: book.id,
              title: book.title,
              author: book.author,
              description: book.description,
              ageRating: book.ageRating,
              emoji: book.displayCover,
            ),
          ),
        );
      },
      child: Container(
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
            // Book cover with real images
            _buildBookCover(book),
            const SizedBox(width: 15),
            // Book info
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
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'by ${book.author}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Continue reading >',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF8E44AD),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Progress bar
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progress.progressPercentage,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF8E44AD),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${(progress.progressPercentage * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookCard(Book book) {
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
          // Book cover with real images
          _buildBookCover(book),
          const SizedBox(width: 15),
          // Book info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_stories,
                      size: 16,
                      color: Color(0xFF8E44AD),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        book.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.person,
                      size: 16,
                      color: Color(0xFF8E44AD),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        book.author,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule,
                      size: 16,
                      color: Color(0xFF8E44AD),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${book.estimatedReadingTime} min • ${book.ageRating}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Read button
          PressableCard(
            onTap: () {
              FeedbackService.instance.playTap();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BookDetailsScreen(
                    bookId: book.id,
                    title: book.title,
                    author: book.author,
                    description: book.description,
                    ageRating: book.ageRating,
                    emoji: book.displayCover,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF8E44AD),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Read >',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


}
