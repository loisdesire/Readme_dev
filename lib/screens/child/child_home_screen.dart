import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/logger.dart';
import '../book/book_details_screen.dart';
import '../book/pdf_reading_screen_syncfusion.dart';
import '../quiz/quiz_screen.dart';
import '../../providers/auth_provider.dart' as auth_provider;
import '../../providers/book_provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_theme.dart';
import 'library_screen.dart';
import 'profile_edit_screen.dart';
import 'weekly_challenge_celebration_screen.dart';
import '../../widgets/pressable_card.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/book_cover.dart';
import '../../widgets/common/progress_button.dart';
import '../../widgets/pulse_animation.dart';
import '../../widgets/floating_animation.dart';
import '../../services/feedback_service.dart';
import '../../utils/page_transitions.dart';

class ChildHomeScreen extends StatefulWidget {
  const ChildHomeScreen({super.key});

  @override
  State<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends State<ChildHomeScreen> {
  @override
  void initState() {
    super.initState();
    // Set status bar to light icons for dark purple app bar
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    // Use addPostFrameCallback to avoid calling notifyListeners during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      // Check for weekly celebration (only once per session)
      _checkWeeklyChallengeOnce();
    });
  }

  @override
  void dispose() {
    // Reset to default when leaving
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    super.dispose();
  }

  Future<void> _loadData() async {
    // Load fresh data - CRITICAL: Always reload progress and user data for fresh state
    if (!mounted) return;

    try {
      final authProvider = Provider.of<auth_provider.AuthProvider>(context, listen: false);
      final bookProvider = Provider.of<BookProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      if (authProvider.userId != null) {
        // Load books only if we don't have them (they don't change often)
        if (bookProvider.allBooks.isEmpty) {
          await bookProvider.loadAllBooks(userId: authProvider.userId);
        }

        // ALWAYS reload AI recommendations to ensure fresh, personalized results
        await bookProvider.loadRecommendedBooks(
          authProvider.getPersonalityTraits(),
          userId: authProvider.userId,
        );

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

  // Check weekly challenge once on screen load (not on every rebuild)
  Future<void> _checkWeeklyChallengeOnce() async {
    if (!mounted) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookProvider = Provider.of<BookProvider>(context, listen: false);
      
      // Calculate books completed this week
      final now = DateTime.now();
      final startOfWeek = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));

      final completedThisWeek = bookProvider.userProgress.where((p) {
        if (!p.isCompleted) return false;
        final completionDate = p.lastReadAt;
        return completionDate.isAfter(startOfWeek) ||
            completionDate.isAtSameMomentAs(startOfWeek);
      }).length;

      final targetBooks = 5;
      final weekKey = 'weeklyChallengeCount_${startOfWeek.year}_${startOfWeek.month}_${startOfWeek.day}';
      final lastKnownCount = prefs.getInt(weekKey) ?? 0;
      
      // Only show celebration if we JUST reached the target (not if already there)
      if (completedThisWeek >= targetBooks && lastKnownCount < targetBooks) {
        // Save the current count so we don't show again
        await prefs.setInt(weekKey, completedThisWeek);
        await _checkAndShowWeeklyCelebration(completedThisWeek, targetBooks);
      } else {
        // Update the count anyway for future checks
        await prefs.setInt(weekKey, completedThisWeek);
      }
    } catch (e) {
      appLog('Error checking weekly challenge: $e', level: 'ERROR');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: SafeArea(
        child: Consumer3<auth_provider.AuthProvider, BookProvider, UserProvider>(
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
                  color: AppTheme.primaryPurple,
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                await _loadData();
              },
              color: const Color(0xFF8E44AD),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                physics: const AlwaysScrollableScrollPhysics(),
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
                              Text(
                                'Hey there,',
                                style: AppTheme.body.copyWith(
                                  color: AppTheme.textGray,
                                ),
                              ),
                              Text(
                                authProvider.userProfile?['username'] as String? ?? 'Reader',
                                style: AppTheme.heading.copyWith(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
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
                              SlideRightRoute(
                                page: const ProfileEditScreen(),
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
                                authProvider.userProfile?['avatar'] ?? '🧒',
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Reading streak - modern integrated card with subtle floating animation
                    FloatingAnimation(
                      offset: 0.5,
                      duration: const Duration(milliseconds: 2500),
                      child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8E44AD),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8E44AD).withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Icon container
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.local_fire_department,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Text
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${userProvider.dailyReadingStreak}-day streak!',
                                  style: AppTheme.buttonText.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Keep it going',
                                  style: AppTheme.buttonText.copyWith(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Vertical day bars
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: _buildVerticalDayBars(
                              userProvider.currentStreakDays,
                              userProvider.weeklyProgress,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ),

                    const SizedBox(height: 30),

                    // Badge progress section - wrapped in Consumer2 to listen for real-time updates from both providers
                    Consumer2<BookProvider, UserProvider>(
                      builder: (context, bookProviderUpdate, userProviderUpdate, _) {
                        // Define badge milestones in order with icons
                        final bookBadges = [
                          {'books': 1, 'name': 'First Book', 'icon': Icons.book},
                          {
                            'books': 3,
                            'name': 'Story Explorer',
                            'icon': Icons.menu_book
                          },
                          {
                            'books': 5,
                            'name': 'Book Lover',
                            'icon': Icons.favorite
                          },
                          {
                            'books': 10,
                            'name': 'Bookworm',
                            'icon': Icons.auto_stories
                          },
                          {
                            'books': 20,
                            'name': 'Super Reader',
                            'icon': Icons.library_books
                          },
                          {
                            'books': 25,
                            'name': 'Reading Star',
                            'icon': Icons.emoji_events
                          },
                          {
                            'books': 50,
                            'name': 'Book Champion',
                            'icon': Icons.star
                          },
                          {
                            'books': 75,
                            'name': 'Reading Hero',
                            'icon': Icons.stars
                          },
                          {
                            'books': 100,
                            'name': 'Book Master',
                            'icon': Icons.workspace_premium
                          },
                          {
                            'books': 200,
                            'name': 'Reading Genius',
                            'icon': Icons.military_tech
                          },
                          {
                            'books': 500,
                            'name': 'Book Wizard',
                            'icon': Icons.grade
                          },
                          {
                            'books': 1000,
                            'name': 'Reading Legend',
                            'icon': Icons.diamond
                          },
                        ];

                        final streakBadges = [
                          {
                            'minutes': 30,
                            'name': 'Reading Starter',
                            'icon': Icons.schedule
                          },
                          {
                            'minutes': 60,
                            'name': 'Hour Hero',
                            'icon': Icons.flash_on
                          },
                          {
                            'minutes': 120,
                            'name': 'Time Keeper',
                            'icon': Icons.rocket_launch
                          },
                          {
                            'minutes': 300,
                            'name': 'Time Traveler',
                            'icon': Icons.sunny
                          },
                          {
                            'minutes': 600,
                            'name': 'Marathon Reader',
                            'icon': Icons.wb_sunny
                          },
                          {
                            'minutes': 1200,
                            'name': 'Time Master',
                            'icon': Icons.nights_stay
                          },
                          {
                            'minutes': 3000,
                            'name': 'Time Champion',
                            'icon': Icons.emoji_events
                          },
                        ];

                        final booksRead = userProviderUpdate.totalBooksRead;
                        
                        // Calculate total reading time from BookProvider - NOW UPDATES IN REAL-TIME
                        // Listener fires → bookProvider.userProgress updates → Consumer rebuilds → totalReadingMinutes recalculates
                        final totalReadingMinutes = bookProviderUpdate.userProgress.fold<int>(
                          0,
                          (total, progress) => total + progress.readingTimeMinutes,
                        );

                      // Find next book milestone
                      final nextBookIndex = bookBadges.indexWhere(
                        (milestone) => (milestone['books'] as int) > booksRead,
                      );

                      // Find next time milestone
                      final nextStreakIndex = streakBadges.indexWhere(
                        (milestone) =>
                            (milestone['minutes'] as int) > totalReadingMinutes,
                      );

                      // Don't show section if both are maxed out
                      if ((nextBookIndex == -1 || booksRead >= 1000) &&
                          (nextStreakIndex == -1 || totalReadingMinutes >= 3000)) {
                        return const SizedBox.shrink();
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Your Progress',
                                style: AppTheme.heading,
                              ),
                              TextButton(
                                onPressed: () {
                                  // Navigate to full badge/achievement screen
                                },
                                child: Text(
                                  'Show all',
                                  style: AppTheme.bodyMedium.copyWith(
                                    color: const Color(0xFF8E44AD),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Two-column grid for badges
                          Row(
                            children: [
                              // Card 1: Books read progress
                              if (nextBookIndex != -1 && booksRead < 1000)
                                Expanded(
                                  child: PulseAnimation(
                                    duration: const Duration(milliseconds: 2000),
                                    minOpacity: 0.85,
                                    child: _buildCircularBadgeCard(
                                    bookBadges[nextBookIndex]['name'] as String,
                                    bookBadges[nextBookIndex]['icon'] as IconData,
                                    booksRead,
                                    bookBadges[nextBookIndex]['books'] as int,
                                    booksRead == 1 ? 'book' : 'books',
                                  ),
                                  ),
                                ),
                              if (nextBookIndex != -1 && booksRead < 1000 && nextStreakIndex != -1 && totalReadingMinutes < 3000)
                                const SizedBox(width: 12),
                              // Card 2: Reading time progress
                              if (nextStreakIndex != -1 && totalReadingMinutes < 3000)
                                Expanded(
                                  child: PulseAnimation(
                                    duration: const Duration(milliseconds: 2000),
                                    minOpacity: 0.85,
                                    child: _buildCircularBadgeCard(
                                    streakBadges[nextStreakIndex]['name'] as String,
                                    streakBadges[nextStreakIndex]['icon'] as IconData,
                                    totalReadingMinutes,
                                    streakBadges[nextStreakIndex]['minutes'] as int,
                                    'minutes',
                                  ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 30),
                        ],
                      );
                      },
                    ),

                    // Weekly Challenge Card
                    _buildWeeklyChallengeCard(),

                    const SizedBox(height: 30),

                    // Continue reading section - only show if there are ongoing books
                    () {
                      // Group progress by bookId and get the latest progress for each book
                      final progressByBook = <String, ReadingProgress>{};

                      for (final progress in bookProvider.userProgress) {
                        if (!progress.isCompleted &&
                            progress.progressPercentage > 0) {
                          final existing = progressByBook[progress.bookId];
                          if (existing == null ||
                              progress.lastReadAt
                                  .isAfter(existing.lastReadAt)) {
                            progressByBook[progress.bookId] = progress;
                          }
                        }
                      }

                      final ongoingBooks = progressByBook.values.toList();
                      ongoingBooks.sort((a, b) => b.lastReadAt
                          .compareTo(a.lastReadAt)); // Most recent first
                      final recentBooks = ongoingBooks.take(2).toList();

                      // Filter out books that don't exist in the book list
                      final validBooks = recentBooks
                          .map((progress) => {
                                'progress': progress,
                                'book':
                                    bookProvider.getBookById(progress.bookId),
                              })
                          .where((item) => item['book'] != null)
                          .toList();

                      if (validBooks.isEmpty) {
                        return const SizedBox
                            .shrink(); // Don't show section if no valid ongoing books
                      }

                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Keep Going',
                                style: AppTheme.heading,
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    SlideRightRoute(
                                      page: const LibraryScreen(
                                          initialTab: 2), // Ongoing tab
                                    ),
                                  );
                                },
                                child: Text(
                                  'Show all',
                                  style: AppTheme.bodyMedium.copyWith(
                                    color: Color(0xFF8E44AD),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // Show ongoing books
                          ...validBooks.map((item) {
                            final progress =
                                item['progress'] as ReadingProgress;
                            final book = item['book'] as Book;

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
                        Text(
                          'Start Reading',
                          style: AppTheme.heading,
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              SlideRightRoute(
                                page: const LibraryScreen(
                                    initialTab: 1), // Recommended tab
                              ),
                            );
                          },
                          child: Text(
                            'Show all',
                            style: AppTheme.bodyMedium.copyWith(
                              color: Color(0xFF8E44AD),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Recommended books list - using combined AI + rule-based recommendations
                    () {
                      // Filter out completed and in-progress books before displaying
                      final availableBooks =
                          bookProvider.combinedRecommendedBooks
                              .where((book) {
                                final progress =
                                    bookProvider.getProgressForBook(book.id);
                                return progress == null;
                              })
                              .take(3)
                              .toList();

                      if (availableBooks.isEmpty) {
                        final hasCompletedQuiz =
                            authProvider.getPersonalityTraits().isNotEmpty;
                        return _buildEmptyRecommendations(hasCompletedQuiz);
                      }

                      return Column(
                        children: availableBooks.map((book) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 15),
                            child: PressableCard(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  SlideUpRoute(
                                    page: BookDetailsScreen(
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
                        }).toList(),
                      );
                    }(),


                  ],
                ),
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
            Text(
              'Oops! Something went wrong',
              style: AppTheme.heading.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              error,
              style: AppTheme.body.copyWith(
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            CompactButton(
              text: 'Try Again',
              onPressed: onRetry,
              icon: Icons.refresh,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyRecommendations(bool hasCompletedQuiz) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 15),
            Text(
              hasCompletedQuiz
                  ? 'Amazing! You\'ve explored all available books. Check back soon for new recommendations!'
                  : 'Complete your personality quiz to get personalized recommendations!',
              style: AppTheme.body.copyWith(
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (!hasCompletedQuiz)
              CompactButton(
                text: 'Take Quiz',
                onPressed: () {
                  Navigator.push(
                    context,
                    ScaleFadeRoute(
                      page: const QuizScreen(),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // Build calendar from provider's streak boolean list. streakDays is expected as [today, yesterday, ...].
  Widget _buildContinueReadingCard(Book book, ReadingProgress progress) {
    return PressableCard(
      onTap: () {
        // Navigate directly to PDF reader with saved page
        if (book.hasPdf && book.pdfUrl != null) {
          Navigator.push(
            context,
            SlideUpRoute(
              page: PdfReadingScreenSyncfusion(
                bookId: book.id,
                title: book.title,
                author: book.author,
                pdfUrl: book.pdfUrl!,
                initialPage: progress.currentPage, // Resume from last page
              ),
            ),
          );
        } else {
          // Fallback to book details if no PDF
          Navigator.push(
            context,
            SlideUpRoute(
              page: BookDetailsScreen(
                bookId: book.id,
                title: book.title,
                author: book.author,
                description: book.description,
                ageRating: book.ageRating,
                emoji: book.displayCover,
              ),
            ),
          );
        }
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
            BookCover(book: book, width: 80, height: 100),
            const SizedBox(width: 12),
            // Book info
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title with icon
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_stories,
                          size: 16,
                          color: Color(0xFF8E44AD),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            book.title,
                            style: AppTheme.body.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.person,
                          size: 16,
                          color: Color(0xFF8E44AD),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            book.author,
                            style: AppTheme.bodyMedium.copyWith(
                              color: Colors.grey,
                            ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Continue reading text
                  Text(
                    'Continue reading >',
                    style: AppTheme.bodyMedium.copyWith(
                      color: Color(0xFF8E44AD),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Progress bar
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress.progressPercentage,
                            backgroundColor: Colors.grey[200],
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF8E44AD)),
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(progress.progressPercentage * 100).round()}%',
                        style: AppTheme.bodySmall.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
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
    // Get progress for this book
    final bookProvider = Provider.of<BookProvider>(context, listen: false);
    final progress = bookProvider.getProgressForBook(book.id);
    
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Cover + Details + CTA
          Row(
            children: [
              // Book cover with real images
              BookCover(book: book),
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
                            style: AppTheme.body.copyWith(
                              fontWeight: FontWeight.w700,
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
                            style: AppTheme.bodyMedium.copyWith(
                              color: Colors.grey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    // Reading time & age rating
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          size: 16,
                          color: Color(0xFF8E44AD),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${book.estimatedReadingTime} min',
                          style: AppTheme.bodyMedium.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.child_care,
                          size: 16,
                          color: Color(0xFF8E44AD),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          book.ageRating,
                          style: AppTheme.bodyMedium.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    // Progress indicator (compact, under metadata)
                    if (progress != null &&
                        progress.progressPercentage > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress.progressPercentage,
                                backgroundColor: Colors.grey[200],
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(
                                        Color(0xFF8E44AD)),
                                minHeight: 4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(progress.progressPercentage * 100).round()}%',
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
              // Action button
              ProgressButton(
                text: progress?.isCompleted == true
                    ? 'Re-read'
                    : progress != null && progress.progressPercentage > 0
                        ? 'Resume'
                        : 'Start',
                type: progress?.isCompleted == true
                    ? ProgressButtonType.completed
                    : progress != null && progress.progressPercentage > 0
                        ? ProgressButtonType.inProgress
                        : ProgressButtonType.notStarted,
                onPressed: () {
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
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChallengeCard() {
    final bookProvider = Provider.of<BookProvider>(context);

    // Calculate books completed this week
    final now = DateTime.now();
    // Start of week is Monday at 00:00:00
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));

    final completedThisWeek = bookProvider.userProgress.where((p) {
      if (!p.isCompleted) return false;

      // Check if completion was this week
      final completionDate = p.lastReadAt;
      return completionDate.isAfter(startOfWeek) ||
          completionDate.isAtSameMomentAs(startOfWeek);
    }).length;

    final userBooksThisWeek = completedThisWeek;
    final targetBooks = 5;
    final progress = targetBooks > 0 ? userBooksThisWeek / targetBooks : 0.0;
    final daysRemaining = 7 - DateTime.now().weekday;
    final isChallengeComplete = userBooksThisWeek >= targetBooks;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: const Color(0xFF8E44AD).withValues(alpha: 0.2),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Trophy watermark positioned absolutely on the right
          Positioned(
            top: -20,
            right: -15,
            child: Text(
              '🏆',
              style: TextStyle(
                fontSize: 100,
                color: Colors.grey.withValues(alpha: 0.12),
              ),
            ),
          ),
          // Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time chip or Complete chip at the top
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isChallengeComplete
                      ? const Color(0xFF8E44AD).withValues(alpha: 0.15)
                      : const Color(0xFF8E44AD).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isChallengeComplete) ...[
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFF8E44AD),
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      isChallengeComplete
                          ? 'Complete'
                          : '$daysRemaining ${daysRemaining == 1 ? 'day' : 'days'} left',
                      style: AppTheme.bodySmall.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF8E44AD),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Title
              Text(
                'This Week\'s Challenge',
                style: AppTheme.heading.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              // Short description
              Text(
                isChallengeComplete
                    ? 'You crushed it! 🎉'
                    : 'Finish $targetBooks books this week',
                style: AppTheme.body.copyWith(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              // Progress bar with count
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 195,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress > 1.0 ? 1.0 : progress,
                        backgroundColor: const Color(0xFF8E44AD).withValues(alpha: 0.12),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF8E44AD),
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Progress count next to bar
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '$userBooksThisWeek',
                          style: AppTheme.heading.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF8E44AD),
                          ),
                        ),
                        TextSpan(
                          text: '/$targetBooks',
                          style: AppTheme.body.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Future<void> _checkAndShowWeeklyCelebration(int booksCompleted, int targetBooks) async {
    if (!mounted) return;
    
    try {
      // Show celebration
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WeeklyChallengeCelebrationScreen(
              booksCompleted: booksCompleted,
              targetBooks: targetBooks,
              pointsEarned: 50, // Bonus points for completing weekly challenge
            ),
          ),
        );
      }
    } catch (e) {
      appLog('Error showing weekly celebration: $e', level: 'ERROR');
    }
  }

  // Build vertical day bars for streak widget
  List<Widget> _buildVerticalDayBars(
      List<bool> streakDays, Map<String, int> weeklyProgress) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = DateTime.now();
    final currentDayIndex = today.weekday - 1;

    return days.asMap().entries.map((entry) {
      final index = entry.key;
      final isFutureDay = index > currentDayIndex;
      final isToday = index == currentDayIndex;

      bool hasRead = false;
      if (!isFutureDay && streakDays.isNotEmpty) {
        final daysAgo = currentDayIndex - index;
        if (daysAgo >= 0 && daysAgo < streakDays.length) {
          hasRead = streakDays[daysAgo];
        }
      }

      return Padding(
        padding: const EdgeInsets.only(left: 3),
        child: Container(
          width: 8,
          height: 40,
          decoration: BoxDecoration(
            // Today: white (full opacity)
            // Previous days with reading: yellow
            // Previous days without reading: white with reduced opacity
            // Future days: white with very low opacity
            color: isToday
                ? Colors.white
                : hasRead
                    ? const Color(0xFFFFD700) // Golden yellow for completed days
                    : Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );
    }).toList();
  }

  // Build circular progress badge card
  Widget _buildCircularBadgeCard(
    String badgeName,
    IconData badgeIcon,
    int current,
    int target,
    String unit,
  ) {
    final remaining = target - current;
    final isCompleted = current >= target;
    final progress = isCompleted ? 1.0 : (current / target);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: Colors.grey.shade200,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Circular progress indicator
          SizedBox(
            width: 70,
            height: 70,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background circle
                SizedBox(
                  width: 70,
                  height: 70,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 6,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.grey.shade200,
                    ),
                  ),
                ),
                // Progress circle
                SizedBox(
                  width: 70,
                  height: 70,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 6,
                    backgroundColor: Colors.transparent,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF8E44AD),
                    ),
                  ),
                ),
                // Icon in center
                Icon(
                  badgeIcon,
                  color: const Color(0xFF8E44AD),
                  size: 28,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Badge name
          Text(
            badgeName,
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          // Progress count
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$current',
                  style: AppTheme.heading.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF8E44AD),
                  ),
                ),
                TextSpan(
                  text: '/$target',
                  style: AppTheme.body.copyWith(
                    fontSize: 16,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Remaining text
          Text(
            isCompleted
                ? 'Done! 🎉'
                : remaining == 1
                    ? '1 $unit to go!'
                    : '$remaining $unit to go!',
            style: AppTheme.bodySmall.copyWith(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}
