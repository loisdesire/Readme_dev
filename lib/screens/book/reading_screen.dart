import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../providers/book_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';

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
  late FlutterTts _flutterTts;
  double _fontSize = 18.0;
  bool _isPlaying = false;
  bool _isTtsInitialized = false;
  double _readingProgress = 0.0;
  int _currentPage = 0;
  int _totalPages = 1;
  List<String> _bookContent = [];
  DateTime? _sessionStart;
  bool _isLoading = true;
  String? _error;
  double _ttsSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    _initializeTts();
    _loadBookContent();
    _sessionStart = DateTime.now();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _updateReadingProgress();
    super.dispose();
  }

  Future<void> _initializeTts() async {
    try {
      _flutterTts = FlutterTts();
      
      // Configure TTS
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(_ttsSpeed);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      
      // Set up completion handler with auto-progression
      _flutterTts.setCompletionHandler(() async {
        if (mounted) {
          setState(() {
            _isPlaying = false;
          });
          
          try {
            // Add a slight delay for better UX
            await Future.delayed(const Duration(seconds: 1));
            
            if (_currentPage < _totalPages - 1) {
              // Auto progress to next page
              await _nextPage();
            } else {
              // On the last page, complete the book
              await _completeBook();
            }
          } catch (e) {
            print('Error during auto page progression: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error during auto page progression: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      });

      // Set up error handler
      _flutterTts.setErrorHandler((msg) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('TTS Error: $msg'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });

      setState(() {
        _isTtsInitialized = true;
      });
    } catch (e) {
      print('TTS initialization error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Text-to-speech not available on this device'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _loadBookContent() async {
    try {
      final bookProvider = Provider.of<BookProvider>(context, listen: false);
      final book = bookProvider.getBookById(widget.bookId);
      
      if (book != null && book.content.isNotEmpty) {
        setState(() {
          _bookContent = book.content;
          _totalPages = book.content.length;
          _isLoading = false;
        });
        
        // Load existing progress
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.userId != null) {
          final progress = bookProvider.getProgressForBook(widget.bookId);
          if (progress != null) {
            setState(() {
              _currentPage = progress.currentPage - 1; // Convert to 0-based index
              _readingProgress = progress.progressPercentage;
            });
          }
        }
      } else {
        // Fallback content if book not found
        setState(() {
          _bookContent = [
            "Welcome to ${widget.title}!\n\nThis is a sample story to demonstrate the reading experience.\n\nOnce upon a time, in a magical world filled with wonder and adventure...",
            "The story continues with exciting adventures and valuable lessons.\n\nOur heroes face challenges that teach them about courage, friendship, and perseverance.",
            "And they all lived happily ever after!\n\nThe End.\n\n🎉 Congratulations on completing this story! 📚✨"
          ];
          _totalPages = _bookContent.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load book content: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _togglePlayPause() async {
    if (!_isTtsInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Text-to-speech is not available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      if (_isPlaying) {
        await _flutterTts.stop();
        setState(() {
          _isPlaying = false;
        });
      } else {
        if (_currentPage < _bookContent.length) {
          await _flutterTts.speak(_bookContent[_currentPage]);
          setState(() {
            _isPlaying = true;
          });
        } else {
          // If we're beyond the content, show completion
          await _completeBook();
        }
      }
    } catch (e) {
      print('TTS Error in _togglePlayPause: $e');
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('TTS Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _nextPage() async {
    if (_currentPage < _totalPages - 1) {
      await _flutterTts.stop();
      setState(() {
        _currentPage++;
        _readingProgress = (_currentPage + 1) / _totalPages;
        _isPlaying = false;
      });
      await _updateReadingProgress();
    } else if (_currentPage == _totalPages - 1) {
      // Book completed!
      await _completeBook();
    }
  }

  Future<void> _previousPage() async {
    if (_currentPage > 0) {
      await _flutterTts.stop();
      setState(() {
        _currentPage--;
        _readingProgress = (_currentPage + 1) / _totalPages;
        _isPlaying = false;
      });
      await _updateReadingProgress();
    }
  }

  Future<void> _updateReadingProgress() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final bookProvider = Provider.of<BookProvider>(context, listen: false);
      
      if (authProvider.userId != null && _sessionStart != null) {
        final sessionDuration = DateTime.now().difference(_sessionStart!).inMinutes;
        
        await bookProvider.updateReadingProgress(
          userId: authProvider.userId!,
          bookId: widget.bookId,
          currentPage: _currentPage + 1, // Convert back to 1-based index
          totalPages: _totalPages,
          additionalReadingTime: sessionDuration,
        );
      }
    } catch (e) {
      print('Error updating reading progress: $e');
    }
  }

  Future<void> _completeBook() async {
    try {
      await _flutterTts.stop();
      await _updateReadingProgress();
      
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final bookProvider = Provider.of<BookProvider>(context, listen: false);
      
      if (authProvider.userId != null) {
        // Mark book as completed in the provider
        await bookProvider.updateReadingProgress(
          userId: authProvider.userId!,
          bookId: widget.bookId,
          currentPage: _totalPages,
          totalPages: _totalPages,
          additionalReadingTime: 0,
          isCompleted: true,
        );
        
        // Refresh user data to get updated stats
        await userProvider.loadUserData(authProvider.userId!);
        
        // Check for achievements (simplified to reduce loading time)
        try {
          // Simple achievement check without heavy backend calls
          if (userProvider.totalBooksRead == 1) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      Text('🏆', style: TextStyle(fontSize: 20)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Achievement Unlocked: First Book Complete!',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Color(0xFF8E44AD),
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
        } catch (achievementError) {
          print('Error checking achievements: $achievementError');
          // Don't block completion if achievements fail
        }
      }

      // Show completion dialog
      if (mounted) {
        _showCompletionDialog();
      }
    } catch (e) {
      print('Error completing book: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing book: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Column(
            children: [
              Text(
                '🎉',
                style: TextStyle(fontSize: 50),
              ),
              SizedBox(height: 10),
              Text(
                'Congratulations!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8E44AD),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'You\'ve completed "${widget.title}"!',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              const Text(
                'Great job on finishing another book! 📚✨',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back to previous screen
              },
              child: const Text(
                'Back to Library',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8E44AD),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back to previous screen
              },
              child: const Text('Continue Reading'),
            ),
          ],
        );
      },
    );
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
          
          // TTS Speed
          Row(
            children: [
              const Text('Reading Speed:', style: TextStyle(fontSize: 16)),
              Expanded(
                child: Slider(
                  value: _ttsSpeed,
                  min: 0.5,
                  max: 2.0,
                  divisions: 6,
                  activeColor: const Color(0xFF8E44AD),
                  onChanged: (value) async {
                    setState(() {
                      _ttsSpeed = value;
                    });
                    if (_isTtsInitialized) {
                      await _flutterTts.setSpeechRate(_ttsSpeed);
                    }
                  },
                ),
              ),
              Text('${_ttsSpeed.toStringAsFixed(1)}x'),
            ],
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFFFFDF7),
        body: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF8E44AD),
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFFFDF7),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '😔',
                  style: TextStyle(fontSize: 60),
                ),
                const SizedBox(height: 20),
                Text(
                  'Error loading book',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final pageContent = _currentPage < _bookContent.length 
        ? _bookContent[_currentPage]
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
                        onPressed: () async {
                          await _flutterTts.stop();
                          await _updateReadingProgress();
                          Navigator.pop(context);
                        },
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
                            'Page ${_currentPage + 1} of $_totalPages',
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
                          onPressed: _currentPage > 0 ? _previousPage : null,
                          icon: Icon(
                            Icons.chevron_left,
                            size: 32,
                            color: _currentPage > 0 
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
                        
                        // Next page or Complete button
                        _currentPage < _totalPages - 1
                            ? IconButton(
                                onPressed: _nextPage,
                                icon: const Icon(
                                  Icons.chevron_right,
                                  size: 32,
                                  color: Color(0xFF8E44AD),
                                ),
                              )
                            : ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                onPressed: _completeBook,
                                child: const Text('Complete'),
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
