import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../book/book_details_screen.dart';
import '../../providers/book_provider.dart';
import '../../providers/auth_provider.dart';
import 'settings_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late TabController _myBooksTabController;
  
  // Search and filter state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedAgeRating;
  List<String> _selectedTraits = [];
  bool _showSearchBar = false;
  bool _isFilterDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _myBooksTabController = TabController(length: 3, vsync: this);
    
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

      if (authProvider.userId != null && bookProvider.allBooks.isEmpty) {
        await bookProvider.loadAllBooks(userId: authProvider.userId);
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
    _myBooksTabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Book cover widget (handles both images and emoji)
  Widget _buildBookCover(Book book) {
    if (book.hasRealCover) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          book.coverImageUrl!,
          width: 60,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Fallback to emoji if image fails to load
            return Container(
              width: 60,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF8E44AD).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  book.displayCover,
                  style: const TextStyle(fontSize: 25),
                ),
              ),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 60,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
        ),
      );
    } else {
      // Fallback to emoji
      return Container(
        width: 60,
        height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFF8E44AD).withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            book.displayCover,
            style: const TextStyle(fontSize: 25),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header with Search/Filter
            _buildHeaderWithSearch(),
            
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
                Tab(text: 'Favorites'),
              ],
            ),
            
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  Column(
                    children: [
                      TabBar(
                        controller: _myBooksTabController,
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
                          Tab(text: 'All'),
                          Tab(text: 'Ongoing'),
                          Tab(text: 'Completed'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _myBooksTabController,
                          children: [
                            _buildMyBooksTab(),
                            _buildMyBooksTab(), // Placeholder for ongoing
                            _buildMyBooksTab(), // Placeholder for completed
                          ],
                        ),
                      ),
                    ],
                  ),
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
          color: Color(0xFFF5F5F5),
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
    return Consumer2<BookProvider, AuthProvider>(
      builder: (context, bookProvider, authProvider, child) {
        // Get all books and apply filters
        final allBooks = bookProvider.allBooks;
        
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
                            book.displayCover,
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
        // Show all books from backend as favorites
        final favoriteBooks = bookProvider.allBooks;

        if (favoriteBooks.isEmpty) {
          return _buildEmptyState(
            'Loading your books...',
            'Please wait while we load your books from the backend',
            '❤️📖',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: favoriteBooks.length,
          itemBuilder: (context, index) {
            final book = favoriteBooks[index];
            
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
                            book.displayCover,
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
                ...['6+', '7+', '12+', '16+', '18+'].map((age) => RadioListTile<String>(
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
}
