import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../providers/book_provider.dart';
import '../../providers/auth_provider.dart';

class PdfReadingScreenSyncfusion extends StatefulWidget {
  final String bookId;
  final String title;
  final String author;
  final String pdfUrl;

  const PdfReadingScreenSyncfusion({
    Key? key,
    required this.bookId,
    required this.title,
    required this.author,
    required this.pdfUrl,
  }) : super(key: key);

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
  double _zoomLevel = 1.0;

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
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(1.0);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      setState(() {
        _isTtsInitialized = true;
      });
    } catch (e) {
      print('TTS initialization error: $e');
    }
  }

  @override
  void dispose() {
    if (_isTtsInitialized) {
      _flutterTts.stop();
    }
    _pdfController.dispose();
    _updateReadingProgress();
    super.dispose();
  }

  void _onPageChanged(PdfPageChangedDetails details) {
    setState(() {
      _currentPage = details.newPageNumber;
    });
    
    print('📄 Page changed: $_currentPage/$_totalPages (${(_currentPage / _totalPages * 100).toStringAsFixed(1)}%)');
    
    _updateReadingProgress();
    
    // Check if book is completed (reached last page)
    if (_currentPage >= _totalPages && _totalPages > 0) {
      print('🎉 Book completed! Marking as done...');
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
    if (!_isTtsInitialized) return;
    try {
      if (_isPlaying) {
        await _flutterTts.stop();
        setState(() {
          _isPlaying = false;
        });
      } else {
        await _flutterTts.speak('Text-to-speech is not available for this PDF page.');
        setState(() {
          _isPlaying = true;
        });
      }
    } catch (e) {
      print('TTS Error: $e');
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
                const Text('🎉', style: TextStyle(fontSize: 20)),
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
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () {
              setState(() {
                _zoomLevel = (_zoomLevel + 0.25).clamp(1.0, 3.0);
                _pdfController.zoomLevel = _zoomLevel;
              });
            },
            tooltip: 'Zoom In',
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: () {
              setState(() {
                _zoomLevel = (_zoomLevel - 0.25).clamp(1.0, 3.0);
                _pdfController.zoomLevel = _zoomLevel;
              });
            },
            tooltip: 'Zoom Out',
          ),
          IconButton(
            icon: Icon(_isPlaying ? Icons.stop : Icons.volume_up),
            onPressed: _isTtsInitialized ? _togglePlayPause : null,
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
              enableDoubleTapZooming: true,
              enableTextSelection: true,
              canShowScrollHead: true,
              canShowScrollStatus: true,
              canShowPaginationDialog: true,
              initialZoomLevel: _zoomLevel,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.black87,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Page $_currentPage of $_totalPages',
                  style: const TextStyle(color: Colors.white),
                ),
                Text(
                  'Zoom: ${(_zoomLevel * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
