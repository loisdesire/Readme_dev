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
import '../../widgets/achievement_popup.dart';
import '../../services/achievement_service.dart';

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
  static const int _samplingIntervalMs = 150;
  static const int _normalThresholdMs = 800; // accumulated dwell required for normal pages
  static const int _lastPageThresholdMs = 300; // accumulated dwell required for last page

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
    _updateReadingProgress();
    super.dispose();
  }

  void _onPageChanged(PdfPageChangedDetails details) {
    final int newPage = details.newPageNumber;
    
    // Validate page number is within valid range
    if (newPage < 1 || newPage > _totalPages) {
      appLog('Invalid page number: $newPage (valid range: 1-$_totalPages), ignoring', level: 'WARN');
      return;
    }
    
    // Store pending page but don't commit immediately
    _pendingPage = newPage;
    // Cancel any existing timer and reset accumulation
    _pageChangeTimer?.cancel();
    _accumulatedDwellMs = 0;

    // Determine threshold: last page gets a smaller threshold so completion
    // feels responsive on mobile.
    final int thresholdMs = (newPage == _totalPages && _totalPages > 0)
        ? _lastPageThresholdMs
        : _normalThresholdMs;

    _pageChangeTimer = Timer.periodic(const Duration(milliseconds: _samplingIntervalMs), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final int controllerPage = _pdfController.pageNumber.toInt();
      if (controllerPage == _pendingPage) {
        _accumulatedDwellMs += _samplingIntervalMs;
        appLog('Dwell sampling: controller=$controllerPage pending=$_pendingPage accumulated=${_accumulatedDwellMs}ms threshold=$thresholdMs', level: 'DEBUG');
        if (_accumulatedDwellMs >= thresholdMs) {
          t.cancel();
          _pageChangeTimer = null;
          if (_pendingPage != _lastReportedPage) {
            appLog('Dwell commit: Page $_pendingPage after ${_accumulatedDwellMs}ms', level: 'DEBUG');
            _commitPageChange(_pendingPage);
          } else {
            appLog('Dwell commit skipped - already reported: $_pendingPage', level: 'DEBUG');
          }
        }
      } else {
        // Viewer moved to another page: reset accumulation and update pending
        appLog('Dwell sampling: controller moved to $controllerPage, resetting accumulated (was ${_accumulatedDwellMs}ms) and pending=$_pendingPage', level: 'DEBUG');
        _pendingPage = controllerPage;
        _accumulatedDwellMs = 0;
      }
    });
  }
  
  void _commitPageChange(int newPage) {
  appLog('Page change committed: $_lastReportedPage -> $newPage (Total: $_totalPages)', level: 'DEBUG');
    
    _lastReportedPage = newPage;
    
    setState(() {
      _currentPage = newPage;
    });
    
  appLog('Current page confirmed: $_currentPage/$_totalPages (${(_currentPage / _totalPages * 100).toStringAsFixed(1)}%)', level: 'DEBUG');
    
    // Update reading progress
    _updateReadingProgress();
    
    // Check if we've reached the last page
    // Check if we've reached the last page. On mobile the viewer sometimes
    // doesn't report the absolute final page reliably, so treat the
    // penultimate page as completion as a fallback.
    if (_totalPages > 0) {
      final bool isLast = _currentPage == _totalPages;
      final bool isPenultimate = _totalPages > 1 && _currentPage == (_totalPages - 1);
      
      if ((isLast || isPenultimate) && !_hasReachedLastPage) {
        appLog('Reached final/penultimate page: $_currentPage/$_totalPages — marking completed', level: 'INFO');
        _hasReachedLastPage = true;
        _markBookAsCompleted();
      } else if (!isLast && !isPenultimate && _hasReachedLastPage) {
        // Reset completion flag when scrolling away from final pages
        appLog('Scrolled away from final pages: $_currentPage/$_totalPages — resetting completion flag', level: 'DEBUG');
        _hasReachedLastPage = false;
      }
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
    // Don't update progress if book has been marked completed to avoid overriding completion
    if (_hasReachedLastPage) {
      appLog('Skipping progress update - book already marked completed', level: 'DEBUG');
      return;
    }
    
    // Avoid using Provider.of(context) here because this method may be
    // called from dispose(). Use FirebaseAuth directly to get the current
    // user id and create a local BookProvider instance to perform the update.
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
        // Update progress even if duration is 0 to track page changes
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
            
            // Check for newly unlocked achievements and show popups
            final pendingAchievements = bookProvider.getPendingAchievementPopups();
            appLog('[ACHIEVEMENT DEBUG] PDF screen found ${pendingAchievements.length} pending achievement popups after delay', level: 'INFO');
            for (final achievement in pendingAchievements) {
              if (mounted) {
                appLog('[ACHIEVEMENT DEBUG] Showing popup for: ${achievement.name}', level: 'INFO');
                await _showAchievementPopup(achievement);
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
    appLog('[PDF] Using cached shared BookProvider for completion', level: 'INFO');
  } else {
    // If no cached provider, try to get it from context if still mounted
    if (mounted) {
      try {
        bookProvider = Provider.of<BookProvider>(context, listen: false);
        appLog('[PDF] Retrieved BookProvider from context for completion', level: 'INFO');
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
          currentPage: _totalPages,
          totalPages: _totalPages,
          additionalReadingTime: sessionDuration > 0 ? sessionDuration : 0,
          isCompleted: true, // Explicitly mark as completed
        );
        
        // Check for achievement popups after completion
        if (mounted) {
          try {
            final userProvider = Provider.of<UserProvider>(context, listen: false);
            await userProvider.loadUserData(firebaseUser.uid);
            
            // Small delay to ensure achievement processing completes
            await Future.delayed(const Duration(milliseconds: 500));
            
            // Check for newly unlocked achievements and show popups
            final pendingAchievements = bookProvider.getPendingAchievementPopups();
            appLog('[ACHIEVEMENT DEBUG] PDF completion found ${pendingAchievements.length} pending achievement popups after delay', level: 'INFO');
            for (final achievement in pendingAchievements) {
              if (mounted) {
                appLog('[ACHIEVEMENT DEBUG] Showing completion popup for: ${achievement.name}', level: 'INFO');
                await _showAchievementPopup(achievement);
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

  Future<void> _showAchievementPopup(Achievement achievement) async {
    if (!mounted) return;
    
    try {
      await showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) {
          return AchievementPopup(achievement: achievement);
        },
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      );
    } catch (e) {
      appLog('Error showing achievement popup: $e', level: 'WARN');
    }
  }
}
