// File: lib/providers/book_provider.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/api_service.dart';
import '../services/analytics_service.dart';
import '../services/achievement_service.dart';
import '../services/content_filter_service.dart';

class Book {
  final String id;
  final String title;
  final String author;
  final String description;
  final String coverEmoji;
  final List<String> traits; // For personality matching
  final String ageRating;
  final int estimatedReadingTime; // in minutes
  final List<String> content; // Pages of the book
  final DateTime createdAt;

  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.coverEmoji,
    required this.traits,
    required this.ageRating,
    required this.estimatedReadingTime,
    required this.content,
    required this.createdAt,
  });

  factory Book.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Book(
      id: doc.id,
      title: data['title'] ?? '',
      author: data['author'] ?? '',
      description: data['description'] ?? '',
      coverEmoji: data['coverEmoji'] ?? '📚',
      traits: List<String>.from(data['traits'] ?? []),
      ageRating: data['ageRating'] ?? '6+',
      estimatedReadingTime: data['estimatedReadingTime'] ?? 15,
      content: List<String>.from(data['content'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'author': author,
      'description': description,
      'coverEmoji': coverEmoji,
      'traits': traits,
      'ageRating': ageRating,
      'estimatedReadingTime': estimatedReadingTime,
      'content': content,
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

  // Load all books with content filtering
  Future<void> loadAllBooks({String? userId}) async {
    try {
      _isLoading = true;
      _error = null;
      // Delay notifying listeners to ensure we finish the build phase
      Future.delayed(Duration.zero, () => notifyListeners());

      final querySnapshot = await _firestore
          .collection('books')
          .orderBy('createdAt', descending: false)
          .get();

      _allBooks = querySnapshot.docs
          .map((doc) => Book.fromFirestore(doc))
          .toList();

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
        // Fallback to local filtering if API fails
        _recommendedBooks = (userId != null ? _filteredBooks : _allBooks).where((book) {
          return book.traits.any((trait) => userTraits.contains(trait));
        }).toList();
      }

      // If no trait matches, show some default books
      if (_recommendedBooks.isEmpty) {
        _recommendedBooks = (userId != null ? _filteredBooks : _allBooks).take(3).toList();
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
  }) async {
    try {
      final progressPercentage = totalPages > 0 ? currentPage / totalPages : 0.0;
      final bookCompleted = isCompleted ?? (currentPage >= totalPages);
      final sessionEnd = DateTime.now();

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

      // Reload user progress
      await loadUserProgress(userId);
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
}