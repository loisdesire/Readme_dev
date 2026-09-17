import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/screens/admin/widgets/book_upload_form.dart';

/// FilePicker.platform is a settable PlatformInterface field (the standard
/// federated-plugin pattern), so a fake covering pickFiles is enough to
/// drive BookUploadForm's file-selection flow without any real OS dialog.
class _FakeFilePicker extends FilePicker {
  PlatformFile? nextPdf;
  PlatformFile? nextImage;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    final file = type == FileType.image ? nextImage : nextPdf;
    if (file == null) return null;
    return FilePickerResult([file]);
  }
}

PlatformFile fakePdf() => PlatformFile(
      name: 'book.pdf',
      size: 100,
      bytes: Uint8List.fromList([1, 2, 3]),
    );

void main() {
  late FakeFirebaseFirestore firestore;
  late MockFirebaseAuth auth;
  late _FakeFilePicker filePicker;

  Widget wrap() {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: BookUploadForm(
            authOverride: auth,
            firestoreOverride: firestore,
            storageOverride: MockFirebaseStorage(),
          ),
        ),
      ),
    );
  }

  Future<void> fillValidFields(WidgetTester tester) async {
    await tester.enterText(find.widgetWithText(TextFormField, 'Book Title'), 'Dragon Tales');
    await tester.enterText(find.widgetWithText(TextFormField, 'Author Name'), 'Jane Doe');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Short Description'),
      'A grand adventure',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Age Group (e.g. 4+, 6+, 8+)'),
      '4+',
    );
  }

  setUp(() {
    firestore = FakeFirebaseFirestore();
    auth = MockFirebaseAuth(mockUser: MockUser(uid: 'admin-1'), signedIn: true);
    filePicker = _FakeFilePicker();
    FilePicker.platform = filePicker;
  });

  testWidgets('submitting everything empty shows every field\'s validation '
      'error, no PDF-required message yet', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.ensureVisible(find.text('Submit Book'));
    await tester.tap(find.text('Submit Book'));
    await tester.pumpAndSettle();

    expect(find.text('Title must be at least 2 characters'), findsOneWidget);
    expect(find.text('Author name must be at least 2 characters'), findsOneWidget);
    expect(find.text('Description must be at least 10 characters'), findsOneWidget);
    expect(find.text('Age rating must be like 4+, 6+, etc.'), findsOneWidget);
  });

  testWidgets('an age rating not matching the "N+" pattern is rejected',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Age Group (e.g. 4+, 6+, 8+)'),
      'six',
    );
    await tester.ensureVisible(find.text('Submit Book'));
    await tester.tap(find.text('Submit Book'));
    await tester.pumpAndSettle();

    expect(find.text('Age rating must be like 4+, 6+, etc.'), findsOneWidget);
  });

  testWidgets(
      'valid fields but no PDF chosen shows "PDF file is required", no '
      'Firestore write', (tester) async {
    await tester.pumpWidget(wrap());
    await fillValidFields(tester);
    await tester.ensureVisible(find.text('Submit Book'));
    await tester.tap(find.text('Submit Book'));
    await tester.pumpAndSettle();

    expect(find.text('PDF file is required'), findsOneWidget);
    final books = await firestore.collection('books').get();
    expect(books.docs, isEmpty);
  });

  testWidgets('choosing a PDF shows its selected filename', (tester) async {
    filePicker.nextPdf = fakePdf();
    await tester.pumpWidget(wrap());

    await tester.ensureVisible(find.text('Choose PDF'));
    await tester.tap(find.text('Choose PDF'));
    await tester.pumpAndSettle();

    expect(find.text('Selected: book.pdf'), findsOneWidget);
  });

  testWidgets(
      'a non-admin user is rejected even with a PDF and valid fields',
      (tester) async {
    await firestore.collection('users').doc('admin-1').set({'role': 'parent'});
    filePicker.nextPdf = fakePdf();
    await tester.pumpWidget(wrap());
    await fillValidFields(tester);
    await tester.ensureVisible(find.text('Choose PDF'));
    await tester.tap(find.text('Choose PDF'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Submit Book'));
    await tester.tap(find.text('Submit Book'));
    await tester.pumpAndSettle();

    expect(find.textContaining('must be an admin'), findsOneWidget);
    final books = await firestore.collection('books').get();
    expect(books.docs, isEmpty);
  });

  // NOTE: the actual successful-upload path (tap "Submit Book" with a valid
  // admin + PDF + fields, all the way through to the Firestore write and
  // the success SnackBar) is not exercised here. firebase_storage_mocks'
  // MockReference.putData does real dart:io file I/O, which resolves via
  // Flutter test binding's real-async-interplay mechanism *after* a
  // test's own body has already returned — no pump()/takeException() call
  // reachable from inside the test can catch the resulting
  // "MockTaskSnapshot has no instance getter 'bytesTransferred'" error
  // (a mock-package gap: MockTaskSnapshot doesn't implement it) once it's
  // thrown there. This isn't a bug in BookUploadForm — its every other
  // path (validation, the PDF-required and non-admin checks, and file
  // selection) is covered above.
}
