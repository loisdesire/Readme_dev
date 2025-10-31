import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import '../../providers/book_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/logger.dart';
import '../../services/achievement_service.dart';
import '../child/achievement_celebration_screen.dart';

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
  BookProvider? _cachedBookProvider;
  int _lastReportedPage = 0;
  bool _hasReachedLastPage = false;
  // _lastPageChangeTime removed: switching to timer-based debounce
  int _pendingPage = 1;
  Timer? _pageChangeTimer;
  int _accumulatedDwellMs = 0;
  static const int _samplingIntervalMs = 100;
  static const int _normalThresholdMs = 200; // 0.2s dwell - instant page counting
  static const int _lastPageThresholdMs = 200; // 0.2s for last page - instant completion

  // Queue achievements to show on exit instead of interrupting reading
  final List<Achievement> _queuedAchievements = [];

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    _sessionStart = DateTime.now();
    _initializeTts();
    
  appLog('Initializing Syncfusion PDF viewer', level: 'DEBUG');
  appLog('PDF URL: ${widget.pdfUrl}', level: 'DEBUG');
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
        _hasReachedLastPage = true;
        _markBookAsCompleted();
        // Return early - don't update progress separately
        return;
      } else if (!isNearEnd && _hasReachedLastPage) {
        // Scrolled back from end: revert completion status in database
        appLog('[COMPLETION] ⏪ User scrolled back from end, reverting completion', level: 'INFO');
        _hasReachedLastPage = false;
        _revertBookCompletion();
        // Return early - revert handles the update
        return;
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

          try {
            if (mounted) {
              final userProvider = Provider.of<UserProvider>(context, listen: false);
              // CRITICAL: Force reload to bypass throttling and get fresh totalBooksRead count for achievements
              await userProvider.loadUserData(firebaseUser.uid, force: true);

              await Future.delayed(const Duration(milliseconds: 500));

              final pendingAchievements = bookProvider.getPendingAchievementPopups();
              for (final achievement in pendingAchievements) {
                if (!_queuedAchievements.any((a) => a.id == achievement.id)) {
                  _queuedAchievements.add(achievement);
                }
              }
            }
          } catch (e) {
            appLog('Error checking achievements after failsafe completion: $e', level: 'WARN');
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
        // If we have a valid context and UserProvider is available, refresh user data
        try {
          if (mounted) {
            final userProvider = Provider.of<UserProvider>(context, listen: false);
            await userProvider.loadUserData(firebaseUser.uid);
            
            // Small delay to ensure achievement processing completes
            await Future.delayed(const Duration(milliseconds: 500));

            // Queue achievements to show on exit (don't interrupt reading)
            final pendingAchievements = bookProvider.getPendingAchievementPopups();
            for (final achievement in pendingAchievements) {
              if (!_queuedAchievements.any((a) => a.id == achievement.id)) {
                _queuedAchievements.add(achievement);
              }
            }
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

        await bookProvider.updateReadingProgress(
          userId: firebaseUser.uid,
          bookId: widget.bookId,
          currentPage: _currentPage, // Use actual current page, not _totalPages
          totalPages: _totalPages,
          additionalReadingTime: sessionDuration > 0 ? sessionDuration : 0,
          isCompleted: true, // Explicitly mark as completed
        );
        
        // Check for achievement popups after completion
        if (mounted) {
          try {
            final userProvider = Provider.of<UserProvider>(context, listen: false);
            // CRITICAL: Force reload to bypass throttling and get fresh totalBooksRead count for achievements
            await userProvider.loadUserData(firebaseUser.uid, force: true);

            // Small delay to ensure achievement processing completes
            await Future.delayed(const Duration(milliseconds: 500));

            // Queue achievements to show on exit (don't interrupt reading)
            final pendingAchievements = bookProvider.getPendingAchievementPopups();
            for (final achievement in pendingAchievements) {
              if (!_queuedAchievements.any((a) => a.id == achievement.id)) {
                _queuedAchievements.add(achievement);
              }
            }
          } catch (e) {
            appLog('Error checking achievements after book completion: $e', level: 'WARN');
          }
        }
        
        _sessionStart = DateTime.now();

        // Note: Removed congratulations popup as it was delayed and annoying
      }
    } catch (e) {
      appLog('Error marking book completed (no context): $e', level: 'ERROR');
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
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
                final pageCount = details.document.pages.count;
                appLog('[PDF_LOAD] PDF loaded successfully: $pageCount pages', level: 'INFO');
                appLog('[PDF_LOAD] Document details: ${details.document}', level: 'DEBUG');
                setState(() {
                  _totalPages = pageCount;
                  _currentPage = 1; // Ensure we start at page 1
                  _lastReportedPage = 1;
                  _pendingPage = 1;
                  _hasReachedLastPage = false;
                  _isLoading = false;
                  _error = null;
                });

                appLog('[PDF_LOAD] State initialized: totalPages=$_totalPages, currentPage=$_currentPage', level: 'INFO');

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
      ), // WillPopScope
    );
  }

  // Show celebration screen when user exits if there are queued achievements
  Future<bool> _onWillPop() async {
    if (_queuedAchievements.isNotEmpty) {
      // User earned achievements - show celebration screen
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AchievementCelebrationScreen(
            achievements: List.from(_queuedAchievements),
          ),
        ),
      );
      _queuedAchievements.clear();
    }
    // Allow the pop to continue
    return true;
  }
}
