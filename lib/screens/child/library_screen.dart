import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../book/book_details_screen.dart';
import 'settings_screen.dart';
import 'child_home_screen.dart';
import '../../providers/book_provider.dart';
import '../../providers/auth_provider.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLibraryData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLibraryData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final bookProvider = Provider.of<BookProvider>(context, listen: false);

      if (authProvider.userId != null) {
        // Load user's books and progress
        await bookProvider.loadUserProgress(authProvider.userId!);
        await bookProvider.loadAllBooks(userId: authProvider.userId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading library: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _loadLibraryData,
            ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'My Library',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Search coming soon! 🔍'),
                              backgroundColor: Color(0xFF8E44AD),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.search,
                          color: Color(0xFF8E44AD),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Filter coming soon! ⚙️'),
                              backgroundColor: Color(0xFF8E44AD),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.tune,
                          color: Color(0xFF8E44AD),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Tabs
            TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF8E44AD),
              labelColor: const Color(0xFF8E44AD),
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.normal,
              ),
              tabs: const [
                Tab(text: 'My Books'),
                Tab(text: 'All Books'),
              ],
            ),
            
            // Tab content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF8E44AD),
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildMyBooksTab(),
                        _buildAllBooksTab(),
                      ],
                    ),
            ),
          ],
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
            _buildNavItem(Icons.home, 'Home', false, () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChildHomeScreen(),
                ),
              );
            }),
            _buildNavItem(Icons.library_books, 'Library', true, () {}),
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

  Widget _buildMyBooksTab() {
    return Consumer2<BookProvider, AuthProvider>(
      builder: (context, bookProvider, authProvider, child) {
        // Get books that user has started reading
        final userBooks = bookProvider.userProgress
            .map((progress) => bookProvider.getBookById(progress.bookId))
            .where((book) => book != null)
            .cast<Book>()
            .toList();

        if (userBooks.isEmpty) {
          return _buildEmptyState(
            'No books yet!',
            'Start exploring and add books to your library',
            '📚✨',
            () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChildHomeScreen(),
                ),
              );
            },
          );
        }

        return RefreshIndicator(
          onRefresh: _loadLibraryData,
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: userBooks.length,
            itemBuilder: (context, index) {
              final book = userBooks[index];
              final progress = bookProvider.getProgressForBook(book.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: _buildBookCard(book, progress),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildAllBooksTab() {
    return Consumer<BookProvider>(
      builder: (context, bookProvider, child) {
        final books = bookProvider.filteredBooks.isNotEmpty 
            ? bookProvider.filteredBooks 
            : bookProvider.allBooks;

        if (books.isEmpty) {
          return _buildEmptyState(
            'No books available!',
            'Check your internet connection and try again',
            '📖😔',
            _loadLibraryData,
          );
        }

        return RefreshIndicator(
          onRefresh: _loadLibraryData,
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              final progress = bookProvider.getProgressForBook(book.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: _buildBookCard(book, progress),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String title, String subtitle, String emoji, VoidCallback onAction) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 80),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
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
              onPressed: onAction,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    title.contains('No books yet') ? Icons.explore : Icons.refresh,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title.contains('No books yet') ? 'Explore Books' : 'Try Again',
                    style: const TextStyle(
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

  Widget _buildBookCard(Book book, ReadingProgress? progress) {
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
                  const SizedBox(height: 5),
                  Text(
                    '${book.estimatedReadingTime} min • ${book.ageRating}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Progress bar (only for books with progress)
                  if (progress != null && progress.progressPercentage > 0) ...[
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
                                  color: progress.isCompleted
                                      ? Colors.green
                                      : const Color(0xFF8E44AD),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          progress.isCompleted
                              ? 'Completed ✅'
                              : '${(progress.progressPercentage * 100).round()}%',
                          style: TextStyle(
                            fontSize: 12,
                            color: progress.isCompleted
                                ? Colors.green
                                : const Color(0xFF8E44AD),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8E44AD).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Not started',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8E44AD),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Action button
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
                  color: progress?.isCompleted == true
                      ? Colors.green
                      : const Color(0xFF8E44AD),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  progress?.isCompleted == true
                      ? 'Read Again'
                      : progress != null && progress.progressPercentage > 0
                          ? 'Continue'
                          : 'Start',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
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
