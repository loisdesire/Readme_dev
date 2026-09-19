import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../book/book_details_screen.dart';
import 'child_home_screen.dart';
import '../../providers/book_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/book_card.dart';
import '../../widgets/pressable_card.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../widgets/common/progress_button.dart';
import '../../services/feedback_service.dart';
import '../../utils/page_transitions.dart';
import '../../widgets/app_dialog.dart';

class LibraryScreen extends StatefulWidget {
  final int initialTab;

  const LibraryScreen({super.key, this.initialTab = 0});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with TickerProviderStateMixin {
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
    _tabController = TabController(
        length: 5,
        vsync: this,
        initialIndex: widget
            .initialTab); // All, Recommended, Ongoing, Completed, Favorites

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
            backgroundColor: AppTheme.errorRed,
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
    if (booksRead > 0 &&
        booksRead % 10 == 0 &&
        !badgeMilestones.contains(booksRead)) {
      if (_lastPopupBooksRead != booksRead) {
        _lastPopupBooksRead = booksRead;
        // Show congratulatory SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Congratulations! You have completed $booksRead books!'),
            backgroundColor: AppTheme.primaryPurple,
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
                Tab(text: 'For You'),
                Tab(text: 'Reading Now'),
                Tab(text: 'Finished'),
                Tab(text: 'My Favorites'),
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
              // Flexible + ellipsis: on a narrow phone width this title
              // plus the two icon buttons on the right didn't reliably fit
              // on one line (found while screenshotting at 400px).
              Flexible(
                child: Text(
                  'Your Library',
                  style: AppTheme.heading.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
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
              height: (_searchQuery.isNotEmpty || _searchFocusNode.hasFocus)
                  ? 56
                  : 0,
              child: (_searchQuery.isNotEmpty || _searchFocusNode.hasFocus)
                  ? TextField(
                      focusNode: _searchFocusNode,
                      controller: _searchController,
                      style: AppTheme.body,
                      decoration: InputDecoration(
                        hintText: 'Search by title, author, or description',
                        hintStyle:
                            AppTheme.body.copyWith(color: Colors.grey[400]),
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
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.12),
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.12),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.22),
                            width: 1.5,
                          ),
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
        if (_searchQuery.isNotEmpty ||
            _selectedAgeRating != null ||
            _selectedTraits.isNotEmpty)
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
                          _buildFilterChip(
                              'Age: ${_selectedAgeRating!.replaceAll('+', '+')}',
                              () {
                            setState(() {
                              _selectedAgeRating = null;
                            });
                          }),
                        ..._selectedTraits
                            .map((trait) => _buildFilterChip(trait, () {
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
          allBooks = bookProvider
              .getBooksSortedByRelevance(userProvider.personalityTraits);
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
            'No matches found',
            'Try different keywords or fewer filters',
            icon: Icons.search_off,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: filteredBooks.length,
          itemBuilder: (context, index) {
            final book = filteredBooks[index];
            final progress = bookProvider.getProgressForBook(book.id);

            return AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 375),
              child: SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(
                  child: Padding(
                    key: ValueKey(book.id),
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
                              emoji: book.displayCover,
                            ),
                          ),
                        );
                      },
                      child: BookCard(
                        book: book,
                        progress: progress,
                        enableHero: false,
                        onTap: () {
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
                    ),
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
              'No favorites yet',
              'Tap the heart on any book you love to save it here',
              icon: Icons.favorite_border,
            );
          }
          return _buildEmptyState(
            'No matches found',
            'Try different keywords or fewer filters',
            icon: Icons.filter_list_off,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: filteredBooks.length,
          itemBuilder: (context, index) {
            final book = filteredBooks[index];
            final progress = bookProvider.getProgressForBook(book.id);

            return AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 375),
              child: SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(
                  child: Padding(
                    key: ValueKey(book.id),
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
                              emoji: book.displayCover,
                            ),
                          ),
                        );
                      },
                      child: BookCard(
                        book: book,
                        progress: progress,
                        enableHero: false,
                        onTap: () {
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
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String title, String subtitle,
      {IconData? icon, Widget? illustration}) {
    // Wrapped in a scroll view: this content's fixed height (icon + two
    // text blocks + a button + padding) can exceed the space actually
    // available for a tab's body — e.g. with the inline search field
    // expanded on a shorter screen, or with the on-screen keyboard up —
    // which otherwise overflows the Column rather than just scrolling.
    // LayoutBuilder + a min-height ConstrainedBox keeps it vertically
    // centered (via the inner Center) in the common case where it fits,
    // while still allowing it to scroll instead of overflow when it doesn't.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
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
                    const SizedBox(height: 40),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: PrimaryButton(
                        text: 'Explore Books',
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            SlideUpRoute(
                              page: const ChildHomeScreen(),
                            ),
                          );
                        },
                        icon: Icons.explore,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Missing methods implementation
  // Inline search replaces the previous dialog-based search. The
  // old dialog method was removed to keep the UX consistent for kids.

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AppDialog(
          icon: Icons.tune,
          iconColor: AppTheme.primaryPurple,
          title: 'Filter Books',
          // "Clear All" doesn't close the dialog (it just resets
          // selections in place), so it isn't a real Cancel — the old
          // AlertDialog had a separate explicit Cancel action too. The
          // footer only fits two buttons, so restore that third,
          // non-destructive "back out without applying" action as a
          // close button instead of dropping it.
          showCloseButton: true,
          secondaryLabel: 'Clear All',
          onSecondary: () => setDialogState(() {
            _selectedAgeRating = null;
            _selectedTraits.clear();
          }),
          primaryLabel: 'Apply',
          onPrimary: () {
            setState(() {});
            Navigator.pop(context);
          },
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Age Rating',
                  style: AppTheme.heading.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                // '4+'/'5+' added to match the app's early-childhood
                // target — see docs/early-childhood-audit.md finding #4.
                ...['4+', '5+', '6+', '7+', '8+', '9+', '10+', '12+']
                    .map((age) => ListTile(
                      title: Text(age, style: AppTheme.body),
                      selected: _selectedAgeRating == age,
                      onTap: () {
                        setDialogState(() {
                          _selectedAgeRating = age;
                        });
                      },
                      trailing: _selectedAgeRating == age
                          ? const Icon(Icons.radio_button_checked,
                              color: AppTheme.primaryPurple)
                          : const Icon(Icons.radio_button_off,
                              color: Colors.grey),
                    )),
                const SizedBox(height: 16),
                Text(
                  'Traits',
                  style: AppTheme.heading.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...[
                  'curious', 'creative', 'imaginative', // Openness
                  'responsible', 'organized', 'persistent', // Conscientiousness
                  'social', 'enthusiastic', 'outgoing', // Extraversion
                  'kind', 'cooperative', 'caring', // Agreeableness
                  'resilient', 'calm', 'positive' // Emotional Stability
                ].map((trait) => CheckboxListTile(
                      title: Text(trait, style: AppTheme.body),
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
        final bookTraits = normalizeTraitsForMatching(book.traits);
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
      final progressA = Provider.of<BookProvider>(context, listen: false)
          .getProgressForBook(a.id);
      final progressB = Provider.of<BookProvider>(context, listen: false)
          .getProgressForBook(b.id);

      final isCompletedA = progressA?.isCompleted == true;
      final isCompletedB = progressB?.isCompleted == true;

      final isStartedA = progressA != null && progressA.progressPercentage > 0;
      final isStartedB = progressB != null && progressB.progressPercentage > 0;

      int bucket(bool isStarted, bool isCompleted) {
        // 0 = not started, 1 = started/in-progress, 2 = completed
        if (isCompleted) return 2;
        if (isStarted) return 1;
        return 0;
      }

      final bucketA = bucket(isStartedA, isCompletedA);
      final bucketB = bucket(isStartedB, isCompletedB);

      // Priority 1: Not-started first, then started, then completed
      if (bucketA != bucketB) return bucketA.compareTo(bucketB);

      // Priority 2: Within same bucket, maintain original order (AI recommendations first)
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
        if (bookProvider.recommendedBooks.isEmpty &&
            userProvider.personalityTraits.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            bookProvider.loadRecommendedBooks(
              userProvider.personalityTraits,
              userId: authProvider.userId,
            );
          });
        }

        // Get combined recommended books and apply filters (limit to 20 max for performance)
        final combinedBooks =
            bookProvider.combinedRecommendedBooks.take(20).toList();
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
            'No matches found',
            'Try different keywords or fewer filters',
            icon: Icons.search_off,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: filteredBooks.length,
          itemBuilder: (context, index) {
            final book = filteredBooks[index];
            final progress = bookProvider.getProgressForBook(book.id);

            return AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 375),
              child: SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(
                  child: Padding(
                    key: ValueKey(book.id),
                    padding: const EdgeInsets.only(bottom: 15),
                    child: PressableCard(
                      onTap: () {
                        FeedbackService.instance.playTap();
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
                      child: BookCard(
                        book: book,
                        progress: progress,
                        enableHero: false,
                        onTap: () {
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
                    ),
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

            return AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 375),
              child: SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(
                  child: Padding(
                    key: ValueKey(book.id),
                    padding: const EdgeInsets.only(bottom: 15),
                    child: PressableCard(
                      onTap: () {
                        FeedbackService.instance.playTap();
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
                      child: BookCard(
                        book: book,
                        progress: progress,
                        enableHero: false,
                        // This tab's own membership already means "ongoing" —
                        // always show Resume/inProgress rather than deriving
                        // it from progress, which may not have caught up yet.
                        buttonTextOverride: 'Resume',
                        buttonTypeOverride: ProgressButtonType.inProgress,
                        onTap: () {
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
                    ),
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
            final progress = bookProvider.getProgressForBook(book.id);

            return AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 375),
              child: SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(
                  child: Padding(
                    key: ValueKey(book.id),
                    padding: const EdgeInsets.only(bottom: 15),
                    child: PressableCard(
                      onTap: () {
                        FeedbackService.instance.playTap();
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
                      child: BookCard(
                        book: book,
                        progress: progress,
                        enableHero: false,
                        // A completed entry should always read 100%/Re-read
                        // even if its progress doc hasn't been backfilled.
                        alwaysShowProgress: true,
                        buttonTextOverride: 'Re-read',
                        buttonTypeOverride: ProgressButtonType.completed,
                        onTap: () {
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
                    ),
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
