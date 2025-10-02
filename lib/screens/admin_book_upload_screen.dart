import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';

class AdminBookUploadScreen extends StatefulWidget {
  const AdminBookUploadScreen({super.key});

  @override
  State<AdminBookUploadScreen> createState() => _AdminBookUploadScreenState();
}

class _AdminBookUploadScreenState extends State<AdminBookUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _title, _author, _description, _ageRating, _coverImageUrl, _pdfUrl;
  List<String> _tags = [];
  List<String> _traits = [];
  bool _isLoading = false;
  String? _error;
  PlatformFile? _pdfFile;
  PlatformFile? _coverFile;

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _pdfFile = result.files.first;
      });
    }
  }

  Future<void> _pickCover() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _coverFile = result.files.first;
      });
    }
  }

  Future<String> _uploadFile(PlatformFile file, String folder) async {
    final ref = FirebaseStorage.instance.ref().child('$folder/${file.name}');
    final uploadTask = await ref.putData(file.bytes!);
    return await ref.getDownloadURL();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _pdfFile == null) return;
    setState(() { _isLoading = true; _error = null; });
    _formKey.currentState!.save();
    try {
      // Upload PDF
      _pdfUrl = await _uploadFile(_pdfFile!, 'books');
      // Upload cover image (optional)
      if (_coverFile != null) {
        _coverImageUrl = await _uploadFile(_coverFile!, 'covers');
      }
      // Add to Firestore
      await FirebaseFirestore.instance.collection('books').add({
        'title': _title,
        'author': _author,
        'description': _description,
        'tags': _tags,
        'traits': _traits,
        'ageRating': _ageRating,
        'pdfUrl': _pdfUrl,
        'coverImageUrl': _coverImageUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });
      setState(() { _isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Book uploaded successfully!')));
      _formKey.currentState!.reset();
      setState(() { _pdfFile = null; _coverFile = null; });
    } catch (e) {
      setState(() { _isLoading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Book Upload'),
        backgroundColor: const Color(0xFF8E44AD),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                onSaved: (v) => _title = v,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Author'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                onSaved: (v) => _author = v,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
                onSaved: (v) => _description = v,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Age Rating'),
                onSaved: (v) => _ageRating = v,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Tags (comma separated)'),
                onSaved: (v) => _tags = v?.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList() ?? [],
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Traits (comma separated)'),
                onSaved: (v) => _traits = v?.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList() ?? [],
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                label: Text(_pdfFile == null ? 'Pick PDF' : _pdfFile!.name),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8E44AD)),
                onPressed: _pickPdf,
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.image),
                label: Text(_coverFile == null ? 'Pick Cover Image (optional)' : _coverFile!.name),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8E44AD)),
                onPressed: _pickCover,
              ),
              const SizedBox(height: 20),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ElevatedButton(
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Upload Book'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8E44AD)),
                onPressed: _isLoading ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
