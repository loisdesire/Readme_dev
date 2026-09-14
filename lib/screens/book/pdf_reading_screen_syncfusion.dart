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
import '../../services/achievement_service.dart';
import '../../services/reading_session_service.dart';
import '../../services/reading_screen_tracker.dart';
import '../../services/content_filter_service.dart';
import '../../utils/pdf_validation.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import 'book_quiz_screen.dart';
import 'book_completion_celebration_screen.dart';
import '../child/league_promotion_screen.dart';
import '../../utils/page_transitions.dart';

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
  State<PdfReadingScreenSyncfusion> createState() =>
      _PdfReadingScreenSyncfusionState();
}

class _PdfReadingScreenSyncfusionState
    extends State<PdfReadingScreenSyncfusion> with WidgetsBindingObserver {
  late FlutterTts _flutterTts;
  bool _isPlaying = false;
  bool _isTtsInitialized = false;
  late PdfViewerController _pdfController;
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoading = true;
  String? _error;
  String? _sessionId; // Track session ID instead of start time
  PdfDocument? _pdfDocument;
  BookProvider? _cachedBookProvider;
  int _lastReportedPage = 0;
  bool _hasReachedLastPage = false;
  bool _isInitialJump = false;
  bool _wasAlreadyCompleted = false;
  int _pendingPage = 1;
  Timer? _pageChangeTimer;
  int _accumulatedDwellMs = 0;
  static const int _samplingIntervalMs = 100;
  static const int _normalThresholdMs = 300;
  static const int _lastPageThresholdMs = 600;

  // PDF caching
  File? _cachedPdfFile;
  bool _isCacheLoading = true;
  bool _hasAttemptedCacheRecovery = false;

  // Session service
  final ReadingSessionService _sessionService = ReadingSessionService();
  int _lastSessionDurationMinutes = 0; // Track duration from last session
  bool _sessionEnded = false; // Prevent ending session twice
  bool _sessionProgressRecorded =
      false; // Track if this session's time was already saved to Firestore

  // "Still actively reading" check-ins (Option A, see
  // docs/reading-session-integrity-design.md) — only ticks while this
  // screen is alive and the app is foregrounded; backgrounding pauses it
  // so idle/abandoned time stops accruing credit server-side.
  static const Duration _heartbeatInterval = Duration(minutes: 10);
  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ReadingScreenTracker.enter();
    _pdfController = PdfViewerController();
    _startReadingSession();
    _initializeTts();
    _checkPdfCache();
    _checkScreenTimeLimit();

    appLog('Initializing Syncfusion PDF viewer', level: 'DEBUG');
    appLog('PDF URL: ${widget.pdfUrl}', level: 'DEBUG');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only resumed counts as "actively reading" for heartbeat purposes —
    // every other state (inactive/paused/hidden/detached) pauses
    // check-ins so time spent backgrounded isn't credited.
    if (state == AppLifecycleState.resumed) {
      _startHeartbeatTimer();
    } else {
      _stopHeartbeatTimer();
    }
  }

  void _startHeartbeatTimer() {
    if (_heartbeatTimer != null || _sessionId == null || _sessionEnded) {
      return;
    }
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      final sessionId = _sessionId;
      if (sessionId == null || _sessionEnded) {
        _stopHeartbeatTimer();
        return;
      }
      _sessionService.sendHeartbeat(sessionId: sessionId);
    });
  }

  void _stopHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // Check if PDF is cached, download if not
  //
  // A cached file's mere *existence* used to be trusted outright — if a
  // past download was ever interrupted (killed mid-write, a transient
  // Firebase Storage hiccup, low disk space) or wrote non-PDF bytes for
  // any reason, that broken file sat in the cache forever: nothing ever
  // re-validated it, so every future open of that book failed with
  // "Failed to load PDF" on this device, permanently, even after
  // whatever caused it was long gone. See SECURITY.md.
  Future<void> _checkPdfCache() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final fileName = _getCacheFileName(widget.pdfUrl);
      final cachedFile = File('${cacheDir.path}/$fileName');

      if (await cachedFile.exists() &&
          looksLikePdf(await cachedFile.readAsBytes())) {
        appLog('[PDF_CACHE] Using cached PDF: ${cachedFile.path}',
            level: 'INFO');
        if (!mounted) return;
        setState(() {
          _cachedPdfFile = cachedFile;
          _isCacheLoading = false;
        });
        return;
      }

      if (await cachedFile.exists()) {
        appLog(
            '[PDF_CACHE] Cached file is not a valid PDF — discarding and '
            're-downloading: ${cachedFile.path}',
            level: 'WARN');
        try {
          await cachedFile.delete();
        } catch (_) {
          // Best-effort; _downloadAndCachePdf overwrites it regardless.
        }
      } else {
        appLog('[PDF_CACHE] No cache found, downloading PDF...', level: 'INFO');
      }
      await _downloadAndCachePdf(cachedFile);
    } catch (e) {
      appLog('[PDF_CACHE] Cache check failed: $e', level: 'ERROR');
      if (!mounted) return;
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

  // Download PDF and save to cache. Returns whether it succeeded, so
  // callers recovering from a bad cache (see _onPdfLoadFailed) know
  // whether the fresh copy is actually usable.
  Future<bool> _downloadAndCachePdf(File cacheFile) async {
    try {
      final response = await http.get(Uri.parse(widget.pdfUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download PDF: ${response.statusCode}');
      }
      if (!looksLikePdf(response.bodyBytes)) {
        throw Exception(
            'Downloaded content is not a valid PDF (${response.bodyBytes.length} bytes)');
      }
      await cacheFile.writeAsBytes(response.bodyBytes);
      appLog('[PDF_CACHE] PDF downloaded and cached: ${cacheFile.path}',
          level: 'INFO');
      if (!mounted) return false;
      setState(() {
        _cachedPdfFile = cacheFile;
        _isCacheLoading = false;
      });
      return true;
    } catch (e) {
      appLog('[PDF_CACHE] Download failed: $e', level: 'ERROR');
      if (!mounted) return false;
      setState(() {
        _isCacheLoading = false;
      });
      return false;
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

      // Set up completion handler - automatically read next page
      _flutterTts.setCompletionHandler(() async {
        if (mounted && _isPlaying) {
          appLog('TTS completed current page, moving to next', level: 'DEBUG');
          // Move to next page and continue reading
          if (_currentPage < _totalPages) {
            _pdfController.nextPage();
            await Future.delayed(
                const Duration(milliseconds: 500)); // Wait for page to load
            await _readCurrentPageContent();
          } else {
            // Reached end of book
            setState(() {
              _isPlaying = false;
            });
          }
        } else if (mounted) {
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

      // Configure voice settings for consistency across platforms
      await _flutterTts.setSpeechRate(0.5); // Normal speed (0.5 is standard)
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0); // Normal pitch

      // Try to set a male voice if available (platform-specific)
      if (Platform.isAndroid || Platform.isIOS) {
        try {
          final voices = await _flutterTts.getVoices;
          if (voices != null) {
            // Look for a male English voice
            dynamic maleVoice;
            for (var voice in voices) {
              final name = voice['name']?.toString().toLowerCase() ?? '';
              final locale = voice['locale']?.toString() ?? '';

              // Prefer male US English voices
              if (locale.contains('en') &&
                  (name.contains('male') && !name.contains('female'))) {
                maleVoice = voice;
                break;
              }
            }

            // If found, set the voice
            if (maleVoice != null) {
              await _flutterTts.setVoice(
                  {'name': maleVoice['name'], 'locale': maleVoice['locale']});
              appLog('TTS using voice: ${maleVoice['name']}', level: 'DEBUG');
            }
          }
        } catch (e) {
          appLog('Could not set specific voice: $e', level: 'WARN');
        }
      }

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

  // Check screen time limit
  Future<void> _checkScreenTimeLimit() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final filterService = ContentFilterService();
      final dailyMinutes = await filterService.getDailyReadingTime(user.uid);
      final restrictions =
          await filterService.getReadingTimeRestrictions(user.uid);

      if (restrictions['hasRestrictions'] == true) {
        // Bug fix: getReadingTimeRestrictions() has always computed
        // isCurrentTimeAllowed from the parent's configured allowedTimes
        // window, but nothing ever read it — only the daily-minutes limit
        // below was actually enforced. A "quiet hours"/bedtime restriction
        // could be set and would silently do nothing. See SECURITY.md.
        final isCurrentTimeAllowed =
            restrictions['isCurrentTimeAllowed'] as bool? ?? true;
        if (!isCurrentTimeAllowed && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text('Outside Reading Hours'),
                content: const Text(
                  "It's outside your allowed reading time right now.\n\nPlease try again during your reading hours!",
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      Navigator.pop(context); // Close reading screen
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          });
          return;
        }

        final maxMinutes = restrictions['maxReadingTimeMinutes'] ?? 60;
        final remainingMinutes = maxMinutes - dailyMinutes;

        if (remainingMinutes <= 0 && mounted) {
          // Exceeded limit - show dialog
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text('Screen Time Limit Reached'),
                content: Text(
                  'You have reached your daily reading limit of $maxMinutes minutes.\n\nPlease take a break and try again tomorrow!',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      Navigator.pop(context); // Close reading screen
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          });
        } else if (remainingMinutes <= 10 && remainingMinutes > 0 && mounted) {
          // Show warning
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'You have $remainingMinutes minutes of reading time left today'),
                backgroundColor: AppTheme.warningOrange,
                duration: const Duration(seconds: 4),
              ),
            );
          });
        }
      }
    } catch (e) {
      appLog('Error checking screen time limit: $e', level: 'ERROR');
    }
  }

  /// Start a reading session
  Future<void> _startReadingSession() async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        _sessionId = await _sessionService.startSession(
          userId: firebaseUser.uid,
          bookId: widget.bookId,
          bookTitle: widget.title,
        );
        if (_sessionId != null && mounted) {
          _startHeartbeatTimer();
        }
      }
    } catch (e) {
      appLog('[SESSION] Error starting session: $e', level: 'ERROR');
    }
  }

  /// End a reading session and update user data
  Future<void> _endReadingSession() async {
    if (_sessionEnded) return; // Already ended, don't call again
    _stopHeartbeatTimer();

    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null && _sessionId != null) {
        final durationMinutes = await _sessionService.endSession(
          sessionId: _sessionId!,
          userId: firebaseUser.uid,
          bookId: widget.bookId,
        );

        _lastSessionDurationMinutes = durationMinutes;
        _sessionEnded = true;

        // Save this session's reading time immediately (don't wait for completion)
        // This ensures each session is accumulated, not lost
        if (_lastSessionDurationMinutes > 0) {
          try {
            final bookProvider = _cachedBookProvider ??
                (mounted
                    ? Provider.of<BookProvider>(context, listen: false)
                    : null);

            if (bookProvider != null) {
              await bookProvider.updateReadingProgress(
                userId: firebaseUser.uid,
                bookId: widget.bookId,
                currentPage: _currentPage,
                totalPages: _totalPages,
                additionalReadingTime: _lastSessionDurationMinutes,
                isCompleted:
                    _hasReachedLastPage, // Only mark completed if we've reached the end
              );
              appLog(
                '[SESSION] Saved session reading time: $_lastSessionDurationMinutes minutes',
                level: 'INFO',
              );
              _sessionProgressRecorded =
                  true; // Mark this session's time as recorded
            }
          } catch (e) {
            appLog('[SESSION] Error saving session progress: $e',
                level: 'ERROR');
          }
        }

        // Refresh user provider so UI updates with new reading time
        if (mounted) {
          final userProvider =
              Provider.of<UserProvider>(context, listen: false);
          await userProvider.loadUserData(firebaseUser.uid, force: true);
        }
      }
    } catch (e) {
      appLog('[SESSION] Error ending session: $e', level: 'ERROR');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopHeartbeatTimer();
    ReadingScreenTracker.exit();
    if (_isTtsInitialized) {
      _flutterTts.stop();
    }
    _pdfController.dispose();
    _pdfDocument?.dispose();
    _pageChangeTimer?.cancel();

    // End the reading session
    _endReadingSession();

    // Don't update progress separately - session tracking handles it
    if (_hasReachedLastPage) {
      appLog('[DISPOSE] Book completed, session has been recorded',
          level: 'INFO');
    }

    super.dispose();
  }

  void _onPageChanged(PdfPageChangedDetails details) {
    final int newPage = details.newPageNumber;

    appLog(
        '[PAGE_CHANGE] onPageChanged fired: newPage=$newPage, totalPages=$_totalPages',
        level: 'INFO');

    // Validate page number is within valid range
    if (newPage < 1 || newPage > _totalPages) {
      appLog(
          '[PAGE_CHANGE] Invalid page number: $newPage (valid range: 1-$_totalPages), ignoring',
          level: 'WARN');
      return;
    }

    // DWELL TIME MODE: Must stay on page for threshold time before counting
    // This prevents rapid swiping to complete books without actually reading

    // Store pending page but don't commit immediately
    _pendingPage = newPage;
    // Cancel any existing timer and reset accumulation
    _pageChangeTimer?.cancel();
    _accumulatedDwellMs = 0;

    appLog('[PAGE_CHANGE] Starting dwell timer for page $newPage',
        level: 'DEBUG');

    appLog(
        '[PAGE_CHANGE] Page $newPage - threshold=${_dwellThresholdForPage(newPage)}ms',
        level: 'INFO');

    _pageChangeTimer =
        Timer.periodic(const Duration(milliseconds: _samplingIntervalMs), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final int controllerPage = _pdfController.pageNumber.round();
      if (controllerPage == _pendingPage) {
        _accumulatedDwellMs += _samplingIntervalMs;
        // Recomputed from the *current* _pendingPage on every tick, rather
        // than captured once when the timer started: the "else" branch
        // below can retarget _pendingPage to a different page mid-timer
        // (catching cases where the PDF viewer's own onPageChanged callback
        // misses an intermediate page during a fast swipe) — if that
        // retargeted page is near the end, it must still get the longer
        // anti-cheat threshold, not whatever page the timer originally
        // started on.
        final int thresholdMs = _dwellThresholdForPage(_pendingPage);
        if (_accumulatedDwellMs >= thresholdMs) {
          t.cancel();
          _pageChangeTimer = null;
          if (_pendingPage != _lastReportedPage) {
            appLog(
                '[PAGE_CHANGE] Dwell threshold met (${_accumulatedDwellMs}ms), committing page $_pendingPage',
                level: 'INFO');
            _commitPageChange(_pendingPage);
          }
        }
      } else {
        // Viewer moved to another page: reset accumulation and update pending
        appLog(
            '[PAGE_CHANGE] User scrolled to different page (controller=$controllerPage, pending=$_pendingPage), resetting timer',
            level: 'DEBUG');
        _pendingPage = controllerPage;
        _accumulatedDwellMs = 0;
      }
    });
  }

  // Last page and second-to-last page get a longer anti-cheat dwell
  // threshold than every other page — see the dwell-timer comment above for
  // why this must be called fresh for whichever page is currently pending,
  // not computed once and cached.
  int _dwellThresholdForPage(int page) {
    final bool isLastPage = page == _totalPages;
    final bool isSecondToLast = _totalPages > 1 && page == _totalPages - 1;
    final bool isNearEnd = isLastPage || isSecondToLast;
    return isNearEnd ? _lastPageThresholdMs : _normalThresholdMs;
  }

  void _commitPageChange(int newPage) {
    _lastReportedPage = newPage;

    setState(() {
      _currentPage = newPage;
    });

    appLog('[COMMIT] Committed page change to $_currentPage of $_totalPages',
        level: 'INFO');

    // Skip completion detection during initial jump to saved page
    if (_isInitialJump) {
      appLog('[COMMIT] Skipping completion check during initial jump',
          level: 'DEBUG');
      _updateReadingProgress();
      return;
    }

    // Check if we've reached the last or second-to-last page FIRST
    // On mobile, PDF viewer doesn't always report the absolute last page reliably
    // Auto-complete at penultimate (second-to-last) page - NO anti-cheat delay
    if (_totalPages > 0) {
      final bool isExactlyLastPage = _currentPage == _totalPages;
      final bool isSecondToLastPage =
          _totalPages > 1 && _currentPage == _totalPages - 1;
      final bool isNearEnd = isExactlyLastPage || isSecondToLastPage;

      appLog(
          '[COMPLETION] Checking completion: currentPage=$_currentPage, totalPages=$_totalPages',
          level: 'INFO');
      appLog(
          '[COMPLETION] isExactlyLastPage=$isExactlyLastPage, isSecondToLastPage=$isSecondToLastPage, isNearEnd=$isNearEnd',
          level: 'INFO');
      appLog('[COMPLETION] _hasReachedLastPage=$_hasReachedLastPage',
          level: 'INFO');

      if (isNearEnd && !_hasReachedLastPage) {
        // Mark as complete - this will also update progress
        // Don't call _updateReadingProgress separately to avoid race condition
        appLog(
            '[COMPLETION] 🎉 MARKING BOOK AS COMPLETED! (page $_currentPage of $_totalPages)',
            level: 'INFO');
        appLog(
            '[COMPLETION] Completion triggered at page $_currentPage of $_totalPages',
            level: 'INFO');
        _hasReachedLastPage = true;
        _markBookAsCompleted();
        // Return early - don't update progress separately
        return;
      } else if (!isNearEnd && _hasReachedLastPage) {
        // Scrolled back from end: only revert if book wasn't already completed
        if (!_wasAlreadyCompleted) {
          appLog(
              '[COMPLETION] ⏪ User scrolled back from end, reverting completion',
              level: 'INFO');
          _hasReachedLastPage = false;
          _revertBookCompletion();
          // Return early - revert handles the update
          return;
        } else {
          appLog('[COMPLETION] Book was already completed, not reverting',
              level: 'INFO');
          _hasReachedLastPage = false;
          // Just update progress normally without reverting completion
        }
      } else if (isNearEnd && _hasReachedLastPage) {
        appLog('[COMPLETION] Already marked as complete, not re-triggering',
            level: 'DEBUG');
        // CRITICAL: Return early to prevent overwriting completion status
        return;
      }
    }

    // Only update regular progress if we're NOT completing/reverting
    // This prevents race condition where progress update overwrites completion
    appLog(
        '[PROGRESS] Updating regular reading progress for page $_currentPage',
        level: 'DEBUG');
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
        if (!mounted) return;
        setState(() {
          _isPlaying = false;
        });
      } else {
        // Attempt to get text from the current page
        await _readCurrentPageContent();
      }
    } catch (e) {
      appLog('TTS Error: $e', level: 'ERROR');
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
      });

      // Show user-friendly error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Text-to-speech is not available on this device'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _readCurrentPageContent() async {
    try {
      // Don't stop if already playing (continuation from previous page)
      // Only stop if user manually triggered new reading

      if (!_isPlaying) {
        setState(() {
          _isPlaying = true;
        });
      }

      // Extract text from current page
      String pageText = await _extractTextFromCurrentPage();

      if (pageText.isNotEmpty) {
        // Clean up the text for better TTS
        String cleanText = pageText.replaceAll(RegExp(r'\s+'), ' ').trim();
        appLog(
            'Reading page text: ${cleanText.substring(0, cleanText.length > 100 ? 100 : cleanText.length)}...',
            level: 'DEBUG');

        // Read the actual page content
        await _flutterTts.speak(cleanText);
      } else {
        // Fallback if no text found, then continue to next page
        await _flutterTts.speak(
            'This page appears to contain images or non-readable content.');
      }
    } catch (e) {
      appLog('Error reading page content: $e', level: 'ERROR');
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
      await _flutterTts.speak('Unable to read this page content.');
    }
  }

  Future<String> _extractTextFromCurrentPage() async {
    try {
      // Prefer the already-cached PDF file over a fresh network fetch: this
      // method runs on every TTS page turn, and re-downloading the whole
      // document each time (the original behavior here) added a full
      // network round-trip to every page during read-aloud, ignored the
      // cache _checkPdfCache() already set up, and broke read-aloud
      // entirely once the device went offline after the initial load.
      final List<int> bytes;
      if (_cachedPdfFile != null && await _cachedPdfFile!.exists()) {
        bytes = await _cachedPdfFile!.readAsBytes();
      } else {
        final response = await http.get(Uri.parse(widget.pdfUrl));
        if (response.statusCode != 200) {
          throw Exception('Failed to load PDF');
        }
        bytes = response.bodyBytes;
      }

      // Dispose the previous document before replacing the reference —
      // PdfDocument holds native resources that aren't freed until
      // dispose() runs, and this method can be called once per page turn.
      _pdfDocument?.dispose();
      _pdfDocument = PdfDocument(inputBytes: bytes);

      if (_currentPage <= _pdfDocument!.pages.count) {
        // Extract text from current page
        String pageText = PdfTextExtractor(_pdfDocument!).extractText(
            startPageIndex: _currentPage - 1, endPageIndex: _currentPage - 1);

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
      if (!mounted) return;

      setState(() {
        _isPlaying = true;
      });

      // Speak the selected text with error handling
      final result = await _flutterTts.speak(cleanText);
      if (result == 0 && mounted) {
        // Speech failed
        setState(() {
          _isPlaying = false;
        });
      }
    } catch (e) {
      appLog('TTS speak selected error: $e', level: 'ERROR');
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
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
          appLog('[PDF] Could not get BookProvider from context: $e',
              level: 'WARN');
          bookProvider = BookProvider();
        }
      } else {
        bookProvider = BookProvider();
      }

      if (firebaseUser != null) {
        // FAILSAFE: Mobile PDFs sometimes don't report the true last page reliably.
        // Our product rule is: treat 98%+ as completion.
        final progressPercentage =
            _totalPages > 0 ? _currentPage / _totalPages : 0.0;
        appLog(
            '[PROGRESS] Current progress: ${(progressPercentage * 100).toStringAsFixed(1)}% (page $_currentPage of $_totalPages)',
            level: 'INFO');

        // _isInitialJump matters here: without it, simply *opening* a
        // one-page book (or resuming one already at/near its last page)
        // satisfies this immediately, with none of the dwell-timer
        // anti-cheat _commitPageChange's own near-end branch enforces —
        // instant completion from zero real reading. See SECURITY.md.
        if (progressPercentage >= 0.98 &&
            !_hasReachedLastPage &&
            !_isInitialJump) {
          appLog(
              '[FAILSAFE] 🎯 Progress >= 98%, completing book! (page $_currentPage of $_totalPages)',
              level: 'INFO');
          _hasReachedLastPage = true;
          // Route through the main completion path so points + celebration happen immediately.
          await _markBookAsCompleted();
          return;
        }

        // Regular progress update
        // If session progress was already recorded at session end, don't add time again
        // Just update page/progress percentages and completion status
        final timeToAdd =
            _sessionProgressRecorded ? 0 : _lastSessionDurationMinutes;
        await bookProvider.updateReadingProgress(
          userId: firebaseUser.uid,
          bookId: widget.bookId,
          currentPage: _currentPage,
          totalPages: _totalPages,
          additionalReadingTime: timeToAdd,
        );

        try {
          if (mounted) {
            final userProvider =
                Provider.of<UserProvider>(context, listen: false);
            await userProvider.loadUserData(firebaseUser.uid);
          }
        } catch (e) {
          appLog('Error reloading user data after PDF progress update: $e',
              level: 'WARN');
        }
      }
    } catch (e) {
      appLog('Error updating reading progress (no context): $e',
          level: 'ERROR');
    }
  }

  Future<void> _markBookAsCompleted() async {
    // Avoid Provider.of(context) because this may be called during dispose.
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;

      if (firebaseUser == null) return;

      // End session + award points in parallel to reduce perceived delay.
      Future<void> endSessionFuture = Future.value();
      if (_sessionId != null && !_sessionEnded) {
        endSessionFuture = _endReadingSession();
      }

      final bookProvider = _cachedBookProvider ??
          (mounted ? Provider.of<BookProvider>(context, listen: false) : null);
      if (bookProvider == null) {
        appLog('[PDF] No BookProvider available to mark completion',
            level: 'WARN');
        return;
      }

      appLog(
          '[COMPLETION] 🎯 Marking book as completed! BookID: ${widget.bookId}',
          level: 'INFO');
      appLog(
          '[COMPLETION] Current page: $_currentPage, Total pages: $_totalPages',
          level: 'INFO');
      appLog('[COMPLETION] Was already completed: $_wasAlreadyCompleted',
          level: 'INFO');

      // If session progress was already recorded at session end, don't add time again
      final timeToAdd =
          _sessionProgressRecorded ? 0 : _lastSessionDurationMinutes;

      // The points Cloud Function verifies reading_progress.isCompleted is
      // already true before paying out — so progress must be written
      // *before* awarding, not after (the old ordering awarded first,
      // which no longer works now that the award is actually checked
      // against real state instead of a trusted client flag). See
      // SECURITY.md's "Point-award security migration".
      final updateProgressFuture = bookProvider.updateReadingProgress(
        userId: firebaseUser.uid,
        bookId: widget.bookId,
        currentPage: _currentPage, // Use actual current page, not _totalPages
        totalPages: _totalPages,
        additionalReadingTime: timeToAdd,
        isCompleted: true, // Explicitly mark as completed
      );

      await Future.wait([endSessionFuture, updateProgressFuture]);

      appLog('[COMPLETION] ✅ Progress updated with isCompleted=true',
          level: 'INFO');
      appLog(
          '[COMPLETION] Time added: $timeToAdd minutes (sessionRecorded: $_sessionProgressRecorded)',
          level: 'DEBUG');

      final award = await AchievementService().awardBookCompletionPoints(
        userId: firebaseUser.uid,
        bookId: widget.bookId,
        isFirstCompletion: !_wasAlreadyCompleted,
      );

      final pointsEarned = award.pointsEarned;
      final totalBooksCompleted = award.totalBooksCompleted;
      final promotedLeague = award.promotedLeague;
      final newTotalPoints = award.newTotalPoints;

      appLog(
        _wasAlreadyCompleted
            ? '[COMPLETION] 📖 Awarded $pointsEarned points for re-read!'
            : '[COMPLETION] 🌟 Awarded $pointsEarned points for first completion!',
        level: 'INFO',
      );

      if (!mounted) return;

      // Achievement popups are now handled by global AchievementListener
      // Just reload user data to keep stats fresh
      try {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        // Load user data in background (don't await) so we can show celebration immediately
        userProvider.loadUserData(firebaseUser.uid, force: true).then((_) {
          appLog('[COMPLETION] ✅ User data reloaded in background',
              level: 'INFO');
        }).catchError((e) {
          appLog('Error reloading user data after book completion: $e',
              level: 'WARN');
        });
      } catch (e) {
        appLog('Error queueing user data reload: $e', level: 'WARN');
      }

      // Show celebration screen IMMEDIATELY without waiting for data reload
      if (!_wasAlreadyCompleted) {
        appLog('[CELEBRATION] 🎉 Showing book completion celebration!',
            level: 'INFO');

        final bookTitle = widget.title;

        // Show celebration screen (data will update via listeners in background)
        // Duration will be tracked via session service, not passed here
        final navigator = Navigator.of(context);
        await navigator.push(
          MaterialPageRoute(
            builder: (context) => BookCompletionCelebrationScreen(
              bookId: widget.bookId,
              bookTitle: bookTitle,
              pointsEarned: pointsEarned,
              isFirstCompletion: !_wasAlreadyCompleted,
              totalBooksCompleted: totalBooksCompleted,
              readingDuration: Duration(minutes: _lastSessionDurationMinutes),
              pagesRead: _totalPages,
            ),
          ),
        );

        if (!mounted) return;

        // Show league promotion screen if promoted
        if (promotedLeague != null) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => LeaguePromotionScreen(
                newLeague: promotedLeague,
                totalPoints: newTotalPoints,
              ),
            ),
          );
        }
      }

      // Quiz popup removed - BookCompletionCelebrationScreen already has "Take Quiz" button
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
        appLog('[PDF_LOAD] Book was already completed: $_wasAlreadyCompleted',
            level: 'INFO');
      }
    } catch (e) {
      appLog('Error checking completion status: $e', level: 'ERROR');
    }
  }

  Future<void> _revertBookCompletion() async {
    // Update database to mark book as NOT completed when user scrolls back
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;

      if (firebaseUser == null) return;

      final bookProvider = _cachedBookProvider ??
          (mounted ? Provider.of<BookProvider>(context, listen: false) : null);
      if (bookProvider == null) {
        appLog('[PDF] No BookProvider available to revert completion',
            level: 'WARN');
        return;
      }

      // Update progress with current page and isCompleted: false
      await bookProvider.updateReadingProgress(
        userId: firebaseUser.uid,
        bookId: widget.bookId,
        currentPage: _currentPage,
        totalPages: _totalPages,
        additionalReadingTime:
            0, // No additional time when reverting (avoid duplicate time)
        isCompleted: false, // Mark as NOT completed
      );
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
    final startPage = widget.initialPage != null &&
            widget.initialPage! > 0 &&
            widget.initialPage! <= pageCount
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

    appLog(
        '[PDF_LOAD] State initialized: totalPages=$_totalPages, currentPage=$_currentPage (initial: ${widget.initialPage})',
        level: 'INFO');

    // Check if book was already completed before opening
    _checkIfAlreadyCompleted();

    // Jump to the saved page if resuming
    if (startPage > 1) {
      appLog('[PDF_RESUME] Jumping to saved page $startPage', level: 'INFO');
      _isInitialJump = true; // Prevent completion detection during jump
      _pdfController.jumpToPage(startPage);
    } else {
      // Even on first page, wait before allowing completion
      _isInitialJump = true;
    }

    // Reset the flag after a settle delay, then run one real completion
    // check for wherever the reader actually is now. This is what marks
    // a book complete when it opens (or resumes) already on its last
    // page — a one-page book, or resuming right near the end — cases
    // where no further onPageChanged event will ever fire to trigger
    // the normal dwell-timer completion path in _commitPageChange.
    // Gating on this real elapsed 1.5s (longer than the near-end dwell
    // threshold itself) is what keeps merely *opening* such a book from
    // instantly completing it, while still actually completing it once
    // real time has passed instead of never. See SECURITY.md.
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      _isInitialJump = false;
      _commitPageChange(_currentPage);
    });

    // DON'T update progress on initial load - only when user actually changes pages
    // This prevents books from auto-completing when opened
  }

  // Common PDF load failure handler.
  //
  // A cached file that fails to parse here is most likely corrupt or
  // incomplete rather than genuinely bad server-side data (see
  // _checkPdfCache's header comment) — including a cache entry poisoned
  // before the validation above existed. Self-heal once per screen visit:
  // drop the bad cache entry and re-download fresh, instead of failing
  // permanently every time this book is opened.
  Future<void> _onPdfLoadFailed(PdfDocumentLoadFailedDetails details) async {
    appLog('PDF load failed: ${details.error}', level: 'ERROR');
    appLog('Description: ${details.description}', level: 'ERROR');

    final badCacheFile = _cachedPdfFile;
    if (badCacheFile != null && !_hasAttemptedCacheRecovery) {
      _hasAttemptedCacheRecovery = true;
      appLog(
          '[PDF_CACHE] Cached PDF failed to load — discarding it and '
          'retrying a fresh download.',
          level: 'WARN');
      try {
        await badCacheFile.delete();
      } catch (_) {
        // Best-effort; _downloadAndCachePdf overwrites the same path regardless.
      }
      if (!mounted) return;
      setState(() {
        _cachedPdfFile = null;
        _isCacheLoading = true;
      });
      final recovered = await _downloadAndCachePdf(badCacheFile);
      if (recovered) return; // Rebuild picks up the fresh, validated file.
    }

    if (!mounted) return;
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title,
                style: AppTheme.heading,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (_totalPages > 0)
                Text(
                  'Page $_currentPage of $_totalPages',
                  style: AppTheme.bodySmall
                      .copyWith(fontWeight: FontWeight.normal),
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
                        appLog(
                            '[PDF_LOAD] PDF loaded from cache: $pageCount pages',
                            level: 'INFO');
                        _onPdfLoaded(details);
                      },
                      onDocumentLoadFailed: _onPdfLoadFailed,
                      onPageChanged: _onPageChanged,
                      onTextSelectionChanged:
                          (PdfTextSelectionChangedDetails details) {
                        if (details.selectedText != null &&
                            details.selectedText!.isNotEmpty) {
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
                        appLog(
                            '[PDF_LOAD] PDF loaded from network: $pageCount pages',
                            level: 'INFO');
                        _onPdfLoaded(details);
                      },
                      onDocumentLoadFailed: _onPdfLoadFailed,
                      onPageChanged: _onPageChanged,
                      onTextSelectionChanged:
                          (PdfTextSelectionChangedDetails details) {
                        if (details.selectedText != null &&
                            details.selectedText!.isNotEmpty) {
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
                                    color: const Color(0xFF8E44AD)
                                        .withValues(alpha: 0.1),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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

  // ignore: unused_element
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
                  color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.quiz,
                  color: AppTheme.primaryPurple,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Book Completed!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryPurple,
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
            CompactButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                // Navigate to quiz screen
                Navigator.push(
                  context,
                  FadeRoute(
                    page: BookQuizScreen(
                      bookId: widget.bookId,
                      bookTitle: widget.title,
                    ),
                  ),
                );
              },
              text: 'Take Quiz',
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
