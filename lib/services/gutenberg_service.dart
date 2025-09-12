// File: lib/services/gutenberg_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chapter.dart';

/// Service for fetching books from Project Gutenberg
/// Uses the Gutendex API: https://gutendex.com/
class GutenbergService {
  static const String _baseUrl = 'https://gutendex.com/books';
  static const String _textBaseUrl = 'https://www.gutenberg.org';
  
  // Singleton pattern
  static final GutenbergService _instance = GutenbergService._internal();
  factory GutenbergService() => _instance;
  GutenbergService._internal();

  /// Search for children's books on Project Gutenberg
  Future<List<GutenbergBook>> searchChildrensBooks({
    int limit = 20,
    String? search,
  }) async {
    try {
      // Search for books with children-friendly subjects
      final subjects = [
        'Children',
        'Juvenile fiction',
        'Fairy tales',
        'Adventure stories',
        'Animal stories',
        'School stories',
        'Family -- Juvenile fiction',
      ];
      
      final queryParams = <String, String>{
        'mime_type': 'text/plain',
        'copyright': 'false', // Only public domain books
        'languages': 'en',
        'limit': limit.toString(),
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      } else {
        // Use subject filtering for general search
        queryParams['topic'] = subjects.first.toLowerCase();
      }

      final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List;
        
        final books = <GutenbergBook>[];
        for (final bookData in results) {
          final book = GutenbergBook.fromJson(bookData);
          // Filter for appropriate books
          if (_isAppropriateForChildren(book)) {
            books.add(book);
          }
        }
        
        return books;
      } else {
        throw GutenbergException('Failed to fetch books: ${response.statusCode}');
      }
    } catch (e) {
      throw GutenbergException('Error searching books: $e');
    }
  }

  /// Get a specific book by ID
  Future<GutenbergBook?> getBook(int bookId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/$bookId'));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final book = GutenbergBook.fromJson(data);
        return _isAppropriateForChildren(book) ? book : null;
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw GutenbergException('Failed to fetch book: ${response.statusCode}');
      }
    } catch (e) {
      throw GutenbergException('Error fetching book: $e');
    }
  }

  /// Download the full text of a book
  Future<String> downloadBookText(GutenbergBook book) async {
    try {
      // Find the plain text URL
      final textUrl = book.getTextUrl();
      if (textUrl == null) {
        throw GutenbergException('No text version available for this book');
      }

      final response = await http.get(Uri.parse(textUrl));
      
      if (response.statusCode == 200) {
        // Clean up the text
        String text = response.body;
        text = _cleanGutenbergText(text);
        return text;
      } else {
        throw GutenbergException('Failed to download text: ${response.statusCode}');
      }
    } catch (e) {
      throw GutenbergException('Error downloading book text: $e');
    }
  }

  /// Process a book into chapters suitable for the app
  Future<List<Chapter>> processBookIntoChapters(
    GutenbergBook book,
    String fullText, {
    int maxChaptersForChildren = 20,
    int targetWordsPerChapter = 1500,
  }) async {
    try {
      // Clean and prepare the text
      final cleanedText = _cleanGutenbergText(fullText);
      
      // Determine if this is a short story or novel
      final wordCount = ChapterUtils.countWords(cleanedText);
      final isShortStory = wordCount < 5000;
      
      List<Chapter> chapters;
      
      if (isShortStory) {
        // For short stories, create fewer, shorter chapters
        chapters = ChapterUtils.createChaptersFromText(
          cleanedText,
          targetWordsPerChapter: 800, // Shorter chapters for short stories
          maxPagesPerChapter: 8,
        );
      } else {
        // For longer books, create more chapters but limit total count for children
        chapters = ChapterUtils.createChaptersFromText(
          cleanedText,
          targetWordsPerChapter: targetWordsPerChapter,
          maxPagesPerChapter: 12,
        );
        
        // If too many chapters for children's attention span, combine some
        if (chapters.length > maxChaptersForChildren) {
          chapters = _combineChapters(chapters, maxChaptersForChildren);
        }
      }
      
      return chapters.where((chapter) => chapter.hasContent).toList();
    } catch (e) {
      throw GutenbergException('Error processing book into chapters: $e');
    }
  }

  /// Estimate reading level based on book metadata and content
  String estimateReadingLevel(GutenbergBook book, String? content) {
    // Use various factors to estimate reading level
    int score = 0;
    
    // Check subjects for complexity indicators
    final subjects = book.subjects.map((s) => s.toLowerCase()).join(' ');
    
    if (subjects.contains('juvenile') || 
        subjects.contains('children') ||
        subjects.contains('fairy') ||
        subjects.contains('picture')) {
      score += 1; // Easy
    }
    
    if (subjects.contains('adventure') || 
        subjects.contains('school') ||
        subjects.contains('animal')) {
      score += 2; // Medium
    }
    
    if (subjects.contains('classic') || 
        subjects.contains('literature') ||
        book.authors.any((a) => a.name.contains('Dickens') || 
                              a.name.contains('Twain') ||
                              a.name.contains('Alcott'))) {
      score += 3; // Advanced
    }
    
    // Analyze content if available
    if (content != null) {
      final wordCount = ChapterUtils.countWords(content);
      final sentences = content.split(RegExp(r'[.!?]+')).length;
      final avgWordsPerSentence = sentences > 0 ? wordCount / sentences : 0;
      
      if (avgWordsPerSentence > 20) {
        score += 2; // Longer sentences = more advanced
      } else if (avgWordsPerSentence > 15) {
        score += 1;
      }
    }
    
    // Determine final level
    if (score <= 3) return 'Easy';
    if (score <= 6) return 'Medium';
    return 'Advanced';
  }

  /// Get curated list of recommended children's books
  List<int> getCuratedChildrensBooks() {
    return [
      // Alice's Adventures in Wonderland
      11,
      // Through the Looking-Glass
      12,
      // The Secret Garden
      113,
      // A Little Princess
      146,
      // The Wonderful Wizard of Oz
      55,
      // Peter Pan
      16,
      // The Jungle Book
      236,
      // Just So Stories
      2781,
      // Treasure Island
      120,
      // Robinson Crusoe (adapted version)
      521,
      // Aesop's Fables
      21,
      // Grimms' Fairy Tales
      2591,
      // The Railway Children
      1874,
      // The Wind in the Willows
      289,
      // Anne of Green Gables
      45,
      // Heidi
      1448,
      // Black Beauty
      271,
      // The Adventures of Tom Sawyer
      74,
      // Little Women
      514,
      // The Princess and the Goblin
      34,
    ];
  }

  /// Check if a book is appropriate for children
  bool _isAppropriateForChildren(GutenbergBook book) {
    final subjects = book.subjects.map((s) => s.toLowerCase()).join(' ');
    final title = book.title.toLowerCase();
    
    // Positive indicators
    final hasChildrenContent = subjects.contains('juvenile') ||
                              subjects.contains('children') ||
                              subjects.contains('fairy') ||
                              subjects.contains('adventure') ||
                              subjects.contains('animal') ||
                              subjects.contains('school') ||
                              subjects.contains('family');
    
    // Negative indicators (content to avoid)
    final hasInappropriateContent = subjects.contains('adult') ||
                                   subjects.contains('erotic') ||
                                   subjects.contains('romance') ||
                                   subjects.contains('horror') ||
                                   subjects.contains('war') ||
                                   subjects.contains('violence') ||
                                   title.contains('adult') ||
                                   title.contains('murder');
    
    // Must have children's content and not have inappropriate content
    return hasChildrenContent && !hasInappropriateContent;
  }

  /// Clean Project Gutenberg text for better reading experience
  String _cleanGutenbergText(String text) {
    // Remove Project Gutenberg header and footer
    final startMarkers = [
      '*** START OF',
      '*END*THE SMALL PRINT',
      'START OF THE PROJECT GUTENBERG',
    ];
    
    final endMarkers = [
      '*** END OF',
      'End of the Project Gutenberg',
      'End of Project Gutenberg',
    ];
    
    String cleanedText = text;
    
    // Find and remove header
    for (final marker in startMarkers) {
      final startIndex = cleanedText.indexOf(marker);
      if (startIndex != -1) {
        final endOfLine = cleanedText.indexOf('\n', startIndex);
        if (endOfLine != -1) {
          cleanedText = cleanedText.substring(endOfLine + 1);
          break;
        }
      }
    }
    
    // Find and remove footer
    for (final marker in endMarkers) {
      final endIndex = cleanedText.lastIndexOf(marker);
      if (endIndex != -1) {
        cleanedText = cleanedText.substring(0, endIndex);
        break;
      }
    }
    
    // Clean up formatting
    cleanedText = cleanedText
        .replaceAll(RegExp(r'\r\n'), '\n')      // Normalize line endings
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')  // Reduce excessive line breaks
        .replaceAll(RegExp(r' {2,}'), ' ')      // Reduce excessive spaces
        .trim();
    
    return cleanedText;
  }

  /// Combine chapters to reduce total count for younger readers
  List<Chapter> _combineChapters(List<Chapter> chapters, int maxChapters) {
    if (chapters.length <= maxChapters) return chapters;
    
    final combined = <Chapter>[];
    final chaptersPerGroup = (chapters.length / maxChapters).ceil();
    
    for (int i = 0; i < chapters.length; i += chaptersPerGroup) {
      final endIndex = (i + chaptersPerGroup < chapters.length) 
          ? i + chaptersPerGroup 
          : chapters.length;
      
      final groupChapters = chapters.sublist(i, endIndex);
      
      // Combine chapters in this group
      final combinedPages = <String>[];
      int totalWordCount = 0;
      int totalEstimatedMinutes = 0;
      
      for (final chapter in groupChapters) {
        combinedPages.addAll(chapter.pages);
        totalWordCount += chapter.wordCount;
        totalEstimatedMinutes += chapter.estimatedMinutes;
      }
      
      final firstChapter = groupChapters.first;
      final lastChapter = groupChapters.last;
      final title = groupChapters.length == 1 
          ? firstChapter.title
          : '${firstChapter.title} - ${lastChapter.title}';
      
      combined.add(Chapter(
        number: combined.length + 1,
        title: title,
        pages: combinedPages,
        wordCount: totalWordCount,
        estimatedMinutes: totalEstimatedMinutes,
      ));
    }
    
    return combined;
  }
}

/// Represents a book from Project Gutenberg
class GutenbergBook {
  final int id;
  final String title;
  final List<GutenbergAuthor> authors;
  final List<String> subjects;
  final List<String> bookshelves;
  final List<String> languages;
  final int downloadCount;
  final Map<String, String> formats;
  final String? mediaType;

  GutenbergBook({
    required this.id,
    required this.title,
    required this.authors,
    required this.subjects,
    required this.bookshelves,
    required this.languages,
    required this.downloadCount,
    required this.formats,
    this.mediaType,
  });

  factory GutenbergBook.fromJson(Map<String, dynamic> json) {
    return GutenbergBook(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      authors: (json['authors'] as List<dynamic>?)
          ?.map((a) => GutenbergAuthor.fromJson(a))
          .toList() ?? [],
      subjects: List<String>.from(json['subjects'] ?? []),
      bookshelves: List<String>.from(json['bookshelves'] ?? []),
      languages: List<String>.from(json['languages'] ?? []),
      downloadCount: json['download_count'] ?? 0,
      formats: Map<String, String>.from(json['formats'] ?? {}),
      mediaType: json['media_type'],
    );
  }

  /// Get the URL for the plain text version
  String? getTextUrl() {
    // Look for plain text format
    final textFormats = [
      'text/plain; charset=utf-8',
      'text/plain',
      'application/plain',
    ];
    
    for (final format in textFormats) {
      if (formats.containsKey(format)) {
        return formats[format];
      }
    }
    
    return null;
  }

  /// Get the main author name
  String get authorName {
    if (authors.isNotEmpty) {
      return authors.first.name;
    }
    return 'Unknown Author';
  }

  /// Check if book is in English
  bool get isEnglish => languages.contains('en');

  /// Get a formatted string of all subjects
  String get subjectsString => subjects.join(', ');

  @override
  String toString() {
    return 'GutenbergBook(id: $id, title: "$title", author: "$authorName")';
  }
}

/// Represents an author from Project Gutenberg
class GutenbergAuthor {
  final String name;
  final int? birthYear;
  final int? deathYear;

  GutenbergAuthor({
    required this.name,
    this.birthYear,
    this.deathYear,
  });

  factory GutenbergAuthor.fromJson(Map<String, dynamic> json) {
    return GutenbergAuthor(
      name: json['name'] ?? '',
      birthYear: json['birth_year'],
      deathYear: json['death_year'],
    );
  }

  @override
  String toString() => name;
}

/// Custom exception for Gutenberg service errors
class GutenbergException implements Exception {
  final String message;
  GutenbergException(this.message);
  
  @override
  String toString() => 'GutenbergException: $message';
}