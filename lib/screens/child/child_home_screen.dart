import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../book/book_details_screen.dart';
import '../quiz/quiz_screen.dart';
import '../../providers/auth_provider.dart';
import '../../providers/book_provider.dart';
import '../../providers/user_provider.dart';
import 'library_screen.dart';
import 'settings_screen.dart';

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

  Future<void> _loadData() async {
    // Minimal loading - only load if data is not already available
    if (!mounted) return;
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final bookProvider = Provider.of<BookProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      if (authProvider.userId != null) {
        // Only load if we don't have data already (offline-first approach)
        if (bookProvider.allBooks.isEmpty) {
          await bookProvider.loadAllBooks(userId: authProvider.userId);
        }
        if (bookProvider.recommendedBooks.isEmpty) {
          await bookProvider.loadRecommendedBooks(
            authProvider.getPersonalityTraits(),
            userId: authProvider.userId,
          );
        }
        if (userProvider.userProfile == null) {
          await userProvider.loadUserData(authProvider.userId!);
        }
      }
    } catch (e) {
      print('Error loading data: $e');
      // Don't show error snackbar to avoid interrupting user experience
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                authProvider.userProfile?['username'] ?? 'Reader',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Profile avatar
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF8E44AD).withOpacity(0.1),
                            border: Border.all(
                              color: const Color(0xFF8E44AD),
                              width: 2,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              '👦',
                              style: TextStyle(fontSize: 24),
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
                          // Week calendar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: _buildWeekCalendar(userProvider.weeklyProgress),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Continue reading section
                    if (bookProvider.userProgress.isNotEmpty) ...[
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
                                  builder: (context) => const LibraryScreen(),
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
                      
                      // Show incomplete books
                      ...bookProvider.userProgress
                          .where((progress) => !progress.isCompleted)
                          .take(2)
                          .map((progress) {
                        final book = bookProvider.getBookById(progress.bookId);
                        if (book == null) return const SizedBox.shrink();
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 15),
                          child: _buildContinueReadingCard(book, progress),
                        );
                      }).toList(),
                      
                      const SizedBox(height: 30),
                    ],
                    
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
                                builder: (context) => const LibraryScreen(),
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
                    
                    // Recommended books list
                    if (bookProvider.recommendedBooks.isNotEmpty)
                      ...bookProvider.recommendedBooks.take(3).map((book) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 15),
                          child: GestureDetector(
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
                                    emoji: book.coverEmoji,
                                  ),
                                ),
                              );
                            },
                            child: _buildBookCard(book),
                          ),
                        );
                      }).toList()
                    else
                      _buildEmptyRecommendations(),
                    
                    const SizedBox(height: 100), // Space for bottom navigation
                  ],
                ),
            );
          },
        ),
      ),
      
      // Bottom Navigation Bar
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          color: Color(0xFFF5F5F5),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(Icons.home, 'Home', true, () {}),
            _buildNavItem(Icons.library_books, 'Library', false, () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LibraryScreen(),
                ),
              );
            }),
            _buildNavItem(Icons.settings, 'Settings', false, () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            }),
          ],
        ),
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

  List<Widget> _buildWeekCalendar(Map<String, int> weeklyProgress) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = DateTime.now();
    final currentDayIndex = today.weekday - 1; // Monday = 0
    
    return days.asMap().entries.map((entry) {
      final index = entry.key;
      final day = entry.value;
      final hasRead = (weeklyProgress[day] ?? 0) > 0;
      final isToday = index == currentDayIndex;
      
      return _buildDayCircle(day, hasRead, isToday: isToday);
    }).toList();
  }

  Widget _buildDayCircle(String day, bool isCompleted, {bool isToday = false}) {
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
            border: isToday 
              ? null 
              : Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 1,
                ),
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
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildContinueReadingCard(Book book, ReadingProgress progress) {
    return GestureDetector(
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
              emoji: book.coverEmoji,
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
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Book cover
            Container(
              width: 60,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF8E44AD).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  book.coverEmoji,
                  style: const TextStyle(fontSize: 30),
                ),
              ),
            ),
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
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Book cover
          Container(
            width: 60,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF8E44AD).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                book.coverEmoji,
                style: const TextStyle(fontSize: 25),
              ),
            ),
          ),
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
          GestureDetector(
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
                    emoji: book.coverEmoji,
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

  Widget _buildNavItem(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? const Color(0xFF8E44AD) : Colors.grey,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? const Color(0xFF8E44AD) : Colors.grey,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
