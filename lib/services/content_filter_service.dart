// File: lib/services/content_filter_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Singleton pattern
  static final ContentFilterService _instance = ContentFilterService._internal();
  factory ContentFilterService() => _instance;
  ContentFilterService._internal();

  // Get content filter for user
  Future<ContentFilter?> getContentFilter(String userId) async {
    try {
      final doc = await _firestore.collection('content_filters').doc(userId).get();
      
      if (doc.exists) {
        return ContentFilter.fromFirestore(doc);
      } else {
        // Return default filter if none exists
        return _getDefaultContentFilter(userId);
      }
    } catch (e) {
      print('Error getting content filter: $e');
      return _getDefaultContentFilter(userId);
    }
  }

  // Update content filter
  Future<void> updateContentFilter(ContentFilter filter) async {
    try {
      await _firestore.collection('content_filters').doc(filter.userId).set(
        filter.toMap(),
        SetOptions(merge: true),
      );
    } catch (e) {
      print('Error updating content filter: $e');
    }
  }

  // Create default content filter
  ContentFilter _getDefaultContentFilter(String userId) {
    return ContentFilter(
      userId: userId,
      allowedCategories: ['adventure', 'fantasy', 'educational', 'friendship'],
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
      print('Error filtering books: $e');
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
      if (title.contains(blockedWord.toLowerCase()) || 
          description.contains(blockedWord.toLowerCase())) {
        return false;
      }
    }

    // Check categories/traits
    final bookTraits = List<String>.from(book['traits'] ?? []);
    if (filter.allowedCategories.isNotEmpty) {
      final hasAllowedCategory = bookTraits.any((trait) => 
          filter.allowedCategories.contains(trait));
      if (!hasAllowedCategory) {
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
    
    // List of potentially inappropriate words/themes
    final inappropriateWords = [
      'violence', 'scary', 'horror', 'death', 'kill', 'murder',
      'blood', 'weapon', 'gun', 'knife', 'fight', 'war',
      'hate', 'angry', 'sad', 'cry', 'fear', 'nightmare'
    ];

    // Check title and description
    for (final word in inappropriateWords) {
      if (title.contains(word) || description.contains(word)) {
        return false;
      }
    }

    // Check content pages
    for (final page in content) {
      final pageText = (page as String? ?? '').toLowerCase();
      for (final word in inappropriateWords) {
        if (pageText.contains(word)) {
          return false;
        }
      }
    }

    return true;
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
      print('Error getting reading time restrictions: $e');
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

  // Track reading time for user
  Future<void> trackReadingTime(String userId, int minutes) async {
    try {
      final today = DateTime.now();
      final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      await _firestore.collection('daily_reading_time').doc('${userId}_$dateKey').set({
        'userId': userId,
        'date': dateKey,
        'totalMinutes': FieldValue.increment(minutes),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error tracking reading time: $e');
    }
  }

  // Get daily reading time for user
  Future<int> getDailyReadingTime(String userId) async {
    try {
      final today = DateTime.now();
      final dateKey = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      final doc = await _firestore.collection('daily_reading_time').doc('${userId}_$dateKey').get();
      
      if (doc.exists) {
        return doc.data()?['totalMinutes'] ?? 0;
      }
      return 0;
    } catch (e) {
      print('Error getting daily reading time: $e');
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
      print('Error checking daily limit: $e');
      return false;
    }
  }

  // Get content filter statistics
  Future<Map<String, dynamic>> getContentFilterStats(String userId) async {
    try {
      final filter = await getContentFilter(userId);
      if (filter == null) return {};

      // Get total books in system
      final allBooksQuery = await _firestore.collection('books').get();
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
      print('Error getting content filter stats: $e');
      return {};
    }
  }

  // Report inappropriate content
  Future<void> reportInappropriateContent({
    required String bookId,
    required String reason,
    required String description,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('content_reports').add({
        'userId': user.uid,
        'bookId': bookId,
        'reason': reason,
        'description': description,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error reporting inappropriate content: $e');
    }
  }

  // Get parental control settings
  Future<Map<String, dynamic>> getParentalControlSettings(String parentUserId) async {
    try {
      final doc = await _firestore.collection('parental_controls').doc(parentUserId).get();
      
      if (doc.exists) {
        return doc.data() ?? {};
      } else {
        return _getDefaultParentalControls();
      }
    } catch (e) {
      print('Error getting parental control settings: $e');
      return _getDefaultParentalControls();
    }
  }

  // Update parental control settings
  Future<void> updateParentalControlSettings(
    String parentUserId,
    Map<String, dynamic> settings,
  ) async {
    try {
      await _firestore.collection('parental_controls').doc(parentUserId).set({
        ...settings,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error updating parental control settings: $e');
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
