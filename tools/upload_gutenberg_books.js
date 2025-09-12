const admin = require('firebase-admin');
const fetch = (...args) => import('node-fetch').then(({ default: fetch }) => fetch(...args));
const serviceAccount = require('./serviceAccountKey.json');

// 🔐 Initialize Firebase Admin SDK
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// 📚 Expanded curated list of high-quality children's books from Project Gutenberg (80 books)
const curatedBooks = [
  // PRIORITY 1: Core Classic Children's Literature (20 books)
  {
    id: 11,
    title: "Alice's Adventures in Wonderland",
    author: "Lewis Carroll",
    expectedTraits: ['imaginative', 'curious', 'adventurous'],
    priority: 1,
  },
  {
    id: 12,
    title: "Through the Looking-Glass",
    author: "Lewis Carroll", 
    expectedTraits: ['imaginative', 'curious', 'creative'],
    priority: 1,
  },
  {
    id: 113,
    title: "The Secret Garden",
    author: "Frances Hodgson Burnett",
    expectedTraits: ['kind', 'curious', 'caring'],
    priority: 1,
  },
  {
    id: 146,
    title: "A Little Princess",
    author: "Frances Hodgson Burnett",
    expectedTraits: ['brave', 'kind', 'imaginative'],
    priority: 1,
  },
  {
    id: 55,
    title: "The Wonderful Wizard of Oz", 
    author: "L. Frank Baum",
    expectedTraits: ['adventurous', 'brave', 'curious'],
    priority: 1,
  },
  {
    id: 16,
    title: "Peter Pan",
    author: "J. M. Barrie",
    expectedTraits: ['adventurous', 'imaginative', 'brave'],
    priority: 1,
  },
  {
    id: 236,
    title: "The Jungle Book",
    author: "Rudyard Kipling",
    expectedTraits: ['adventurous', 'brave', 'curious'],
    priority: 1,
  },
  {
    id: 21,
    title: "Aesop's Fables",
    author: "Aesop",
    expectedTraits: ['wise', 'curious', 'thoughtful'],
    priority: 1,
  },
  {
    id: 2591,
    title: "Grimms' Fairy Tales",
    author: "Jacob Grimm and Wilhelm Grimm",
    expectedTraits: ['imaginative', 'brave', 'kind'],
    priority: 1,
  },
  {
    id: 289,
    title: "The Wind in the Willows",
    author: "Kenneth Grahame",
    expectedTraits: ['adventurous', 'friendly', 'kind'],
    priority: 1,
  },
  {
    id: 74,
    title: "The Adventures of Tom Sawyer",
    author: "Mark Twain",
    expectedTraits: ['adventurous', 'mischievous', 'clever'],
    priority: 1,
  },
  {
    id: 514,
    title: "Little Women",
    author: "Louisa May Alcott",
    expectedTraits: ['family-loving', 'kind', 'determined'],
    priority: 1,
  },
  {
    id: 1322,
    title: "Heidi",
    author: "Johanna Spyri",
    expectedTraits: ['kind', 'nature-loving', 'cheerful'],
    priority: 1,
  },
  {
    id: 271,
    title: "Black Beauty",
    author: "Anna Sewell",
    expectedTraits: ['kind', 'caring', 'empathetic'],
    priority: 1,
  },
  {
    id: 120,
    title: "Treasure Island",
    author: "Robert Louis Stevenson", 
    expectedTraits: ['adventurous', 'brave', 'curious'],
    priority: 1,
  },
  {
    id: 45,
    title: "Anne of Green Gables",
    author: "L. M. Montgomery",
    expectedTraits: ['imaginative', 'spirited', 'kind'],
    priority: 1,
  },
  {
    id: 1874,
    title: "The Railway Children",
    author: "E. Nesbit",
    expectedTraits: ['adventurous', 'kind', 'family-loving'],
    priority: 1,
  },
  {
    id: 968,
    title: "A Christmas Carol",
    author: "Charles Dickens",
    expectedTraits: ['kind', 'transformative', 'caring'],
    priority: 1,
  },
  {
    id: 103,
    title: "Around the World in Eighty Days",
    author: "Jules Verne",
    expectedTraits: ['adventurous', 'determined', 'curious'],
    priority: 1,
  },
  {
    id: 164,
    title: "Twenty Thousand Leagues under the Sea",
    author: "Jules Verne",
    expectedTraits: ['curious', 'adventurous', 'scientific'],
    priority: 1,
  },

  // PRIORITY 2: Extended Children's Classics (25 books)
  {
    id: 2781,
    title: "Just So Stories",
    author: "Rudyard Kipling",
    expectedTraits: ['imaginative', 'curious', 'creative'],
    priority: 2,
  },
  {
    id: 1257,
    title: "The Swiss Family Robinson",
    author: "Johann David Wyss",
    expectedTraits: ['resourceful', 'family-oriented', 'adventurous'],
    priority: 2,
  },
  {
    id: 521,
    title: "Robinson Crusoe",
    author: "Daniel Defoe",
    expectedTraits: ['resourceful', 'adventurous', 'determined'],
    priority: 2,
  },
  {
    id: 36,
    title: "The War of the Worlds",
    author: "H. G. Wells",
    expectedTraits: ['curious', 'scientific', 'adventurous'],
    priority: 2,
  },
  {
    id: 35,
    title: "The Invisible Man",
    author: "H. G. Wells",
    expectedTraits: ['scientific', 'curious', 'thought-provoking'],
    priority: 2,
  },
  {
    id: 5230,
    title: "The Time Machine",
    author: "H. G. Wells",
    expectedTraits: ['curious', 'scientific', 'adventurous'],
    priority: 2,
  },
  {
    id: 76,
    title: "Adventures of Huckleberry Finn",
    author: "Mark Twain",
    expectedTraits: ['adventurous', 'free-spirited', 'moral'],
    priority: 2,
  },
  {
    id: 37106,
    title: "Little Men",
    author: "Louisa May Alcott",
    expectedTraits: ['educational', 'family-oriented', 'moral'],
    priority: 2,
  },
  {
    id: 3345,
    title: "An Old-Fashioned Girl",
    author: "Louisa May Alcott",
    expectedTraits: ['principled', 'kind', 'traditional'],
    priority: 2,
  },
  {
    id: 5097,
    title: "Eight Cousins",
    author: "Louisa May Alcott",
    expectedTraits: ['family-oriented', 'strong', 'growing'],
    priority: 2,
  },
  {
    id: 28054,
    title: "The Story of Doctor Dolittle",
    author: "Hugh Lofting",
    expectedTraits: ['kind', 'animal-loving', 'adventurous'],
    priority: 2,
  },
  {
    id: 32032,
    title: "The Enchanted Castle",
    author: "E. Nesbit",
    expectedTraits: ['imaginative', 'magical', 'adventurous'],
    priority: 2,
  },
  {
    id: 4085,
    title: "The Adventures of Pinocchio",
    author: "Carlo Collodi",
    expectedTraits: ['learning', 'honest', 'growing'],
    priority: 2,
  },
  {
    id: 28885,
    title: "Pollyanna",
    author: "Eleanor H. Porter",
    expectedTraits: ['optimistic', 'kind', 'cheerful'],
    priority: 2,
  },
  {
    id: 8581,
    title: "Rebecca of Sunnybrook Farm",
    author: "Kate Douglas Wiggin",
    expectedTraits: ['spirited', 'optimistic', 'kind'],
    priority: 2,
  },
  {
    id: 4016,
    title: "What Katy Did",
    author: "Susan Coolidge",
    expectedTraits: ['learning', 'family-oriented', 'growing'],
    priority: 2,
  },
  {
    id: 34,
    title: "The Princess and the Goblin",
    author: "George MacDonald",
    expectedTraits: ['brave', 'kind', 'imaginative'],
    priority: 2,
  },
  {
    id: 1934,
    title: "Anne of the Island",
    author: "L. M. Montgomery",
    expectedTraits: ['imaginative', 'mature', 'determined'],
    priority: 2,
  },
  {
    id: 67098,
    title: "Five Children and It",
    author: "E. Nesbit",
    expectedTraits: ['adventurous', 'imaginative', 'learning'],
    priority: 2,
  },
  {
    id: 6761,
    title: "Five Little Peppers and How They Grew",
    author: "Margaret Sidney",
    expectedTraits: ['family-oriented', 'resourceful', 'optimistic'],
    priority: 2,
  },
  {
    id: 8689,
    title: "Jack and Jill",
    author: "Louisa May Alcott",
    expectedTraits: ['friendship', 'recovery', 'community'],
    priority: 2,
  },
  {
    id: 2366,
    title: "Under the Lilacs",
    author: "Louisa May Alcott",
    expectedTraits: ['kind', 'gentle', 'caring'],
    priority: 2,
  },
  {
    id: 8492,
    title: "The Story of the Treasure Seekers",
    author: "E. Nesbit",
    expectedTraits: ['adventurous', 'resourceful', 'family-oriented'],
    priority: 2,
  },
  {
    id: 158,
    title: "Emma",
    author: "Jane Austen",
    expectedTraits: ['social', 'learning', 'romantic'],
    priority: 2,
  },
  {
    id: 1342,
    title: "Pride and Prejudice",
    author: "Jane Austen",
    expectedTraits: ['romantic', 'witty', 'social'],
    priority: 2,
  },

  // PRIORITY 3: Classic Literature for Advanced Readers (20 books)
  {
    id: 98,
    title: "A Tale of Two Cities",
    author: "Charles Dickens",
    expectedTraits: ['historical', 'heroic', 'dramatic'],
    priority: 3,
  },
  {
    id: 1400,
    title: "Great Expectations",
    author: "Charles Dickens",
    expectedTraits: ['growing', 'learning', 'social'],
    priority: 3,
  },
  {
    id: 730,
    title: "Oliver Twist",
    author: "Charles Dickens",
    expectedTraits: ['resilient', 'kind', 'survivor'],
    priority: 3,
  },
  {
    id: 1023,
    title: "Bleak House",
    author: "Charles Dickens",
    expectedTraits: ['just', 'compassionate', 'social'],
    priority: 3,
  },
  {
    id: 766,
    title: "Wuthering Heights",
    author: "Emily Brontë",
    expectedTraits: ['passionate', 'dramatic', 'complex'],
    priority: 3,
  },
  {
    id: 135,
    title: "Les Misérables",
    author: "Victor Hugo",
    expectedTraits: ['just', 'compassionate', 'heroic'],
    priority: 3,
  },
  {
    id: 2500,
    title: "Don Quixote",
    author: "Miguel de Cervantes",
    expectedTraits: ['idealistic', 'adventurous', 'humorous'],
    priority: 3,
  },
  {
    id: 844,
    title: "The Importance of Being Earnest",
    author: "Oscar Wilde",
    expectedTraits: ['witty', 'clever', 'humorous'],
    priority: 3,
  },
  {
    id: 1661,
    title: "The Adventures of Sherlock Holmes",
    author: "Arthur Conan Doyle",
    expectedTraits: ['analytical', 'curious', 'clever'],
    priority: 3,
  },
  {
    id: 1184,
    title: "The Count of Monte Cristo",
    author: "Alexandre Dumas",
    expectedTraits: ['determined', 'clever', 'just'],
    priority: 3,
  },
  {
    id: 1259,
    title: "Twenty Years After",
    author: "Alexandre Dumas",
    expectedTraits: ['brave', 'loyal', 'adventurous'],
    priority: 3,
  },
  {
    id: 1727,
    title: "The Odyssey",
    author: "Homer",
    expectedTraits: ['adventurous', 'determined', 'heroic'],
    priority: 3,
  },
  {
    id: 3207,
    title: "The Iliad",
    author: "Homer",
    expectedTraits: ['brave', 'heroic', 'loyal'],
    priority: 3,
  },
  {
    id: 1065,
    title: "The Raven and Other Poems",
    author: "Edgar Allan Poe",
    expectedTraits: ['poetic', 'atmospheric', 'literary'],
    priority: 3,
  },
  {
    id: 1524,
    title: "Hamlet",
    author: "William Shakespeare",
    expectedTraits: ['thoughtful', 'dramatic', 'complex'],
    priority: 3,
  },
  {
    id: 1112,
    title: "Romeo and Juliet",
    author: "William Shakespeare",
    expectedTraits: ['romantic', 'passionate', 'tragic'],
    priority: 3,
  },
  {
    id: 174,
    title: "The Picture of Dorian Gray",
    author: "Oscar Wilde",
    expectedTraits: ['philosophical', 'artistic', 'moral'],
    priority: 3,
  },
  {
    id: 209,
    title: "The Turn of the Screw",
    author: "Henry James",
    expectedTraits: ['mysterious', 'atmospheric', 'psychological'],
    priority: 3,
  },
  {
    id: 2265,
    title: "The Divine Comedy",
    author: "Dante Alighieri",
    expectedTraits: ['spiritual', 'determined', 'wise'],
    priority: 3,
  },
  {
    id: 1998,
    title: "Paradise Lost",
    author: "John Milton",
    expectedTraits: ['philosophical', 'epic', 'moral'],
    priority: 3,
  },

  // PRIORITY 4: Additional Quality Stories (15 books)
  {
    id: 2403,
    title: "The Mysterious Island",
    author: "Jules Verne",
    expectedTraits: ['resourceful', 'scientific', 'adventurous'],
    priority: 4,
  },
  {
    id: 4078,
    title: "The Food of the Gods",
    author: "H. G. Wells",
    expectedTraits: ['scientific', 'thought-provoking', 'curious'],
    priority: 4,
  },
  {
    id: 5946,
    title: "When the Sleeper Wakes",
    author: "H. G. Wells",
    expectedTraits: ['futuristic', 'thought-provoking', 'adventurous'],
    priority: 4,
  },
  {
    id: 3254,
    title: "Jo's Boys",
    author: "Louisa May Alcott",
    expectedTraits: ['mature', 'educational', 'family-oriented'],
    priority: 4,
  },
  {
    id: 5771,
    title: "Rose in Bloom",
    author: "Louisa May Alcott",
    expectedTraits: ['mature', 'kind', 'principled'],
    priority: 4,
  },
  {
    id: 33511,
    title: "The Bobbsey Twins at the Seashore",
    author: "Laura Lee Hope",
    expectedTraits: ['family-oriented', 'adventurous', 'friendly'],
    priority: 4,
  },
  {
    id: 8127,
    title: "The Land of Oz",
    author: "L. Frank Baum",
    expectedTraits: ['imaginative', 'brave', 'magical'],
    priority: 4,
  },
  {
    id: 30254,
    title: "The Blue Fairy Book",
    author: "Andrew Lang",
    expectedTraits: ['imaginative', 'magical', 'traditional'],
    priority: 4,
  },
  {
    id: 1974,
    title: "The Arabian Nights",
    author: "Anonymous",
    expectedTraits: ['imaginative', 'adventurous', 'magical'],
    priority: 4,
  },
  {
    id: 4517,
    title: "The Hunchback of Notre Dame",
    author: "Victor Hugo",
    expectedTraits: ['compassionate', 'dramatic', 'historical'],
    priority: 4,
  },
  {
    id: 2554,
    title: "Crime and Punishment",
    author: "Fyodor Dostoyevsky",
    expectedTraits: ['moral', 'psychological', 'deep'],
    priority: 4,
  },
  {
    id: 2600,
    title: "War and Peace",
    author: "Leo Tolstoy",
    expectedTraits: ['epic', 'historical', 'philosophical'],
    priority: 4,
  },
  {
    id: 5200,
    title: "Metamorphosis",
    author: "Franz Kafka",
    expectedTraits: ['philosophical', 'thought-provoking', 'symbolic'],
    priority: 4,
  },
  {
    id: 4300,
    title: "Ulysses",
    author: "James Joyce",
    expectedTraits: ['literary', 'complex', 'artistic'],
    priority: 4,
  },
  {
    id: 19993,
    title: "Andersen's Fairy Tales",
    author: "Hans Christian Andersen",
    expectedTraits: ['imaginative', 'touching', 'moral'],
    priority: 4,
  }
];

// 🎯 Map traits for personality matching in the Flutter app
const traitMapping = {
  'imaginative': ['creative', 'dreamy', 'artistic'],
  'adventurous': ['brave', 'explorer', 'daring'],
  'curious': ['inquisitive', 'thoughtful', 'analytical'],
  'kind': ['caring', 'gentle', 'empathetic'],
  'brave': ['courageous', 'bold', 'heroic'],
  'wise': ['thoughtful', 'analytical', 'mature'],
  'friendly': ['social', 'outgoing', 'warm'],
  'family-loving': ['caring', 'loyal', 'loving'],
  'spirited': ['energetic', 'lively', 'enthusiastic'],
  'empathetic': ['caring', 'sensitive', 'understanding'],
};

// 🔧 Helper functions for text processing
function estimateReadingTime(wordCount) {
  const wordsPerMinute = 150; // Average reading speed for children
  return Math.ceil(wordCount / wordsPerMinute);
}

function estimateReadingHours(wordCount) {
  const minutes = estimateReadingTime(wordCount);
  return Math.floor(minutes / 60);
}

function countWords(text) {
  if (!text || text.trim().length === 0) return 0;
  return text.trim().split(/\s+/).length;
}

function determineReadingLevel(wordCount, title, author) {
  // Base level on word count and known authors
  let level = 0;
  
  // Word count indicators
  if (wordCount > 50000) level += 3; // Very long books
  else if (wordCount > 25000) level += 2; // Long books  
  else if (wordCount > 10000) level += 1; // Medium books
  
  // Author-based adjustments
  if (author.includes('Carroll') || author.includes('Baum') || title.includes('Fairy Tales')) {
    level += 0; // Keep easier
  } else if (author.includes('Stevenson') || author.includes('Montgomery')) {
    level += 1; // Slightly more advanced
  }
  
  // Title-based adjustments
  if (title.includes('Fables') || title.includes('Just So')) {
    level -= 1; // Shorter stories, easier
  }
  
  // Determine final level
  if (level <= 1) return 'Easy';
  if (level <= 3) return 'Medium'; 
  return 'Advanced';
}

function determineContentType(wordCount, title) {
  if (title.includes('Fables') || title.includes('Just So') || title.includes('Tales')) {
    return 'collection'; // Collection of stories
  } else if (wordCount < 15000) {
    return 'story'; // Short story or novella
  } else {
    return 'novel'; // Full novel
  }
}

function processChapters(text, title, maxChapters = 25) {
  console.log(`Processing chapters for "${title}"...`);
  
  // Clean the text first
  let cleanedText = text
    .replace(/\*\*\* START OF [\s\S]*?\*\*\*/i, '') // Remove Gutenberg header
    .replace(/\*\*\* END OF [\s\S]*$/i, '')         // Remove Gutenberg footer
    .replace(/\r\n/g, '\n')                         // Normalize line endings
    .replace(/\n{3,}/g, '\n\n')                     // Reduce excessive breaks
    .trim();

  if (!cleanedText || cleanedText.length < 100) {
    console.log(`⚠️ Text too short for "${title}"`);
    return null;
  }

  const wordCount = countWords(cleanedText);
  console.log(`Word count: ${wordCount} words`);

  // Detect chapter breaks
  const chapterPatterns = [
    /(?:^|\n\n+)\s*(?:CHAPTER|Chapter)\s+([IVXLC]+|\d+)[\s.:]+([^\n]*)/gm,
    /(?:^|\n\n+)\s*([IVXLC]+|\d+)\.?\s+([^\n]{1,50})\n/gm,
    /(?:^|\n\n+)\s*([^\n]{1,50})\n(?=\s*\n)/gm,
  ];

  let chapterBreaks = [];
  let pattern = null;

  // Find the best pattern that gives reasonable chapters
  for (let i = 0; i < chapterPatterns.length; i++) {
    pattern = chapterPatterns[i];
    chapterBreaks = [];
    let match;
    
    while ((match = pattern.exec(cleanedText)) !== null) {
      chapterBreaks.push({
        index: match.index,
        number: match[1] || chapterBreaks.length + 1,
        title: match[2] || `Chapter ${chapterBreaks.length + 1}`,
      });
    }
    
    // Reset regex for next iteration
    pattern.lastIndex = 0;
    
    // If we found reasonable chapters, use them
    if (chapterBreaks.length >= 2 && chapterBreaks.length <= maxChapters) {
      console.log(`Found ${chapterBreaks.length} chapters using pattern ${i + 1}`);
      break;
    }
  }

  // If no good chapter breaks found, create artificial ones
  if (chapterBreaks.length < 2 || chapterBreaks.length > maxChapters) {
    console.log(`Creating artificial chapters for "${title}"`);
    chapterBreaks = [];
    
    const targetWordsPerChapter = Math.min(2000, Math.max(800, wordCount / 15));
    const words = cleanedText.split(/\s+/);
    
    for (let i = 0; i < words.length; i += targetWordsPerChapter) {
      const chapterNumber = Math.floor(i / targetWordsPerChapter) + 1;
      chapterBreaks.push({
        index: i,
        number: chapterNumber,
        title: `Part ${chapterNumber}`,
      });
    }
  }

  // Process chapters
  const chapters = [];
  for (let i = 0; i < chapterBreaks.length; i++) {
    const currentBreak = chapterBreaks[i];
    const nextBreak = chapterBreaks[i + 1];
    
    let chapterText;
    if (nextBreak) {
      chapterText = cleanedText.substring(currentBreak.index, nextBreak.index);
    } else {
      chapterText = cleanedText.substring(currentBreak.index);
    }
    
    chapterText = chapterText.trim();
    if (chapterText.length < 50) continue; // Skip very short chapters
    
    // Split chapter into pages (max 300 words per page for comfortable reading)
    const chapterWords = chapterText.split(/\s+/);
    const pages = [];
    const wordsPerPage = 250;
    
    for (let j = 0; j < chapterWords.length; j += wordsPerPage) {
      const pageWords = chapterWords.slice(j, j + wordsPerPage);
      const pageText = pageWords.join(' ');
      if (pageText.trim().length > 0) {
        pages.push(pageText);
      }
    }
    
    if (pages.length > 0) {
      const chapterWordCount = countWords(chapterText);
      chapters.push({
        number: chapters.length + 1,
        title: currentBreak.title.trim() || `Chapter ${chapters.length + 1}`,
        pages: pages,
        wordCount: chapterWordCount,
        estimatedMinutes: estimateReadingTime(chapterWordCount),
      });
    }
  }

  console.log(`Created ${chapters.length} chapters with ${chapters.reduce((sum, c) => sum + c.pages.length, 0)} total pages`);
  return chapters;
}

// 🌐 Fetch book data from Project Gutenberg
async function fetchGutenbergBook(bookInfo) {
  const { id, title, author, expectedTraits } = bookInfo;
  
  try {
    console.log(`📖 Fetching "${title}" by ${author} (ID: ${id})...`);
    
    // Get book metadata from Gutendex API
    const metadataUrl = `https://gutendex.com/books/${id}`;
    const metadataResponse = await fetch(metadataUrl);
    
    if (!metadataResponse.ok) {
      throw new Error(`Failed to fetch metadata: ${metadataResponse.status}`);
    }
    
    const metadata = await metadataResponse.json();
    
    // Find text download URL with more flexible approach
    const textFormats = [
      'text/plain; charset=utf-8',
      'text/plain',
      'application/plain',
      'text/plain; charset=us-ascii',
    ];
    
    let textUrl = null;
    
    // First try the preferred formats
    for (const format of textFormats) {
      if (metadata.formats && metadata.formats[format]) {
        textUrl = metadata.formats[format];
        break;
      }
    }
    
    // If no exact match, look for any text format
    if (!textUrl && metadata.formats) {
      const formatKeys = Object.keys(metadata.formats);
      const textFormatKey = formatKeys.find(key => 
        key.includes('text/plain') || 
        key.includes('text') ||
        metadata.formats[key].includes('.txt')
      );
      
      if (textFormatKey) {
        textUrl = metadata.formats[textFormatKey];
      }
    }
    
    // If still no text URL, try to construct one from Gutenberg ID
    if (!textUrl) {
      // Try common Gutenberg text URL patterns
      const possibleUrls = [
        `https://www.gutenberg.org/files/${id}/${id}-0.txt`,
        `https://www.gutenberg.org/files/${id}/${id}.txt`,
        `https://www.gutenberg.org/ebooks/${id}.txt.utf-8`,
      ];
      
      // Test which one works
      for (const url of possibleUrls) {
        try {
          const testResponse = await fetch(url, { method: 'HEAD' });
          if (testResponse.ok) {
            textUrl = url;
            console.log(`📄 Found text at: ${url}`);
            break;
          }
        } catch (e) {
          // Continue to next URL
        }
      }
    }
    
    if (!textUrl) {
      throw new Error('No plain text format available after trying multiple approaches');
    }
    
    console.log(`📄 Downloading text from: ${textUrl}`);
    
    // Download the text
    const textResponse = await fetch(textUrl);
    if (!textResponse.ok) {
      throw new Error(`Failed to download text: ${textResponse.status}`);
    }
    
    const fullText = await textResponse.text(); // Fix: Use .text() method directly
    const wordCount = countWords(fullText);
    
    console.log(`✅ Downloaded ${wordCount} words`);
    
    // Process into chapters
    const chapters = processChapters(fullText, title);
    
    if (!chapters || chapters.length === 0) {
      throw new Error('Failed to process chapters');
    }
    
    // Calculate reading metrics
    const estimatedMinutes = estimateReadingTime(wordCount);
    const estimatedHours = estimateReadingHours(wordCount);
    const readingLevel = determineReadingLevel(wordCount, title, author);
    const contentType = determineContentType(wordCount, title);
    
    // Get cover image URL if available
    let coverImageUrl = null;
    const coverFormats = ['image/jpeg', 'image/png'];
    for (const format of coverFormats) {
      if (metadata.formats[format]) {
        coverImageUrl = metadata.formats[format];
        break;
      }
    }
    
    // Build traits list
    const traits = [...expectedTraits];
    // Add mapped traits for variety
    expectedTraits.forEach(trait => {
      if (traitMapping[trait]) {
        traits.push(...traitMapping[trait].slice(0, 2)); // Add up to 2 mapped traits
      }
    });
    
    // Remove duplicates and limit to 6 traits
    const uniqueTraits = [...new Set(traits)].slice(0, 6);
    
    const bookData = {
      title: title,
      author: author,
      description: metadata.subjects?.slice(0, 3).join(', ') || `A classic ${contentType} by ${author}`,
      coverImageUrl: coverImageUrl, // Real cover if available
      coverEmoji: null, // Will use real covers from previous implementation
      traits: uniqueTraits,
      ageRating: readingLevel === 'Advanced' ? '10+' : '6+',
      estimatedReadingTime: Math.min(estimatedMinutes, 999), // Cap at 999 minutes
      content: [], // Empty - using chapters instead
      chapters: chapters,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      source: 'Project Gutenberg',
      hasRealContent: true,
      contentType: contentType,
      wordCount: wordCount,
      readingLevel: readingLevel,
      estimatedReadingHours: estimatedHours,
      gutenbergMetadata: {
        gutenbergId: id,
        downloadCount: metadata.download_count,
        subjects: metadata.subjects || [],
        languages: metadata.languages || ['en'],
        originalFormats: Object.keys(metadata.formats || {}),
      },
    };
    
    console.log(`📊 Book stats: ${wordCount} words, ${chapters.length} chapters, ${readingLevel} level, ${estimatedHours}h reading time`);
    
    return bookData;
    
  } catch (error) {
    console.error(`❌ Error processing "${title}": ${error.message}`);
    return null;
  }
}

// 🚀 Main upload function
async function uploadGutenbergBooks() {
  let successCount = 0;
  let errorCount = 0;
  
  console.log(`🚀 Starting upload of ${curatedBooks.length} Project Gutenberg books...`);
  console.log('📚 This will replace sample content with full classic literature\n');
  
  // Sort by priority (priority 1 books first)
  const sortedBooks = curatedBooks.sort((a, b) => a.priority - b.priority);
  
  for (const bookInfo of sortedBooks) {
    try {
      // Check for existing book
      const existing = await db.collection('books')
        .where('title', '==', bookInfo.title)
        .where('source', '==', 'Project Gutenberg')
        .get();
      
      if (!existing.empty) {
        console.log(`⚠️ Skipping "${bookInfo.title}" - already exists`);
        continue;
      }
      
      // Fetch and process book
      const bookData = await fetchGutenbergBook(bookInfo);
      
      if (bookData) {
        // Upload to Firestore
        await db.collection('books').add(bookData);
        console.log(`✅ Uploaded: "${bookInfo.title}" - ${bookData.chapters.length} chapters, ${bookData.readingLevel} level`);
        successCount++;
      } else {
        errorCount++;
      }
      
      // Add delay to be respectful to the API
      await new Promise(resolve => setTimeout(resolve, 2000));
      
    } catch (error) {
      console.error(`❌ Failed to upload "${bookInfo.title}": ${error.message}`);
      errorCount++;
    }
  }
  
  console.log(`\n🎉 Upload complete!`);
  console.log(`✅ Successfully uploaded: ${successCount} books`);
  console.log(`❌ Errors: ${errorCount} books`);
  console.log(`📚 Total classic literature books now available for children!`);
}

// 🧹 Optional: Remove sample books (keep Open Library books)
async function cleanupSampleBooks() {
  console.log('🧹 Removing old sample books...');
  
  const sampleTitles = [
    'The Enchanted Monkey',
    'Fairytale Adventures', 
    'Space Explorers',
    'The Brave Little Dragon',
    'Ocean Friends',
  ];
  
  let removedCount = 0;
  
  for (const title of sampleTitles) {
    const snapshot = await db.collection('books').where('title', '==', title).get();
    
    for (const doc of snapshot.docs) {
      await doc.ref.delete();
      console.log(`🗑️ Removed: "${title}"`);
      removedCount++;
    }
  }
  
  console.log(`✅ Removed ${removedCount} sample books`);
}

// 🎯 Main execution
async function main() {
  try {
    console.log('📖 PROJECT GUTENBERG INTEGRATION STARTING...');
    console.log('🎯 Goal: Replace sample content with full classic children\'s literature\n');
    
    // Optional: Clean up sample books first
    // Uncomment if you want to remove the short sample books
    // await cleanupSampleBooks();
    
    await uploadGutenbergBooks();
    
    console.log('\n✨ INTEGRATION COMPLETE!');
    console.log('🎉 The ReadMe app now has full-length classic children\'s books!');
    console.log('📚 Users can now enjoy complete stories like Alice in Wonderland, Peter Pan, and more.');
    
  } catch (error) {
    console.error('💥 Fatal error:', error);
  } finally {
    process.exit(0);
  }
}

// Run the script
main().catch(console.error);