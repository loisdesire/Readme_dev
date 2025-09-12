import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../providers/book_provider_gutenberg.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/chapter.dart';
import '../../screens/child/library_screen.dart';

class ReadingScreenEnhanced extends StatefulWidget {
  final String bookId;
  final String title;
  final String author;

  const ReadingScreenEnhanced({
    super.key,
    required this.bookId,
    required this.title,
    required this.author,
  });

  @override
  State<ReadingScreenEnhanced> createState() => _ReadingScreenEnhancedState();
}

class _ReadingScreenEnhancedState extends State<ReadingScreenEnhanced> {
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
  
  // NEW: Chapter-based navigation
  int _currentChapter = 1;
  int _totalChapters = 1;
  int _currentPageInChapter = 0;
  List<Chapter> _chapters = [];
  bool _isFullLengthBook = false;
  
  // NEW: Navigation and bookmarks
  final List<Map<String, dynamic>> _bookmarks = [];
  bool _showTableOfContents = false;

  @override
  void initState() {
    super.initState();
    _initializeTts();
    _loadBookContent();
    _sessionStart = DateTime.now();
  }

  late BookProviderGutenberg _bookProvider;
  late AuthProvider _authProvider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bookProvider = Provider.of<BookProviderGutenberg>(context, listen: false);
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
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
      
      // Set up completion handler
      _flutterTts.setCompletionHandler(() async {
        if (mounted) {
          setState(() {
            _isPlaying = false;
          });
          
          try {
            await Future.delayed(const Duration(seconds: 1));
            
            if (_currentPage < _totalPages - 1) {
              await _nextPage();
            } else {
              await _completeBook();
            }
          } catch (e) {
            print('Error during auto page progression: $e');
          }
        }
      });

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
    }
  }

  Future<void> _loadBookContent() async {
    try {
      final book = _bookProvider.getBookById(widget.bookId);
      
      if (book != null) {
        setState(() {
          _isFullLengthBook = book.isFullLengthBook;
          
          if (_isFullLengthBook && book.chapters != null) {
            // Handle full-length book with chapters
            _chapters = book.chapters!;
            _totalChapters = _chapters.length;
            _bookContent = book.getContentForReading();
            _totalPages = _bookContent.length;
          } else {
            // Handle short story
            _bookContent = book.content;
            _totalPages = book.content.length;
            _totalChapters = 1;
          }
          
          _isLoading = false;
        });
        
        // Load existing progress
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.userId != null) {
          final progress = _bookProvider.getProgressForBook(widget.bookId);
          if (progress != null) {
            setState(() {
              _currentPage = progress.currentPage - 1;
              _readingProgress = progress.progressPercentage;
              
              if (_isFullLengthBook) {
                _currentChapter = progress.currentChapter ?? 1;
                _currentPageInChapter = progress.currentPageInChapter ?? 0;
              }
            });
          }
        }
      } else {
        // Fallback content
        setState(() {
          _bookContent = [
            "Welcome to ${widget.title}!\n\nThis story is currently loading. Please try again in a moment.",
          ];
          _totalPages = 1;
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
        }
      }
    } catch (e) {
      print('TTS Error: $e');
    }
  }

  Future<void> _nextPage() async {
    if (_currentPage < _totalPages - 1) {
      await _flutterTts.stop();
      setState(() {
        _currentPage++;
        _readingProgress = (_currentPage + 1) / _totalPages;
        _isPlaying = false;
        
        // Update chapter progress for full-length books
        if (_isFullLengthBook) {
          _updateChapterProgress();
        }
      });
      await _updateReadingProgress();
    } else {
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
        
        // Update chapter progress for full-length books
        if (_isFullLengthBook) {
          _updateChapterProgress();
        }
      });
      await _updateReadingProgress();
    }
  }

  // NEW: Chapter navigation methods
  void _updateChapterProgress() {
    if (!_isFullLengthBook || _chapters.isEmpty) return;
    
    int cumulativePages = 0;
    for (int i = 0; i < _chapters.length; i++) {
      if (_currentPage < cumulativePages + _chapters[i].totalPages) {
        _currentChapter = i + 1;
        _currentPageInChapter = _currentPage - cumulativePages;
        break;
      }
      cumulativePages += _chapters[i].totalPages;
    }
  }

  Future<void> _goToChapter(int chapterNumber) async {
    if (!_isFullLengthBook || chapterNumber < 1 || chapterNumber > _totalChapters) return;
    
    await _flutterTts.stop();
    
    // Calculate the starting page for this chapter
    int startPage = 0;
    for (int i = 0; i < chapterNumber - 1; i++) {
      startPage += _chapters[i].totalPages;
    }
    
    setState(() {
      _currentChapter = chapterNumber;
      _currentPage = startPage;
      _currentPageInChapter = 0;
      _readingProgress = (_currentPage + 1) / _totalPages;
      _isPlaying = false;
      _showTableOfContents = false;
    });
    
    await _updateReadingProgress();
  }

  void _addBookmark() {
    final bookmark = {
      'page': _currentPage,
      'chapter': _currentChapter,
      'pageInChapter': _currentPageInChapter,
      'timestamp': DateTime.now(),
      'preview': _bookContent[_currentPage].substring(0, 50) + '...',
    };
    
    setState(() {
      _bookmarks.add(bookmark);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bookmark added!'),
        backgroundColor: Color(0xFF8E44AD),
      ),
    );
  }

  Future<void> _updateReadingProgress() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      if (authProvider.userId != null && _sessionStart != null) {
        final sessionDuration = DateTime.now().difference(_sessionStart!).inMinutes;
        
        await _bookProvider.updateReadingProgress(
          userId: authProvider.userId!,
          bookId: widget.bookId,
          currentPage: _currentPage + 1,
          totalPages: _totalPages,
          additionalReadingTime: sessionDuration,
          currentChapter: _isFullLengthBook ? _currentChapter : null,
          totalChapters: _isFullLengthBook ? _totalChapters : null,
          currentPageInChapter: _isFullLengthBook ? _currentPageInChapter : null,
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
      
      if (authProvider.userId != null) {
        await _bookProvider.updateReadingProgress(
          userId: authProvider.userId!,
          bookId: widget.bookId,
          currentPage: _totalPages,
          totalPages: _totalPages,
          additionalReadingTime: 0,
          isCompleted: true,
          currentChapter: _totalChapters,
          totalChapters: _totalChapters,
        );
      }

      if (mounted) {
        _showCompletionDialog();
      }
    } catch (e) {
      print('Error completing book: $e');
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
              Text('🎉', style: TextStyle(fontSize: 50)),
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
              if (_isFullLengthBook)
                Text(
                  'Amazing! You read all $_totalChapters chapters! 📚✨',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                )
              else
                const Text(
                  'Great job on finishing another story! 📚✨',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text('Read Again', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8E44AD),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LibraryScreen()),
                );
              },
              child: const Text('Go to Library'),
            ),
          ],
        );
      },
    );
  }

  void _showTableOfContents() {
    setState(() {
      _showTableOfContents = true;
    });
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

  Widget _buildTableOfContents() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Table of Contents',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8E44AD),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showTableOfContents = false;
                    });
                  },
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          
          // Chapter list
          Expanded(
            child: ListView.builder(
              itemCount: _chapters.length,
              itemBuilder: (context, index) {
                final chapter = _chapters[index];
                final isCurrentChapter = (index + 1) == _currentChapter;
                
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isCurrentChapter 
                        ? const Color(0xFF8E44AD) 
                        : Colors.grey[300],
                    child: Text(
                      '${chapter.number}',
                      style: TextStyle(
                        color: isCurrentChapter ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    chapter.title,
                    style: TextStyle(
                      fontWeight: isCurrentChapter ? FontWeight.bold : FontWeight.normal,
                      color: isCurrentChapter ? const Color(0xFF8E44AD) : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    '${chapter.totalPages} pages • ${chapter.estimatedMinutes} min',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () => _goToChapter(index + 1),
                );
              },
            ),
          ),
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
          child: CircularProgressIndicator(color: Color(0xFF8E44AD)),
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
                const Text('😔', style: TextStyle(fontSize: 60)),
                const SizedBox(height: 20),
                const Text(
                  'Error loading book',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
      backgroundColor: const Color(0xFFFFFDF7),
      body: SafeArea(
        child: _showTableOfContents 
            ? _buildTableOfContents()
            : Column(
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
                        // Top row with navigation
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: () async {
                                await _flutterTts.stop();
                                await _updateReadingProgress();
                                Navigator.pop(context);
                              },
                              icon: const Icon(Icons.arrow_back, color: Color(0xFF8E44AD)),
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
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            
                            Row(
                              children: [
                                if (_isFullLengthBook)
                                  IconButton(
                                    onPressed: _showTableOfContents,
                                    icon: const Icon(Icons.list, color: Color(0xFF8E44AD)),
                                  ),
                                IconButton(
                                  onPressed: _addBookmark,
                                  icon: const Icon(Icons.bookmark_add, color: Color(0xFF8E44AD)),
                                ),
                                IconButton(
                                  onPressed: _showSettings,
                                  icon: const Icon(Icons.settings, color: Color(0xFF8E44AD)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 15),
                        
                        // Progress information
                        if (_isFullLengthBook) ...[
                          // Chapter progress
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Chapter $_currentChapter of $_totalChapters',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              Text(
                                'Page ${_currentPageInChapter + 1} of ${_chapters.isNotEmpty ? _chapters[_currentChapter - 1].totalPages : 1}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        
                        // Overall progress
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Page ${_currentPage + 1} of $_totalPages',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            Text(
                              '${(_readingProgress * 100).round()}% complete',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
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
                          
                          // Navigation controls
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