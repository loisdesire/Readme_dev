// File: lib/services/content_filter_service.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';
import '../utils/date_utils.dart';
import 'logger.dart';

class ContentFilter {
  final String userId;
  final List<String> allowedCategories;
  final List<String> blockedWords;
  final String maxAgeRating;
  final bool enableSafeMode;
  final List<String> allowedAuthors;
  final List<String> blockedAuthors;
  final int maxReadingTimeMinutes;
  final List<String> allowedTimes; // Time slots when reading is allowed
  final DateTime createdAt;
  final DateTime updatedAt;

  ContentFilter({
    required this.userId,
    required this.allowedCategories,
    required this.blockedWords,
    required this.maxAgeRating,
    required this.enableSafeMode,
    required this.allowedAuthors,
    required this.blockedAuthors,
    required this.maxReadingTimeMinutes,
    required this.allowedTimes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ContentFilter.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ContentFilter(
      userId: data['userId'] ?? '',
      allowedCategories: List<String>.from(data['allowedCategories'] ?? []),
      blockedWords: List<String>.from(data['blockedWords'] ?? []),
      maxAgeRating: data['maxAgeRating'] ?? '12+',
      enableSafeMode: data['enableSafeMode'] ?? true,
      allowedAuthors: List<String>.from(data['allowedAuthors'] ?? []),
      blockedAuthors: List<String>.from(data['blockedAuthors'] ?? []),
      maxReadingTimeMinutes: data['maxReadingTimeMinutes'] ?? 60,
      allowedTimes: List<String>.from(data['allowedTimes'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'allowedCategories': allowedCategories,
      'blockedWords': blockedWords,
      'maxAgeRating': maxAgeRating,
      'enableSafeMode': enableSafeMode,
      'allowedAuthors': allowedAuthors,
      'blockedAuthors': blockedAuthors,
      'maxReadingTimeMinutes': maxReadingTimeMinutes,
      'allowedTimes': allowedTimes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

class ContentFilterService {
  final FirebaseService _firebase;

  // Singleton pattern
  static final ContentFilterService _instance = ContentFilterService._internal();
  factory ContentFilterService() => _instance;
  ContentFilterService._internal() : _firebase = FirebaseService();

  /// Test-only: an independent (non-singleton) instance wrapping a fake.
  @visibleForTesting
  ContentFilterService.withInstances({required FirebaseService firebaseService})
      : _firebase = firebaseService;

  // Get content filter for user
  Future<ContentFilter?> getContentFilter(String userId) async {
    try {
      final doc = await _firebase.firestore.collection('content_filters').doc(userId).get();
      
      if (doc.exists) {
        return ContentFilter.fromFirestore(doc);
      } else {
        // Return default filter if none exists
        return _getDefaultContentFilter(userId);
      }
    } catch (e) {
      appLog('Error getting content filter: $e', level: 'ERROR');
      return _getDefaultContentFilter(userId);
    }
  }

  // Update content filter
  Future<void> updateContentFilter(ContentFilter filter) async {
    try {
      await _firebase.firestore.collection('content_filters').doc(filter.userId).set(
        filter.toMap(),
        SetOptions(merge: true),
      );
    } catch (e) {
      appLog('Error updating content filter: $e', level: 'ERROR');
    }
  }

  // Create default content filter
  ContentFilter _getDefaultContentFilter(String userId) {
    return ContentFilter(
      userId: userId,
      // Must stay a superset of ALLOWED_TAGS in functions/lib/ai_helpers.js —
      // that's the actual tag vocabulary the AI tagging Cloud Function
      // assigns to books. A tag missing here means any book tagged only
      // with it silently disappears from every user's library under the
      // default filter's "at least one allowed tag" rule.
      allowedCategories: [
        'adventure', 'fantasy', 'friendship', 'animals', 'family',
        'learning', 'kindness', 'creativity', 'imagination', 'responsibility',
        'cooperation', 'resilience', 'organization', 'enthusiasm', 'positivity',
        'bravery', 'sharing', 'art', 'exploration', 'teamwork', 'emotions',
        'self-acceptance', 'problem-solving', 'leadership', 'confidence',
        'patience', 'generosity', 'helpfulness', 'playfulness', 'curiosity',
        'innovation',
      ],
      blockedWords: [],
      maxAgeRating: '12+',
      enableSafeMode: true,
      allowedAuthors: [],
      blockedAuthors: [],
      maxReadingTimeMinutes: 60,
      allowedTimes: ['06:00-22:00'], // 6 AM to 10 PM
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  // Filter books based on content filter
  Future<List<Map<String, dynamic>>> filterBooks(
    List<Map<String, dynamic>> books,
    String userId,
  ) async {
    try {
      final filter = await getContentFilter(userId);
      if (filter == null) return books;

      return books.where((book) => _isBookAllowed(book, filter)).toList();
    } catch (e) {
      appLog('Error filtering books: $e', level: 'ERROR');
      return books;
    }
  }

  // Check if a book is allowed based on content filter
  bool _isBookAllowed(Map<String, dynamic> book, ContentFilter filter) {
    // Check age rating
    if (!_isAgeRatingAllowed(book['ageRating'] ?? '6+', filter.maxAgeRating)) {
      return false;
    }

    // Check blocked authors
    final author = book['author'] ?? '';
    if (filter.blockedAuthors.contains(author)) {
      return false;
    }

    // Check allowed authors (if specified)
    if (filter.allowedAuthors.isNotEmpty && !filter.allowedAuthors.contains(author)) {
      return false;
    }

    // Check blocked words in title and description
    final title = (book['title'] ?? '').toLowerCase();
    final description = (book['description'] ?? '').toLowerCase();

    for (final blockedWord in filter.blockedWords) {
      if (_containsWord(title, blockedWord) ||
          _containsWord(description, blockedWord)) {
        return false;
      }
    }

    // Check categories/tags - books have 'tags' field with categories
    final bookTags = List<String>.from(book['tags'] ?? []);
    
    if (filter.allowedCategories.isNotEmpty) {
      // Check if book has at least one allowed tag
      final hasAllowedTag = bookTags.any((tag) => 
          filter.allowedCategories.contains(tag));
      
      if (!hasAllowedTag) {
        return false;
      }
    }

    // Additional safe mode checks
    if (filter.enableSafeMode) {
      if (!_isSafeModeCompliant(book)) {
        return false;
      }
    }

    return true;
  }

  // Check if age rating is allowed
  bool _isAgeRatingAllowed(String bookAgeRating, String maxAgeRating) {
    final bookAge = _parseAgeRating(bookAgeRating);
    final maxAge = _parseAgeRating(maxAgeRating);
    return bookAge <= maxAge;
  }

  // Parse age rating to integer
  int _parseAgeRating(String ageRating) {
    final regex = RegExp(r'(\d+)');
    final match = regex.firstMatch(ageRating);
    return match != null ? int.parse(match.group(1)!) : 6;
  }

  // Check if book complies with safe mode
  bool _isSafeModeCompliant(Map<String, dynamic> book) {
    final title = (book['title'] ?? '').toLowerCase();
    final description = (book['description'] ?? '').toLowerCase();
    final content = book['content'] as List<dynamic>? ?? [];
    
    // List of potentially inappropriate words/themes. Deliberately scoped to
    // real safety concerns (violence, weapons, graphic/scary content) —
    // NOT ordinary negative emotions. Sadness, fear, anger, and crying are
    // normal, healthy content in children's literature (a character being
    // scared of the dark, feeling sad about a move, crying and being
    // comforted); a book about those isn't a safety issue and shouldn't be
    // hidden from anyone by default. 'angry', 'sad', 'cry', 'fear', and
    // 'hate' were removed for exactly this reason — see SECURITY.md.
    final inappropriateWords = [
      'violence', 'scary', 'horror', 'death', 'kill', 'murder',
      'blood', 'weapon', 'gun', 'knife', 'fight', 'war', 'nightmare',
    ];

    // Check title and description
    for (final word in inappropriateWords) {
      if (_containsWord(title, word) || _containsWord(description, word)) {
        return false;
      }
    }

    // Check content pages
    for (final page in content) {
      final pageText = (page as String? ?? '').toLowerCase();
      for (final word in inappropriateWords) {
        if (_containsWord(pageText, word)) {
          return false;
        }
      }
    }

    return true;
  }

  /// Whole-word match, case-insensitive-by-convention (callers pass
  /// already-lowercased text and words). A naive `String.contains` here
  /// would flag "skills" for containing "kill", "begun" for "gun", or
  /// "warm"/"forward"/"awarded" for "war" — all common in ordinary
  /// children's-book blurbs — and silently vanish the book from every
  /// user's library under the default (on-by-default) safe mode filter.
  bool _containsWord(String text, String word) {
    if (word.isEmpty) return false;
    return RegExp(r'\b' + RegExp.escape(word) + r'\b').hasMatch(text);
  }

  // Check if current time is within allowed reading times
  bool isReadingTimeAllowed(String userId) {
    // This would typically be called with the user's content filter
    // For now, return true as a placeholder
    return true;
  }

  // Get reading time restrictions for user
  Future<Map<String, dynamic>> getReadingTimeRestrictions(String userId) async {
    try {
      final filter = await getContentFilter(userId);
      if (filter == null) {
        return {
          'hasRestrictions': false,
          'maxReadingTimeMinutes': 60,
          'allowedTimes': ['06:00-22:00'],
        };
      }

      final now = DateTime.now();
      final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      
      bool isCurrentTimeAllowed = false;
      for (final timeSlot in filter.allowedTimes) {
        if (_isTimeInSlot(currentTime, timeSlot)) {
          isCurrentTimeAllowed = true;
          break;
        }
      }

      return {
        'hasRestrictions': true,
        'maxReadingTimeMinutes': filter.maxReadingTimeMinutes,
        'allowedTimes': filter.allowedTimes,
        'isCurrentTimeAllowed': isCurrentTimeAllowed,
        'currentTime': currentTime,
      };
    } catch (e) {
      appLog('Error getting reading time restrictions: $e', level: 'ERROR');
      return {
        'hasRestrictions': false,
        'maxReadingTimeMinutes': 60,
        'allowedTimes': ['06:00-22:00'],
      };
    }
  }

  // Check if current time is within a time slot
  bool _isTimeInSlot(String currentTime, String timeSlot) {
    try {
      final parts = timeSlot.split('-');
      if (parts.length != 2) return true;

      final startTime = parts[0];
      final endTime = parts[1];

      final current = _timeToMinutes(currentTime);
      final start = _timeToMinutes(startTime);
      final end = _timeToMinutes(endTime);

      if (start <= end) {
        // Same day time slot
        return current >= start && current <= end;
      } else {
        // Overnight time slot (e.g., 22:00-06:00)
        return current >= start || current <= end;
      }
    } catch (e) {
      return true; // Allow if parsing fails
    }
  }

  // Convert time string to minutes since midnight
  int _timeToMinutes(String time) {
    final parts = time.split(':');
    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);
    return hours * 60 + minutes;
  }

  // Track reading time for user (uses AppDateUtils for date formatting)
  Future<void> trackReadingTime(String userId, int minutes) async {
    try {
      final today = DateTime.now();
      final dateKey = AppDateUtils.formatDateKey(today);

      await _firebase.firestore.collection('daily_reading_time').doc('${userId}_$dateKey').set({
        'userId': userId,
        'date': dateKey,
        'totalMinutes': FieldValue.increment(minutes),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      appLog('Error tracking reading time: $e', level: 'ERROR');
    }
  }

  // Get daily reading time for user (uses AppDateUtils for date formatting)
  Future<int> getDailyReadingTime(String userId) async {
    try {
      final today = DateTime.now();
      final dateKey = AppDateUtils.formatDateKey(today);

      final doc = await _firebase.firestore.collection('daily_reading_time').doc('${userId}_$dateKey').get();
      
      if (doc.exists) {
        return doc.data()?['totalMinutes'] ?? 0;
      }
      return 0;
    } catch (e) {
      appLog('Error getting daily reading time: $e', level: 'ERROR');
      return 0;
    }
  }

  // Check if user has exceeded daily reading limit
  Future<bool> hasExceededDailyLimit(String userId) async {
    try {
      final filter = await getContentFilter(userId);
      if (filter == null) return false;

      final dailyTime = await getDailyReadingTime(userId);
      return dailyTime >= filter.maxReadingTimeMinutes;
    } catch (e) {
      appLog('Error checking daily limit: $e', level: 'ERROR');
      return false;
    }
  }

  // Get content filter statistics
  Future<Map<String, dynamic>> getContentFilterStats(String userId) async {
    try {
      final filter = await getContentFilter(userId);
      if (filter == null) return {};

      // Get total books in system
      final allBooksQuery = await _firebase.firestore.collection('books').get();
      final totalBooks = allBooksQuery.docs.length;

      // Get filtered books count
      final allBooks = allBooksQuery.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
      
      final filteredBooks = await filterBooks(allBooks, userId);
      final allowedBooks = filteredBooks.length;

      return {
        'totalBooks': totalBooks,
        'allowedBooks': allowedBooks,
        'blockedBooks': totalBooks - allowedBooks,
        'filterEffectiveness': totalBooks > 0 ? (totalBooks - allowedBooks) / totalBooks : 0,
        'allowedCategories': filter.allowedCategories,
        'blockedWordsCount': filter.blockedWords.length,
        'maxAgeRating': filter.maxAgeRating,
        'safeModeEnabled': filter.enableSafeMode,
      };
    } catch (e) {
      appLog('Error getting content filter stats: $e', level: 'ERROR');
      return {};
    }
  }

  // Report inappropriate content
  Future<void> reportInappropriateContent({
    required String bookId,
    required String reason,
    required String description,
  }) async {
    final user = _firebase.currentUser;
    if (user == null) return;

    try {
      await _firebase.firestore.collection('content_reports').add({
        'userId': user.uid,
        'bookId': bookId,
        'reason': reason,
        'description': description,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      appLog('Error reporting inappropriate content: $e', level: 'ERROR');
    }
  }

  // Get parental control settings
  Future<Map<String, dynamic>> getParentalControlSettings(String parentUserId) async {
    try {
      final doc = await _firebase.firestore.collection('parental_controls').doc(parentUserId).get();
      
      if (doc.exists) {
        return doc.data() ?? {};
      } else {
        return _getDefaultParentalControls();
      }
    } catch (e) {
      appLog('Error getting parental control settings: $e', level: 'ERROR');
      return _getDefaultParentalControls();
    }
  }

  // Update parental control settings
  Future<void> updateParentalControlSettings(
    String parentUserId,
    Map<String, dynamic> settings,
  ) async {
    try {
      await _firebase.firestore.collection('parental_controls').doc(parentUserId).set({
        ...settings,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      appLog('Error updating parental control settings: $e', level: 'ERROR');
    }
  }

  // Get default parental controls
  Map<String, dynamic> _getDefaultParentalControls() {
    return {
      'requireApprovalForNewBooks': false,
      'sendProgressReports': true,
      'allowBookPurchases': false,
      'maxDailyReadingTime': 60,
      'bedtimeMode': {
        'enabled': true,
        'startTime': '20:00',
        'endTime': '07:00',
      },
      'contentFiltering': {
        'enabled': true,
        'strictMode': false,
      },
    };
  }
}
