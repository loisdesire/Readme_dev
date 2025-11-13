// File: lib/providers/book_provider.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/api_service.dart';
import '../services/analytics_service.dart';
import '../services/achievement_service.dart';
import '../services/content_filter_service.dart';
import '../services/logger.dart';
import 'base_provider.dart';
// user_provider should not be imported here to avoid accidental instantiation

class Book {
  final String id;
  final String title;
  final String author;
  final String description;
  final String? coverImageUrl; // Real cover image URL from Open Library
  final String? coverEmoji;    // Emoji fallback for books without covers
  final List<String> traits; // For personality matching
  final List<String> tags; // For categorization (adventure, fantasy, etc.)
  final String ageRating;
  final int estimatedReadingTime; // in minutes
  final String? pdfUrl; // PDF file URL (local or remote)
  final DateTime createdAt;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    this.coverImageUrl,        // Real cover from Open Library
    this.coverEmoji,           // Emoji fallback
    required this.traits,
    this.tags = const [], // Tags for categorization
    required this.ageRating,
    required this.estimatedReadingTime,
    this.pdfUrl,               // PDF file URL
    required this.createdAt,
  });

  // Enhanced helper methods for cover display
  String get displayCover => coverEmoji ?? '📚';
  bool get hasRealCover => coverImageUrl != null &&
                          coverImageUrl!.isNotEmpty &&
                          coverImageUrl!.startsWith('http');

  // Get the best available cover (prioritize real images)
  String? get bestCoverUrl => hasRealCover ? coverImageUrl : null;
  String get fallbackEmoji => coverEmoji ?? '📚';

  // PDF support
  bool get hasPdf => pdfUrl != null && pdfUrl!.isNotEmpty;

  factory Book.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Enhanced PDF URL validation
    String? pdfUrl = data['pdfUrl'];
    if (pdfUrl != null && !pdfUrl.startsWith('http')) {
      appLog('Invalid PDF URL format for book "${data['title'] ?? 'Unknown'}": $pdfUrl', level: 'WARN');
      pdfUrl = null;
    }

    // Enhanced cover URL validation
    String? validCoverUrl = data['coverImageUrl'];
    if (validCoverUrl != null && !validCoverUrl.startsWith('http')) {
      appLog('Invalid cover URL format for book "${data['title'] ?? 'Unknown'}": $validCoverUrl', level: 'WARN');
      validCoverUrl = null;
    }
    
    return Book(
      id: doc.id,
      title: data['title'] ?? '',
      author: data['author'] ?? '',
      description: data['description'] ?? '',
      coverImageUrl: validCoverUrl, // Validated cover URL
      coverEmoji: data['coverEmoji'], // Fallback emoji
      traits: List<String>.from(data['traits'] ?? []),
      tags: List<String>.from(data['tags'] ?? []),
      ageRating: data['ageRating'] ?? '6+',
      estimatedReadingTime: data['estimatedReadingTime'] ?? 15,
      pdfUrl: pdfUrl,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'author': author,
      'description': description,
      'coverImageUrl': coverImageUrl, // Real cover image URL
      'coverEmoji': coverEmoji, // Emoji fallback
      'traits': traits,
      'tags': tags,
      'ageRating': ageRating,
      'estimatedReadingTime': estimatedReadingTime,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class ReadingProgress {
  final String id;
  final String userId;
  final String bookId;
  final int currentPage;
  final int totalPages;
  final double progressPercentage;
  final int readingTimeMinutes;
  final DateTime lastReadAt;
  final bool isCompleted;

  ReadingProgress({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.currentPage,
    required this.totalPages,
    required this.progressPercentage,
    required this.readingTimeMinutes,
    required this.lastReadAt,
    required this.isCompleted,
  });

  factory ReadingProgress.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReadingProgress(
      id: doc.id,
      userId: data['userId'] ?? '',
      bookId: data['bookId'] ?? '',
      currentPage: data['currentPage'] ?? 1,
      totalPages: data['totalPages'] ?? 1,
      progressPercentage: (data['progressPercentage'] ?? 0.0).toDouble(),
      readingTimeMinutes: data['readingTimeMinutes'] ?? 0,
      lastReadAt: (data['lastReadAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isCompleted: data['isCompleted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'bookId': bookId,
      'currentPage': currentPage,
      'totalPages': totalPages,
      'progressPercentage': progressPercentage,
      'readingTimeMinutes': readingTimeMinutes,
      'lastReadAt': Timestamp.fromDate(lastReadAt),
      'isCompleted': isCompleted,
    };
  }
}

class BookProvider extends BaseProvider {
  /// Expose error for compatibility with screens expecting 'error' property
  String? get error => errorMessage;
  // Throttle map to avoid writing progress for the same user/book too often
  final Map<String, DateTime> _lastProgressUpdate = {};
  final Duration _minProgressUpdateInterval = const Duration(seconds: 2);
  final ApiService _apiService = ApiService();
  final AnalyticsService _analyticsService = AnalyticsService();
  final AchievementService _achievementService = AchievementService();
  final ContentFilterService _contentFilterService = ContentFilterService();

  List<Book> _allBooks = [];
  List<Book> _recommendedBooks = [];
  List<ReadingProgress> _userProgress = [];
  List<Book> _filteredBooks = [];
  Set<String> _favoriteBookIds = {}; // Track user's favorite book IDs
  // Removed _sessionStart - no longer needed

  // Cache management for stale-while-revalidate
  DateTime? _recommendedBooksLastFetch;
  DateTime? _allBooksLastFetch;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  // Getters
  List<Book> get allBooks => _allBooks;
  List<Book> get recommendedBooks => _recommendedBooks;

  // Check if cache is still valid (fresh)
  bool get _hasValidRecommendedBooksCache {
    if (_recommendedBooks.isEmpty || _recommendedBooksLastFetch == null) {
      return false;
    }
    final age = DateTime.now().difference(_recommendedBooksLastFetch!);
    return age < _cacheExpiry;
  }

  bool get _hasValidAllBooksCache {
    if (_allBooks.isEmpty || _allBooksLastFetch == null) {
      return false;
    }
    final age = DateTime.now().difference(_allBooksLastFetch!);
    return age < _cacheExpiry;
  }

  // Favorites getter - returns books from filteredBooks that are favorited
  List<Book> get favoriteBooks {
    final allBooksList = _filteredBooks.isNotEmpty ? _filteredBooks : _allBooks;
    return allBooksList.where((book) => _favoriteBookIds.contains(book.id)).toList();
  }

  // Check if a book is favorited
  bool isFavorite(String bookId) {
    return _favoriteBookIds.contains(bookId);
  }

  // Store the last used userTraits for correct rule-based scoring
  List<String> _lastUserTraits = [];

  /// Returns a combined list: AI-recommended books first (however many exist), then rule-based (trait) recommended books not already in the AI list.
  List<Book> get combinedRecommendedBooks {
    final allBooksList = _filteredBooks.isNotEmpty ? _filteredBooks : _allBooks;

    // Get AI recommendation IDs (could be any number: 1-5 or more)
    final aiIds = _recommendedBooks.map((b) => b.id).toSet();

    // Ensure traits is never null/undefined
    final traits = _lastUserTraits.isEmpty ? <String>[] : _lastUserTraits;

    // Get rule-based books (excluding AI recommendations)
    final booksWithScores = allBooksList
        .where((book) => !aiIds.contains(book.id))
        .map((book) {
          final score = _calculateBookRelevanceScore(book, traits);
          return {'book': book, 'score': score};
        })
        .where((item) => (item['score'] as int) >= 3) // Only books with 3+ matching traits
        .toList();

    booksWithScores.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    final ruleBasedBooks = booksWithScores.map((item) => item['book'] as Book).toList();

    // Combine: AI recommendations FIRST (however many exist), then rule-based
    final combined = [..._recommendedBooks, ...ruleBasedBooks];

    appLog('[COMBINED_RECS] AI books: ${_recommendedBooks.length}, Rule-based books: ${ruleBasedBooks.length}, Total: ${combined.length}', level: 'INFO');
    appLog('[COMBINED_RECS] First 5 combined books: ${combined.take(5).map((b) => b.title).join(", ")}', level: 'INFO');

    return combined;
  }
  List<ReadingProgress> get userProgress => _userProgress;
  List<Book> get filteredBooks => _filteredBooks;
  // isLoading and errorMessage inherited from BaseProvider

  // Initialize sample books (call this once to populate the database)
  Future<void> initializeSampleBooks() async {
    try {
      // Check if books already exist to avoid duplicates
      final existingBooks = await firestore.collection('books').limit(1).get();
      if (existingBooks.docs.isNotEmpty) {
  appLog('Sample books already exist, skipping initialization', level: 'DEBUG');
        return;
      }

      final sampleBooks = [
        {
          'title': 'The Enchanted Monkey',
          'author': 'Maya Adventure',
          'description': 'Follow Koko the monkey on an amazing adventure through the magical jungle! Discover hidden treasures, make new friends, and learn about courage and friendship.',
          'coverEmoji': '🐒✨',
          'traits': ['adventurous', 'curious', 'brave'],
          'ageRating': '6+',
          'estimatedReadingTime': 15,
          'content': [
            "Once upon a time, in a magical jungle filled with colorful flowers and singing birds, there lived a curious little monkey named Koko.\n\nKoko had golden fur that sparkled in the sunlight and big, bright eyes that were always looking for adventure.\n\nOne sunny morning, Koko was swinging from branch to branch when he noticed something shiny hidden behind a waterfall.",
            "\"What could that be?\" Koko wondered aloud, his tail curling with excitement.\n\nHe swung closer to the waterfall, feeling the cool mist on his face. Behind the rushing water, he could see a cave with something glowing inside.\n\nKoko had never seen anything like it before. His heart raced with curiosity and a little bit of fear.",
            "Taking a deep breath, Koko carefully climbed behind the waterfall. The cave was warm and filled with a soft, golden light.\n\nIn the center of the cave sat an old, wise turtle with a shell that shimmered like a rainbow.\n\n\"Hello, young monkey,\" said the turtle with a kind smile. \"I've been waiting for someone brave enough to find me.\"",
          ],
        },
        {
          'title': 'Fairytale Adventures',
          'author': 'Emma Wonder',
          'description': 'Enter a world of magic and wonder! Meet brave princesses, helpful fairies, and discover that true magic comes from kindness and courage.',
          'coverEmoji': '🧚‍♀️🌟',
          'traits': ['imaginative', 'creative', 'kind'],
          'ageRating': '6+',
          'estimatedReadingTime': 12,
          'content': [
            "In a kingdom far, far away, where rainbow bridges crossed crystal rivers, lived a young princess named Luna who had a very special gift.",
            "Princess Luna could talk to animals! Every morning, she would wake up to find squirrels, rabbits, and birds gathered around her window, all chattering excitedly about their adventures.",
            "One day, a little fox came running to her with tears in his eyes. \"Princess Luna!\" he cried. \"The Magic Forest is losing all its colors! Without them, all the animals will forget how to be happy!\"",
          ],
        },
        {
          'title': 'Space Explorers',
          'author': 'Captain Cosmos',
          'description': 'Blast off on an incredible journey through space! Meet friendly aliens, explore distant planets, and learn about the wonders of the universe.',
          'coverEmoji': '🚀🤖',
          'traits': ['curious', 'analytical', 'adventurous'],
          'ageRating': '7+',
          'estimatedReadingTime': 18,
          'content': [
            "Commander Zara adjusted her space helmet and looked out at the twinkling stars. Today was the day she would lead her first mission to Planet Zephyr!",
            "\"Are you ready, Robo?\" she asked her faithful robot companion, who beeped excitedly in response.\n\nTogether, they climbed aboard their shiny silver spaceship and prepared for the adventure of a lifetime.",
            "As their rocket zoomed through the colorful nebula clouds, Zara spotted something amazing - a planet covered in crystal mountains that sparkled like diamonds in the starlight!",
          ],
        },
        {
          'title': 'The Brave Little Dragon',
          'author': 'Fire Tales',
          'description': 'Meet Spark, a small dragon who discovers that being different makes you special! A heartwarming story about friendship and self-acceptance.',
          'coverEmoji': '🐲🔥',
          'traits': ['brave', 'kind', 'creative'],
          'ageRating': '6+',
          'estimatedReadingTime': 14,
          'content': [
            "In a valley surrounded by tall mountains, there lived a little dragon named Spark who was different from all the other dragons.",
            "While other dragons breathed fire, Spark could only make tiny sparkles that danced in the air like fireflies.",
            "One day, when the village was in danger, Spark discovered that his special sparkles were exactly what was needed to save everyone!",
          ],
        },
        {
          'title': 'Ocean Friends',
          'author': 'Marina Deep',
          'description': 'Dive into an underwater adventure with Finn the fish and his ocean friends! Learn about friendship, teamwork, and protecting our seas.',
          'coverEmoji': '🐠🌊',
          'traits': ['curious', 'kind', 'adventurous'],
          'ageRating': '6+',
          'estimatedReadingTime': 16,
          'content': [
            "Deep beneath the sparkling waves, in a coral reef full of colors, lived a cheerful little fish named Finn.",
            "Finn loved exploring the ocean and making new friends, from tiny seahorses to gentle sea turtles.",
            "When the reef faced a big problem, Finn and his friends had to work together to find a solution and save their beautiful home.",
          ],
        },
      ];

  appLog('Adding ${sampleBooks.length} sample books to database...', level: 'DEBUG');
      
      for (final bookData in sampleBooks) {
        await firestore.collection('books').add({
          ...bookData,
          'createdAt': FieldValue.serverTimestamp(),
        });
  appLog('Added book: ${bookData['title']}', level: 'DEBUG');
      }
      
  appLog('Sample books initialized successfully!', level: 'DEBUG');
    } catch (e) {
  appLog('Error initializing sample books: $e', level: 'ERROR');
      rethrow; // Re-throw to handle in calling code
    }
  }

  // Load all books with content filtering
  Future<void> loadAllBooks({String? userId, bool forceRefresh = false}) async {
    try {
      // Stale-while-revalidate: use cache if fresh, refresh in background
      final hasFreshCache = !forceRefresh && _hasValidAllBooksCache;

      if (!hasFreshCache) {
        setLoading(true);
        clearError();
        // Delay notifying listeners to ensure we finish the build phase
        Future.delayed(Duration.zero, () => notifyListeners());
      } else {
        appLog('[CACHE] Using cached all books (age: ${DateTime.now().difference(_allBooksLastFetch!).inSeconds}s)', level: 'INFO');
      }

      // Load all books from Firestore
      final querySnapshot = await firestore
          .collection('books')
          .get();

      _allBooks = querySnapshot.docs
          .map((doc) => Book.fromFirestore(doc))
          .toList();

  appLog('Loaded ${_allBooks.length} books from database', level: 'DEBUG');

      // Apply content filtering if userId is provided
      if (userId != null) {
        try {
          final booksData = _allBooks.map((book) => {
            'id': book.id,
            'title': book.title,
            'author': book.author,
            'description': book.description,
            'ageRating': book.ageRating,
            'traits': book.traits,
          }).toList();

          final filteredBooksData = await _contentFilterService.filterBooks(booksData, userId);
          final filteredIds = filteredBooksData.map((book) => book['id']).toSet();
          
          _filteredBooks = _allBooks.where((book) => filteredIds.contains(book.id)).toList();
          // Debug image print removed
        } catch (filterError) {
          appLog('Error applying content filter: $filterError', level: 'ERROR');
          // Fallback to all books if filtering fails
          _filteredBooks = _allBooks;
        }
      } else {
        _filteredBooks = _allBooks;
      }

      // Update cache timestamp
      _allBooksLastFetch = DateTime.now();

      setLoading(false);
      Future.delayed(Duration.zero, () => notifyListeners());
    } catch (e) {
  appLog('Error loading books: $e', level: 'ERROR');
      setError('Oops! We couldn\'t load the books. Please try again.');
      setLoading(false);
      Future.delayed(Duration.zero, () => notifyListeners());
    }
  }

  // Get recommended books based on personality traits with enhanced filtering
  Future<void> loadRecommendedBooks(List<String> userTraits, {String? userId, bool forceRefresh = false}) async {
    try {
      // Stale-while-revalidate strategy:
      // 1. If cache is valid and fresh, use it immediately (no spinner)
      // 2. Refresh data in background
      // 3. Only show spinner if cache is empty or force refresh
      final hasFreshCache = !forceRefresh && _hasValidRecommendedBooksCache;

      if (!hasFreshCache) {
        // No cache or expired - show loading spinner
        setLoading(true);
        Future.delayed(Duration.zero, () => notifyListeners());
      } else {
        // Cache is fresh - use it immediately, refresh in background
        appLog('[CACHE] Using cached recommended books (age: ${DateTime.now().difference(_recommendedBooksLastFetch!).inSeconds}s)', level: 'INFO');
      }

      // Store the last used userTraits for correct rule-based scoring
      _lastUserTraits = userTraits;

      if (_allBooks.isEmpty) {
        await loadAllBooks(userId: userId);
      }

      // Ensure filtered books are ready if userId is provided
      if (userId != null && _filteredBooks.isEmpty && _allBooks.isNotEmpty) {
        appLog('[RECOMMENDATIONS] Filtered books not ready, waiting...', level: 'INFO');
        // Wait a bit for filtering to complete
        await Future.delayed(const Duration(milliseconds: 1000));
        if (_filteredBooks.isEmpty) {
          appLog('[RECOMMENDATIONS] Filtering still not complete, using all books as fallback', level: 'WARN');
          _filteredBooks = _allBooks;
        }
      }

      // Use API service for enhanced recommendations
      try {
        final recommendedBooksData = await _apiService.getRecommendedBooks(userTraits, userId: userId);
        final recommendedIds = recommendedBooksData.map((book) => book['id']).toList();
        final allBooksList = userId != null ? _filteredBooks : _allBooks;

        appLog('[RECOMMENDATIONS] Using book list: ${userId != null ? "filtered" : "all"} (${allBooksList.length} books)', level: 'INFO');
        appLog('[RECOMMENDATIONS] User traits: ${userTraits.join(", ")}', level: 'INFO');
        appLog('[RECOMMENDATIONS] AI-recommended book IDs (in order): ${recommendedIds.join(", ")}', level: 'INFO');
        appLog('[RECOMMENDATIONS] Number of AI recommendations: ${recommendedIds.length}', level: 'INFO');
        appLog('[RECOMMENDATIONS] BookProvider instance: $hashCode', level: 'INFO');

        // Get the actual Book objects for the AI recommendations (in order)
        final aiBooks = recommendedIds
            .map((id) {
              try {
                final book = allBooksList.firstWhere((book) => book.id == id);
                return book;
              } catch (_) {
                return null;
              }
            })
            .whereType<Book>()
            .toList();

        // Use only AI recommendations if available
        if (aiBooks.isNotEmpty) {
          _recommendedBooks = aiBooks;
          appLog('[RECOMMENDATIONS] ✅ Using AI recommendations: ${aiBooks.map((b) => b.title).join(", ")}', level: 'INFO');
        } else {
          appLog('[RECOMMENDATIONS] ⚠️ No AI recommendations found, falling back to rule-based', level: 'WARN');
          // If AI returned no valid books, fall back to trait-based scoring
          final booksWithScores = allBooksList.map((book) {
            final score = _calculateBookRelevanceScore(book, userTraits);
            return {'book': book, 'score': score};
          }).toList();

          booksWithScores.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

          _recommendedBooks = booksWithScores
              .where((item) => (item['score'] as int) > 0)
              .take(10)
              .map((item) => item['book'] as Book)
              .toList();
        }
      } catch (e) {
        appLog('API recommendation failed, using local filtering: $e', level: 'WARN');
        // Fallback to enhanced local filtering with trait scoring
        final booksWithScores = (userId != null ? _filteredBooks : _allBooks).map((book) {
          final score = _calculateBookRelevanceScore(book, userTraits);
          return {'book': book, 'score': score};
        }).toList();

        // Sort by relevance score (highest first)
        booksWithScores.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

        // Take top 10 most relevant books
        _recommendedBooks = booksWithScores
            .where((item) => (item['score'] as int) > 0) // Only books with some relevance
            .take(10)
            .map((item) => item['book'] as Book)
            .toList();
      }

      // If no trait matches, show some default books sorted by estimated reading time
      if (_recommendedBooks.isEmpty) {
        final sortedBooks = (userId != null ? _filteredBooks : _allBooks).toList();
        sortedBooks.sort((a, b) => a.estimatedReadingTime.compareTo(b.estimatedReadingTime));
        _recommendedBooks = sortedBooks.take(5).toList();
      }

      // Update cache timestamp
      _recommendedBooksLastFetch = DateTime.now();

      setLoading(false);
      Future.delayed(Duration.zero, () => notifyListeners());
    } catch (e) {
      appLog('Error loading recommendations: $e', level: 'ERROR');
      setError('Oops! We couldn\'t find books for you. Please try again.');
      setLoading(false);
      Future.delayed(Duration.zero, () => notifyListeners());
    }
  }

  // Enhanced book relevance scoring for better recommendations
  int _calculateBookRelevanceScore(Book book, List<String>? userTraits) {
    int score = 0;
    
    // Safety check: if userTraits is null or empty, return 0
    if (userTraits == null || userTraits.isEmpty) {
      return 0;
    }
    
    // High priority: Direct trait matches
    if (book.traits.isNotEmpty) {
      for (String trait in book.traits) {
        if (userTraits.contains(trait)) {
          score += 15; // Higher score for direct trait matches
        }
      }
    }

    // Medium priority: Tag-to-trait mapping
    if (book.tags.isNotEmpty) {
      for (String tag in book.tags) {
        List<String> relatedTraits = _getTraitsForTag(tag);
        for (String relatedTrait in relatedTraits) {
          if (userTraits.contains(relatedTrait)) {
            score += 8; // Medium score for tag-trait matches
          }
        }
      }
    }

    // Low priority: Age appropriateness bonus
    if (book.ageRating.isNotEmpty) {
      score += 2; // Small bonus for having age rating
    }

    // Bonus for shorter reading time (better for engagement)
    if (book.estimatedReadingTime <= 20) {
      score += 3;
    }

    return score;
  }

  // Enhanced tag-to-trait mapping for better recommendations
  List<String> _getTraitsForTag(String tag) {
    switch (tag.toLowerCase()) {
      // Openness tags
      case 'adventure':
        return ['adventurous', 'brave', 'enthusiastic'];
      case 'fantasy':
        return ['imaginative', 'creative'];
      case 'creativity':
        return ['creative', 'imaginative', 'artistic'];
      case 'art':
        return ['artistic', 'creative', 'imaginative'];
      case 'imagination':
        return ['imaginative', 'creative'];
      case 'exploration':
        return ['curious', 'adventurous', 'enthusiastic'];
      case 'innovation':
        return ['inventive', 'creative', 'curious'];
      
      // Conscientiousness tags
      case 'learning':
        return ['curious', 'persistent', 'focused'];
      case 'responsibility':
        return ['responsible', 'organized', 'careful'];
      case 'organization':
        return ['organized', 'responsible', 'focused'];
      case 'perseverance':
        return ['persistent', 'hardworking', 'focused'];
      case 'problem-solving':
        return ['persistent', 'focused', 'inventive'];
      
      // Extraversion tags
      case 'friendship':
        return ['friendly', 'social', 'kind'];
      case 'teamwork':
        return ['cooperative', 'social', 'helpful'];
      case 'cooperation':
        return ['cooperative', 'helpful', 'friendly'];
      case 'leadership':
        return ['confident', 'outgoing', 'responsible'];
      case 'playfulness':
        return ['playful', 'cheerful', 'enthusiastic'];
      case 'humor':
        return ['cheerful', 'playful', 'social'];
      
      // Agreeableness tags
      case 'kindness':
        return ['kind', 'caring', 'helpful'];
      case 'animals':
        return ['caring', 'gentle', 'kind'];
      case 'family':
        return ['caring', 'kind', 'cooperative'];
      case 'helpfulness':
        return ['helpful', 'kind', 'caring'];
      case 'sharing':
        return ['sharing', 'generous', 'cooperative'];
      case 'generosity':
        return ['generous', 'kind', 'helpful'];
      
      // Emotional Stability tags
      case 'emotions':
        return ['calm', 'positive', 'caring'];
      case 'resilience':
        return ['brave', 'positive', 'persistent'];
      case 'positivity':
        return ['positive', 'cheerful', 'optimistic'];
      case 'confidence':
        return ['confident', 'brave', 'outgoing'];
      case 'bravery':
        return ['brave', 'confident', 'adventurous'];
      case 'patience':
        return ['calm', 'patient', 'focused'];
      case 'self-acceptance':
        return ['confident', 'positive', 'calm'];
      
      default:
        return [];
    }
  }

  // Get user's reading progress
  Future<void> loadUserProgress(String userId) async {
    try {
      final querySnapshot = await firestore
          .collection('reading_progress')
          .where('userId', isEqualTo: userId)
          .orderBy('lastReadAt', descending: true)
          .get();

      _userProgress = querySnapshot.docs
          .map((doc) => ReadingProgress.fromFirestore(doc))
          .toList();

      Future.delayed(Duration.zero, () => notifyListeners());
    } catch (e) {
  appLog('Error loading user progress: $e', level: 'ERROR');
      // Don't notify listeners on error to avoid build issues
    }
  }

  // Update reading progress with enhanced tracking
  Future<void> updateReadingProgress({
    required String userId,
    required String bookId,
    required int currentPage,
    required int totalPages,
    required int additionalReadingTime,
    bool? isCompleted,
  }) async {
    try {
      // Fix: Only mark as completed if explicitly set or if at the very last page
      // Changed from 95% to requiring the actual last page (or 98% minimum)
      final progressPercentage = totalPages > 0 ? currentPage / totalPages : 0.0;
      final bookCompleted = isCompleted ?? (currentPage >= totalPages || progressPercentage >= 0.98);

      // Normalize progress to 100% when book is completed
      final finalCurrentPage = bookCompleted ? totalPages : currentPage;
      final finalProgressPercentage = bookCompleted ? 1.0 : progressPercentage;
      final sessionEnd = DateTime.now();

      // Throttle frequent progress writes for the same user/book to reduce
      // Firestore traffic. Do not throttle if the book is being marked completed
      // to ensure final state is written.
      try {
        final key = '\$userId|\$bookId';
        final last = _lastProgressUpdate[key];
        if (!bookCompleted && last != null) {
          final since = DateTime.now().difference(last);
          if (since < _minProgressUpdateInterval) {
            return; // Throttled
          }
        }
      } catch (e) {
        // If throttle check fails for any reason, continue with write
        appLog('Throttle check error: $e', level: 'WARN');
      }

      // Check if progress already exists
      final existingProgressQuery = await firestore
          .collection('reading_progress')
          .where('userId', isEqualTo: userId)
          .where('bookId', isEqualTo: bookId)
          .get();

      if (existingProgressQuery.docs.isNotEmpty) {
        // Update existing progress
        final docId = existingProgressQuery.docs.first.id;
        final existingData = existingProgressQuery.docs.first.data();
        
        await firestore.collection('reading_progress').doc(docId).update({
          'currentPage': finalCurrentPage,
          'progressPercentage': finalProgressPercentage,
          'readingTimeMinutes': (existingData['readingTimeMinutes'] ?? 0) + additionalReadingTime,
          'lastReadAt': FieldValue.serverTimestamp(),
          'isCompleted': bookCompleted,
        });
        // update last-write timestamp for throttle
        try {
          _lastProgressUpdate['$userId|$bookId'] = DateTime.now();
        } catch (_) {}
      } else {
        // Create new progress record
        await firestore.collection('reading_progress').add({
          'userId': userId,
          'bookId': bookId,
          'currentPage': finalCurrentPage,
          'totalPages': totalPages,
          'progressPercentage': finalProgressPercentage,
          'readingTimeMinutes': additionalReadingTime,
          'lastReadAt': FieldValue.serverTimestamp(),
          'isCompleted': bookCompleted,
        });
        // update last-write timestamp for throttle
        try {
          _lastProgressUpdate['$userId|$bookId'] = DateTime.now();
        } catch (_) {}
      }

      // Track analytics - ALWAYS track, not dependent on _sessionStart
      final book = getBookById(bookId);
      final sessionDuration = additionalReadingTime * 60; // Convert minutes to seconds
      if (sessionDuration > 0) {
        final sessionStart = sessionEnd.subtract(Duration(seconds: sessionDuration));
        await _analyticsService.trackReadingSession(
          bookId: bookId,
          bookTitle: book?.title ?? 'Unknown',
          pageNumber: currentPage,
          totalPages: totalPages,
          sessionDurationSeconds: sessionDuration,
          sessionStart: sessionStart,
          sessionEnd: sessionEnd,
        );
      }

      // Track content filter reading time
      await _contentFilterService.trackReadingTime(userId, additionalReadingTime);

      // CRITICAL FIX: Always reload progress to keep UI in sync
      await loadUserProgress(userId);

      // Notify listeners so UI updates immediately
      notifyListeners();

      // Check achievements after every reading session (not just book completions)
      // This ensures streak achievements are detected even if no book was completed
      await _checkAchievements(userId);
      // Note: We intentionally do NOT instantiate UserProvider here. The UI
      // layer should call UserProvider.loadUserData(...) after update to
      // refresh streaks and aggregated stats. Instantiating a provider
      // outside of the widget tree causes missing dependencies and is unsafe.
    } catch (e) {
  appLog('Error updating reading progress: $e', level: 'ERROR');
    }
  }

  // Get book by ID
  Book? getBookById(String bookId) {
    try {
      return _allBooks.firstWhere((book) => book.id == bookId);
    } catch (e) {
      return null;
    }
  }

  // Get progress for a specific book
  ReadingProgress? getProgressForBook(String bookId) {
    try {
      return _userProgress.firstWhere((progress) => progress.bookId == bookId);
    } catch (e) {
      return null;
    }
  }

  // Start reading session (no longer needed - analytics tracked directly)
  void startReadingSession() {
    // No-op - analytics now tracked directly in updateReadingProgress
  }

  // End reading session (no longer needed - analytics tracked directly)
  void endReadingSession() {
    // No-op - analytics now tracked directly in updateReadingProgress
  }

  // Check and unlock achievements
  // Achievement popups are now handled by AchievementListener via Firebase stream
  Future<void> _checkAchievements(String userId) async {
    try {
      appLog('[ACHIEVEMENT] Checking achievements for user: $userId', level: 'DEBUG');

      // Get user stats
      final completedBooks = _userProgress.where((p) => p.isCompleted).length;

      final totalReadingTime = _userProgress.fold<int>(
        0,
        (total, progress) => total + progress.readingTimeMinutes,
      );

      // Get analytics for streak calculation
      final analytics = await _analyticsService.getUserReadingAnalytics(userId);
      final currentStreak = analytics['currentStreak'] ?? 0;
      final totalSessions = analytics['totalSessions'] ?? 0;

      appLog('[ACHIEVEMENT] Stats - Books: $completedBooks, Time: $totalReadingTime min, Streak: $currentStreak, Sessions: $totalSessions', level: 'DEBUG');

      // Check and unlock achievements
      // When achievements unlock, they're written to Firebase with popupShown: false
      // AchievementListener streams Firebase and automatically shows popups
      final newlyUnlocked = await _achievementService.checkAndUnlockAchievements(
        booksCompleted: completedBooks,
        readingStreak: currentStreak,
        totalReadingMinutes: totalReadingTime,
        totalSessions: totalSessions,
      );

      if (newlyUnlocked.isNotEmpty) {
        appLog('[ACHIEVEMENT] ${newlyUnlocked.length} new achievements unlocked: ${newlyUnlocked.map((a) => a.name).join(', ')}', level: 'INFO');
        appLog('[ACHIEVEMENT] AchievementListener will automatically show popups via Firebase stream', level: 'DEBUG');
      }
    } catch (e) {
  appLog('Error checking achievements: $e', level: 'ERROR');
    }
  }

  // Get filtered books for user
  // Track book interaction
  Future<void> trackBookInteraction({
    required String bookId,
    required String action,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _analyticsService.trackBookInteraction(
        bookId: bookId,
        action: action,
        metadata: metadata,
      );
    } catch (e) {
  appLog('Error tracking book interaction: $e', level: 'ERROR');
    }
  }

  // Load user's favorite books
  Future<void> loadFavorites(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('user_favorites')
          .doc(userId)
          .collection('favorites')
          .get();

      _favoriteBookIds = snapshot.docs.map((doc) => doc.id).toSet();
      notifyListeners();
    } catch (e) {
      appLog('Error loading favorites: $e', level: 'ERROR');
    }
  }

  // Toggle favorite status for a book
  Future<void> toggleFavorite(String userId, String bookId) async {
    try {
      final favRef = FirebaseFirestore.instance
          .collection('user_favorites')
          .doc(userId)
          .collection('favorites')
          .doc(bookId);

      if (_favoriteBookIds.contains(bookId)) {
        // Remove from favorites
        await favRef.delete();
        _favoriteBookIds.remove(bookId);

        // Track analytics
        await trackBookInteraction(
          bookId: bookId,
          action: 'remove_favorite',
        );
      } else {
        // Add to favorites
        await favRef.set({
          'bookId': bookId,
          'addedAt': FieldValue.serverTimestamp(),
        });
        _favoriteBookIds.add(bookId);

        // Track analytics
        await trackBookInteraction(
          bookId: bookId,
          action: 'add_favorite',
        );
      }

      notifyListeners();
    } catch (e) {
      appLog('Error toggling favorite: $e', level: 'ERROR');
      rethrow;
    }
  }

  // Get reading time restrictions
  // Clear recommendations cache to force refresh
  void clearRecommendationsCache() {
    _recommendedBooks.clear();
    notifyListeners();
  }

  // Clear all user-specific cached data (call on logout to prevent data bleeding between users)
  void clearUserData() {
    _recommendedBooks.clear();
    _userProgress.clear();
    _favoriteBookIds.clear();
    _filteredBooks.clear();
    _lastUserTraits.clear();
    notifyListeners();
  }

  // clearError() inherited from BaseProvider

  // NEW: Get books by reading status
  List<Book> getBooksByStatus(String status) {
  // Debug image print removed
    
    switch (status.toLowerCase()) {
      case 'all':
        return _allBooks;
      case 'ongoing':
        // Books with progress but not completed
        final ongoingProgress = _userProgress
            .where((progress) {
              final isOngoing = progress.progressPercentage > 0 && !progress.isCompleted;
              // Debug image print removed
              return isOngoing;
            })
            .toList();
        
  // Debug image print removed
        final ongoingBookIds = ongoingProgress.map((progress) => progress.bookId).toSet();
        return _allBooks.where((book) => ongoingBookIds.contains(book.id)).toList();
      case 'completed':
        // Books that are completed
        final completedProgress = _userProgress
            .where((progress) {
              // Debug image print removed
              return progress.isCompleted;
            })
            .toList();
        
  // Debug image print removed
        final completedBookIds = completedProgress.map((progress) => progress.bookId).toSet();
        return _allBooks.where((book) => completedBookIds.contains(book.id)).toList();
      default:
        return _allBooks;
    }
  }

  // NEW: Get books sorted by trait relevance for better user experience
  List<Book> getBooksSortedByRelevance(List<String> userTraits) {
    if (userTraits.isEmpty) {
      return filteredBooks; // Return filtered books if no traits
    }

    final booksWithScores = filteredBooks.map((book) {
      final score = _calculateBookRelevanceScore(book, userTraits);
      return {'book': book, 'score': score};
    }).toList();

    // Sort by relevance score (highest first)
    booksWithScores.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    
    return booksWithScores.map((item) => item['book'] as Book).toList();
  }

  // NEW: Add book to favorites. If userId provided, persist to Firestore.
  // Keeps a non-breaking fallback when userId isn't provided (local-only notify).
  Future<void> addToFavorites(String bookId, {String? userId}) async {
    try {
      if (userId != null) {
        // Store favorites as an array on the user's document for simplicity
        await firestore.collection('users').doc(userId).set({
          'favorites': FieldValue.arrayUnion([bookId])
        }, SetOptions(merge: true));
        appLog('Added book $bookId to favorites for user $userId', level: 'DEBUG');
      } else {
        appLog('Adding book $bookId to local favorites (no userId provided)', level: 'DEBUG');
      }
      notifyListeners();
    } catch (e) {
      appLog('Error adding favorite $bookId: $e', level: 'ERROR');
    }
  }

  // NEW: Remove book from favorites. If userId provided, remove from Firestore.
  Future<void> removeFromFavorites(String bookId, {String? userId}) async {
    try {
      if (userId != null) {
        await firestore.collection('users').doc(userId).set({
          'favorites': FieldValue.arrayRemove([bookId])
        }, SetOptions(merge: true));
        appLog('Removed book $bookId from favorites for user $userId', level: 'DEBUG');
      } else {
        appLog('Removing book $bookId from local favorites (no userId provided)', level: 'DEBUG');
      }
      notifyListeners();
    } catch (e) {
      appLog('Error removing favorite $bookId: $e', level: 'ERROR');
    }
  }
}
