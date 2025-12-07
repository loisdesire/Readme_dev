import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../../providers/book_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/logger.dart';
import '../../theme/app_theme.dart';
import 'book_quiz_screen.dart';

class PdfReadingScreenSyncfusion extends StatefulWidget {
  final String bookId;
  final String title;
  final String author;
  final String pdfUrl;
  final int? initialPage; // Optional starting page for continuing reading

  const PdfReadingScreenSyncfusion({
    super.key,
    required this.bookId,
    required this.title,
    required this.author,
    required this.pdfUrl,
    this.initialPage,
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
  BookProvider? _cachedBookProvider;
  int _lastReportedPage = 0;
  bool _hasReachedLastPage = false;
  bool _isInitialJump = false; // Flag to prevent completion during resume
  bool _wasAlreadyCompleted = false; // Track if book was completed before opening
  // _lastPageChangeTime removed: switching to timer-based debounce
  int _pendingPage = 1;
  Timer? _pageChangeTimer;
  int _accumulatedDwellMs = 0;
  static const int _samplingIntervalMs = 100;
  static const int _normalThresholdMs = 200; // 0.2s dwell - instant page counting
  static const int _lastPageThresholdMs = 200; // 0.2s for last page - instant completion

  // PDF caching
  File? _cachedPdfFile;
  bool _isCacheLoading = true;

  // Achievement popups are now handled by global AchievementListener

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    _sessionStart = DateTime.now();
    _initializeTts();
    _checkPdfCache();

  appLog('Initializing Syncfusion PDF viewer', level: 'DEBUG');
  appLog('PDF URL: ${widget.pdfUrl}', level: 'DEBUG');
  }

  // Check if PDF is cached, download if not
  Future<void> _checkPdfCache() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final fileName = _getCacheFileName(widget.pdfUrl);
      final cachedFile = File('${cacheDir.path}/$fileName');

      if (await cachedFile.exists()) {
        appLog('[PDF_CACHE] Using cached PDF: ${cachedFile.path}', level: 'INFO');
        setState(() {
          _cachedPdfFile = cachedFile;
          _isCacheLoading = false;
        });
      } else {
        appLog('[PDF_CACHE] No cache found, downloading PDF...', level: 'INFO');
        await _downloadAndCachePdf(cachedFile);
      }
    } catch (e) {
      appLog('[PDF_CACHE] Cache check failed: $e', level: 'ERROR');
      setState(() {
        _isCacheLoading = false;
      });
    }
  }

  // Generate cache file name from URL using hash
  String _getCacheFileName(String url) {
    final bytes = utf8.encode(url);
    final digest = sha256.convert(bytes);
    return 'pdf_$digest.pdf';
  }

  // Download PDF and save to cache
  Future<void> _downloadAndCachePdf(File cacheFile) async {
    try {
      final response = await http.get(Uri.parse(widget.pdfUrl));
      if (response.statusCode == 200) {
        await cacheFile.writeAsBytes(response.bodyBytes);
        appLog('[PDF_CACHE] PDF downloaded and cached: ${cacheFile.path}', level: 'INFO');
        setState(() {
          _cachedPdfFile = cacheFile;
          _isCacheLoading = false;
        });
      } else {
        throw Exception('Failed to download PDF: ${response.statusCode}');
      }
    } catch (e) {
      appLog('[PDF_CACHE] Download failed: $e', level: 'ERROR');
      setState(() {
        _isCacheLoading = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cache the BookProvider instance so we don't need to use context in dispose
    try {
      _cachedBookProvider = Provider.of<BookProvider>(context, listen: false);
    } catch (_) {
      // Provider might not be available; leave cached as null and fallback to
      // FirebaseAuth + temporary BookProvider in update methods.
      _cachedBookProvider = null;
    }
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
    _pageChangeTimer?.cancel();

    // CRITICAL: Only update progress on dispose if book is NOT completed
    // Otherwise we'll overwrite the completion status with incomplete progress
    if (!_hasReachedLastPage) {
      _updateReadingProgress();
    } else {
      appLog('[DISPOSE] Book already completed, skipping progress update to preserve completion status', level: 'INFO');
    }

    super.dispose();
  }

  void _onPageChanged(PdfPageChangedDetails details) {
    final int newPage = details.newPageNumber;

    appLog('[PAGE_CHANGE] onPageChanged fired: newPage=$newPage, totalPages=$_totalPages', level: 'INFO');

    // Validate page number is within valid range
    if (newPage < 1 || newPage > _totalPages) {
      appLog('[PAGE_CHANGE] Invalid page number: $newPage (valid range: 1-$_totalPages), ignoring', level: 'WARN');
      return;
    }

    // DWELL TIME MODE: Must stay on page for threshold time before counting
    // This prevents rapid swiping to complete books without actually reading

    // Store pending page but don't commit immediately
    _pendingPage = newPage;
    // Cancel any existing timer and reset accumulation
    _pageChangeTimer?.cancel();
    _accumulatedDwellMs = 0;

    appLog('[PAGE_CHANGE] Starting dwell timer for page $newPage', level: 'DEBUG');

    // Determine threshold: last page gets special handling
    final bool isLastPage = newPage == _totalPages;
    final bool isSecondToLast = _totalPages > 1 && newPage == _totalPages - 1;
    final bool isNearEnd = isLastPage || isSecondToLast;
    final int thresholdMs = isNearEnd ? _lastPageThresholdMs : _normalThresholdMs;

    appLog('[PAGE_CHANGE] Page $newPage - isLastPage=$isLastPage, isSecondToLast=$isSecondToLast, threshold=${thresholdMs}ms', level: 'INFO');

    _pageChangeTimer = Timer.periodic(const Duration(milliseconds: _samplingIntervalMs), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final int controllerPage = _pdfController.pageNumber.toInt();
      if (controllerPage == _pendingPage) {
        _accumulatedDwellMs += _samplingIntervalMs;
        if (_accumulatedDwellMs >= thresholdMs) {
          t.cancel();
          _pageChangeTimer = null;
          if (_pendingPage != _lastReportedPage) {
            appLog('[PAGE_CHANGE] Dwell threshold met (${_accumulatedDwellMs}ms), committing page $_pendingPage', level: 'INFO');
            _commitPageChange(_pendingPage);
          }
        }
      } else {
        // Viewer moved to another page: reset accumulation and update pending
        appLog('[PAGE_CHANGE] User scrolled to different page (controller=$controllerPage, pending=$_pendingPage), resetting timer', level: 'DEBUG');
        _pendingPage = controllerPage;
        _accumulatedDwellMs = 0;
      }
    });
  }
  
  void _commitPageChange(int newPage) {
    _lastReportedPage = newPage;

    setState(() {
      _currentPage = newPage;
    });

    appLog('[COMMIT] Committed page change to $_currentPage of $_totalPages', level: 'INFO');

    // Skip completion detection during initial jump to saved page
    if (_isInitialJump) {
      appLog('[COMMIT] Skipping completion check during initial jump', level: 'DEBUG');
      _updateReadingProgress();
      return;
    }

    // Check if we've reached the last or second-to-last page FIRST
    // On mobile, PDF viewer doesn't always report the absolute last page reliably
    // Auto-complete at penultimate (second-to-last) page - NO anti-cheat delay
    if (_totalPages > 0) {
      final bool isExactlyLastPage = _currentPage == _totalPages;
      final bool isSecondToLastPage = _totalPages > 1 && _currentPage == _totalPages - 1;
      final bool isNearEnd = isExactlyLastPage || isSecondToLastPage;

      appLog('[COMPLETION] Checking completion: currentPage=$_currentPage, totalPages=$_totalPages', level: 'INFO');
      appLog('[COMPLETION] isExactlyLastPage=$isExactlyLastPage, isSecondToLastPage=$isSecondToLastPage, isNearEnd=$isNearEnd', level: 'INFO');
      appLog('[COMPLETION] _hasReachedLastPage=$_hasReachedLastPage', level: 'INFO');

      if (isNearEnd && !_hasReachedLastPage) {
        // Mark as complete - this will also update progress
        // Don't call _updateReadingProgress separately to avoid race condition
        appLog('[COMPLETION] 🎉 MARKING BOOK AS COMPLETED! (page $_currentPage of $_totalPages)', level: 'INFO');
        print('[WEB] 🎉 COMPLETION TRIGGERED! Page $_currentPage of $_totalPages');
        _hasReachedLastPage = true;
        _markBookAsCompleted();
        // Return early - don't update progress separately
        return;
      } else if (!isNearEnd && _hasReachedLastPage) {
        // Scrolled back from end: only revert if book wasn't already completed
        if (!_wasAlreadyCompleted) {
          appLog('[COMPLETION] ⏪ User scrolled back from end, reverting completion', level: 'INFO');
          _hasReachedLastPage = false;
          _revertBookCompletion();
          // Return early - revert handles the update
          return;
        } else {
          appLog('[COMPLETION] Book was already completed, not reverting', level: 'INFO');
          _hasReachedLastPage = false;
          // Just update progress normally without reverting completion
        }
      } else if (isNearEnd && _hasReachedLastPage) {
        appLog('[COMPLETION] Already marked as complete, not re-triggering', level: 'DEBUG');
        // CRITICAL: Return early to prevent overwriting completion status
        return;
      }
    }

    // Only update regular progress if we're NOT completing/reverting
    // This prevents race condition where progress update overwrites completion
    appLog('[PROGRESS] Updating regular reading progress for page $_currentPage', level: 'DEBUG');
    _updateReadingProgress();
    
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
    // Always update progress - allow updates even after completion so scrolling back works
    try {
  final firebaseUser = FirebaseAuth.instance.currentUser;
  
  // Use cached provider if available, otherwise try to get from context
  BookProvider bookProvider;
  if (_cachedBookProvider != null) {
    bookProvider = _cachedBookProvider!;
  } else if (mounted) {
    try {
      bookProvider = Provider.of<BookProvider>(context, listen: false);
    } catch (e) {
      appLog('[PDF] Could not get BookProvider from context: $e', level: 'WARN');
      bookProvider = BookProvider();
    }
  } else {
    bookProvider = BookProvider();
  }
  
  if (firebaseUser != null && _sessionStart != null) {
        final sessionDuration = DateTime.now().difference(_sessionStart!).inMinutes;

        // FAILSAFE: Check if we've reached 95%+ completion (catches final page detection issues)
        final progressPercentage = _totalPages > 0 ? _currentPage / _totalPages : 0.0;
        appLog('[PROGRESS] Current progress: ${(progressPercentage * 100).toStringAsFixed(1)}% (page $_currentPage of $_totalPages)', level: 'INFO');

        if (progressPercentage >= 0.95 && !_hasReachedLastPage) {
          appLog('[FAILSAFE] 🎯 Progress >= 95%, auto-completing book! (page $_currentPage of $_totalPages)', level: 'INFO');
          _hasReachedLastPage = true;
          // Use markBookAsCompleted instead of updating regular progress
          final completionDuration = DateTime.now().difference(_sessionStart!).inMinutes;
          await bookProvider.updateReadingProgress(
            userId: firebaseUser.uid,
            bookId: widget.bookId,
            currentPage: _totalPages, // Force to last page
            totalPages: _totalPages,
            additionalReadingTime: completionDuration > 0 ? completionDuration : 0,
            isCompleted: true, // Force completion
          );

          // Achievement popups are now handled by global AchievementListener
          // Just reload user data to keep stats fresh
          try {
            if (mounted) {
              final userProvider = Provider.of<UserProvider>(context, listen: false);
              await userProvider.loadUserData(firebaseUser.uid, force: true);
            }
          } catch (e) {
            appLog('Error reloading user data after failsafe completion: $e', level: 'WARN');
          }

          _sessionStart = DateTime.now();
          return; // Don't do regular progress update
        }

        // Regular progress update
        await bookProvider.updateReadingProgress(
          userId: firebaseUser.uid,
          bookId: widget.bookId,
          currentPage: _currentPage,
          totalPages: _totalPages,
          additionalReadingTime: sessionDuration > 0 ? sessionDuration : 0,
        );

        // Refresh user data to keep stats current
        try {
          if (mounted) {
            final userProvider = Provider.of<UserProvider>(context, listen: false);
            await userProvider.loadUserData(firebaseUser.uid);
          }
        } catch (e) {
          appLog('Error reloading user data after PDF progress update: $e', level: 'WARN');
        }
        if (sessionDuration > 0) {
          _sessionStart = DateTime.now();
        }
      }
    } catch (e) {
      appLog('Error updating reading progress (no context): $e', level: 'ERROR');
    }
  }

  Future<void> _markBookAsCompleted() async {
    // Avoid Provider.of(context) because this may be called during dispose.
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;

      // Try to get the shared provider instance, but fallback safely
      BookProvider bookProvider;
      if (_cachedBookProvider != null) {
        bookProvider = _cachedBookProvider!;
      } else {
        // If no cached provider, try to get it from context if still mounted
        if (mounted) {
          try {
            bookProvider = Provider.of<BookProvider>(context, listen: false);
          } catch (e) {
            appLog('[PDF] Could not get BookProvider from context, creating new instance', level: 'WARN');
            bookProvider = BookProvider();
          }
        } else {
          appLog('[PDF] Widget not mounted, creating temporary BookProvider', level: 'WARN');
          bookProvider = BookProvider();
        }
      }

      if (firebaseUser != null) {
        final sessionDuration = DateTime.now().difference(_sessionStart!).inMinutes;

        appLog('[COMPLETION] 🎯 Marking book as completed! BookID: ${widget.bookId}', level: 'INFO');
        appLog('[COMPLETION] Current page: $_currentPage, Total pages: $_totalPages', level: 'INFO');
        appLog('[COMPLETION] Was already completed: $_wasAlreadyCompleted', level: 'INFO');

        await bookProvider.updateReadingProgress(
          userId: firebaseUser.uid,
          bookId: widget.bookId,
          currentPage: _currentPage, // Use actual current page, not _totalPages
          totalPages: _totalPages,
          additionalReadingTime: sessionDuration > 0 ? sessionDuration : 0,
          isCompleted: true, // Explicitly mark as completed
        );

        appLog('[COMPLETION] ✅ Progress updated with isCompleted=true', level: 'INFO');

        // Achievement popups are now handled by global AchievementListener
        // Just reload user data to keep stats fresh
        if (mounted) {
          try {
            final userProvider = Provider.of<UserProvider>(context, listen: false);
            await userProvider.loadUserData(firebaseUser.uid, force: true);
            appLog('[COMPLETION] ✅ User data reloaded', level: 'INFO');
          } catch (e) {
            appLog('Error reloading user data after book completion: $e', level: 'WARN');
          }
        }

        _sessionStart = DateTime.now();

        // Show quiz popup if book was just completed (not already completed before)
        print('[WEB DEBUG] mounted=$mounted, wasAlreadyCompleted=$_wasAlreadyCompleted');
        if (mounted && !_wasAlreadyCompleted) {
          appLog('[QUIZ_POPUP] 🎉 Showing quiz dialog! (mounted=$mounted, wasAlreadyCompleted=$_wasAlreadyCompleted)', level: 'INFO');
          print('[WEB] 🎉🎉🎉 BOOK COMPLETED - SHOWING QUIZ POPUP NOW!');
          _showQuizDialog();
        } else {
          appLog('[QUIZ_POPUP] ⏭️ Skipping quiz dialog (mounted=$mounted, wasAlreadyCompleted=$_wasAlreadyCompleted)', level: 'INFO');
          print('[WEB] ⏭️ Quiz popup skipped - mounted=$mounted, wasAlreadyCompleted=$_wasAlreadyCompleted');
        }

        // Note: Removed congratulations popup as it was delayed and annoying
      }
    } catch (e) {
      appLog('Error marking book completed (no context): $e', level: 'ERROR');
    }
  }

  Future<void> _checkIfAlreadyCompleted() async {
    // Check if this book was already completed before opening
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) return;

      final progressQuery = await FirebaseFirestore.instance
          .collection('reading_progress')
          .where('userId', isEqualTo: firebaseUser.uid)
          .where('bookId', isEqualTo: widget.bookId)
          .get();

      if (progressQuery.docs.isNotEmpty) {
        final data = progressQuery.docs.first.data();
        _wasAlreadyCompleted = data['isCompleted'] == true;
        appLog('[PDF_LOAD] Book was already completed: $_wasAlreadyCompleted', level: 'INFO');
      }
    } catch (e) {
      appLog('Error checking completion status: $e', level: 'ERROR');
    }
  }

  Future<void> _revertBookCompletion() async {
    // Update database to mark book as NOT completed when user scrolls back
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;

      BookProvider bookProvider;
      if (_cachedBookProvider != null) {
        bookProvider = _cachedBookProvider!;
      } else if (mounted) {
        try {
          bookProvider = Provider.of<BookProvider>(context, listen: false);
        } catch (e) {
          bookProvider = BookProvider();
        }
      } else {
        bookProvider = BookProvider();
      }

      if (firebaseUser != null) {
        // Update progress with current page and isCompleted: false
        await bookProvider.updateReadingProgress(
          userId: firebaseUser.uid,
          bookId: widget.bookId,
          currentPage: _currentPage,
          totalPages: _totalPages,
          additionalReadingTime: 0, // No additional time when reverting
          isCompleted: false, // Mark as NOT completed
        );
      }
    } catch (e) {
      appLog('Error reverting book completion: $e', level: 'ERROR');
    }
  }

  // Common PDF load success handler
  void _onPdfLoaded(PdfDocumentLoadedDetails details) {
    appLog('PDF loaded successfully', level: 'INFO');
    final pageCount = details.document.pages.count;
    appLog('[PDF_LOAD] Document details: ${details.document}', level: 'DEBUG');
    
    // Use initialPage if provided, otherwise start at page 1
    final startPage = widget.initialPage != null && widget.initialPage! > 0 && widget.initialPage! <= pageCount
        ? widget.initialPage!
        : 1;
    
    setState(() {
      _totalPages = pageCount;
      _currentPage = startPage;
      _lastReportedPage = startPage;
      _pendingPage = startPage;
      _hasReachedLastPage = false;
      _isLoading = false;
      _error = null;
    });

    appLog('[PDF_LOAD] State initialized: totalPages=$_totalPages, currentPage=$_currentPage (initial: ${widget.initialPage})', level: 'INFO');

    // Check if book was already completed before opening
    _checkIfAlreadyCompleted();

    // Jump to the saved page if resuming
    if (startPage > 1) {
      appLog('[PDF_RESUME] Jumping to saved page $startPage', level: 'INFO');
      _isInitialJump = true; // Prevent completion detection during jump
      _pdfController.jumpToPage(startPage);
      // Reset flag after a short delay to allow jump to complete
      Future.delayed(const Duration(milliseconds: 500), () {
        _isInitialJump = false;
      });
    }

    // DON'T update progress on initial load - only when user actually changes pages
    // This prevents books from auto-completing when opened
  }

  // Common PDF load failure handler
  void _onPdfLoadFailed(PdfDocumentLoadFailedDetails details) {
    appLog('PDF load failed: ${details.error}', level: 'ERROR');
    appLog('Description: ${details.description}', level: 'ERROR');
    setState(() {
      _error = 'Failed to load PDF: ${details.description}';
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: AppTheme.heading,
            ),
            if (_totalPages > 0)
              Text(
                'Page $_currentPage of $_totalPages',
                style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.normal),
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
          if (_error != null)
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
                      style: AppTheme.body.copyWith(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                // Use cached file if available, otherwise load from network
                if (_cachedPdfFile != null && !_isCacheLoading)
                  SfPdfViewer.file(
                    _cachedPdfFile!,
                    controller: _pdfController,
                    onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                      final pageCount = details.document.pages.count;
                      appLog('[PDF_LOAD] PDF loaded from cache: $pageCount pages', level: 'INFO');
                      _onPdfLoaded(details);
                    },
                    onDocumentLoadFailed: _onPdfLoadFailed,
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
                  )
                else if (!_isCacheLoading)
                  SfPdfViewer.network(
                    widget.pdfUrl,
                    controller: _pdfController,
                    onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                      final pageCount = details.document.pages.count;
                      appLog('[PDF_LOAD] PDF loaded from network: $pageCount pages', level: 'INFO');
                      _onPdfLoaded(details);
                    },
                    onDocumentLoadFailed: _onPdfLoadFailed,
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
                // Skeleton UI - shows while PDF is loading
                if (_isLoading)
                  Container(
                    color: const Color(0xFFF9F9F9),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Book info card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Book icon placeholder
                              Container(
                                width: 60,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8E44AD).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.menu_book,
                                  size: 32,
                                  color: Color(0xFF8E44AD),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Book info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.title,
                                      style: AppTheme.heading.copyWith(
                                        fontSize: 18,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'by ${widget.author}',
                                      style: AppTheme.bodyMedium.copyWith(
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF8E44AD),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Loading book...',
                                          style: AppTheme.bodySmall.copyWith(
                                            color: const Color(0xFF8E44AD),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Content placeholder
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.auto_stories,
                                    size: 64,
                                    color: Color(0xFFE0E0E0),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Preparing your reading experience...',
                                    style: AppTheme.body.copyWith(
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      ), // WillPopScope
    );
  }

  void _showQuizDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8E44AD).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.quiz,
                  color: Color(0xFF8E44AD),
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Book Completed! 🎉',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8E44AD),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Great job finishing this book!',
                style: AppTheme.body.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Would you like to test your knowledge with a quick quiz?',
                style: AppTheme.body.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: Text(
                'Skip',
                style: AppTheme.body.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8E44AD),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                // Navigate to quiz screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookQuizScreen(
                      bookId: widget.bookId,
                      bookTitle: widget.title,
                    ),
                  ),
                );
              },
              child: const Text(
                'Take Quiz',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Achievement popups are now handled by global AchievementListener
  Future<bool> _onWillPop() async {
    // Allow the navigation to continue
    return true;
  }
}
