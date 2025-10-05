import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../book/book_details_screen.dart';
import '../../providers/book_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_theme.dart';
import 'settings_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  
  // Search and filter state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedAgeRating;
  final List<String> _selectedTraits = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this); // All, Recommended, Ongoing, Completed, Favorites
    
    // Listen to search changes
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    
    // Use addPostFrameCallback to avoid calling notifyListeners during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLibraryData();
    });
  }

  Future<void> _loadLibraryData() async {
    if (!mounted) return;
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final bookProvider = Provider.of<BookProvider>(context, listen: false);

      if (authProvider.userId != null) {
        // Load books if not already loaded
        if (bookProvider.allBooks.isEmpty) {
          await bookProvider.loadAllBooks(userId: authProvider.userId);
        }
        // Load user progress for ongoing/completed tabs
        await bookProvider.loadUserProgress(authProvider.userId!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading library: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

   // Enhanced book cover widget with caching and smooth loading
  Widget _buildBookCover(Book book) {
    if (book.hasRealCover) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: book.coverImageUrl!,
          width: 60,
          height: 80,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 60,
            height: 80,
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
            width: 60,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF8E44AD).withOpacity(0.2),
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
        width: 60,
        height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFF8E44AD).withOpacity(0.2),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
  backgroundColor: AppTheme.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header with Search/Filter
            _buildHeaderWithSearch(),
            
            // Single TabBar with 5 tabs
            TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primaryPurple,
              labelColor: AppTheme.primaryPurple,
              unselectedLabelColor: AppTheme.textGray,
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
              isScrollable: true,
              tabs: const [
                Tab(text: 'All Books'),
                Tab(text: 'Recommended'),
                Tab(text: 'Ongoing'),
                Tab(text: 'Completed'),
                Tab(text: 'Favorites'),
              ],
            ),
            
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAllBooksTab(),
                  _buildRecommendedBooksTab(),
                  _buildOngoingBooksTab(),
                  _buildCompletedBooksTab(),
                  _buildFavoritesTab(),
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
          color: AppTheme.lightGray,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
              },
              child: _buildNavItem(Icons.home, 'Home', false),
            ),
            _buildNavItem(Icons.library_books, 'Library', true),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
              child: _buildNavItem(Icons.settings, 'Settings', false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderWithSearch() {
    return Column(
      children: [
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
                      _showSearchDialog();
                    },
                    icon: const Icon(
                      Icons.search,
                      color: Color(0xFF8E44AD),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      _showFilterDialog();
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
        if (_searchQuery.isNotEmpty || _selectedAgeRating != null || _selectedTraits.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        if (_searchQuery.isNotEmpty)
                          _buildFilterChip('Search: $_searchQuery', () {
                            setState(() {
                              _searchQuery = '';
                            });
                          }),
                        if (_selectedAgeRating != null)
                          _buildFilterChip('Age: ${_selectedAgeRating!.replaceAll('+', '+')}', () {
                            setState(() {
                              _selectedAgeRating = null;
                            });
                          }),
                        ..._selectedTraits.map((trait) => _buildFilterChip(trait, () {
                          setState(() {
                            _selectedTraits.remove(trait);
                          });
                        })),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _clearAllFilters,
                  icon: const Icon(Icons.clear_all, color: Color(0xFF8E44AD)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
        backgroundColor: const Color(0xFF8E44AD).withOpacity(0.1),
        deleteIcon: const Icon(Icons.close, size: 16),
        onDeleted: onRemove,
      ),
    );
  }

  Widget _buildMyBooksTab() {
    return Consumer3<BookProvider, AuthProvider, UserProvider>(
      builder: (context, bookProvider, authProvider, userProvider, child) {
        // Get all books, sorted by trait relevance if user has traits
        List<Book> allBooks;
        if (userProvider.personalityTraits.isNotEmpty) {
          allBooks = bookProvider.getBooksSortedByRelevance(userProvider.personalityTraits);
        } else {
          allBooks = bookProvider.allBooks;
        }
        
        // Apply search and filters
        final filteredBooks = _applyFilters(allBooks);

        if (filteredBooks.isEmpty) {
          if (allBooks.isEmpty) {
            return _buildEmptyState(
              'Loading your books...',
              'Please wait while we load your 60+ books from the backend',
              '📚✨',
            );
          }
          return _buildEmptyState(
            'No books found',
            'Try adjusting your search or filter criteria',
            '🔍📖',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: filteredBooks.length,
          itemBuilder: (context, index) {
            final book = filteredBooks[index];
            final progress = bookProvider.getProgressForBook(book.id);
            
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
                        color: Colors.grey.withOpacity(0.1),
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
                            const SizedBox(height: 10),
                            // Progress bar (only for reading/completed books)
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
                                        ? 'Done'
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
                      Container(
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
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFavoritesTab() {
    return Consumer<BookProvider>(
      builder: (context, bookProvider, child) {
    // Only show books explicitly marked as favorite
    final favoriteBooks = bookProvider.allBooks
      .where((book) => book.tags.contains('favorite'))
      .toList();
        
        final filteredBooks = _applyFilters(favoriteBooks);

        if (filteredBooks.isEmpty) {
          if (favoriteBooks.isEmpty) {
            return _buildEmptyState(
              'No favorite books yet',
              'Tap the heart icon on a book to add it to your favorites.',
              '',
            );
          }
          return _buildEmptyState(
            'No books found',
            'Try adjusting your search or filter criteria',
            '',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: favoriteBooks.length,
          itemBuilder: (context, index) {
            final book = filteredBooks[index];
            final progress = bookProvider.getProgressForBook(book.id);
            
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
                        color: Colors.grey.withOpacity(0.1),
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
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'Favorite',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.red,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (progress != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: progress.isCompleted 
                                          ? Colors.green.withOpacity(0.1)
                                          : const Color(0xFF8E44AD).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                    progress.isCompleted 
                      ? 'Done'
                      : '${(progress.progressPercentage * 100).round()}%',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: progress.isCompleted 
                                            ? Colors.green
                                            : const Color(0xFF8E44AD),
                                        fontWeight: FontWeight.w500,
                                      ),
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
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String title, String subtitle, String emoji) {
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
              onPressed: () {
                // Navigate back to home to explore books
                Navigator.pop(context);
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.explore, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Explore Books',
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

  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    return Column(
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
    );
  }

  // Missing methods implementation
  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Books'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Search by title, author, or description...',
            prefixIcon: Icon(Icons.search),
          ),
          autofocus: true,
          onSubmitted: (_) {
            setState(() {
              _searchQuery = _searchController.text;
            });
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _searchQuery = _searchController.text;
              });
              Navigator.pop(context);
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filter Books'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Age Rating',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...['6+', '7+', '8+', '9+'].map((age) => RadioListTile<String>(
                  title: Text(age),
                  value: age,
                  groupValue: _selectedAgeRating,
                  onChanged: (value) {
                    setDialogState(() {
                      _selectedAgeRating = value;
                    });
                  },
                )),
                const SizedBox(height: 16),
                const Text(
                  'Traits',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...['adventurous', 'curious', 'brave', 'imaginative', 'creative', 'kind', 'analytical'].map((trait) => CheckboxListTile(
                  title: Text(trait),
                  value: _selectedTraits.contains(trait),
                  onChanged: (value) {
                    setDialogState(() {
                      if (value == true) {
                        _selectedTraits.add(trait);
                      } else {
                        _selectedTraits.remove(trait);
                      }
                    });
                  },
                )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setDialogState(() {
                  _selectedAgeRating = null;
                  _selectedTraits.clear();
                });
              },
              child: const Text('Clear All'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {});
                Navigator.pop(context);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  List<Book> _applyFilters(List<Book> books) {
    return books.where((book) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final title = book.title.toLowerCase();
        final author = book.author.toLowerCase();
        final description = book.description.toLowerCase();
        
        if (!title.contains(query) && 
            !author.contains(query) && 
            !description.contains(query)) {
          return false;
        }
      }

      // Age rating filter
      if (_selectedAgeRating != null) {
        if (book.ageRating != _selectedAgeRating) {
          return false;
        }
      }

      // Traits filter
      if (_selectedTraits.isNotEmpty) {
        final bookTraits = book.traits.map((t) => t.toLowerCase()).toList();
        bool hasMatchingTrait = false;
        for (final trait in _selectedTraits) {
          if (bookTraits.contains(trait.toLowerCase())) {
            hasMatchingTrait = true;
            break;
          }
        }
        if (!hasMatchingTrait) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  void _clearAllFilters() {
    setState(() {
      _searchQuery = '';
      _selectedAgeRating = null;
      _selectedTraits.clear();
      _searchController.clear();
    });
  }

  // All Books Tab - same as _buildMyBooksTab but renamed
  Widget _buildAllBooksTab() {
    return _buildMyBooksTab();
  }

  // Recommended Books Tab - shows books based on user traits
  Widget _buildRecommendedBooksTab() {
    return Consumer3<BookProvider, AuthProvider, UserProvider>(
      builder: (context, bookProvider, authProvider, userProvider, child) {
        // Load recommendations if not already loaded
        if (bookProvider.recommendedBooks.isEmpty && userProvider.personalityTraits.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            bookProvider.loadRecommendedBooks(
              userProvider.personalityTraits, 
              userId: authProvider.userId,
            );
          });
        }
        
        // Get recommended books and apply filters
        final recommendedBooks = bookProvider.recommendedBooks;
        final filteredBooks = _applyFilters(recommendedBooks);

        if (filteredBooks.isEmpty) {
          if (recommendedBooks.isEmpty) {
            return _buildEmptyState(
              'No recommendations yet',
              'Complete some reading activities to get personalized book recommendations!',
              '✨📚',
            );
          }
          return _buildEmptyState(
            'No books found',
            'Try adjusting your search or filter criteria',
            '🔍📖',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: filteredBooks.length,
          itemBuilder: (context, index) {
            final book = filteredBooks[index];
            final progress = bookProvider.getProgressForBook(book.id);
            
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
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 2,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          _buildBookCover(book),
                          // Recommended badge
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.amber,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.star,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 15),
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
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'Recommended ⭐',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.amber,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (progress != null && progress.progressPercentage > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: progress.isCompleted 
                                          ? Colors.green.withOpacity(0.1)
                                          : const Color(0xFF8E44AD).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      progress.isCompleted 
                                          ? 'Done ✅'
                                          : '${(progress.progressPercentage * 100).round()}%',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: progress.isCompleted 
                                            ? Colors.green
                                            : const Color(0xFF8E44AD),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
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
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Ongoing Books Tab
  Widget _buildOngoingBooksTab() {
    return Consumer<BookProvider>(
      builder: (context, bookProvider, child) {
        final ongoingBooks = bookProvider.getBooksByStatus('ongoing');
        final filteredBooks = _applyFilters(ongoingBooks);

        if (filteredBooks.isEmpty) {
          return _buildEmptyState(
            'No ongoing books',
            'Start reading some books to see them here!',
            '📖⏳',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: filteredBooks.length,
          itemBuilder: (context, index) {
            final book = filteredBooks[index];
            final progress = bookProvider.getProgressForBook(book.id);
            
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
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 2,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _buildBookCover(book),
                      const SizedBox(width: 15),
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
                            const SizedBox(height: 10),
                            if (progress != null) ...[
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
                                      color: Color(0xFF8E44AD),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8E44AD),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Completed Books Tab
  Widget _buildCompletedBooksTab() {
        return Consumer<BookProvider>(
          builder: (context, bookProvider, child) {
            final completedBooks = bookProvider.getBooksByStatus('completed');
            final filteredBooks = _applyFilters(completedBooks);
            
            if (filteredBooks.isEmpty) {
              return _buildEmptyState(
                'No completed books',
                'Finish reading some books to see them here!',
                '',
              );
            }
            
            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: filteredBooks.length,
              itemBuilder: (context, index) {
                final book = filteredBooks[index];
                
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
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 2,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              _buildBookCover(book),
                              Positioned(
                                top: -2,
                                right: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 15),
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
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Done',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Read Again',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
  }
}
