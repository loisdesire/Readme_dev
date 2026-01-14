import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../theme/app_theme.dart';

class BooksTable extends StatefulWidget {
  const BooksTable({super.key});

  @override
  State<BooksTable> createState() => _BooksTableState();
}

class _BooksTableState extends State<BooksTable> {
  String _searchQuery = '';
  String? _deleteError;

  Future<void> _deleteBook(String bookId, String? pdfUrl, String? coverUrl) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Book', style: AppTheme.heading),
        content: const Text('Are you sure you want to delete this book? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Delete files from storage
      if (pdfUrl != null && pdfUrl.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(pdfUrl).delete();
        } catch (e) {
          // Ignore storage deletion errors
        }
      }
      if (coverUrl != null && coverUrl.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(coverUrl).delete();
        } catch (e) {
          // Ignore storage deletion errors
        }
      }

      // Delete from Firestore
      await FirebaseFirestore.instance.collection('books').doc(bookId).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Book deleted successfully'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      setState(() => _deleteError = e.toString());
    }
  }

  Future<void> _editBook(Map<String, dynamic> book, String bookId) async {
    final titleController = TextEditingController(text: book['title']);
    final authorController = TextEditingController(text: book['author']);
    final descriptionController = TextEditingController(text: book['description']);
    final ageRatingController = TextEditingController(text: book['ageRating']);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Book', style: AppTheme.heading),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: authorController,
                decoration: const InputDecoration(labelText: 'Author'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ageRatingController,
                decoration: const InputDecoration(labelText: 'Age Rating'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != true) return;

    try {
      await FirebaseFirestore.instance.collection('books').doc(bookId).update({
        'title': titleController.text.trim(),
        'author': authorController.text.trim(),
        'description': descriptionController.text.trim(),
        'ageRating': ageRatingController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Book updated successfully'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manage Books',
                    style: AppTheme.logoSmall.copyWith(color: AppTheme.black87),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'View, edit, and delete books from the library',
                    style: AppTheme.bodySmall.copyWith(color: AppTheme.textGray),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 300,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search books...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        if (_deleteError != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
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
                    _deleteError!,
                    style: AppTheme.bodySmall.copyWith(color: AppTheme.errorRed),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => setState(() => _deleteError = null),
                ),
              ],
            ),
          ),
        ],
        SizedBox(
          height: 600, // Fixed height instead of Expanded
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('books')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.errorRed),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryPurple),
                );
              }

              var books = snapshot.data!.docs;

              // Filter by search query
              if (_searchQuery.isNotEmpty) {
                books = books.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final title = data['title']?.toString().toLowerCase() ?? '';
                  final author = data['author']?.toString().toLowerCase() ?? '';
                  return title.contains(_searchQuery) || author.contains(_searchQuery);
                }).toList();
              }

              if (books.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.library_books_rounded,
                        size: 64,
                        color: AppTheme.textGray,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty ? 'No books uploaded yet' : 'No books found',
                        style: AppTheme.heading.copyWith(color: AppTheme.textGray),
                      ),
                    ],
                  ),
                );
              }

              return Container(
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderGray),
                  boxShadow: AppTheme.defaultCardShadow,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(
                        AppTheme.primaryPurpleOpaque10,
                      ),
                      columns: [
                        DataColumn(
                          label: Text(
                            'Cover',
                            style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Title',
                            style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Author',
                            style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Age',
                            style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'PDF',
                            style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Needs Tagging',
                            style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Actions',
                            style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                      rows: books.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final bookId = doc.id;

                        return DataRow(
                          cells: [
                            DataCell(
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryPurpleOpaque10,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: data['coverImageUrl'] != null &&
                                          data['coverImageUrl'].isNotEmpty
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            data['coverImageUrl'],
                                            width: 40,
                                            height: 40,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Text(
                                              data['displayCover'] ?? '📚',
                                              style: const TextStyle(fontSize: 20),
                                            ),
                                          ),
                                        )
                                      : Text(
                                          data['displayCover'] ?? '📚',
                                          style: const TextStyle(fontSize: 20),
                                        ),
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 200,
                                child: Text(
                                  data['title'] ?? '',
                                  style: AppTheme.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 150,
                                child: Text(
                                  data['author'] ?? '',
                                  style: AppTheme.bodySmall,
                                ),
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.secondaryYellow.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  data['ageRating'] ?? '',
                                  style: AppTheme.bodySmall.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Icon(
                                data['pdfUrl'] != null && data['pdfUrl'].isNotEmpty
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                color: data['pdfUrl'] != null && data['pdfUrl'].isNotEmpty
                                    ? AppTheme.successGreen
                                    : AppTheme.errorRed,
                                size: 20,
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: (data['needsTagging'] == true
                                          ? AppTheme.warningOrange
                                          : AppTheme.successGreen)
                                      .withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  data['needsTagging'] == true ? 'Yes' : 'Tagged',
                                  style: AppTheme.bodySmall.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: data['needsTagging'] == true
                                        ? AppTheme.warningOrange
                                        : AppTheme.successGreen,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.edit,
                                      color: AppTheme.primaryPurple,
                                      size: 20,
                                    ),
                                    onPressed: () => _editBook(data, bookId),
                                    tooltip: 'Edit',
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete,
                                      color: AppTheme.errorRed,
                                      size: 20,
                                    ),
                                    onPressed: () => _deleteBook(
                                      bookId,
                                      data['pdfUrl'],
                                      data['coverImageUrl'],
                                    ),
                                    tooltip: 'Delete',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
