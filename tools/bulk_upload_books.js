// bulk_upload_books.js
// Batch upload books and metadata to Firebase Storage and Firestore
// Usage: node bulk_upload_books.js <metadata.json>

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const { Storage } = require('@google-cloud/storage');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: '<YOUR_FIREBASE_STORAGE_BUCKET>' // e.g. 'your-app.appspot.com'
});
const db = admin.firestore();
const bucket = admin.storage().bucket();

// Helper: Upload file to Storage and get URL
async function uploadFile(localPath, storagePath) {
  await bucket.upload(localPath, {
    destination: storagePath,
    public: true,
    metadata: { cacheControl: 'public,max-age=31536000' },
  });
  const file = bucket.file(storagePath);
  const [url] = await file.getSignedUrl({ action: 'read', expires: '03-01-2030' });
  return url;
}

// Main bulk upload function
async function bulkUpload(metadataPath) {
  const metadata = JSON.parse(fs.readFileSync(metadataPath, 'utf8'));
  for (const book of metadata.books) {
    try {
      // Check for duplicate by title
      const existing = await db.collection('books').where('title', '==', book.title).get();
      if (!existing.empty) {
        console.log(`Skipped (already exists): ${book.title}`);
        continue;
      }

      // Upload PDF
      const pdfLocal = path.resolve(book.pdfFile);
      const pdfStorage = `books/pdfs/${path.basename(book.pdfFile)}`;
      const pdfUrl = await uploadFile(pdfLocal, pdfStorage);

      // Upload cover image (optional)
      let coverImageUrl = '';
      if (book.coverImage) {
        const coverLocal = path.resolve(book.coverImage);
        const coverStorage = `books/covers/${path.basename(book.coverImage)}`;
        coverImageUrl = await uploadFile(coverLocal, coverStorage);
      }

      // Prepare Firestore document
      const bookDoc = {
        title: book.title,
        author: book.author,
        description: book.description,
        pdfUrl,
        coverImageUrl,
        ageRating: book.ageRating || '',
        tags: book.tags || [],
        traits: book.traits || [],
        needsTagging: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      await db.collection('books').add(bookDoc);
      console.log(`Uploaded: ${book.title}`);
    } catch (err) {
      console.error(`Error uploading ${book.title}:`, err);
    }
  }
  console.log('Bulk upload complete.');
}

// Entry point
if (process.argv.length < 3) {
  console.error('Usage: node bulk_upload_books.js <metadata.json>');
  process.exit(1);
}

bulkUpload(process.argv[2]);
