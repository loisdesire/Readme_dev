import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../services/logger.dart';
import 'package:pdfx/pdfx.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import '../../providers/auth_provider.dart';
import '../../screens/child/library_screen.dart';
import '../../providers/book_provider.dart';

class ReadingScreen extends StatefulWidget {
  final String bookId; // REAL bookId
  final String pdfPath; // Can be local path or URL
  final String title;
  final String author;

  const ReadingScreen({
    super.key,
    required this.bookId,
    required this.pdfPath,
    required this.title,
    required this.author,
  });

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  List<dynamic> _availableVoices = [];
  String? _selectedVoice;
  late FlutterTts _flutterTts;
  bool _isPlaying = false;
  bool _isTtsInitialized = false;
  double _readingProgress = 0.0;
  int _currentPage = 0;
  int _totalPages = 1;
  DateTime? _sessionStart;
  // BookProvider reference
  BookProvider? _bookProvider;
  bool _isLoading = true;
  String? _error;
  double _ttsSpeed = 1.0;
  
  // PDF controller
  PdfController? _pdfController;
  
  // Helper method to fetch PDF from URL
  Future<Uint8List> _fetchPdfFromUrl(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Failed to load PDF from URL');
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeTts();
    _loadPdf();
    _sessionStart = DateTime.now();
    // Get BookProvider instance
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _bookProvider = Provider.of<BookProvider>(context, listen: false);
      });
    });
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _pdfController?.dispose();
    _updateReadingProgress();
    super.dispose();
  }

  Future<void> _initializeTts() async {
    try {
      _flutterTts = FlutterTts();
      
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(_ttsSpeed);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      try {
        final voices = await _flutterTts.getVoices;
        if (mounted) {
          setState(() {
            _availableVoices = voices ?? [];
            if (_availableVoices.isNotEmpty) {
              _selectedVoice = _availableVoices.first['name'] as String?;
            }
          });
        }
      } catch (e) {
  appLog('Error loading TTS voices: $e', level: 'ERROR');
      }
      
      _flutterTts.setCompletionHandler(() {
        if (mounted) {
          setState(() {
            _isPlaying = false;
          });
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

      if (mounted) {
        setState(() {
          _isTtsInitialized = true;
        });
      }
    } catch (e) {
  appLog('TTS initialization error: $e', level: 'ERROR');
    }
  }

  Future<void> _loadPdf() async {
    try {
      // Check if it's a URL or local path
      if (widget.pdfPath.startsWith('http')) {
        _pdfController = PdfController(
          document: PdfDocument.openData(
            _fetchPdfFromUrl(widget.pdfPath),
          ),
        );
      } else {
        _pdfController = PdfController(
          document: PdfDocument.openFile(widget.pdfPath),
        );
      }

      // Wait for document to load
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!mounted) return;

      if (_pdfController != null) {
        setState(() {
          _totalPages = _pdfController!.pagesCount ?? 1;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load PDF: $e';
          _isLoading = false;
        });
      }
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
        if (_selectedVoice != null) {
          await _flutterTts.setVoice(<String, String>{'name': _selectedVoice!});
        }
        await _flutterTts.speak("Reading page ${_currentPage + 1}");
        setState(() {
          _isPlaying = true;
        });
      }
    } catch (e) {
  appLog('TTS Error: $e', level: 'ERROR');
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    }
  }

  Future<void> _nextPage() async {
    await _flutterTts.stop();
    if (_currentPage < _totalPages - 1) {
      _pdfController?.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentPage++;
        _readingProgress = (_currentPage + 1) / _totalPages;
        _isPlaying = false;
      });
      await _updateReadingProgress();
    } else {
      await _completeBook();
    }
  }

  Future<void> _previousPage() async {
    await _flutterTts.stop();
    if (_currentPage > 0) {
      _pdfController?.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
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
      if (_bookProvider == null) return;
      if (authProvider.userId != null && _sessionStart != null) {
        final now = DateTime.now();
        int sessionDuration = now.difference(_sessionStart!).inSeconds;
        if (sessionDuration < 1) sessionDuration = 1; // Always at least 1 second
  appLog('[ReadingScreen] Writing reading session: userId=${authProvider.userId}, bookId=${widget.bookId}, sessionDurationSeconds=$sessionDuration, currentPage=${_currentPage + 1}, totalPages=$_totalPages', level: 'DEBUG');
        await _bookProvider!.updateReadingProgress(
          userId: authProvider.userId!,
          bookId: widget.bookId,
          currentPage: _currentPage + 1,
          totalPages: _totalPages,
          additionalReadingTime: (sessionDuration / 60).round(),
          isCompleted: (_currentPage + 1) >= _totalPages,
        );
        // Reset session start for next session
        _sessionStart = now;
      }
    } catch (e) {
  appLog('Error updating reading progress: $e', level: 'ERROR');
    }
  }

  Future<void> _completeBook() async {
    try {
      await _flutterTts.stop();
      await _updateReadingProgress();
      if (!mounted) return;

      _showCompletionDialog();
    } catch (e) {
  appLog('Error completing book: $e', level: 'ERROR');
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
                '📚',
                style: TextStyle(fontSize: 50),
              ),
              SizedBox(height: 10),
              Text(
                'Book Completed!',
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
                'Great job on finishing another book!',
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
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text(
                'Read Again',
                style: TextStyle(color: Colors.grey),
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
                Navigator.of(context).pop();
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LibraryScreen(),
                  ),
                );
              },
              child: const Text('Go to Library'),
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
      builder: (context) => Container(
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
            if (_availableVoices.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text('Voice:', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButton<String>(
                      value: _selectedVoice,
                      isExpanded: true,
                      items: _availableVoices.map<DropdownMenuItem<String>>((voice) {
                        return DropdownMenuItem<String>(
                          value: voice['name'] as String?,
                          child: Text(voice['name'] ?? 'Unknown'),
                        );
                      }).toList(),
                      onChanged: (value) async {
                        setState(() {
                          _selectedVoice = value;
                        });
                        if (_isTtsInitialized && _selectedVoice != null) {
                          await _flutterTts.setVoice(<String, String>{'name': _selectedVoice!});
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF8E44AD),
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF7),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x1A9E9E9E),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () async {
                          await _flutterTts.stop();
                          await _updateReadingProgress();
                          if (!context.mounted) return;
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
                      IconButton(
                        onPressed: _showSettings,
                        icon: const Icon(Icons.settings, color: Color(0xFF8E44AD)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                ],
              ),
            ),
            Expanded(
              child: _pdfController != null
                  ? PdfView(
                      controller: _pdfController!,
                      onPageChanged: (page) {
                        setState(() {
                          _currentPage = page - 1;
                          _readingProgress = page / _totalPages;
                        });
                      },
                    )
                  : const Center(child: Text('Loading PDF...')),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: _currentPage > 0 ? _previousPage : null,
                    icon: Icon(
                      Icons.chevron_left,
                      size: 32,
                      color: _currentPage > 0 ? const Color(0xFF8E44AD) : Colors.grey[400],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF8E44AD),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0x4D8E44AD),
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
            ),
          ],
        ),
      ),
    );
  }
}
