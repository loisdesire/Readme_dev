const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Initialize Firebase Admin SDK
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function verifyRealCovers() {
  try {
    console.log('🔍 Verifying books with real cover images...\n');
    
    const booksSnapshot = await db.collection('books').get();
    console.log(`📚 Total books in database: ${booksSnapshot.docs.length}`);
    
    let booksWithRealCovers = 0;
    let booksWithEmojiOnly = 0;
    
    console.log('\n📖 Book Cover Analysis:');
    console.log('=' .repeat(80));
    
    booksSnapshot.docs.forEach((doc, index) => {
      const data = doc.data();
      const title = data.title || 'Unknown';
      const author = data.author || 'Unknown';
      const coverImageUrl = data.coverImageUrl;
      const coverEmoji = data.coverEmoji;
      const source = data.source || 'Sample';
      
      console.log(`${(index + 1).toString().padStart(2, '0')}. "${title}" by ${author}`);
      
      if (coverImageUrl && coverImageUrl.startsWith('http')) {
        console.log(`    ✅ Real cover: ${coverImageUrl.substring(0, 60)}...`);
        console.log(`    🏷️  Source: ${source}`);
        booksWithRealCovers++;
      } else {
        console.log(`    📱 Emoji cover: ${coverEmoji || '📚'}`);
        console.log(`    🏷️  Source: ${source}`);
        booksWithEmojiOnly++;
      }
      console.log('');
    });
    
    console.log('=' .repeat(80));
    console.log('📊 SUMMARY:');
    console.log(`✅ Books with real cover images: ${booksWithRealCovers}`);
    console.log(`📱 Books with emoji covers only: ${booksWithEmojiOnly}`);
    console.log(`📈 Real cover percentage: ${((booksWithRealCovers / booksSnapshot.docs.length) * 100).toFixed(1)}%`);
    
    if (booksWithRealCovers > 0) {
      console.log('\n🎉 SUCCESS: Real book covers are now available in the database!');
      console.log('📱 The Flutter app will display these real images with emoji fallbacks.');
    } else {
      console.log('\n⚠️  WARNING: No real covers found. Only emoji covers available.');
    }
    
  } catch (error) {
    console.error('❌ Error verifying covers:', error);
  } finally {
    process.exit(0);
  }
}

// Run verification
verifyRealCovers().catch(console.error);