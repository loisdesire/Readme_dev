// File: lib/models/chapter.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a chapter or section within a book
class Chapter {
  final int number;              // Chapter number (1-based)
  final String title;            // Chapter title (e.g., "Chapter 1: The Rabbit Hole")
  final List<String> pages;      // Pages within the chapter for comfortable reading
  final int wordCount;           // Approximate word count for this chapter
  final int estimatedMinutes;    // Estimated reading time for this chapter
  final String? subtitle;        // Optional subtitle or description

  Chapter({
    required this.number,
    required this.title,
    required this.pages,
    required this.wordCount,
    required this.estimatedMinutes,
    this.subtitle,
  });

  /// Create a Chapter from Firestore document data
  factory Chapter.fromMap(Map<String, dynamic> data) {
    return Chapter(
      number: data['number'] ?? 1,
      title: data['title'] ?? '',
      pages: List<String>.from(data['pages'] ?? []),
      wordCount: data['wordCount'] ?? 0,
      estimatedMinutes: data['estimatedMinutes'] ?? 5,
      subtitle: data['subtitle'],
    );
  }

  /// Convert Chapter to Map for Firestore storage
  Map<String, dynamic> toMap() {
    return {
      'number': number,
      'title': title,
      'pages': pages,
      'wordCount': wordCount,
      'estimatedMinutes': estimatedMinutes,
      'subtitle': subtitle,
    };
  }

  /// Get the total number of pages in this chapter
  int get totalPages => pages.length;

  /// Check if this chapter has content
  bool get hasContent => pages.isNotEmpty && pages.any((page) => page.trim().isNotEmpty);

  /// Get a specific page by index (0-based)
  String? getPage(int pageIndex) {
    if (pageIndex >= 0 && pageIndex < pages.length) {
      return pages[pageIndex];
    }
    return null;
  }

  /// Get a short preview of the chapter (first 100 characters)
  String get preview {
    if (pages.isNotEmpty && pages.first.isNotEmpty) {
      final firstPage = pages.first.trim();
      return firstPage.length > 100 
          ? '${firstPage.substring(0, 100)}...'
          : firstPage;
    }
    return 'No content available';
  }

  /// Create a copy of this chapter with updated fields
  Chapter copyWith({
    int? number,
    String? title,
    List<String>? pages,
    int? wordCount,
    int? estimatedMinutes,
    String? subtitle,
  }) {
    return Chapter(
      number: number ?? this.number,
      title: title ?? this.title,
      pages: pages ?? List<String>.from(this.pages),
      wordCount: wordCount ?? this.wordCount,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      subtitle: subtitle ?? this.subtitle,
    );
  }

  @override
  String toString() {
    return 'Chapter(number: $number, title: "$title", pages: ${pages.length}, wordCount: $wordCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Chapter &&
        other.number == number &&
        other.title == title &&
        other.pages.length == pages.length &&
        other.wordCount == wordCount;
  }

  @override
  int get hashCode {
    return number.hashCode ^ 
           title.hashCode ^ 
           pages.length.hashCode ^ 
           wordCount.hashCode;
  }
}

/// Utility class for chapter-related operations
class ChapterUtils {
  /// Estimate reading time based on word count
  static int estimateReadingTime(int wordCount, {int wordsPerMinute = 150}) {
    return (wordCount / wordsPerMinute).ceil();
  }

  /// Split text into pages based on target word count per page
  static List<String> splitTextIntoPages(String text, {int wordsPerPage = 200}) {
    final words = text.split(RegExp(r'\s+'));
    final pages = <String>[];
    
    for (int i = 0; i < words.length; i += wordsPerPage) {
      final endIndex = (i + wordsPerPage < words.length) ? i + wordsPerPage : words.length;
      final pageWords = words.sublist(i, endIndex);
      pages.add(pageWords.join(' '));
    }
    
    return pages.where((page) => page.trim().isNotEmpty).toList();
  }

  /// Count words in a text string
  static int countWords(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  /// Extract chapter title from text (looks for common patterns)
  static String extractChapterTitle(String text, int chapterNumber) {
    // Common chapter title patterns
    final patterns = [
      RegExp(r'^Chapter\s+(\d+|[IVX]+)[:.\s]+(.+?)(?:\n|\.|$)', caseSensitive: false),
      RegExp(r'^(\d+|[IVX]+)\.?\s+(.+?)(?:\n|\.|$)', caseSensitive: false),
      RegExp(r'^(.+?)(?:\n\n|\n|$)'), // First line as title
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text.trim());
      if (match != null) {
        String title = match.group(2) ?? match.group(1) ?? '';
        title = title.trim();
        if (title.isNotEmpty && title.length < 100) {
          return title;
        }
      }
    }
    
    // Fallback title
    return 'Chapter $chapterNumber';
  }

  /// Create chapters from a long text by detecting chapter breaks
  static List<Chapter> createChaptersFromText(
    String fullText, {
    int targetWordsPerChapter = 2000,
    int maxPagesPerChapter = 15,
  }) {
    final chapters = <Chapter>[];
    
    // Try to detect natural chapter breaks
    final chapterBreaks = _detectChapterBreaks(fullText);
    
    if (chapterBreaks.length > 1) {
      // Use detected chapter breaks
      for (int i = 0; i < chapterBreaks.length - 1; i++) {
        final chapterText = fullText.substring(chapterBreaks[i], chapterBreaks[i + 1]);
        final chapter = _createChapterFromText(chapterText, i + 1, maxPagesPerChapter);
        if (chapter.hasContent) {
          chapters.add(chapter);
        }
      }
    } else {
      // Split by target word count
      final words = fullText.split(RegExp(r'\s+'));
      int chapterNumber = 1;
      
      for (int i = 0; i < words.length; i += targetWordsPerChapter) {
        final endIndex = (i + targetWordsPerChapter < words.length) 
            ? i + targetWordsPerChapter 
            : words.length;
        final chapterWords = words.sublist(i, endIndex);
        final chapterText = chapterWords.join(' ');
        
        final chapter = _createChapterFromText(chapterText, chapterNumber, maxPagesPerChapter);
        if (chapter.hasContent) {
          chapters.add(chapter);
          chapterNumber++;
        }
      }
    }
    
    return chapters;
  }

  /// Detect chapter breaks in text
  static List<int> _detectChapterBreaks(String text) {
    final breaks = <int>[0]; // Always start at the beginning
    
    // Look for chapter markers
    final chapterPattern = RegExp(
      r'(^|\n\n+)\s*(Chapter\s+(\d+|[IVX]+)|CHAPTER\s+(\d+|[IVX]+)|\d+\.\s)',
      multiLine: true,
    );
    
    final matches = chapterPattern.allMatches(text);
    for (final match in matches) {
      if (match.start > 0) {
        breaks.add(match.start);
      }
    }
    
    breaks.add(text.length); // Always end at the text end
    return breaks..sort();
  }

  /// Create a single chapter from text
  static Chapter _createChapterFromText(String text, int number, int maxPages) {
    final title = extractChapterTitle(text, number);
    final wordCount = countWords(text);
    final estimatedMinutes = estimateReadingTime(wordCount);
    
    // Split into pages, but don't exceed maxPages
    var pages = splitTextIntoPages(text, wordsPerPage: 250);
    
    if (pages.length > maxPages) {
      // If too many pages, increase words per page to fit within limit
      final targetWordsPerPage = (wordCount / maxPages).ceil();
      pages = splitTextIntoPages(text, wordsPerPage: targetWordsPerPage);
    }
    
    return Chapter(
      number: number,
      title: title,
      pages: pages,
      wordCount: wordCount,
      estimatedMinutes: estimatedMinutes,
    );
  }
}