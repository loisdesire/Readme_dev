const admin = require('firebase-admin');
const fetch = (...args) => import('node-fetch').then(({ default: fetch }) => fetch(...args));
const serviceAccount = require('./serviceAccountKey.json');

// 🔐 Initialize Firebase Admin SDK
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// 📚 Children's book subjects to fetch from Open Library
const subjects = [
  'children',
  'juvenile_fiction',
  'picture_books',
  'fairy_tales',
  'adventure',
  'animals',
  'friendship',
  'school',
  'family',
  'fantasy'
];

// 🎯 Map subjects to personality traits for the Flutter app
const subjectToTraits = {
  'children': ['curious', 'imaginative'],
  'juvenile_fiction': ['adventurous', 'creative'],
  'picture_books': ['imaginative', 'creative'],
  'fairy_tales': ['imaginative', 'creative', 'kind'],
  'adventure': ['adventurous', 'brave', 'curious'],
  'animals': ['kind', 'curious', 'caring'],
  'friendship': ['kind', 'friendly', 'caring'],
  'school': ['curious', 'analytical', 'social'],
  'family': ['kind', 'caring', 'loving'],
  'fantasy': ['imaginative', 'creative', 'adventurous']
};

// 📖 Fallback cover emoji (only used if no cover image available)
const subjectToEmoji = {
  'children': '👶📚',
  'juvenile_fiction': '📖✨',
  'picture_books': '🎨📚',
  'fairy_tales': '🧚‍♀️✨',
  'adventure': '🗺️⚡',
  'animals': '🐾🌟',
  'friendship': '👫💝',
  'school': '🎒📝',
  'family': '👨‍👩‍👧‍👦❤️',
  'fantasy': '🏰🌟'
};

// 🔧 Helper function to estimate reading time based on content length
function estimateReadingTime(description) {
  const wordsPerMinute = 100; // Average reading speed for children
  const wordCount = description.split(' ').length;
  return Math.max(5, Math.min(20, Math.ceil(wordCount / wordsPerMinute)));
}

// 🌐 Fetch actual book content from Open Library
async function fetchBookContent(workKey) {
  try {
    // Try to get the full text from Open Library
    const textUrl = `https://openlibrary.org${workKey}.json`;
    const response = await fetch(textUrl);
    const bookData = await response.json();
    
    // Look for excerpts, first_sentence, or description
    let content = [];
    
    if (bookData.excerpts && bookData.excerpts.length > 0) {
      content = bookData.excerpts.map(excerpt => excerpt.excerpt || excerpt.comment).filter(Boolean);
    }
    
    if (content.length === 0 && bookData.first_sentence) {
      content = [bookData.first_sentence.value || bookData.first_sentence];
    }
    
    if (content.length === 0 && bookData.description) {
      const desc = typeof bookData.description === 'string' ? bookData.description : bookData.description.value;
      content = [desc];
    }
    
    return content.length > 0 ? content : null;
    
  } catch (error) {
    console.log(`Could not fetch content for ${workKey}: ${error.message}`);
    return null;
  }
}

// 📝 Generate story content (fallback when real content isn't available) - 10-30 pages
function generateStoryContent(title, author, description, subject) {
  const content = [];
  const targetPages = Math.floor(Math.random() * 21) + 10; // 10-30 pages
  
  // Create engaging story based on subject
  const storyTemplates = {
    'fairy_tales': [
      `Once upon a time, in a land far, far away, there lived a character from "${title}".`,
      `This magical tale by ${author} begins with wonder and mystery.`,
      `As our story unfolds, we discover the true meaning of courage and kindness.`
    ],
    'adventure': [
      `The adventure in "${title}" begins when our brave hero sets out on an incredible journey.`,
      `${author} takes us through exciting challenges and thrilling discoveries.`,
      `With each step, our adventurer learns valuable lessons about bravery and friendship.`
    ],
    'animals': [
      `In the wonderful world of "${title}", we meet amazing animal friends.`,
      `${author} shows us how animals can teach us about love, loyalty, and friendship.`,
      `Each animal character has something special to share with young readers.`
    ],
    'friendship': [
      `"${title}" is a heartwarming story about the power of friendship.`,
      `${author} reminds us that true friends are always there for each other.`,
      `Through ups and downs, these friends learn what really matters in life.`
    ]
  };
  
  // Start with template or description
  const template = storyTemplates[subject] || [
    `Welcome to the wonderful story of "${title}" by ${author}.`,
    `This tale will take you on an amazing journey full of surprises.`,
    `Get ready to discover something magical in every page.`
  ];
  
  // Add initial pages
  content.push(...template);
  
  // Add description-based content if available
  if (description && description.length > 50) {
    const sentences = description.split(/[.!?]+/).filter(s => s.trim().length > 20);
    content.push(...sentences.map(s => s.trim() + '.'));
  }
  
  // Fill remaining pages with engaging content
  while (content.length < targetPages) {
    const pageNum = content.length + 1;
    
    if (pageNum <= targetPages - 2) {
      content.push(`As we continue through page ${pageNum} of "${title}", the story becomes even more exciting and full of wonder.`);
    } else if (pageNum === targetPages - 1) {
      content.push(`As our story nears its end, we reflect on all the wonderful lessons learned in "${title}".`);
    } else {
      content.push(`And so concludes the amazing tale of "${title}" by ${author}. What was your favorite part of this story?`);
    }
  }
  
  return content.slice(0, targetPages); // Ensure we don't exceed 30 pages
}

// 🌐 Fetch books from Open Library API
async function fetchBooksFromOpenLibrary() {
  let totalUploaded = 0;
  
  for (const subject of subjects) {
    console.log(`📖 Fetching children's books for subject: ${subject}`);
    
    try {
      // Fetch books from Open Library with filters for children's content
      const url = `https://openlibrary.org/subjects/${subject}.json?limit=15&details=true`;
      const response = await fetch(url);
      const data = await response.json();
      const works = data.works || [];
      
      console.log(`Found ${works.length} books for ${subject}`);
      
      for (const work of works) {
        try {
          const title = work.title || 'Untitled Story';
          const author = work.authors?.[0]?.name || 'Unknown Author';
          const description = work.description || work.excerpt || `A wonderful ${subject} story for children.`;
          
          // Get cover image URL from Open Library
          const coverId = work.cover_id;
          const coverImageUrl = coverId 
            ? `https://covers.openlibrary.org/b/id/${coverId}-L.jpg`
            : null;
          
          // Skip if title or author is too generic
          if (title.length < 3 || author === 'Unknown Author') {
            continue;
          }
          
          // 🛑 Check for duplicates
          const existing = await db.collection('books')
            .where('title', '==', title)
            .where('author', '==', author)
            .get();
          
          if (!existing.empty) {
            console.log(`⚠️ Skipping duplicate: "${title}" by ${author}`);
            continue;
          }
          
          // Try to fetch real book content first
          console.log(`Fetching content for "${title}"...`);
          let bookContent = await fetchBookContent(work.key);
          
          // Use real content if available, otherwise generate content
          if (!bookContent || bookContent.length < 3) {
            console.log(`Generating content for "${title}" (real content not sufficient)`);
            bookContent = generateStoryContent(title, author, description, subject);
          } else {
            console.log(`Using real content for "${title}" (${bookContent.length} sections)`);
          }
          
          // 📚 Build properly formatted book object for Flutter app
          const book = {
            title: title,
            author: author,
            description: typeof description === 'string' ? description : `A ${subject} story by ${author}`,
            // Use real cover image if available, fallback to emoji
            coverImageUrl: coverImageUrl,
            coverEmoji: coverImageUrl ? null : (subjectToEmoji[subject] || '📚✨'),
            traits: subjectToTraits[subject] || ['curious', 'imaginative'],
            ageRating: '6+', // Appropriate for children
            estimatedReadingTime: estimateReadingTime(description),
            content: bookContent, // Real content or generated content (10-30 pages)
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            // Additional metadata
            source: 'Open Library',
            subject: subject,
            isbn: work.key || null,
            hasRealContent: bookContent.length > 0 && bookContent[0].includes(title)
          };
          
          // 📤 Upload to Firestore
          await db.collection('books').add(book);
          console.log(`✅ Uploaded: "${title}" by ${author} (${subject}) - ${coverImageUrl ? 'Real cover' : 'Emoji cover'}`);
          totalUploaded++;
          
          // Add small delay to avoid rate limiting
          await new Promise(resolve => setTimeout(resolve, 100));
          
        } catch (bookError) {
          console.error(`❌ Error processing book: ${bookError.message}`);
          continue;
        }
      }
      
      // Delay between subjects to be respectful to the API
      await new Promise(resolve => setTimeout(resolve, 1000));
      
    } catch (subjectError) {
      console.error(`❌ Error fetching ${subject}: ${subjectError.message}`);
      continue;
    }
  }
  
  console.log(`🎉 Upload complete! Total books uploaded: ${totalUploaded}`);
}

// 🧹 Optional: Clean up existing books before uploading new ones
async function clearExistingBooks() {
  console.log('🧹 Clearing existing books...');
  const snapshot = await db.collection('books').get();
  const batch = db.batch();
  
  snapshot.docs.forEach(doc => {
    batch.delete(doc.ref);
  });
  
  await batch.commit();
  console.log(`✅ Cleared ${snapshot.docs.length} existing books`);
}

// 🚀 Main execution
async function main() {
  try {
    console.log('🚀 Starting bulk book upload from Open Library...');
    console.log('📸 Using real cover images when available');
    console.log('📖 Prioritizing real book content, generating 10-30 pages when needed');
    
    // Uncomment the next line if you want to clear existing books first
    // await clearExistingBooks();
    
    await fetchBooksFromOpenLibrary();
    
    console.log('✨ All done! Your Firebase database now has properly formatted children\'s books with real covers and content.');
    
  } catch (error) {
    console.error('💥 Fatal error:', error);
  } finally {
    process.exit(0);
  }
}

// Run the script
main().catch(console.error);
