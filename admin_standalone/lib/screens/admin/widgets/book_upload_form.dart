import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_button.dart';

class BookUploadForm extends StatefulWidget {
  const BookUploadForm({super.key});

  @override
  State<BookUploadForm> createState() => _BookUploadFormState();
}

class _BookUploadFormState extends State<BookUploadForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _ageRatingController = TextEditingController();
  final _coverEmojiController = TextEditingController(text: '📚');

  PlatformFile? _pdfFile;
  PlatformFile? _coverImage;
  Uint8List? _pdfBytes;
  Uint8List? _coverBytes;
  
  bool _uploading = false;
  double _uploadProgress = 0;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _descriptionController.dispose();
    _ageRatingController.dispose();
    _coverEmojiController.dispose();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result != null) {
      setState(() {
        _pdfFile = result.files.first;
        _pdfBytes = result.files.first.bytes;
      });
    }
  }

  Future<void> _pickCoverImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result != null) {
      setState(() {
        _coverImage = result.files.first;
        _coverBytes = result.files.first.bytes;
      });
    }
  }

  Future<void> _submitBook() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_pdfFile == null || _pdfBytes == null) {
      setState(() => _error = 'PDF file is required');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _error = 'You must be signed in as admin');
      return;
    }

    setState(() {
      _uploading = true;
      _error = null;
      _success = null;
      _uploadProgress = 0;
    });

    try {
      // Verify admin status
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists || userDoc.data()?['role'] != 'admin') {
        throw Exception('You must be an admin to upload books');
      }

      // Upload PDF
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${_titleController.text.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.pdf';
      final pdfRef = FirebaseStorage.instance.ref().child('books/pdfs/$fileName');
      
      final pdfUploadTask = pdfRef.putData(_pdfBytes!);
      
      pdfUploadTask.snapshotEvents.listen((snapshot) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
      });

      await pdfUploadTask;
      final pdfUrl = await pdfRef.getDownloadURL();

      // Upload cover image if provided
      String coverImageUrl = '';
      if (_coverImage != null && _coverBytes != null) {
        final ext = _coverImage!.extension ?? 'png';
        final coverFileName = '${DateTime.now().millisecondsSinceEpoch}_${_titleController.text.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_cover.$ext';
        final coverRef = FirebaseStorage.instance.ref().child('books/covers/$coverFileName');
        await coverRef.putData(_coverBytes!);
        coverImageUrl = await coverRef.getDownloadURL();
      }

      // Create book document
      await FirebaseFirestore.instance.collection('books').add({
        'title': _titleController.text.trim(),
        'author': _authorController.text.trim(),
        'description': _descriptionController.text.trim(),
        'ageRating': _ageRatingController.text.trim(),
        'pdfUrl': pdfUrl,
        'coverImageUrl': coverImageUrl,
        'displayCover': coverImageUrl.isEmpty ? _coverEmojiController.text : '',
        'createdAt': FieldValue.serverTimestamp(),
        'needsTagging': true,
        'isVisible': true,
      });

      setState(() {
        _success = 'Book uploaded successfully! AI will process it soon.';
        _uploading = false;
      });

      // Clear form
      _titleController.clear();
      _authorController.clear();
      _descriptionController.clear();
      _ageRatingController.clear();
      _coverEmojiController.text = '📚';
      setState(() {
        _pdfFile = null;
        _coverImage = null;
        _pdfBytes = null;
        _coverBytes = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Upload failed: ${e.toString()}';
        _uploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upload Book',
          style: AppTheme.logoSmall.copyWith(color: AppTheme.black87),
        ),
        const SizedBox(height: 4),
        Text(
          'Add a new book to the library',
          style: AppTheme.bodySmall.copyWith(color: AppTheme.textGray),
        ),
        const SizedBox(height: 32),
        Container(
          constraints: const BoxConstraints(maxWidth: 700),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderGray),
            boxShadow: AppTheme.defaultCardShadow,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Book Details',
                  style: AppTheme.heading.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Book Title',
                    hintText: 'Enter the book\'s title',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 2) {
                      return 'Title must be at least 2 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _authorController,
                  decoration: InputDecoration(
                    labelText: 'Author Name',
                    hintText: 'Who wrote the book?',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 2) {
                      return 'Author name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Short Description',
                    hintText: 'What\'s this book about?',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 10) {
                      return 'Description must be at least 10 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _ageRatingController,
                  decoration: InputDecoration(
                    labelText: 'Age Group (e.g. 6+, 8+, 12+)',
                    hintText: 'Recommended age, e.g. 6+',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || !RegExp(r'^\d+\+$').hasMatch(value)) {
                      return 'Age rating must be like 6+, 8+, etc.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _coverEmojiController,
                  decoration: InputDecoration(
                    labelText: 'Cover Emoji (fallback if no image)',
                    hintText: '📚',
                    helperText: 'Used as fallback when cover image is not available',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Cover Image Upload
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.borderGray),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.image, color: AppTheme.primaryPurple),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Cover Image (optional)',
                              style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          SecondaryButton(
                            text: 'Choose Image',
                            onPressed: _pickCoverImage,
                            height: 40,
                            width: 140,
                          ),
                        ],
                      ),
                      if (_coverImage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Selected: ${_coverImage!.name}',
                          style: AppTheme.bodySmall.copyWith(color: AppTheme.successGreen),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // PDF Upload
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.borderGray),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.picture_as_pdf, color: AppTheme.errorRed),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'PDF File (required)',
                              style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          SecondaryButton(
                            text: 'Choose PDF',
                            onPressed: _pickPdf,
                            height: 40,
                            width: 140,
                          ),
                        ],
                      ),
                      if (_pdfFile != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Selected: ${_pdfFile!.name}',
                          style: AppTheme.bodySmall.copyWith(color: AppTheme.successGreen),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: AppTheme.errorRed, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: AppTheme.bodySmall.copyWith(color: AppTheme.errorRed),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_success != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: AppTheme.successGreen, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _success!,
                            style: AppTheme.bodySmall.copyWith(color: AppTheme.successGreen),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_uploading) ...[
                  Column(
                    children: [
                      LinearProgressIndicator(
                        value: _uploadProgress,
                        backgroundColor: AppTheme.borderGray,
                        color: AppTheme.primaryPurple,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Uploading... ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                        style: AppTheme.bodySmall.copyWith(color: AppTheme.textGray),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ],
                PrimaryButton(
                  text: 'Submit Book',
                  onPressed: _uploading ? null : _submitBook,
                  height: 48,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
