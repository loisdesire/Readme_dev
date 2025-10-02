import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../providers/book_provider.dart';
import '../../providers/auth_provider.dart';

class PdfReadingScreen extends StatefulWidget {
  final String bookId;
  final String title;
  final String author;
  final String pdfUrl;

  const PdfReadingScreen({
    super.key,
    required this.bookId,
    required this.title,
    required this.author,
    required this.pdfUrl,
  });

  @override
  State<PdfReadingScreen> createState() => _PdfReadingScreenState();
}

class _PdfReadingScreenState extends State<PdfReadingScreen> {
  late FlutterTts _flutterTts;
  bool _isPlaying = false;
  bool _isTtsInitialized = false;
  late PdfViewerController _pdfController;
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoading = true;
  String? _error;
  double _zoomLevel = 1.0;
  DateTime? _sessionStart;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
    _sessionStart = DateTime.now();
    _initializeTts();
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
    _updateReadingProgress();
    super.dispose();
  }

  void _onPageChanged(int pageNumber) {
    setState(() {
      _currentPage = pageNumber;
    });
    _updateReadingProgress();
    // Optionally stop TTS when page changes
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
        // NOTE: PDF text extraction is not natively supported by SfPdfViewer.
        // You may need to use a package like 'pdf_text' to extract text from the PDF for TTS.
        // For now, we show a placeholder message.
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
      await bookProvider.updateReadingProgress(
        userId: authProvider.userId!,
        bookId: widget.bookId,
        currentPage: _currentPage,
        totalPages: _totalPages,
        additionalReadingTime: sessionDuration,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(Icons.zoom_in),
            onPressed: () {
              setState(() {
                _zoomLevel = (_zoomLevel + 0.25).clamp(1.0, 3.0);
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.zoom_out),
            onPressed: () {
              setState(() {
                _zoomLevel = (_zoomLevel - 0.25).clamp(1.0, 3.0);
              });
            },
          ),
          IconButton(
            icon: Icon(_isPlaying ? Icons.stop : Icons.volume_up),
            onPressed: _isTtsInitialized ? _togglePlayPause : null,
            tooltip: 'Text-to-Speech',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Go Back'),
                      ),
                    ],
                  ),
                )
              : SfPdfViewer.network(
                  widget.pdfUrl,
                  controller: _pdfController,
                  onDocumentLoaded: (details) {
                    setState(() {
                      _totalPages = details.document.pages.count;
                      _isLoading = false;
                    });
                  },
                  onPageChanged: (details) {
                    _onPageChanged(details.newPageNumber);
                  },
                  canShowScrollHead: true,
                  canShowScrollStatus: true,
                  enableDoubleTapZooming: true,
                  initialZoomLevel: _zoomLevel,
                ),
    );
  }
}
