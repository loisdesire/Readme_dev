// File: lib/screens/parent/reading_history_screen.dart
import 'package:flutter/material.dart';

class ReadingHistoryScreen extends StatelessWidget {
  const ReadingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final readingHistory = [
      {
        'title': 'The enchanted monkey',
        'time': '6 hours ago',
        'status': 'Ongoing',
        'emoji': '🐒✨',
        'progress': 0.7,
        'minutesRead': 25,
      },
      {
        'title': 'Adventures of koko',
        'time': '2 days ago',
        'status': 'Completed',
        'emoji': '🌟🐵',
        'progress': 1.0,
        'minutesRead': 45,
      },
      {
        'title': 'Space explorers',
        'time': '3 days ago',
        'status': 'Completed',
        'emoji': '🚀🤖',
        'progress': 1.0,
        'minutesRead': 30,
      },
      {
        'title': 'Magic forest',
        'time': '1 week ago',
        'status': 'Paused',
        'emoji': '🌲✨',
        'progress': 0.4,
        'minutesRead': 15,
      },
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Color(0xFF8E44AD)),
        ),
        title: const Text(
          'Reading History',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: readingHistory.length,
        itemBuilder: (context, index) {
          final book = readingHistory[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F9F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8E44AD).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Icon(
                            book['status'] == 'Completed'
                                ? Icons.check_circle
                                : book['status'] == 'Ongoing'
                                    ? Icons.menu_book
                                    : Icons.pause_circle,
                            size: 24,
                            color: book['status'] == 'Completed'
                                ? Colors.green
                                : book['status'] == 'Ongoing'
                                    ? Color(0xFF8E44AD)
                                    : Colors.orange,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              book['title'] as String,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              book['time'] as String,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: book['status'] == 'Completed' 
                              ? Colors.green.withOpacity(0.1) 
                              : const Color(0xFF8E44AD).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          book['status'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: book['status'] == 'Completed' 
                                ? Colors.green 
                                : const Color(0xFF8E44AD),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  // Progress bar
                  Row(
                    children: [
                      Text(
                        'Progress: ${((book['progress'] as double) * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${book['minutesRead']} min read',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: book['progress'] as double,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      book['status'] == 'Completed' ? Colors.green : const Color(0xFF8E44AD),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}