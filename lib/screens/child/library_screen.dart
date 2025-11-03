import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../book/book_details_screen.dart';
import '../../providers/book_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pressable_card.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/common/progress_button.dart';
import '../../services/feedback_service.dart';

class LibraryScreen extends StatefulWidget {
  final int initialTab;
  
  const LibraryScreen({super.key, this.initialTab = 0});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  
  // Search and filter state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final FocusNode _searchFocusNode = FocusNode();
  String? _selectedAgeRating;
  final List<String> _selectedTraits = [];
  
  int? _lastPopupBooksRead; // To avoid duplicate popups

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this, initialIndex: widget.initialTab); // All, Recommended, Ongoing, Completed, Favorites
    
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

      // Listen for changes in totalBooksRead to show popup
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      userProvider.addListener(_checkShowBooksReadPopup);

      if (authProvider.userId != null) {
        // Load books if not already loaded - this will automatically apply content filters
        if (bookProvider.filteredBooks.isEmpty) {
          await bookProvider.loadAllBooks(userId: authProvider.userId);
        }

        // CRITICAL FIX: Always reload progress and favorites for fresh state (in parallel)
        await Future.wait([
          bookProvider.loadUserProgress(authProvider.userId!),
          bookProvider.loadFavorites(authProvider.userId!),
        ]);
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


  void _checkShowBooksReadPopup() {
    if (!mounted) return;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final int booksRead = userProvider.totalBooksRead;
    // Only show for every 10 books, but not for badge milestones (handled elsewhere)
    const badgeMilestones = [1, 3, 5, 10, 20, 25, 50, 75, 100, 200, 500, 1000];
    if (booksRead > 0 && booksRead % 10 == 0 && !badgeMilestones.contains(booksRead)) {
      if (_lastPopupBooksRead != booksRead) {
        _lastPopupBooksRead = booksRead;
        // Show congratulatory SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Congratulations! You have completed $booksRead books!'),
            backgroundColor: Colors.deepPurple,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
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
          height: 90,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 60,
            height: 90,
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
            height: 90,
            decoration: BoxDecoration(
              color: AppTheme.primaryPurpleOpaque10,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                book.fallbackEmoji,
                style: const TextStyle(fontSize: 28),
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
        height: 90,
        decoration: BoxDecoration(
          color: AppTheme.primaryPurpleOpaque10,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            book.fallbackEmoji,
            style: const TextStyle(fontSize: 28),
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
              padding: const EdgeInsets.symmetric(horizontal: 20),
              tabAlignment: TabAlignment.start,
              indicatorColor: AppTheme.primaryPurple,
              labelColor: AppTheme.primaryPurple,
              unselectedLabelColor: AppTheme.textGray,
              labelStyle: AppTheme.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: AppTheme.bodyMedium,
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
      bottomNavigationBar: const AppBottomNav(
        currentTab: NavTab.library,
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
              Text(
                'My Library',
                style: AppTheme.heading.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Row(
                children: [
                  // Inline expanding search: tapping the icon expands a TextField in place
                  IconButton(
                    onPressed: () {
                      setState(() {
                        // Focus the inline search to open it
                        if (_searchQuery.isEmpty) {
                          FocusScope.of(context).requestFocus(_searchFocusNode);
                        } else {
                          // clear if already active
                          _clearAllFilters();
                        }
                      });
                      FeedbackService.instance.playTap();
                    },
                    icon: Icon(
                      _searchQuery.isNotEmpty ? Icons.close : Icons.search,
                      color: const Color(0xFF8E44AD),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      _showFilterDialog();
                      FeedbackService.instance.playTap();
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
        // Inline search field shown when focused or has text
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: SizedBox(
              height: (_searchQuery.isNotEmpty || _searchFocusNode.hasFocus) ? 56 : 0,
              child: (_searchQuery.isNotEmpty || _searchFocusNode.hasFocus)
                  ? TextField(
                      focusNode: _searchFocusNode,
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by title, author, or description',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _clearAllFilters();
                                  FeedbackService.instance.playTap();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (v) => setState(() {
                        _searchQuery = v;
                      }),
                      onSubmitted: (_) => setState(() {}),
                    )
                  : const SizedBox.shrink(),
            ),
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
          style: AppTheme.bodySmall,
        ),
  backgroundColor: const Color(0x1A8E44AD),
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
          allBooks = bookProvider.filteredBooks;
        }
        
        // Apply search and filters
        final filteredBooks = _applyFilters(allBooks);

        if (filteredBooks.isEmpty) {
          if (allBooks.isEmpty) {
            return _buildEmptyState(
              'Loading your books...',
              'Please wait while we load your 60+ books from the backend',
              icon: Icons.cloud_download,
            );
          }
          return _buildEmptyState(
            'No books found',
            'Try adjusting your search or filter criteria',
            icon: Icons.search_off,
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
              child: PressableCard(
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
                      // Top Row: Cover + Details + CTA
                      Row(
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
                                // Reading time & age rating on same line
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
                                if (progress != null && progress.progressPercentage > 0) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: progress.progressPercentage,
                                            backgroundColor: Colors.grey[200],
                                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8E44AD)),
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
                                    ? 'Continue'
                                    : 'Start',
                            type: progress?.isCompleted == true
                                ? ProgressButtonType.completed
                                : progress != null && progress.progressPercentage > 0
                                    ? ProgressButtonType.inProgress
                                    : ProgressButtonType.notStarted,
                          ),
                        ],
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
    // Get user's favorite books from BookProvider
    final favoriteBooks = bookProvider.favoriteBooks;

        final filteredBooks = _applyFilters(favoriteBooks);

        if (filteredBooks.isEmpty) {
          if (favoriteBooks.isEmpty) {
            return _buildEmptyState(
              'No favorite books yet',
              'Tap the heart icon on a book to add it to your favorites.',
              icon: Icons.favorite_border,
            );
          }
          return _buildEmptyState(
            'No books found',
            'Try adjusting your search or filter criteria',
            icon: Icons.filter_list_off,
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
              child: PressableCard(
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
                      // Top Row: Cover + Details + CTA
                      Row(
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
                                // Reading time & age rating on same line
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
                                if (progress != null && progress.progressPercentage > 0) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: progress.progressPercentage,
                                            backgroundColor: Colors.grey[200],
                                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8E44AD)),
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
                                    ? 'Continue'
                                    : 'Start',
                            type: progress?.isCompleted == true
                                ? ProgressButtonType.completed
                                : progress != null && progress.progressPercentage > 0
                                    ? ProgressButtonType.inProgress
                                    : ProgressButtonType.notStarted,
                          ),
                        ],
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

  Widget _buildEmptyState(String title, String subtitle, {IconData? icon, Widget? illustration}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Use illustration if provided, otherwise use icon or default
            if (illustration != null)
              illustration
            else if (icon != null)
              Icon(
                icon,
                size: 80,
                color: const Color(0x4D8E44AD),
              )
            else
              Icon(
                Icons.auto_stories,
                size: 80,
                color: const Color(0x4D8E44AD),
              ),
            const SizedBox(height: 30),
            Text(
              title,
              style: AppTheme.heading.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: AppTheme.body.copyWith(
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.explore, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Explore Books',
                    style: AppTheme.buttonText.copyWith(
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



  // Missing methods implementation
  // Inline search replaces the previous dialog-based search. The
  // old dialog method was removed to keep the UX consistent for kids.

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
                ...['6+', '7+', '8+', '9+'].map((age) => ListTile(
                  title: Text(age),
                  selected: _selectedAgeRating == age,
                  onTap: () {
                    setDialogState(() {
                      _selectedAgeRating = age;
                    });
                  },
                  trailing: _selectedAgeRating == age
                      ? const Icon(Icons.radio_button_checked, color: Color(0xFF8E44AD))
                      : const Icon(Icons.radio_button_off, color: Colors.grey),
                )),
                const SizedBox(height: 16),
                const Text(
                  'Traits',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...[
                  'curious', 'creative', 'imaginative', // Openness
                  'responsible', 'organized', 'persistent', // Conscientiousness
                  'social', 'enthusiastic', 'outgoing', // Extraversion
                  'kind', 'cooperative', 'caring', // Agreeableness
                  'resilient', 'calm', 'positive' // Emotional Stability
                ].map((trait) => CheckboxListTile(
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
    // Store original indices BEFORE filtering to preserve AI-first order
    final bookIndices = <String, int>{};
    for (var i = 0; i < books.length; i++) {
      bookIndices[books[i].id] = i;
    }
    
    final filteredBooks = books.where((book) {
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

    // Sort books: completed books go to the bottom, but preserve original order otherwise
    
    filteredBooks.sort((a, b) {
      final progressA = Provider.of<BookProvider>(context, listen: false).getProgressForBook(a.id);
      final progressB = Provider.of<BookProvider>(context, listen: false).getProgressForBook(b.id);
      
      final isCompletedA = progressA?.isCompleted == true;
      final isCompletedB = progressB?.isCompleted == true;

      // Priority 1: Completed books always go to the bottom
      if (isCompletedA && !isCompletedB) return 1;
      if (!isCompletedA && isCompletedB) return -1;
      
      // Priority 2: Within same completion status, maintain original order (AI recommendations first)
      return (bookIndices[a.id] ?? 0).compareTo(bookIndices[b.id] ?? 0);
    });

    return filteredBooks;
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
        // Load recommendations if not loaded yet
        if (bookProvider.recommendedBooks.isEmpty && userProvider.personalityTraits.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            bookProvider.loadRecommendedBooks(
              userProvider.personalityTraits, 
              userId: authProvider.userId,
            );
          });
        }
        
        // Get combined recommended books and apply filters (limit to 20 max for performance)
        final combinedBooks = bookProvider.combinedRecommendedBooks.take(20).toList();
        final filteredBooks = _applyFilters(combinedBooks);

        if (filteredBooks.isEmpty) {
          if (combinedBooks.isEmpty) {
            return _buildEmptyState(
              'No recommendations yet',
              'Complete some reading activities to get personalized book recommendations!',
              icon: Icons.recommend,
            );
          }
          return _buildEmptyState(
            'No books found',
            'Try adjusting your search or filter criteria',
            icon: Icons.search_off,
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
              child: PressableCard(
                onTap: () {
                  FeedbackService.instance.playTap();
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
                      // Top Row: Cover + Details + CTA
                      Row(
                        children: [
                          // Book cover
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
                                // Reading time & age rating on same line
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
                                if (progress != null && progress.progressPercentage > 0) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: progress.progressPercentage,
                                            backgroundColor: Colors.grey[200],
                                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8E44AD)),
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
                                    ? 'Continue'
                                    : 'Start',
                            type: progress?.isCompleted == true
                                ? ProgressButtonType.completed
                                : progress != null && progress.progressPercentage > 0
                                    ? ProgressButtonType.inProgress
                                    : ProgressButtonType.notStarted,
                          ),
                        ],
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
            'Start reading some books to see them here',
            icon: Icons.menu_book,
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
              child: PressableCard(
                onTap: () {
                  FeedbackService.instance.playTap();
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
                      // Top Row: Cover + Details + CTA
                      Row(
                        children: [
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
                                // Reading time & age rating on same line
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
                                if (progress != null && progress.progressPercentage > 0) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: progress.progressPercentage,
                                            backgroundColor: Colors.grey[200],
                                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8E44AD)),
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
                            text: 'Continue',
                            type: ProgressButtonType.inProgress,
                          ),
                        ],
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
                'Finish reading some books to see them here',
                icon: Icons.check_circle_outline,
              );
            }
            
            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: filteredBooks.length,
              itemBuilder: (context, index) {
                final book = filteredBooks[index];
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: PressableCard(
                    onTap: () {
                      FeedbackService.instance.playTap();
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
                          // Top Row: Cover + Details + CTA
                          Row(
                            children: [
                              // Book cover
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
                                    // Reading time & age rating on same line
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.schedule,
                                          size: 14,
                                          color: Color(0xFF8E44AD),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${book.estimatedReadingTime} min',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(width: 15),
                                        const Icon(
                                          Icons.child_care,
                                          size: 14,
                                          color: Color(0xFF8E44AD),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          book.ageRating,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Progress indicator (always show for completed)
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: LinearProgressIndicator(
                                              value: 1.0,
                                              backgroundColor: Colors.grey[200],
                                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8E44AD)),
                                              minHeight: 4,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '100%',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Action button
                              ProgressButton(
                                text: 'Re-read',
                                type: ProgressButtonType.completed,
                              ),
                            ],
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
