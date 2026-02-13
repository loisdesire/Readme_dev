// File: lib/screens/parent/reading_history_screen.dart
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/common/app_card.dart';

class ReadingHistoryScreen extends StatelessWidget {
  final String childId;

  const ReadingHistoryScreen({
    super.key,
    required this.childId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryPurple),
        ),
        title: Text(
          'Reading History',
          style: AppTheme.heading.copyWith(fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchReadingHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final readingHistory = snapshot.data ?? [];
          if (readingHistory.isEmpty) {
            return Center(
              child: Text(
                'No reading history yet',
                style: AppTheme.bodyMedium,
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: readingHistory.length,
            itemBuilder: (context, index) {
              final book = readingHistory[index];
              final isCompleted = book['isCompleted'] ?? false;
              final status = isCompleted ? 'Completed' : 'Ongoing';
              return Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryPurpleOpaque10,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Icon(
                                status == 'Completed'
                                    ? Icons.check_circle
                                    : Icons.menu_book,
                                size: 24,
                                color: status == 'Completed'
                                    ? AppTheme.successGreen
                                    : AppTheme.primaryPurple,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  book['bookTitle'] ?? 'Unknown',
                                  style: AppTheme.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  book['author'] ?? 'Unknown Author',
                                  style: AppTheme.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatTimestamp(book['lastReadAt']),
                                  style: AppTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: status == 'Completed'
                                  ? AppTheme.greenOpaque10
                                  : AppTheme.primaryPurpleOpaque10,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: status == 'Completed'
                                    ? AppTheme.successGreen
                                    : AppTheme.primaryPurple,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      // Progress bar and stats
                      Row(
                        children: [
                          Text(
                            'Progress: ${((book['progressPercentage'] ?? 0.0) * 100).round()}%',
                            style: AppTheme.bodySmall,
                          ),
                          const Spacer(),
                          if (book['totalPages'] != null &&
                              book['totalPages'] > 0)
                            Text(
                              'Page ${book['currentPage']}/${book['totalPages']}',
                              style: AppTheme.bodySmall,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (book['readingTimeMinutes'] != null &&
                          book['readingTimeMinutes'] > 0)
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.45),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${book['readingTimeMinutes']} min read',
                              style: AppTheme.bodySmall,
                            ),
                          ],
                        ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value:
                            (book['progressPercentage'] ?? 0.0).clamp(0.0, 1.0),
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          status == 'Completed'
                              ? AppTheme.successGreen
                              : AppTheme.primaryPurple,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Fetch reading history from reading_progress collection
  Future<List<Map<String, dynamic>>> _fetchReadingHistory() async {
    try {
      // Fetch all reading progress for the child
      final progressQuery = await FirebaseFirestore.instance
          .collection('reading_progress')
          .where('userId', isEqualTo: childId)
          .orderBy('lastReadAt', descending: true)
          .get();

      if (progressQuery.docs.isEmpty) {
        return [];
      }

      // Get all unique book IDs
      final bookIds = progressQuery.docs
          .map((doc) => doc.data()['bookId'] as String?)
          .where((id) => id != null)
          .toSet()
          .toList();

      if (bookIds.isEmpty) {
        return [];
      }

      // Fetch book details for all books
      // Firestore 'in' queries are limited to 10 items, so we need to batch
      final List<Map<String, dynamic>> allBooks = [];

      for (int i = 0; i < bookIds.length; i += 10) {
        final batch = bookIds.skip(i).take(10).toList();
        final booksQuery = await FirebaseFirestore.instance
            .collection('books')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        for (final bookDoc in booksQuery.docs) {
          allBooks.add({
            'id': bookDoc.id,
            ...bookDoc.data(),
          });
        }
      }

      // Create a map of bookId to book data
      final Map<String, Map<String, dynamic>> bookMap = {};
      for (final book in allBooks) {
        bookMap[book['id']] = book;
      }

      // Combine progress with book data
      final List<Map<String, dynamic>> history = [];

      for (final progressDoc in progressQuery.docs) {
        final progressData = progressDoc.data();
        final bookId = progressData['bookId'] as String?;

        if (bookId != null && bookMap.containsKey(bookId)) {
          final book = bookMap[bookId]!;
          history.add({
            'bookId': bookId,
            'bookTitle': book['title'] ?? 'Unknown Book',
            'author': book['author'] ?? 'Unknown Author',
            'progressPercentage':
                (progressData['progressPercentage'] as num?)?.toDouble() ?? 0.0,
            'isCompleted': progressData['isCompleted'] ?? false,
            'lastReadAt': progressData['lastReadAt'],
            'readingTimeMinutes': progressData['readingTimeMinutes'] ?? 0,
            'currentPage': progressData['currentPage'] ?? 0,
            'totalPages': progressData['totalPages'] ?? 0,
          });
        }
      }

      return history;
    } catch (e) {
      debugPrint('Error fetching reading history: $e');
      return [];
    }
  }

  // Format Firestore Timestamp or DateTime to a readable string
  String _formatTimestamp(dynamic ts) {
    if (ts == null) return '';
    DateTime dt;
    if (ts is Timestamp) {
      dt = ts.toDate();
    } else if (ts is DateTime) {
      dt = ts;
    } else {
      return ts.toString();
    }
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays > 0) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} min ago';
    } else {
      return 'Just now';
    }
  }
}
