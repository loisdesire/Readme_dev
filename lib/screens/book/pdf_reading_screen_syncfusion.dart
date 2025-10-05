import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import '../../providers/book_provider.dart';
import '../../providers/auth_provider.dart';

class PdfReadingScreenSyncfusion extends StatefulWidget {
  final String bookId;
  final String title;
  final String author;
  final String pdfUrl;

  const PdfReadingScreenSyncfusion({
    super.key,
    required this.bookId,
    required this.title,
    required this.author,
    required this.pdfUrl,
  });

  @override
  State<PdfReadingScreenSyncfusion> createState() => _PdfReadingScreenSyncfusionState();
}

class _PdfReadingScreenSyncfusionState extends State<PdfReadingScreenSyncfusion> {
  late FlutterTts _flutterTts;
  bool _isPlaying = false;
  bool _isTtsInitialized = false;
  late PdfViewerController _pdfController;
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoading = true;
  String? _error;
  DateTime? _sessionStart;
  PdfDocument? _pdfDocument;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    _sessionStart = DateTime.now();
    _initializeTts();
    
    print('Initializing Syncfusion PDF viewer');
    print('PDF URL: ${widget.pdfUrl}');
  }

  Future<void> _initializeTts() async {
    try {
      _flutterTts = FlutterTts();
      
      // Set up error handlers first
      _flutterTts.setErrorHandler((msg) {
        print('TTS Error Handler: $msg');
        if (mounted) {
          setState(() {
            _isPlaying = false;
          });
        }
      });
      
      // Set up completion handler
      _flutterTts.setCompletionHandler(() {
        if (mounted) {
          setState(() {
            _isPlaying = false;
          });
        }
      });
      
      // Initialize TTS settings with error handling
      try {
        await _flutterTts.setLanguage("en-US");
      } catch (e) {
        print('Language setting failed, trying default: $e');
      }
      
      await _flutterTts.setSpeechRate(0.8); // Slower rate for better clarity
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      
      // Mark as initialized - we'll handle errors in speak methods
      setState(() {
        _isTtsInitialized = true;
      });
      
      print('TTS initialized successfully');
      
    } catch (e) {
      print('TTS initialization error: $e');
      // Still mark as initialized so button works
      setState(() {
        _isTtsInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    if (_isTtsInitialized) {
      _flutterTts.stop();
    }
    _pdfController.dispose();
    _pdfDocument?.dispose();
    _updateReadingProgress();
    super.dispose();
  }

  void _onPageChanged(PdfPageChangedDetails details) {
    setState(() {
      _currentPage = details.newPageNumber;
    });
    
    print('Page changed: $_currentPage/$_totalPages (${(_currentPage / _totalPages * 100).toStringAsFixed(1)}%)');
    
    _updateReadingProgress();
    
    // Check if book is completed (reached last page)
    if (_currentPage >= _totalPages && _totalPages > 0) {
      print('Book completed! Marking as done...');
      _markBookAsCompleted();
    }
    
    if (_isPlaying) {
      _flutterTts.stop();
      setState(() {
        _isPlaying = false;
      });
    }
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_isPlaying) {
        await _flutterTts.stop();
        setState(() {
          _isPlaying = false;
        });
      } else {
        // Attempt to get text from the current page
        await _readCurrentPageContent();
      }
    } catch (e) {
      print('TTS Error: $e');
      setState(() {
        _isPlaying = false;
      });
      
      // Show user-friendly error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Text-to-speech is not available on this device'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _readCurrentPageContent() async {
    try {
      // Stop any current speech first
      await _flutterTts.stop();
      
      setState(() {
        _isPlaying = true;
      });
      
      // Extract text from current page
      String pageText = await _extractTextFromCurrentPage();
      
      if (pageText.isNotEmpty) {
        // Clean up the text for better TTS
        String cleanText = pageText.replaceAll(RegExp(r'\s+'), ' ').trim();
        print('Reading page text: ${cleanText.substring(0, cleanText.length > 100 ? 100 : cleanText.length)}...');
        
        // Read the actual page content
        await _flutterTts.speak(cleanText);
      } else {
        // Fallback if no text found
        await _flutterTts.speak('This page appears to contain images or non-readable content.');
      }
      
    } catch (e) {
      print('Error reading page content: $e');
      setState(() {
        _isPlaying = false;
      });
      await _flutterTts.speak('Unable to read this page content.');
    }
  }

  Future<String> _extractTextFromCurrentPage() async {
    try {
      // Load PDF document from URL
      final response = await http.get(Uri.parse(widget.pdfUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to load PDF');
      }
      
      // Load PDF document
      _pdfDocument = PdfDocument(inputBytes: response.bodyBytes);
      
      if (_currentPage <= _pdfDocument!.pages.count) {
        // Extract text from current page
        String pageText = PdfTextExtractor(_pdfDocument!).extractText(startPageIndex: _currentPage - 1, endPageIndex: _currentPage - 1);
        
        return pageText;
      }
      
      return '';
    } catch (e) {
      print('Error extracting text: $e');
      return '';
    }
  }

  Future<void> _speakSelectedText(String selectedText) async {
    if (!_isTtsInitialized) return;
    
    try {
      // Stop current speech if playing
      await _flutterTts.stop();
      
      // Clean the text
      String cleanText = selectedText.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (cleanText.isEmpty) return;
      
      setState(() {
        _isPlaying = true;
      });
      
      // Speak the selected text with error handling
      final result = await _flutterTts.speak(cleanText);
      if (result == 0) {
        // Speech failed
        setState(() {
          _isPlaying = false;
        });
      }
      
    } catch (e) {
      print('TTS speak selected error: $e');
      setState(() {
        _isPlaying = false;
      });
    }
  }

  Future<void> _updateReadingProgress() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bookProvider = Provider.of<BookProvider>(context, listen: false);
    if (authProvider.userId != null && _sessionStart != null) {
      final sessionDuration = DateTime.now().difference(_sessionStart!).inMinutes;
      // Update progress even if duration is 0 to track page changes
      await bookProvider.updateReadingProgress(
        userId: authProvider.userId!,
        bookId: widget.bookId,
        currentPage: _currentPage,
        totalPages: _totalPages,
        additionalReadingTime: sessionDuration > 0 ? sessionDuration : 0,
      );
      if (sessionDuration > 0) {
        _sessionStart = DateTime.now();
      }
    }
  }

  Future<void> _markBookAsCompleted() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bookProvider = Provider.of<BookProvider>(context, listen: false);
    if (authProvider.userId != null) {
      final sessionDuration = DateTime.now().difference(_sessionStart!).inMinutes;
      await bookProvider.updateReadingProgress(
        userId: authProvider.userId!,
        bookId: widget.bookId,
        currentPage: _totalPages,
        totalPages: _totalPages,
        additionalReadingTime: sessionDuration > 0 ? sessionDuration : 0,
        isCompleted: true, // Explicitly mark as completed
      );
      _sessionStart = DateTime.now();
      
      // Show completion message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.celebration, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Congratulations! You completed "${widget.title}"!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 18),
            ),
            if (_totalPages > 0)
              Text(
                'Page $_currentPage of $_totalPages',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isPlaying ? Icons.stop : Icons.volume_up),
            onPressed: _togglePlayPause,
            tooltip: 'Text-to-Speech',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading)
            const LinearProgressIndicator()
          else if (_error != null)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.red[100],
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: SfPdfViewer.network(
              widget.pdfUrl,
              controller: _pdfController,
              onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                print('PDF loaded successfully: ${details.document.pages.count} pages');
                setState(() {
                  _totalPages = details.document.pages.count;
                  _isLoading = false;
                  _error = null;
                });
              },
              onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                print('PDF load failed: ${details.error}');
                print('Description: ${details.description}');
                setState(() {
                  _error = 'Failed to load PDF: ${details.description}';
                  _isLoading = false;
                });
              },
              onPageChanged: _onPageChanged,
              onTextSelectionChanged: (PdfTextSelectionChangedDetails details) {
                if (details.selectedText != null && details.selectedText!.isNotEmpty) {
                  _speakSelectedText(details.selectedText!);
                }
              },
              enableDoubleTapZooming: true,
              enableTextSelection: true,
              canShowScrollHead: true,
              canShowScrollStatus: true,
              canShowPaginationDialog: true,
            ),
          ),
        ],
      ),
    );
  }
}
