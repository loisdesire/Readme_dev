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

// Extract main character name from title
function extractMainCharacter(title, subject) {
  const titleWords = title.toLowerCase().split(/[\s\-_]+/);
  
  // Common character names in children's books
  const commonNames = ['alice', 'peter', 'lucy', 'charlie', 'max', 'ruby', 'sam', 'lily', 'jack', 'emma', 'oliver', 'sophie', 'ben', 'mia'];
  const foundName = titleWords.find(word => commonNames.includes(word));
  if (foundName) return foundName.charAt(0).toUpperCase() + foundName.slice(1);
  
  // Animal names
  const animalNames = ['Fluffy', 'Whiskers', 'Buddy', 'Bella', 'Charlie', 'Luna', 'Max', 'Daisy', 'Rocky', 'Rosie'];
  if (subject === 'animals') {
    return animalNames[Math.floor(Math.random() * animalNames.length)];
  }
  
  // Default names by subject
  const defaultNames = {
    'fairy_tales': ['Princess Luna', 'Prince Leo', 'Fairy Rose'],
    'adventure': ['Captain Alex', 'Explorer Maya', 'Brave Sam'],
    'friendship': ['Emma', 'Jake', 'Lily'],
    'school': ['Alex', 'Maya', 'Sam'],
    'family': ['Little Bear', 'Sunny', 'Hope']
  };
  
  const names = defaultNames[subject] || ['Alex', 'Maya', 'Sam'];
  return names[Math.floor(Math.random() * names.length)];
}

// Generate supporting characters
function generateSupportingCharacters(subject, isAnimalStory) {
  if (isAnimalStory) {
    return ['Wise Owl', 'Friendly Rabbit', 'Helpful Squirrel'];
  }
  
  const characterSets = {
    'fairy_tales': ['Wise Wizard', 'Kind Fairy', 'Talking Tree'],
    'adventure': ['Brave Companion', 'Wise Guide', 'Loyal Friend'],
    'friendship': ['Best Friend', 'New Kid', 'Helpful Neighbor'],
    'school': ['Teacher Ms. Green', 'Classmate Tom', 'Principal Johnson'],
    'family': ['Grandma Rose', 'Uncle Joe', 'Little Sister']
  };
  
  return characterSets[subject] || ['Good Friend', 'Wise Helper', 'Kind Neighbor'];
}

// Generate beginning pages
function generateBeginning(title, mainCharacter, subject, description, pages) {
  const content = [];
  
  // Opening
  const openings = {
    'fairy_tales': `Once upon a time, in a magical kingdom filled with wonder and enchantment, there lived ${mainCharacter}. This is the story of "${title}" and the incredible adventure that changed everything.`,
    'adventure': `${mainCharacter} had always dreamed of great adventures. Little did they know that today would be the beginning of the most amazing journey of their life, as told in "${title}".`,
    'animals': `In a peaceful meadow where wildflowers danced in the breeze, ${mainCharacter} lived happily with all the woodland creatures. This is their heartwarming story from "${title}".`,
    'friendship': `${mainCharacter} was a kind and caring child who believed that friendship was the most precious treasure in the world. The story of "${title}" shows us just how right they were.`,
    'school': `Every morning, ${mainCharacter} walked to school with excitement, ready to learn something new. Today's lesson would be more special than any other, as we discover in "${title}".`,
    'family': `${mainCharacter} loved their family more than anything in the world. The warm story of "${title}" reminds us that home is where love lives.`
  };
  
  content.push(openings[subject] || `This is the wonderful story of ${mainCharacter}, whose adventure in "${title}" will warm your heart and spark your imagination.`);
  
  // Character introduction
  content.push(`${mainCharacter} was known throughout the land for their kind heart and curious spirit. Every day brought new possibilities, and ${mainCharacter} approached each one with wonder and excitement.`);
  
  // Setting description
  const settings = {
    'fairy_tales': `The kingdom where ${mainCharacter} lived was filled with crystal castles, rainbow bridges, and gardens where flowers sang gentle melodies. Magic sparkled in the air like tiny stars.`,
    'adventure': `${mainCharacter} lived in a cozy village nestled between rolling green hills and mysterious forests. Beyond the hills lay unexplored lands full of secrets waiting to be discovered.`,
    'animals': `The forest was ${mainCharacter}'s home, where ancient oak trees provided shelter and crystal streams bubbled with fresh, cool water. Every creature lived in harmony here.`,
    'friendship': `${mainCharacter}'s neighborhood was filled with friendly families, colorful gardens, and a playground where children's laughter echoed throughout the day.`,
    'school': `Sunshine Elementary was a special place where learning was an adventure. The classrooms were bright and cheerful, and every teacher cared deeply about their students.`,
    'family': `${mainCharacter}'s home was filled with warmth, love, and the delicious smell of fresh-baked cookies. Family photos lined the walls, each one telling a story of happy memories.`
  };
  
  content.push(settings[subject] || `${mainCharacter} lived in a wonderful place where every day was filled with new discoveries and the promise of adventure.`);
  
  // Add more beginning content to reach target pages
  for (let i = content.length; i < pages; i++) {
    const additionalContent = [
      `One bright morning, ${mainCharacter} woke up feeling that something special was about to happen. The sun seemed to shine a little brighter, and the birds sang a little sweeter.`,
      `As ${mainCharacter} went about their morning routine, they couldn't shake the feeling that today would be different from all the others. Little did they know how right they were.`,
      `The day started like any other, but ${mainCharacter} had learned that the most ordinary moments often held the most extraordinary surprises.`
    ];
    
    if (i - 3 < additionalContent.length) {
      content.push(additionalContent[i - 3]);
    } else {
      content.push(`${mainCharacter} took a deep breath and stepped forward, ready to embrace whatever adventure awaited them in this beautiful day.`);
    }
  }
  
  return content;
}

// Generate middle pages with plot development
function generateMiddle(mainCharacter, supportingCharacters, subject, pages, isAnimalStory, isAdventureStory) {
  const content = [];
  
  // Introduce the main challenge or quest
  const challenges = {
    'fairy_tales': `Suddenly, a gentle voice called out to ${mainCharacter}. It was ${supportingCharacters[0]}, who brought news that the kingdom's magical crystal had lost its sparkle, and only a pure heart could restore its power.`,
    'adventure': `While exploring the forest, ${mainCharacter} discovered an ancient map hidden in a hollow tree. The map showed the location of a legendary treasure that could help their village in times of need.`,
    'animals': `One day, ${supportingCharacters[1]} came running to ${mainCharacter} with worrying news. The forest's magical spring, which provided fresh water for all the animals, had mysteriously stopped flowing.`,
    'friendship': `When ${mainCharacter} arrived at school, they noticed a new student sitting alone at lunch. ${supportingCharacters[0]} explained that the new student was shy and hadn't made any friends yet.`,
    'school': `During science class, ${supportingCharacters[0]} announced a special project where students would work together to solve a real problem in their community.`,
    'family': `${mainCharacter} discovered that ${supportingCharacters[0]} had been feeling sad lately, and they were determined to find a way to bring back the joy and laughter to their beloved family member.`
  };
  
  content.push(challenges[subject] || `${mainCharacter} discovered that their help was needed to solve an important problem, and they knew they couldn't turn away from someone in need.`);
  
  // Character development and obstacles
  content.push(`At first, ${mainCharacter} felt uncertain about taking on such a big responsibility. But then they remembered all the times others had helped them, and their courage began to grow.`);
  
  content.push(`${supportingCharacters[1]} offered to help ${mainCharacter} on their quest. "Together, we can accomplish anything," they said with a warm smile that filled ${mainCharacter} with hope.`);
  
  // Journey/adventure development
  for (let i = 3; i < pages - 3; i++) {
    const middleEvents = [
      `As they traveled deeper into their adventure, ${mainCharacter} and ${supportingCharacters[1]} encountered their first real challenge. It seemed impossible at first, but they refused to give up.`,
      `${supportingCharacters[2]} appeared just when they needed help the most. "I've been watching your journey," they said kindly. "Your determination has impressed me, and I want to help."`,
      `The path ahead was not easy, but ${mainCharacter} had learned that the most worthwhile journeys often require patience, courage, and the willingness to help others along the way.`,
      `When they reached what seemed like an impossible obstacle, ${mainCharacter} remembered something important their family had taught them: "When we work together and believe in ourselves, we can overcome any challenge."`,
      `${supportingCharacters[0]} shared a piece of ancient wisdom: "The greatest treasures are not gold or jewels, but the friendships we make and the kindness we show to others."`,
      `As they continued their quest, ${mainCharacter} began to realize that they were not just solving a problem – they were discovering their own inner strength and the power of compassion.`,
      `Each step of the journey taught ${mainCharacter} something new about courage, friendship, and the importance of never giving up on what's right.`,
      `The adventure was challenging, but ${mainCharacter} found joy in every small victory and learned to appreciate the beauty in every moment of their journey.`,
      `When doubt crept into ${mainCharacter}'s mind, ${supportingCharacters[1]} reminded them of how far they had already come and how many people they had already helped along the way.`,
      `The most difficult part of their quest required ${mainCharacter} to be brave in a way they had never been before, but they found strength in the love and support of their friends.`
    ];
    
    const eventIndex = (i - 3) % middleEvents.length;
    content.push(middleEvents[eventIndex]);
  }
  
  // Building to climax
  content.push(`As they approached the most challenging part of their quest, ${mainCharacter} felt both nervous and excited. They had grown so much during this adventure, and now it was time to put everything they had learned to the test.`);
  
  content.push(`${supportingCharacters[0]} and ${supportingCharacters[1]} stood beside ${mainCharacter}, ready to face whatever came next. Their friendship had grown stronger with each challenge they had overcome together.`);
  
  content.push(`The moment of truth had arrived. ${mainCharacter} took a deep breath, remembered all the lessons they had learned, and stepped forward with confidence and determination.`);
  
  return content;
}

// Generate ending pages
function generateEnding(mainCharacter, supportingCharacters, subject, pages, title) {
  const content = [];
  
  // Climax resolution
  const resolutions = {
    'fairy_tales': `With a heart full of love and courage, ${mainCharacter} touched the magical crystal. Immediately, it began to sparkle brighter than ever before, filling the entire kingdom with warm, golden light.`,
    'adventure': `${mainCharacter} realized that the real treasure wasn't gold or jewels, but the friendships they had made and the confidence they had gained during their incredible journey.`,
    'animals': `${mainCharacter} discovered that the spring had stopped flowing because it was blocked by fallen rocks. Working together, all the forest animals cleared the path, and the crystal-clear water began to flow once again.`,
    'friendship': `${mainCharacter} approached the new student with a warm smile and invited them to join their group. Soon, the whole class was laughing and playing together, and a beautiful new friendship was born.`,
    'school': `${mainCharacter} and their classmates presented their solution to the community problem. Their hard work and creativity impressed everyone, and their idea was chosen to be implemented in the town.`,
    'family': `${mainCharacter} organized a special surprise that brought the whole family together. The house was once again filled with laughter, love, and the joy that makes a family strong.`
  };
  
  content.push(resolutions[subject] || `Through courage, kindness, and determination, ${mainCharacter} found the perfect solution to the challenge they had faced.`);
  
  // Celebration and reflection
  content.push(`Everyone celebrated ${mainCharacter}'s success, but the greatest joy came from knowing that they had made a real difference in the lives of others.`);
  
  content.push(`${supportingCharacters[0]} smiled proudly at ${mainCharacter}. "You have shown us all what it means to be truly brave and kind. Your adventure has inspired everyone around you."`);
  
  // Add more ending content if needed
  for (let i = 3; i < pages - 1; i++) {
    const endingEvents = [
      `As ${mainCharacter} looked back on their adventure, they realized how much they had grown and learned. The shy, uncertain person who had started this journey was now confident and wise.`,
      `The friends ${mainCharacter} had made during their quest would remain close forever. They had shared something special that created an unbreakable bond between them.`,
      `${mainCharacter} knew that this was just the beginning of many more adventures to come. With their newfound confidence and wonderful friends, anything was possible.`
    ];
    
    if (i - 3 < endingEvents.length) {
      content.push(endingEvents[i - 3]);
    }
  }
  
  // Final conclusion
  content.push(`And so ends the wonderful tale of "${title}". ${mainCharacter}'s adventure reminds us all that with courage, kindness, and good friends by our side, we can overcome any challenge and make the world a brighter place for everyone.`);
  
  return content;
}

// 📝 Generate rich, coherent story content - 15-40 pages
function generateStoryContent(title, author, description, subject) {
  const content = [];
  const targetPages = Math.floor(Math.random() * 26) + 15; // 15-40 pages
  
  // Extract key elements from title and description for story coherence
  const titleWords = title.toLowerCase().split(/[\s\-_]+/);
  const isAnimalStory = titleWords.some(word => ['cat', 'dog', 'bear', 'rabbit', 'fox', 'mouse', 'bird', 'lion', 'elephant', 'monkey', 'fish', 'dragon', 'unicorn'].includes(word));
  const isAdventureStory = titleWords.some(word => ['adventure', 'journey', 'quest', 'treasure', 'island', 'forest', 'mountain', 'castle', 'magic'].includes(word));
  const isFamilyStory = titleWords.some(word => ['family', 'mother', 'father', 'sister', 'brother', 'home', 'house'].includes(word));
  
  // Character names based on title
  const mainCharacter = extractMainCharacter(title, subject);
  const supportingCharacters = generateSupportingCharacters(subject, isAnimalStory);
  
  // Story structure: Beginning (20%), Middle (60%), End (20%)
  const beginningPages = Math.ceil(targetPages * 0.2);
  const middlePages = Math.ceil(targetPages * 0.6);
  const endPages = targetPages - beginningPages - middlePages;
  
  // BEGINNING - Introduction and setup
  content.push(...generateBeginning(title, mainCharacter, subject, description, beginningPages));
  
  // MIDDLE - Development and challenges
  content.push(...generateMiddle(mainCharacter, supportingCharacters, subject, middlePages, isAnimalStory, isAdventureStory));
  
  // END - Resolution and conclusion
  content.push(...generateEnding(mainCharacter, supportingCharacters, subject, endPages, title));
  
  return content.slice(0, targetPages);
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
          
          // Use real content if available, otherwise generate rich content
          if (!bookContent || bookContent.length < 3) {
            console.log(`Generating rich story content for "${title}" (real content not sufficient)`);
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
            estimatedReadingTime: Math.max(15, Math.min(40, bookContent.length * 2)), // 2 minutes per page
            content: bookContent, // Rich generated content (15-40 pages)
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            // Additional metadata
            source: 'Open Library + Enhanced Generation',
            subject: subject,
            isbn: work.key || null,
            hasRealContent: bookContent.length > 0 && !bookContent[0].includes('wonderful story of')
          };
          
          // 📤 Upload to Firestore
          await db.collection('books').add(book);
          console.log(`✅ Uploaded: "${title}" by ${author} (${subject}) - ${bookContent.length} pages - ${coverImageUrl ? 'Real cover' : 'Emoji cover'}`);
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
    console.log('🚀 Starting enhanced bulk book upload from Open Library...');
    console.log('📸 Using real cover images when available');
    console.log('📖 Generating rich, coherent stories with 15-40 pages each');
    console.log('🎭 Creating proper character development and story arcs');
    
    // Uncomment the next line if you want to clear existing books first
    // await clearExistingBooks();
    
    await fetchBooksFromOpenLibrary();
    
    console.log('✨ All done! Your Firebase database now has children\'s books with rich, engaging content!');
    
  } catch (error) {
    console.error('💥 Fatal error:', error);
  } finally {
    process.exit(0);
  }
}

// Run the script
main().catch(console.error);
