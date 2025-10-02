// // File: lib/providers/book_provider_gutenberg.dart
// import 'package:flutter/foundation.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import '../services/api_service.dart';
// import '../services/analytics_service.dart';
// import '../services/achievement_service.dart';
// import '../services/content_filter_service.dart';
// import '../services/gutenberg_service.dart';
// import '../models/chapter.dart';

// /// Enhanced Book model with Project Gutenberg support
// class BookGutenberg {
//   final String id;
//   final String title;
//   final String author;
//   final String description;
//   final String? coverImageUrl; // Real cover image URL from Open Library
//   final String? coverEmoji;    // Emoji fallback for books without covers
//   final List<String> traits; // For personality matching
//   final String ageRating;
//   final int estimatedReadingTime; // in minutes for short content
//   final List<String> content; // Pages of the book (for short stories)
//   final DateTime createdAt;
//   final String? source; // Source of the book (Open Library, Gutenberg, etc.)
//   final bool hasRealContent; // Whether book contains real excerpts
  
//   // NEW: Project Gutenberg specific fields
//   final int? wordCount; // Total word count for full books
//   final String? readingLevel; // Easy, Medium, Advanced
//   final int? estimatedReadingHours; // For full books (vs minutes for short stories)
//   final String contentType; // 'short_story', 'novel', 'collection'
//   final int? gutenbergId; // Original Project Gutenberg book ID
//   final Map<String, dynamic>? gutenbergMetadata; // Original Gutenberg metadata

//   BookGutenberg({
//     required this.id,
//     required this.title,
//     required this.author,
//     required this.description,
//     this.coverImageUrl,        // Real cover from Open Library
//     this.coverEmoji,           // Emoji fallback
//     required this.traits,
//     required this.ageRating,
//     required this.estimatedReadingTime,
//     required this.content,
//     required this.createdAt,
//     this.source,               // Book source
//     this.hasRealContent = false, // Content authenticity flag
//     // NEW: Gutenberg fields
//     this.wordCount,            // Total words
//     this.readingLevel,         // Difficulty level
//     this.estimatedReadingHours, // Hours for full books
//     this.contentType = 'short_story', // Default to short story
//     this.gutenbergId,          // Original Gutenberg ID
//     this.gutenbergMetadata,    // Original metadata
//   });

//   // Enhanced helper methods for cover display
//   String get displayCover => coverEmoji ?? '📚';
//   bool get hasRealCover => coverImageUrl != null && 
//                           coverImageUrl!.isNotEmpty && 
//                           coverImageUrl!.startsWith('http');
  
//   // Get the best available cover (prioritize real images)
//   String? get bestCoverUrl => hasRealCover ? coverImageUrl : null;
//   String get fallbackEmoji => coverEmoji ?? '📚';

//   // NEW: Enhanced methods for full-length books
//   bool get isFullLengthBook => chapters != null && chapters!.isNotEmpty;

//   // Get total reading time (minutes for short stories, hours for novels)
//   String get readingTimeDisplay {
//     if (isFullLengthBook && estimatedReadingHours != null) {
//       if (estimatedReadingHours! < 1) {
//         return '${(estimatedReadingHours! * 60).round()} min';
//       } else if (estimatedReadingHours! == 1) {
//         return '1 hour';
//       } else {
//         return '$estimatedReadingHours hours';
//       }
//     } else {
//       return '$estimatedReadingTime min';
//     }
//   }

//   // Get chapter count
//   int get chapterCount => chapters?.length ?? 0;

//   // Get total page count
//   int get totalPages {
//     if (isFullLengthBook) {
//       return chapters!.fold(0, (sum, chapter) => sum + chapter.totalPages);
//     } else {
//       return content.length;
//     }
//   }

//   // Get content for reading (either chapters or simple content)
//   List<String> getContentForReading() {
//     if (isFullLengthBook && chapters != null) {
//       // Flatten all chapter pages into a single list
//       final allPages = <String>[];
//       for (final chapter in chapters!) {
//         allPages.addAll(chapter.pages);
//       }
//       return allPages;
//     } else {
//       return content;
//     }
//   }

//   // Get chapter by number
//   Chapter? getChapter(int chapterNumber) {
//     if (chapters != null && chapterNumber > 0 && chapterNumber <= chapters!.length) {
//       return chapters![chapterNumber - 1];
//     }
//     return null;
//   }

//   factory BookGutenberg.fromFirestore(DocumentSnapshot doc) {
//     final data = doc.data() as Map<String, dynamic>;
    
//     // Handle content field safely (String or List)
//     List<String> contentList = [];
//     final contentData = data['content'];
//     if (contentData != null) {
//       if (contentData is String) {
//         contentList = [contentData];
//       } else if (contentData is List) {
//         contentList = List<String>.from(contentData);
//       }
//     }

//     // Handle chapters field safely
//     List<Chapter>? chaptersList;
//     if (data['chapters'] != null && data['chapters'] is List) {
//       chaptersList = (data['chapters'] as List)
//           .map((chapterData) => Chapter.fromMap(chapterData))
//           .toList();
//     }
    
//     // Ensure we have valid cover URL format
//     String? validCoverUrl = data['coverImageUrl'];
//     if (validCoverUrl != null && !validCoverUrl.startsWith('http')) {
//       validCoverUrl = null; // Invalid URL format
//     }
    
//     return BookGutenberg(
//       id: doc.id,
//       title: data['title'] ?? '',
//       author: data['author'] ?? '',
//       description: data['description'] ?? '',
//       coverImageUrl: validCoverUrl, // Validated cover URL
//       coverEmoji: data['coverEmoji'], // Fallback emoji
//       traits: List<String>.from(data['traits'] ?? []),
//       ageRating: data['ageRating'] ?? '6+',
//       estimatedReadingTime: data['estimatedReadingTime'] ?? 15,
//       content: contentList, // Safe content handling
//       createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
//       source: data['source'], // Book source tracking
//       hasRealContent: data['hasRealContent'] ?? false, // Content authenticity
//       // NEW: Gutenberg fields
//       chapters: chaptersList,
//       wordCount: data['wordCount'],
//       readingLevel: data['readingLevel'],
//       estimatedReadingHours: data['estimatedReadingHours'],
//       contentType: data['contentType'] ?? 'short_story',
//       gutenbergId: data['gutenbergId'],
//       gutenbergMetadata: data['gutenbergMetadata'],
//     );
//   }

//   Map<String, dynamic> toMap() {
//     return {
//       'title': title,
//       'author': author,
//       'description': description,
//       'coverImageUrl': coverImageUrl, // Real cover image URL
//       'coverEmoji': coverEmoji, // Emoji fallback
//       'traits': traits,
//       'ageRating': ageRating,
//       'estimatedReadingTime': estimatedReadingTime,
//       'content': content,
//       'createdAt': Timestamp.fromDate(createdAt),
//       'source': source, // Book source
//       'hasRealContent': hasRealContent, // Content authenticity
//       // NEW: Gutenberg fields
//       'chapters': chapters?.map((chapter) => chapter.toMap()).toList(),
//       'wordCount': wordCount,
//       'readingLevel': readingLevel,
//       'estimatedReadingHours': estimatedReadingHours,
//       'contentType': contentType,
//       'gutenbergId': gutenbergId,
//       'gutenbergMetadata': gutenbergMetadata,
//     };
//   }
// }

// class ReadingProgress {
//   final String id;
//   final String userId;
//   final String bookId;
//   final int currentPage;
//   final int totalPages;
//   final double progressPercentage;
//   final int readingTimeMinutes;
//   final DateTime lastReadAt;
//   final bool isCompleted;
//   // NEW: Chapter-based progress tracking
//   final int? currentChapter;
//   final int? totalChapters;
//   final int? currentPageInChapter;

//   ReadingProgress({
//     required this.id,
//     required this.userId,
//     required this.bookId,
//     required this.currentPage,
//     required this.totalPages,
//     required this.progressPercentage,
//     required this.readingTimeMinutes,
//     required this.lastReadAt,
//     required this.isCompleted,
//     this.currentChapter,
//     this.totalChapters,
//     this.currentPageInChapter,
//   });

//   factory ReadingProgress.fromFirestore(DocumentSnapshot doc) {
//     final data = doc.data() as Map<String, dynamic>;
//     return ReadingProgress(
//       id: doc.id,
//       userId: data['userId'] ?? '',
//       bookId: data['bookId'] ?? '',
//       currentPage: data['currentPage'] ?? 1,
//       totalPages: data['totalPages'] ?? 1,
//       progressPercentage: (data['progressPercentage'] ?? 0.0).toDouble(),
//       readingTimeMinutes: data['readingTimeMinutes'] ?? 0,
//       lastReadAt: (data['lastReadAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
//       isCompleted: data['isCompleted'] ?? false,
//       currentChapter: data['currentChapter'],
//       totalChapters: data['totalChapters'],
//       currentPageInChapter: data['currentPageInChapter'],
//     );
//   }

//   Map<String, dynamic> toMap() {
//     return {
//       'userId': userId,
//       'bookId': bookId,
//       'currentPage': currentPage,
//       'totalPages': totalPages,
//       'progressPercentage': progressPercentage,
//       'readingTimeMinutes': readingTimeMinutes,
//       'lastReadAt': Timestamp.fromDate(lastReadAt),
//       'isCompleted': isCompleted,
//       'currentChapter': currentChapter,
//       'totalChapters': totalChapters,
//       'currentPageInChapter': currentPageInChapter,
//     };
//   }
// }

// /// Enhanced Book Provider with Project Gutenberg integration
// class BookProviderGutenberg extends ChangeNotifier {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final ApiService _apiService = ApiService();
//   final AnalyticsService _analyticsService = AnalyticsService();
//   final AchievementService _achievementService = AchievementService();
//   final ContentFilterService _contentFilterService = ContentFilterService();
//   final GutenbergService _gutenbergService = GutenbergService();
  
//   List<BookGutenberg> _allBooks = [];
//   List<BookGutenberg> _recommendedBooks = [];
//   List<ReadingProgress> _userProgress = [];
//   List<BookGutenberg> _filteredBooks = [];
//   bool _isLoading = false;
//   String? _error;
//   DateTime? _sessionStart;

//   // Getters
//   List<BookGutenberg> get allBooks => _allBooks;
//   List<BookGutenberg> get recommendedBooks => _recommendedBooks;
//   List<ReadingProgress> get userProgress => _userProgress;
//   List<BookGutenberg> get filteredBooks => _filteredBooks;
//   bool get isLoading => _isLoading;
//   String? get error => _error;

//   // NEW: Get books by content type
//   List<BookGutenberg> get shortStories => _allBooks.where((book) => book.isShortStory).toList();
//   List<BookGutenberg> get novels => _allBooks.where((book) => book.isNovel).toList();
//   List<BookGutenberg> get collections => _allBooks.where((book) => book.isCollection).toList();
//   List<BookGutenberg> get fullLengthBooks => _allBooks.where((book) => book.isFullLengthBook).toList();

//   /// Load all books from Firestore (including Gutenberg books)
//   Future<void> loadAllBooks({String? userId}) async {
//     try {
//       _isLoading = true;
//       _error = null;
//       Future.delayed(Duration.zero, () => notifyListeners());

//       final querySnapshot = await _firestore
//           .collection('books')
//           .get();

//       _allBooks = querySnapshot.docs
//           .map((doc) => BookGutenberg.fromFirestore(doc))
//           .toList();

//       print('DEBUG: Loaded ${_allBooks.length} books from Firestore');
//       print('DEBUG: Full-length books: ${fullLengthBooks.length}');
//       print('DEBUG: Short stories: ${shortStories.length}');

//       // Apply content filtering if userId is provided
//       if (userId != null) {
//         try {
//           final booksData = _allBooks.map((book) => {
//             'id': book.id,
//             'title': book.title,
//             'author': book.author,
//             'description': book.description,
//             'ageRating': book.ageRating,
//             'traits': book.traits,
//             'content': book.getContentForReading(),
//           }).toList();

//           final filteredBooksData = await _contentFilterService.filterBooks(booksData, userId);
//           final filteredIds = filteredBooksData.map((book) => book['id']).toSet();
          
//           _filteredBooks = _allBooks.where((book) => filteredIds.contains(book.id)).toList();
//           print('DEBUG: After filtering: ${_filteredBooks.length} books');
//         } catch (filterError) {
//           print('Error applying content filter: $filterError');
//           _filteredBooks = _allBooks;
//         }
//       } else {
//         _filteredBooks = _allBooks;
//       }

//       _isLoading = false;
//       Future.delayed(Duration.zero, () => notifyListeners());
//     } catch (e) {
//       print('Error loading books: $e');
//       _error = 'Failed to load books: $e';
//       _isLoading = false;
//       Future.delayed(Duration.zero, () => notifyListeners());
//     }
//   }

//   /// Get recommended books based on personality traits with enhanced filtering
//   Future<void> loadRecommendedBooks(List<String> userTraits, {String? userId}) async {
//     try {
//       _isLoading = true;
//       Future.delayed(Duration.zero, () => notifyListeners());

//       if (_allBooks.isEmpty) {
//         await loadAllBooks(userId: userId);
//       }

//       // Use local filtering for recommendations
//       _recommendedBooks = (userId != null ? _filteredBooks : _allBooks).where((book) {
//         return book.traits.any((trait) => userTraits.contains(trait));
//       }).toList();

//       // If no trait matches, show some default books
//       if (_recommendedBooks.isEmpty) {
//         _recommendedBooks = (userId != null ? _filteredBooks : _allBooks).take(3).toList();
//       }

//       _isLoading = false;
//       Future.delayed(Duration.zero, () => notifyListeners());
//     } catch (e) {
//       print('Error loading recommendations: $e');
//       _error = 'Failed to load recommendations: $e';
//       _isLoading = false;
//       Future.delayed(Duration.zero, () => notifyListeners());
//     }
//   }

//   /// Get user's reading progress
//   Future<void> loadUserProgress(String userId) async {
//     try {
//       final querySnapshot = await _firestore
//           .collection('reading_progress')
//           .where('userId', isEqualTo: userId)
//           .orderBy('lastReadAt', descending: true)
//           .get();

//       _userProgress = querySnapshot.docs
//           .map((doc) => ReadingProgress.fromFirestore(doc))
//           .toList();

//       Future.delayed(Duration.zero, () => notifyListeners());
//     } catch (e) {
//       print('Error loading user progress: $e');
//     }
//   }

//   /// Enhanced reading progress update with chapter support
//   Future<void> updateReadingProgress({
//     required String userId,
//     required String bookId,
//     required int currentPage,
//     required int totalPages,
//     required int additionalReadingTime,
//     bool? isCompleted,
//     int? currentChapter,
//     int? totalChapters,
//     int? currentPageInChapter,
//   }) async {
//     try {
//       final progressPercentage = totalPages > 0 ? currentPage / totalPages : 0.0;
//       final bookCompleted = isCompleted ?? (currentPage >= totalPages);
//       final sessionEnd = DateTime.now();

//       // Check if progress already exists
//       final existingProgressQuery = await _firestore
//           .collection('reading_progress')
//           .where('userId', isEqualTo: userId)
//           .where('bookId', isEqualTo: bookId)
//           .get();

//       final progressData = {
//         'currentPage': currentPage,
//         'progressPercentage': progressPercentage,
//         'lastReadAt': FieldValue.serverTimestamp(),
//         'isCompleted': bookCompleted,
//         'currentChapter': currentChapter,
//         'totalChapters': totalChapters,
//         'currentPageInChapter': currentPageInChapter,
//       };

//       if (existingProgressQuery.docs.isNotEmpty) {
//         // Update existing progress
//         final docId = existingProgressQuery.docs.first.id;
//         final existingData = existingProgressQuery.docs.first.data();
        
//         progressData['readingTimeMinutes'] = (existingData['readingTimeMinutes'] ?? 0) + additionalReadingTime;
        
//         await _firestore.collection('reading_progress').doc(docId).update(progressData);
//       } else {
//         // Create new progress record
//         progressData.addAll({
//           'userId': userId,
//           'bookId': bookId,
//           'totalPages': totalPages,
//           'readingTimeMinutes': additionalReadingTime,
//         });
        
//         await _firestore.collection('reading_progress').add(progressData);
//       }

//       // Track analytics
//       if (_sessionStart != null) {
//         final book = getBookById(bookId);
//         await _analyticsService.trackReadingSession(
//           bookId: bookId,
//           bookTitle: book?.title ?? 'Unknown',
//           pageNumber: currentPage,
//           totalPages: totalPages,
//           sessionDurationSeconds: sessionEnd.difference(_sessionStart!).inSeconds,
//           sessionStart: _sessionStart!,
//           sessionEnd: sessionEnd,
//         );
//       }

//       // Track content filter reading time
//       await _contentFilterService.trackReadingTime(userId, additionalReadingTime);

//       // Check and unlock achievements
//       await _checkAchievements(userId);

//       // Reload user progress
//       await loadUserProgress(userId);
//     } catch (e) {
//       print('Error updating reading progress: $e');
//     }
//   }

//   /// Get book by ID
//   BookGutenberg? getBookById(String bookId) {
//     try {
//       return _allBooks.firstWhere((book) => book.id == bookId);
//     } catch (e) {
//       return null;
//     }
//   }

//   /// Get progress for a specific book
//   ReadingProgress? getProgressForBook(String bookId) {
//     try {
//       return _userProgress.firstWhere((progress) => progress.bookId == bookId);
//     } catch (e) {
//       return null;
//     }
//   }

//   /// Start reading session
//   void startReadingSession() {
//     _sessionStart = DateTime.now();
//   }

//   /// End reading session
//   void endReadingSession() {
//     _sessionStart = null;
//   }

//   /// Check and unlock achievements
//   Future<void> _checkAchievements(String userId) async {
//     try {
//       // Get user stats
//       final completedBooks = _userProgress.where((p) => p.isCompleted).length;
//       final totalReadingTime = _userProgress.fold<int>(
//         0, 
//         (sum, progress) => sum + progress.readingTimeMinutes,
//       );

//       // Get analytics for streak calculation
//       final analytics = await _analyticsService.getUserReadingAnalytics(userId);
//       final currentStreak = analytics['currentStreak'] ?? 0;
//       final totalSessions = analytics['totalSessions'] ?? 0;

//       // Check achievements
//       await _achievementService.checkAndUnlockAchievements(
//         booksCompleted: completedBooks,
//         readingStreak: currentStreak,
//         totalReadingMinutes: totalReadingTime,
//         totalSessions: totalSessions,
//       );
//     } catch (e) {
//       print('Error checking achievements: $e');
//     }
//   }

//   /// NEW: Search books with enhanced filtering
//   List<BookGutenberg> searchBooks(String query) {
//     if (query.isEmpty) return _allBooks;
    
//     final lowercaseQuery = query.toLowerCase();
//     return _allBooks.where((book) {
//       return book.title.toLowerCase().contains(lowercaseQuery) ||
//              book.author.toLowerCase().contains(lowercaseQuery) ||
//              book.description.toLowerCase().contains(lowercaseQuery) ||
//              book.traits.any((trait) => trait.toLowerCase().contains(lowercaseQuery)) ||
//              (book.readingLevel?.toLowerCase().contains(lowercaseQuery) ?? false);
//     }).toList();
//   }

//   /// NEW: Filter books by reading level
//   List<BookGutenberg> filterByReadingLevel(String level) {
//     if (level.isEmpty || level == 'All') return _allBooks;
//     return _allBooks.where((book) => book.readingLevel == level).toList();
//   }

//   /// NEW: Filter books by content type
//   List<BookGutenberg> filterByContentType(String type) {
//     switch (type.toLowerCase()) {
//       case 'short_story':
//       case 'short stories':
//         return shortStories;
//       case 'novel':
//       case 'novels':
//         return novels;
//       case 'collection':
//       case 'collections':
//         return collections;
//       case 'full':
//       case 'full_length':
//         return fullLengthBooks;
//       default:
//         return _allBooks;
//     }
//   }

//   /// Clear error
//   void clearError() {
//     _error = null;
//     Future.delayed(Duration.zero, () => notifyListeners());
//   }

//   // Additional utility methods for the new book structure
//   String getReadingTimeForBook(String bookId) {
//     final book = getBookById(bookId);
//     return book?.readingTimeDisplay ?? '15 min';
//   }

//   int getChapterCount(String bookId) {
//     final book = getBookById(bookId);
//     return book?.chapterCount ?? 0;
//   }

//   Chapter? getChapter(String bookId, int chapterNumber) {
//     final book = getBookById(bookId);
//     return book?.getChapter(chapterNumber);
//   }
// }