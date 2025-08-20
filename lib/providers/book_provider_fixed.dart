// FIXED VERSION - Replace the loadAllBooks method in your book_provider.dart with this:

// Load all books with content filtering - FIXED VERSION
Future<void> loadAllBooks({String? userId}) async {
  try {
    _isLoading = true;
    _error = null;
    // Delay notifying listeners to ensure we finish the build phase
    Future.delayed(Duration.zero, () => notifyListeners());

    // FIXED: Remove orderBy to get ALL books, regardless of createdAt field
    final querySnapshot = await _firestore
        .collection('books')
        .get(); // No orderBy constraint

    _allBooks = querySnapshot.docs
        .map((doc) => Book.fromFirestore(doc))
        .toList();

    print('DEBUG: Loaded ${_allBooks.length} books from Firestore');
    print('DEBUG: Book titles: ${_allBooks.map((b) => b.title).take(10).join(", ")}');

    // Apply content filtering if userId is provided
    if (userId != null) {
      try {
        final booksData = _allBooks.map((book) => {
          'id': book.id,
          'title': book.title,
          'author': book.author,
          'description': book.description,
          'ageRating': book.ageRating,
          'traits': book.traits,
          'content': book.content,
        }).toList();

        final filteredBooksData = await _contentFilterService.filterBooks(booksData, userId);
        final filteredIds = filteredBooksData.map((book) => book['id']).toSet();
        
        _filteredBooks = _allBooks.where((book) => filteredIds.contains(book.id)).toList();
        print('DEBUG: After filtering: ${_filteredBooks.length} books');
      } catch (filterError) {
        print('Error applying content filter: $filterError');
        // Fallback to all books if filtering fails
        _filteredBooks = _allBooks;
      }
    } else {
      _filteredBooks = _allBooks;
    }

    _isLoading = false;
    Future.delayed(Duration.zero, () => notifyListeners());
  } catch (e) {
    print('Error loading books: $e');
    _error = 'Failed to load books: $e';
    _isLoading = false;
    Future.delayed(Duration.zero, () => notifyListeners());
  }
}
