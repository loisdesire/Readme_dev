// File: lib/screens/book/reading_screen.dart
import 'package:flutter/material.dart';

class ReadingScreen extends StatefulWidget {
  final String bookId;
  final String title;
  final String author;

  const ReadingScreen({
    super.key,
    required this.bookId,
    required this.title,
    required this.author,
  });

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  double _fontSize = 18.0;
  bool _isPlaying = false;
  double _readingProgress = 0.15; // 15% read
  int _currentPage = 1;
  final int _totalPages = 24;

  // Sample book content
  final List<String> _bookPages = [
    "Once upon a time, in a magical jungle filled with colorful flowers and singing birds, there lived a curious little monkey named Koko.\n\nKoko had golden fur that sparkled in the sunlight and big, bright eyes that were always looking for adventure.\n\nOne sunny morning, Koko was swinging from branch to branch when he noticed something shiny hidden behind a waterfall.",
    
    "\"What could that be?\" Koko wondered aloud, his tail curling with excitement.\n\nHe swung closer to the waterfall, feeling the cool mist on his face. Behind the rushing water, he could see a cave with something glowing inside.\n\nKoko had never seen anything like it before. His heart raced with curiosity and a little bit of fear.",
    
    "Taking a deep breath, Koko carefully climbed behind the waterfall. The cave was warm and filled with a soft, golden light.\n\nIn the center of the cave sat an old, wise turtle with a shell that shimmered like a rainbow.\n\n\"Hello, young monkey,\" said the turtle with a kind smile. \"I've been waiting for someone brave enough to find me.\"",
  ];

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
    
    // Show TTS feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isPlaying ? 'Reading aloud... 🔊' : 'Paused ⏸️'),
        backgroundColor: const Color(0xFF8E44AD),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _nextPage() {
    if (_currentPage < _totalPages) {
      setState(() {
        _currentPage++;
        _readingProgress = _currentPage / _totalPages;
      });
    }
  }

  void _previousPage() {
    if (_currentPage > 1) {
      setState(() {
        _currentPage--;
        _readingProgress = _currentPage / _totalPages;
      });
    }
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildSettingsSheet(),
    );
  }

  Widget _buildSettingsSheet() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Reading Settings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8E44AD),
            ),
          ),
          const SizedBox(height: 20),
          
          // Font size slider
          Row(
            children: [
              const Text('Font Size:', style: TextStyle(fontSize: 16)),
              Expanded(
                child: Slider(
                  value: _fontSize,
                  min: 14.0,
                  max: 28.0,
                  divisions: 7,
                  activeColor: const Color(0xFF8E44AD),
                  onChanged: (value) {
                    setState(() {
                      _fontSize = value;
                    });
                  },
                ),
              ),
              Text('${_fontSize.round()}'),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // TTS Speed (placeholder)
          Row(
            children: [
              const Text('Reading Speed:', style: TextStyle(fontSize: 16)),
              Expanded(
                child: Slider(
                  value: 1.0,
                  min: 0.5,
                  max: 2.0,
                  activeColor: const Color(0xFF8E44AD),
                  onChanged: (value) {
                    // TODO: Implement TTS speed change
                  },
                ),
              ),
              const Text('1x'),
            ],
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pageContent = _currentPage <= _bookPages.length 
        ? _bookPages[_currentPage - 1]
        : "The End\n\nCongratulations! You've finished reading \"${widget.title}\"!\n\n🎉📚✨";

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF7), // Warm reading background
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Top row with back button and settings
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Color(0xFF8E44AD),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              widget.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'by ${widget.author}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _showSettings,
                        icon: const Icon(
                          Icons.settings,
                          color: Color(0xFF8E44AD),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 15),
                  
                  // Progress bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Page $_currentPage of $_totalPages',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            '${(_readingProgress * 100).round()}% complete',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _readingProgress,
                        backgroundColor: Colors.grey[300],
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8E44AD)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Reading content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // Text content
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 2,
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            pageContent,
                            style: TextStyle(
                              fontSize: _fontSize,
                              height: 1.8,
                              color: Colors.black87,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Navigation and controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Previous page
                        IconButton(
                          onPressed: _currentPage > 1 ? _previousPage : null,
                          icon: Icon(
                            Icons.chevron_left,
                            size: 32,
                            color: _currentPage > 1 
                                ? const Color(0xFF8E44AD)
                                : Colors.grey[400],
                          ),
                        ),
                        
                        // Play/Pause button
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF8E44AD),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF8E44AD).withOpacity(0.3),
                                spreadRadius: 2,
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: IconButton(
                            onPressed: _togglePlayPause,
                            icon: Icon(
                              _isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                        
                        // Next page
                        IconButton(
                          onPressed: _currentPage < _totalPages ? _nextPage : null,
                          icon: Icon(
                            Icons.chevron_right,
                            size: 32,
                            color: _currentPage < _totalPages 
                                ? const Color(0xFF8E44AD)
                                : Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}