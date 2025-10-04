// File: lib/providers/book_provider.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/api_service.dart';
import '../services/analytics_service.dart';
import '../services/achievement_service.dart';
import '../services/content_filter_service.dart';
import '../models/chapter.dart';
import 'user_provider.dart';

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
  final String? source; // Source of the book (Open Library, Project Gutenberg, etc.)
  final bool hasRealContent; // Whether book contains real excerpts
  final String contentType; // NEW: 'story' | 'novel' | 'collection'
  final int wordCount; // NEW: Total word count
  final String readingLevel; // NEW: 'Easy' | 'Medium' | 'Advanced'
  final int estimatedReadingHours; // NEW: For full books (in addition to minutes)
  final Map<String, dynamic>? gutenbergMetadata; // NEW: Project Gutenberg metadata
  final List<String> content; // Legacy content for single pages
  final List<Chapter>? chapters; // NEW: Chapter structure for multi-chapter books

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
    this.source,               // Book source
    this.hasRealContent = false, // Content authenticity flag
    this.contentType = 'story', // NEW: Default to story
    this.wordCount = 0,        // NEW: Word count
    this.readingLevel = 'Easy', // NEW: Reading level
    this.estimatedReadingHours = 0, // NEW: Reading hours
    this.gutenbergMetadata,    // NEW: Gutenberg metadata
    this.content = const [],   // Legacy content
    this.chapters,             // NEW: Chapter structure
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
  
  // Chapter support
  bool get hasChapters => chapters != null && chapters!.isNotEmpty;
  int get totalChapters => chapters?.length ?? 0;
  int get totalPages {
    if (hasChapters) {
      return chapters!.fold(0, (sum, chapter) => sum + chapter.totalPages);
    }
    return content.length;
  }
  
  // Get reading content as a list of strings
  List<String> getReadingContent() {
    if (hasChapters) {
      final List<String> allPages = [];
      for (final chapter in chapters!) {
        allPages.addAll(chapter.pages);
      }
      return allPages;
    }
    return content;
  }

  // NEW: Get chapter by number
  Chapter? getChapter(int chapterNumber) {
    if (hasChapters && chapterNumber > 0 && chapterNumber <= chapters!.length) {
      return chapters![chapterNumber - 1];
    }
    return null;
  }

  // NEW: Get page info (which chapter and page within chapter)
  Map<String, int> getPageInfo(int globalPageIndex) {
    if (!hasChapters) {
      return {'chapter': 1, 'pageInChapter': globalPageIndex + 1, 'totalInChapter': content.length};
    }

    int currentIndex = 0;
    for (int i = 0; i < chapters!.length; i++) {
      final chapter = chapters![i];
      if (globalPageIndex < currentIndex + chapter.totalPages) {
        return {
          'chapter': i + 1,
          'pageInChapter': globalPageIndex - currentIndex + 1,
          'totalInChapter': chapter.totalPages,
        };
      }
      currentIndex += chapter.totalPages;
    }

    // If we get here, return the last chapter
    final lastChapter = chapters!.last;
    return {
      'chapter': chapters!.length,
      'pageInChapter': lastChapter.totalPages,
      'totalInChapter': lastChapter.totalPages,
    };
  }

  // NEW: Check if this is a full-length book
  bool get isFullBook => contentType == 'novel' || wordCount > 5000 || totalChapters > 3;

  // NEW: Get appropriate reading time display
  String get readingTimeDisplay {
    if (isFullBook && estimatedReadingHours > 0) {
      final hours = estimatedReadingHours;
      final minutes = estimatedReadingTime % 60;
      if (hours >= 1) {
        return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
      }
    }
    return '${estimatedReadingTime}m';
  }

  factory Book.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Enhanced PDF URL validation with logging
    String? pdfUrl = data['pdfUrl'];
    if (pdfUrl != null) {
      if (!pdfUrl.startsWith('http')) {
        print('⚠️ Invalid PDF URL format for book "${data['title'] ?? 'Unknown'}": $pdfUrl');
        pdfUrl = null;
      } else {
        print('✅ Valid PDF URL for book "${data['title'] ?? 'Unknown'}": ${pdfUrl.substring(0, pdfUrl.length > 80 ? 80 : pdfUrl.length)}...');
      }
    } else {
      print('ℹ️ No PDF URL for book "${data['title'] ?? 'Unknown'}"');
    }
    
    // Enhanced validation with logging
    String? validCoverUrl = data['coverImageUrl'];
    if (validCoverUrl != null) {
      if (!validCoverUrl.startsWith('http')) {
        print('⚠️ Invalid cover URL format for book "${data['title'] ?? 'Unknown'}": $validCoverUrl');
        validCoverUrl = null;
      } else {
        print('✅ Valid cover URL for book "${data['title'] ?? 'Unknown'}": ${validCoverUrl.substring(0, validCoverUrl.length > 80 ? 80 : validCoverUrl.length)}...');
      }
    } else {
      print('ℹ️ No cover URL for book "${data['title'] ?? 'Unknown'}", will use emoji fallback');
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
      source: data['source'], // Book source tracking
      hasRealContent: data['hasRealContent'] ?? false, // Content authenticity
      contentType: data['contentType'] ?? 'story', // NEW: Content type
      wordCount: data['wordCount'] ?? 0, // NEW: Word count
      readingLevel: data['readingLevel'] ?? 'Easy', // NEW: Reading level
      estimatedReadingHours: data['estimatedReadingHours'] ?? 0, // NEW: Reading hours
      gutenbergMetadata: data['gutenbergMetadata'] as Map<String, dynamic>?, // NEW: Gutenberg metadata
      content: List<String>.from(data['content'] ?? []), // Legacy content
      chapters: data['chapters'] != null 
          ? (data['chapters'] as List).map((c) => Chapter.fromMap(c as Map<String, dynamic>)).toList()
          : null, // NEW: Chapter structure
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
      'content': content, // Legacy content
      'chapters': chapters?.map((chapter) => chapter.toMap()).toList(), // NEW: Chapter structure
      'createdAt': Timestamp.fromDate(createdAt),
      'source': source, // Book source
      'hasRealContent': hasRealContent, // Content authenticity
      'contentType': contentType, // NEW: Content type
      'wordCount': wordCount, // NEW: Word count
      'readingLevel': readingLevel, // NEW: Reading level
      'estimatedReadingHours': estimatedReadingHours, // NEW: Reading hours
      'gutenbergMetadata': gutenbergMetadata, // NEW: Gutenberg metadata
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
  final int? currentChapter;
  final int? currentPageInChapter;

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
    this.currentChapter,
    this.currentPageInChapter,
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
      currentChapter: data['currentChapter'],
      currentPageInChapter: data['currentPageInChapter'],
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
      'currentChapter': currentChapter,
      'currentPageInChapter': currentPageInChapter,
    };
  }
}

class BookProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ApiService _apiService = ApiService();
  final AnalyticsService _analyticsService = AnalyticsService();
  final AchievementService _achievementService = AchievementService();
  final ContentFilterService _contentFilterService = ContentFilterService();
  
  List<Book> _allBooks = [];
  List<Book> _recommendedBooks = [];
  List<ReadingProgress> _userProgress = [];
  List<Book> _filteredBooks = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _sessionStart;

  // Getters
  List<Book> get allBooks => _allBooks;
  List<Book> get recommendedBooks => _recommendedBooks;
  List<ReadingProgress> get userProgress => _userProgress;
  List<Book> get filteredBooks => _filteredBooks;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Initialize sample books (call this once to populate the database)
  Future<void> initializeSampleBooks() async {
    try {
      // Check if books already exist to avoid duplicates
      final existingBooks = await _firestore.collection('books').limit(1).get();
      if (existingBooks.docs.isNotEmpty) {
        print('Sample books already exist, skipping initialization');
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

      print('Adding ${sampleBooks.length} sample books to database...');
      
      for (final bookData in sampleBooks) {
        await _firestore.collection('books').add({
          ...bookData,
          'createdAt': FieldValue.serverTimestamp(),
        });
        print('Added book: ${bookData['title']}');
      }
      
      print('Sample books initialized successfully!');
    } catch (e) {
      print('Error initializing sample books: $e');
      rethrow; // Re-throw to handle in calling code
    }
  }

  // FIXED: Load all books with content filtering - removes orderBy constraint
  Future<void> loadAllBooks({String? userId}) async {
    try {
      _isLoading = true;
      _error = null;
      // Delay notifying listeners to ensure we finish the build phase
      Future.delayed(Duration.zero, () => notifyListeners());

      // FIXED: Only get visible books (books with PDFs)
      final querySnapshot = await _firestore
          .collection('books')
          .where('isVisible', isEqualTo: true)
          .get();

      _allBooks = querySnapshot.docs
          .map((doc) => Book.fromFirestore(doc))
          .toList();

      if (_allBooks.isNotEmpty) {
      }

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
            'content': book.content,
          }).toList();

          final filteredBooksData = await _contentFilterService.filterBooks(booksData, userId);
          final filteredIds = filteredBooksData.map((book) => book['id']).toSet();
          
          _filteredBooks = _allBooks.where((book) => filteredIds.contains(book.id)).toList();
          // Debug image print removed
        } catch (filterError) {
          print('Error applying content filter: $filterError');
          // Fallback to all books if filtering fails
          _filteredBooks = _allBooks;
        }
      } else {
        _filteredBooks = _allBooks;
      }

      _isLoading = false;
      Future.delayed(Duration.zero, () => notifyListeners());
    } catch (e) {
      print('Error loading books: $e');
      _error = 'Failed to load books: $e';
      _isLoading = false;
      Future.delayed(Duration.zero, () => notifyListeners());
    }
  }

  // Get recommended books based on personality traits with enhanced filtering
  Future<void> loadRecommendedBooks(List<String> userTraits, {String? userId}) async {
    try {
      _isLoading = true;
      Future.delayed(Duration.zero, () => notifyListeners());

      if (_allBooks.isEmpty) {
        await loadAllBooks(userId: userId);
      }

      // Use API service for enhanced recommendations
      try {
        final recommendedBooksData = await _apiService.getRecommendedBooks(userTraits);
        final recommendedIds = recommendedBooksData.map((book) => book['id']).toSet();
        
        _recommendedBooks = (userId != null ? _filteredBooks : _allBooks)
            .where((book) => recommendedIds.contains(book.id))
            .toList();
      } catch (e) {
        print('API recommendation failed, using local filtering: $e');
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

      _isLoading = false;
      Future.delayed(Duration.zero, () => notifyListeners());
    } catch (e) {
      print('Error loading recommendations: $e');
      _error = 'Failed to load recommendations: $e';
      _isLoading = false;
      Future.delayed(Duration.zero, () => notifyListeners());
    }
  }

  // Enhanced book relevance scoring for better recommendations
  int _calculateBookRelevanceScore(Book book, List<String> userTraits) {
    int score = 0;
    
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
      case 'adventure':
        return ['adventurous', 'brave', 'curious'];
      case 'fantasy':
        return ['imaginative', 'creative', 'curious'];
      case 'friendship':
        return ['kind', 'social', 'caring'];
      case 'animals':
        return ['caring', 'kind', 'curious'];
      case 'family':
        return ['caring', 'kind'];
      case 'learning':
        return ['curious', 'analytical'];
      case 'kindness':
        return ['kind', 'caring'];
      case 'creativity':
        return ['creative', 'imaginative'];
      case 'imagination':
        return ['imaginative', 'creative', 'curious'];
      default:
        return [];
    }
  }

  // Get user's reading progress
  Future<void> loadUserProgress(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('reading_progress')
          .where('userId', isEqualTo: userId)
          .orderBy('lastReadAt', descending: true)
          .get();

      _userProgress = querySnapshot.docs
          .map((doc) => ReadingProgress.fromFirestore(doc))
          .toList();

      Future.delayed(Duration.zero, () => notifyListeners());
    } catch (e) {
      print('Error loading user progress: $e');
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
    int? currentChapter,
    int? currentPageInChapter,
  }) async {
    try {
      // Fix: Only mark as completed if explicitly set or if at the very last page
      // Changed from 95% to requiring the actual last page (or 98% minimum)
      final progressPercentage = totalPages > 0 ? currentPage / totalPages : 0.0;
      final bookCompleted = isCompleted ?? (currentPage >= totalPages || progressPercentage >= 0.98);
      final sessionEnd = DateTime.now();
      
      print('📊 Progress Update: Page $currentPage/$totalPages (${(progressPercentage * 100).toStringAsFixed(1)}%) - Completed: $bookCompleted');

      // Check if progress already exists
      final existingProgressQuery = await _firestore
          .collection('reading_progress')
          .where('userId', isEqualTo: userId)
          .where('bookId', isEqualTo: bookId)
          .get();

      if (existingProgressQuery.docs.isNotEmpty) {
        // Update existing progress
        final docId = existingProgressQuery.docs.first.id;
        final existingData = existingProgressQuery.docs.first.data();
        
        await _firestore.collection('reading_progress').doc(docId).update({
          'currentPage': currentPage,
          'progressPercentage': progressPercentage,
          'readingTimeMinutes': (existingData['readingTimeMinutes'] ?? 0) + additionalReadingTime,
          'lastReadAt': FieldValue.serverTimestamp(),
          'isCompleted': bookCompleted,
          'currentChapter': currentChapter,
          'currentPageInChapter': currentPageInChapter,
        });
      } else {
        // Create new progress record
        await _firestore.collection('reading_progress').add({
          'userId': userId,
          'bookId': bookId,
          'currentPage': currentPage,
          'totalPages': totalPages,
          'progressPercentage': progressPercentage,
          'readingTimeMinutes': additionalReadingTime,
          'lastReadAt': FieldValue.serverTimestamp(),
          'isCompleted': bookCompleted,
          'currentChapter': currentChapter,
          'currentPageInChapter': currentPageInChapter,
        });
      }

      // Track analytics
      if (_sessionStart != null) {
        final book = getBookById(bookId);
        await _analyticsService.trackReadingSession(
          bookId: bookId,
          bookTitle: book?.title ?? 'Unknown',
          pageNumber: currentPage,
          totalPages: totalPages,
          sessionDurationSeconds: sessionEnd.difference(_sessionStart!).inSeconds,
          sessionStart: _sessionStart!,
          sessionEnd: sessionEnd,
        );
      }

      // Track content filter reading time
      await _contentFilterService.trackReadingTime(userId, additionalReadingTime);

      // Check and unlock achievements
      await _checkAchievements(userId);

      // Reload user progress and trigger user stats update
      await loadUserProgress(userId);
      // Also trigger user stats update for streaks and minutes
      try {
        final userProvider = UserProvider();
        await userProvider.loadUserData(userId);
      } catch (e) {
        print('Error updating user stats after reading progress: $e');
      }
    } catch (e) {
      print('Error updating reading progress: $e');
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

  // Start reading session
  void startReadingSession() {
    _sessionStart = DateTime.now();
  }

  // End reading session
  void endReadingSession() {
    _sessionStart = null;
  }

  // Check and unlock achievements
  Future<void> _checkAchievements(String userId) async {
    try {
      // Get user stats
      final completedBooks = _userProgress.where((p) => p.isCompleted).length;
      final totalReadingTime = _userProgress.fold<int>(
        0, 
        (sum, progress) => sum + progress.readingTimeMinutes,
      );

      // Get analytics for streak calculation
      final analytics = await _analyticsService.getUserReadingAnalytics(userId);
      final currentStreak = analytics['currentStreak'] ?? 0;
      final totalSessions = analytics['totalSessions'] ?? 0;

      // Check achievements
      await _achievementService.checkAndUnlockAchievements(
        booksCompleted: completedBooks,
        readingStreak: currentStreak,
        totalReadingMinutes: totalReadingTime,
        totalSessions: totalSessions,
      );
    } catch (e) {
      print('Error checking achievements: $e');
    }
  }

  // Get filtered books for user
  Future<List<Book>> getFilteredBooks(String userId) async {
    if (_filteredBooks.isEmpty && _allBooks.isNotEmpty) {
      await loadAllBooks(userId: userId);
    }
    return _filteredBooks;
  }

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
      print('Error tracking book interaction: $e');
    }
  }

  // Get reading time restrictions
  Future<Map<String, dynamic>> getReadingTimeRestrictions(String userId) async {
    return await _contentFilterService.getReadingTimeRestrictions(userId);
  }

  // Check if user has exceeded daily reading limit
  Future<bool> hasExceededDailyLimit(String userId) async {
    return await _contentFilterService.hasExceededDailyLimit(userId);
  }

  // Report inappropriate content
  Future<void> reportInappropriateContent({
    required String bookId,
    required String reason,
    required String description,
  }) async {
    await _contentFilterService.reportInappropriateContent(
      bookId: bookId,
      reason: reason,
      description: description,
    );
  }

  // Clear error
  void clearError() {
    _error = null;
    Future.delayed(Duration.zero, () => notifyListeners());
  }

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

  // NEW: Search books by title, author, or description
  List<Book> searchBooks(String query) {
    if (query.isEmpty) return _allBooks;
    
    final lowercaseQuery = query.toLowerCase();
    return _allBooks.where((book) {
      return book.title.toLowerCase().contains(lowercaseQuery) ||
             book.author.toLowerCase().contains(lowercaseQuery) ||
             book.description.toLowerCase().contains(lowercaseQuery) ||
             book.traits.any((trait) => trait.toLowerCase().contains(lowercaseQuery));
    }).toList();
  }

  // NEW: Filter books by age rating
  List<Book> filterBooksByAge(String ageRating) {
    if (ageRating.isEmpty || ageRating == 'All') return _allBooks;
    return _allBooks.where((book) => book.ageRating == ageRating).toList();
  }

  // NEW: Filter books by traits
  List<Book> filterBooksByTraits(List<String> traits) {
    if (traits.isEmpty) return _allBooks;
    return _allBooks.where((book) {
      return book.traits.any((trait) => traits.contains(trait));
    }).toList();
  }

  // NEW: Get books sorted by trait relevance for better user experience
  List<Book> getBooksSortedByRelevance(List<String> userTraits) {
    if (userTraits.isEmpty) {
      return _allBooks; // Return unsorted if no traits
    }

    final booksWithScores = _allBooks.map((book) {
      final score = _calculateBookRelevanceScore(book, userTraits);
      return {'book': book, 'score': score};
    }).toList();

    // Sort by relevance score (highest first)
    booksWithScores.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    
    return booksWithScores.map((item) => item['book'] as Book).toList();
  }

  // NEW: Get favorite books (for now, return first 10 books as favorites)
  // TODO: Implement proper favorites system with user preferences
  List<Book> getFavoriteBooks() {
    // For now, return books that have been read (have progress)
    final readBookIds = _userProgress.map((progress) => progress.bookId).toSet();
    final favoriteBooks = _allBooks.where((book) => readBookIds.contains(book.id)).toList();
    
    // If no read books, return first 5 books as sample favorites
    if (favoriteBooks.isEmpty) {
      return _allBooks.take(5).toList();
    }
    
    return favoriteBooks;
  }

  // NEW: Add book to favorites (placeholder for future implementation)
  Future<void> addToFavorites(String bookId) async {
    // TODO: Implement favorites in Firestore
    print('Adding book $bookId to favorites');
    notifyListeners();
  }

  // NEW: Remove book from favorites (placeholder for future implementation)
  Future<void> removeFromFavorites(String bookId) async {
    // TODO: Implement favorites removal in Firestore
    print('Removing book $bookId from favorites');
    notifyListeners();
  }
}
