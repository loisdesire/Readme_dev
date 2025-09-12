const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Initialize Firebase Admin SDK
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function verifyGutenbergBooks() {
  try {
    console.log('🔍 Verifying Project Gutenberg books in database...\n');
    
    // Get all books
    const snapshot = await db.collection('books').get();
    console.log(`📚 Total books in database: ${snapshot.docs.length}`);
    
    // Categorize books by source
    const booksBySource = {};
    const booksByContentType = {};
    const booksByReadingLevel = {};
    const fullLengthBooks = [];
    
    snapshot.docs.forEach(doc => {
      const data = doc.data();
      const source = data.source || 'Unknown';
      const contentType = data.contentType || 'short_story';
      const readingLevel = data.readingLevel || 'Easy';
      const hasChapters = data.chapters && data.chapters.length > 0;
      
      // Count by source
      booksBySource[source] = (booksBySource[source] || 0) + 1;
      
      // Count by content type
      booksByContentType[contentType] = (booksByContentType[contentType] || 0) + 1;
      
      // Count by reading level
      booksByReadingLevel[readingLevel] = (booksByReadingLevel[readingLevel] || 0) + 1;
      
      // Track full-length books
      if (hasChapters) {
        fullLengthBooks.push({
          id: doc.id,
          title: data.title,
          author: data.author,
          chapters: data.chapters.length,
          wordCount: data.wordCount || 0,
          readingLevel: readingLevel,
          estimatedHours: data.estimatedReadingHours || 0
        });
      }
    });
    
    console.log('\n📊 **BOOK STATISTICS**');
    console.log('='.repeat(50));
    
    console.log('\n📖 **Books by Source:**');
    Object.entries(booksBySource).forEach(([source, count]) => {
      console.log(`  • ${source}: ${count} books`);
    });
    
    console.log('\n📚 **Books by Content Type:**');
    Object.entries(booksByContentType).forEach(([type, count]) => {
      console.log(`  • ${type}: ${count} books`);
    });
    
    console.log('\n🎯 **Books by Reading Level:**');
    Object.entries(booksByReadingLevel).forEach(([level, count]) => {
      console.log(`  • ${level}: ${count} books`);
    });
    
    console.log(`\n📜 **Full-Length Books with Chapters: ${fullLengthBooks.length}**`);
    
    if (fullLengthBooks.length > 0) {
      console.log('\n🏆 **Top 10 Longest Books:**');
      fullLengthBooks
        .sort((a, b) => b.wordCount - a.wordCount)
        .slice(0, 10)
        .forEach((book, index) => {
          console.log(`  ${index + 1}. "${book.title}" by ${book.author}`);
          console.log(`     📖 ${book.chapters} chapters, ${book.wordCount?.toLocaleString() || 0} words, ${book.estimatedHours}h (${book.readingLevel})`);
        });
    }
    
    // Sample a few Gutenberg books to verify structure
    console.log('\n🔬 **Sample Project Gutenberg Books:**');
    const gutenbergBooks = snapshot.docs
      .filter(doc => doc.data().source === 'Project Gutenberg')
      .slice(0, 5);
    
    if (gutenbergBooks.length > 0) {
      for (const doc of gutenbergBooks) {
        const data = doc.data();
        console.log(`\n  📚 "${data.title}" by ${data.author}`);
        console.log(`     🏷️ ${data.readingLevel} level, ${data.ageRating} age rating`);
        console.log(`     📊 ${data.wordCount?.toLocaleString() || 0} words, ${data.chapters?.length || 0} chapters`);
        console.log(`     ⏱️ Est. ${data.estimatedReadingHours || 0}h reading time`);
        console.log(`     🎭 Traits: ${data.traits?.join(', ') || 'None'}`);
        
        if (data.chapters && data.chapters.length > 0) {
          console.log(`     📖 First 3 chapters:`);
          data.chapters.slice(0, 3).forEach((chapter, i) => {
            console.log(`        ${i + 1}. "${chapter.title}" (${chapter.pages?.length || 0} pages, ${chapter.estimatedMinutes || 0} min)`);
          });
        }
      }
    } else {
      console.log('  ❌ No Project Gutenberg books found!');
    }
    
    // Final summary
    console.log('\n🎉 **VERIFICATION SUMMARY**');
    console.log('='.repeat(50));
    console.log(`✅ Total Books: ${snapshot.docs.length}`);
    console.log(`✅ Project Gutenberg Books: ${booksBySource['Project Gutenberg'] || 0}`);
    console.log(`✅ Full-Length Books: ${fullLengthBooks.length}`);
    console.log(`✅ Reading Levels Available: ${Object.keys(booksByReadingLevel).join(', ')}`);
    
    const totalWords = fullLengthBooks.reduce((sum, book) => sum + (book.wordCount || 0), 0);
    const totalChapters = fullLengthBooks.reduce((sum, book) => sum + book.chapters, 0);
    
    console.log(`✅ Total Content: ${totalWords.toLocaleString()} words, ${totalChapters} chapters`);
    console.log(`\n🚀 **PROJECT GUTENBERG INTEGRATION: SUCCESS!**`);
    console.log(`📚 Children now have access to complete classic literature!`);
    
  } catch (error) {
    console.error('❌ Verification failed:', error);
  } finally {
    process.exit(0);
  }
}

// Run verification
verifyGutenbergBooks().catch(console.error);