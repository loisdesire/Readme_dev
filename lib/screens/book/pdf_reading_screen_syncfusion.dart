import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import '../../providers/book_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/logger.dart';

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
  int _lastReportedPage = 0;
  bool _hasReachedLastPage = false;
  DateTime? _lastPageChangeTime;
  int _pendingPage = 1;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    _sessionStart = DateTime.now();
    _lastPageChangeTime = DateTime.now();
    _initializeTts();
    
  appLog('Initializing Syncfusion PDF viewer', level: 'DEBUG');
  appLog('PDF URL: ${widget.pdfUrl}', level: 'DEBUG');
  }

  Future<void> _initializeTts() async {
    try {
      _flutterTts = FlutterTts();
      
      // Set up error handlers first
      _flutterTts.setErrorHandler((msg) {
        appLog('TTS Error Handler: $msg', level: 'ERROR');
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
        appLog('Language setting failed, trying default: $e', level: 'WARN');
      }
      
      await _flutterTts.setSpeechRate(0.8); // Slower rate for better clarity
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      
      // Mark as initialized - we'll handle errors in speak methods
      setState(() {
        _isTtsInitialized = true;
      });
      
  appLog('TTS initialized successfully', level: 'DEBUG');
      
    } catch (e) {
      appLog('TTS initialization error: $e', level: 'ERROR');
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
    final int newPage = details.newPageNumber;
    final DateTime now = DateTime.now();
    
    // Validate page number is within valid range
    if (newPage < 1 || newPage > _totalPages) {
      appLog('Invalid page number: $newPage (valid range: 1-$_totalPages), ignoring', level: 'WARN');
      return;
    }
    
    // Store pending page but don't commit immediately
    _pendingPage = newPage;
    
    // Only commit page change if:
    // 1. It's different from last reported page
    // 2. At least 800ms has passed since last change (debounce)
    // 3. OR it's the last page (always count last page)
    final timeSinceLastChange = _lastPageChangeTime != null 
        ? now.difference(_lastPageChangeTime!).inMilliseconds 
        : 1000;
    
    final bool shouldCommit = (newPage != _lastReportedPage) && 
                              (timeSinceLastChange > 800 || newPage == _totalPages);
    
    if (!shouldCommit) {
      appLog('⏭Debouncing page change: $newPage (waited ${timeSinceLastChange}ms, need 800ms)', level: 'DEBUG');
      
      // Schedule a delayed check to commit if user stays on this page
      Future.delayed(const Duration(milliseconds: 900), () {
        if (_pendingPage == newPage && newPage != _lastReportedPage && mounted) {
          appLog('Delayed commit: Page $newPage confirmed after delay', level: 'DEBUG');
          _commitPageChange(newPage);
        }
      });
      return;
    }
    
    _commitPageChange(newPage);
  }
  
  void _commitPageChange(int newPage) {
  appLog('Page change committed: $_lastReportedPage -> $newPage (Total: $_totalPages)', level: 'DEBUG');
    
    _lastReportedPage = newPage;
    _lastPageChangeTime = DateTime.now();
    
    setState(() {
      _currentPage = newPage;
    });
    
  appLog('Current page confirmed: $_currentPage/$_totalPages (${(_currentPage / _totalPages * 100).toStringAsFixed(1)}%)', level: 'DEBUG');
    
    // Update reading progress
    _updateReadingProgress();
    
    // Check if we've reached the last page
    if (_currentPage == _totalPages && _totalPages > 0 && !_hasReachedLastPage) {
      appLog('Last page reached! Marking book as completed...', level: 'INFO');
      _hasReachedLastPage = true;
      _markBookAsCompleted();
    }
    
    // Stop TTS when page changes
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
      appLog('TTS Error: $e', level: 'ERROR');
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
  appLog('Reading page text: ${cleanText.substring(0, cleanText.length > 100 ? 100 : cleanText.length)}...', level: 'DEBUG');
        
        // Read the actual page content
        await _flutterTts.speak(cleanText);
      } else {
        // Fallback if no text found
        await _flutterTts.speak('This page appears to contain images or non-readable content.');
      }
      
    } catch (e) {
  appLog('Error reading page content: $e', level: 'ERROR');
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
  appLog('Error extracting text: $e', level: 'ERROR');
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
  appLog('TTS speak selected error: $e', level: 'ERROR');
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
                appLog('PDF loaded successfully: ${details.document.pages.count} pages', level: 'DEBUG');
                setState(() {
                  _totalPages = details.document.pages.count;
                  _currentPage = 1; // Ensure we start at page 1
                  _lastReportedPage = 1;
                  _pendingPage = 1;
                  _hasReachedLastPage = false;
                  _lastPageChangeTime = DateTime.now();
                  _isLoading = false;
                  _error = null;
                });
                
                // Initial progress update
                _updateReadingProgress();
              },
              onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                appLog('PDF load failed: ${details.error}', level: 'ERROR');
                appLog('Description: ${details.description}', level: 'ERROR');
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
