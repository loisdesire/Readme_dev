// regenerate_storage_urls.js
// Regenerate all Firebase Storage signed URLs with new credentials

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'readme-40267',
  storageBucket: 'readme-40267.firebasestorage.app'
});

const db = admin.firestore();
const bucket = admin.storage().bucket();

// Generate signed URL that expires in 50 years
async function generateSignedUrl(filePath) {
  try {
    const file = bucket.file(filePath);
    
    // Check if file exists
    const [exists] = await file.exists();
    if (!exists) {
      console.log(`   ⚠️  File not found: ${filePath}`);
      return null;
    }
    
    // Generate signed URL (expires in 50 years)
    const [url] = await file.getSignedUrl({
      action: 'read',
      expires: '01-01-2074' // Far future date
    });
    
    return url;
  } catch (error) {
    console.error(`   ❌ Error generating URL for ${filePath}: ${error.message}`);
    return null;
  }
}

// Extract file path from old URL or construct from book data
function extractFilePath(url, bookTitle, type) {
  if (!url) return null;
  
  try {
    // Try to extract from existing URL
    if (url.includes('googleapis.com')) {
      const urlParts = url.split('googleapis.com/')[1];
      const pathWithParams = urlParts.split('?')[0];
      const pathParts = pathWithParams.split('/');
      pathParts.shift(); // Remove bucket name
      const filePath = pathParts.join('/');
      return decodeURIComponent(filePath);
    }
    
    // Construct from book title
    const sanitizedTitle = bookTitle.toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '');
    
    if (type === 'cover') {
      return `books/covers/${sanitizedTitle}.jpg`;
    } else if (type === 'pdf') {
      return `books/pdfs/${sanitizedTitle}.pdf`;
    }
  } catch (error) {
    console.error(`   ❌ Error extracting file path: ${error.message}`);
  }
  
  return null;
}

async function regenerateAllUrls() {
  try {
    console.log('🔄 Starting URL regeneration process...\n');
    
    // Get all books
    const snapshot = await db.collection('books').get();
    const books = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    
    console.log(`📚 Found ${books.length} books\n`);
    
    let successCount = 0;
    let failCount = 0;
    let skippedCount = 0;
    
    for (let i = 0; i < books.length; i++) {
      const book = books[i];
      console.log(`\n📖 Processing ${i + 1}/${books.length}: "${book.title}"`);
      
      const updates = {};
      let hasUpdates = false;
      
      // Regenerate cover URL
      if (book.coverImageUrl) {
        console.log(`   🖼️  Regenerating cover URL...`);
        const coverPath = extractFilePath(book.coverImageUrl, book.title, 'cover');
        
        if (coverPath) {
          const newCoverUrl = await generateSignedUrl(coverPath);
          if (newCoverUrl) {
            updates.coverImageUrl = newCoverUrl;
            hasUpdates = true;
            console.log(`   ✅ Cover URL regenerated`);
          } else {
            console.log(`   ⚠️  Could not regenerate cover URL`);
          }
        }
      }
      
      // Regenerate PDF URL
      if (book.pdfUrl) {
        console.log(`   📄 Regenerating PDF URL...`);
        const pdfPath = extractFilePath(book.pdfUrl, book.title, 'pdf');
        
        if (pdfPath) {
          const newPdfUrl = await generateSignedUrl(pdfPath);
          if (newPdfUrl) {
            updates.pdfUrl = newPdfUrl;
            hasUpdates = true;
            console.log(`   ✅ PDF URL regenerated`);
          } else {
            console.log(`   ⚠️  Could not regenerate PDF URL`);
          }
        }
      }
      
      // Update Firestore if we have new URLs
      if (hasUpdates) {
        try {
          await db.collection('books').doc(book.id).update(updates);
          console.log(`   💾 Updated in Firestore`);
          successCount++;
        } catch (error) {
          console.error(`   ❌ Failed to update Firestore: ${error.message}`);
          failCount++;
        }
      } else {
        console.log(`   ⏭️  No URLs to regenerate`);
        skippedCount++;
      }
    }
    
    console.log(`\n${'='.repeat(50)}`);
    console.log(`📊 Summary:`);
    console.log(`   ✅ Successfully updated: ${successCount} books`);
    console.log(`   ❌ Failed: ${failCount} books`);
    console.log(`   ⏭️  Skipped: ${skippedCount} books`);
    console.log(`${'='.repeat(50)}\n`);
    
    console.log('✨ URL regeneration complete!');
    console.log('📱 Try refreshing your app now - images and PDFs should load!');
    
  } catch (error) {
    console.error('❌ Error in regeneration process:', error);
  }
}

// Run the script
regenerateAllUrls()
  .then(() => process.exit(0))
  .catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
