const admin = require('firebase-admin');
const fetch = (...args) => import('node-fetch').then(({ default: fetch }) => fetch(...args));
const serviceAccount = require('./serviceAccountKey.json');

// 🔐 Initialize Firebase Admin SDK
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// 🎯 Google Books API queries for children's content
const googleBooksQueries = [
  'subject:juvenile+fiction+age:3-8',
  'subject:picture+books',
  'subject:children+stories',
  'subject:fairy+tales',
  'subject:bedtime+stories',
  'subject:adventure+children',
  'subject:animals+children',
  'subject:friendship+children',
  'subject:family+children',
  'subject:fantasy+children'
];

// 🎭 Enhanced character and story generation
function extractMainCharacter(title, subject) {
  const titleWords = title.toLowerCase().split(/[\s\-_]+/);
  
  // Common character names in children's books
  const commonNames = ['alice', 'peter', 'lucy', 'charlie', 'max', 'ruby', 'sam', 'lily', 'jack', 'emma', 'oliver', 'sophie', 'ben', 'mia'];
  const foundName = titleWords.find(word => commonNames.includes(word));
  if (foundName) return foundName.charAt(0).toUpperCase() + foundName.slice(1);
  
  // Animal names
  const animalNames = ['Fluffy', 'Whiskers', 'Buddy', 'Bella', 'Charlie', 'Luna', 'Max', 'Daisy', 'Rocky', 'Rosie'];
  if (subject && subject.includes('animal')) {
    return animalNames[Math.floor(Math.random() * animalNames.length)];
  }
  
  // Default names by subject
  const defaultNames = {
    'fairy': ['Princess Luna', 'Prince Leo', 'Fairy Rose'],
    'adventure': ['Captain Alex', 'Explorer Maya', 'Brave Sam'],
    'friendship': ['Emma', 'Jake', 'Lily'],
    'school': ['Alex', 'Maya', 'Sam'],
    'family': ['Little Bear', 'Sunny', 'Hope']
  };
  
  const subjectKey = Object.keys(defaultNames).find(key => subject && subject.includes(key));
  const names = defaultNames[subjectKey] || ['Alex', 'Maya', 'Sam'];
  return names[Math.floor(Math.random() * names.length)];
}

// Generate supporting characters
function generateSupportingCharacters(subject, isAnimalStory) {
  if (isAnimalStory) {
    return ['Wise Owl', 'Friendly Rabbit', 'Helpful Squirrel'];
  }
  
  const characterSets = {
    'fairy': ['Wise Wizard', 'Kind Fairy', 'Talking Tree'],
    'adventure': ['Brave Companion', 'Wise Guide', 'Loyal Friend'],
    'friendship': ['Best Friend', 'New Kid', 'Helpful Neighbor'],
    'school': ['Teacher Ms. Green', 'Classmate Tom', 'Principal Johnson'],
    'family': ['Grandma Rose', 'Uncle Joe', 'Little Sister']
  };
  
  const subjectKey = Object.keys(characterSets).find(key => subject && subject.includes(key));
  return characterSets[subjectKey] || ['Good Friend', 'Wise Helper', 'Kind Neighbor'];
}

// Enhanced story content generation with better narrative structure
function generateEnhancedStoryContent(title, author, description, categories, pageCount = null) {
  const content = [];
  const targetPages = pageCount && pageCount > 10 ? Math.min(pageCount, 40) : (Math.floor(Math.random() * 26) + 15);
  
  // Determine story type from categories and description
  const categoryText = (categories || []).join(' ').toLowerCase();
  const descText = (description || '').toLowerCase();
  const titleText = title.toLowerCase();
  
  const isAnimalStory = /animal|pet|dog|cat|bear|rabbit|fox|bird|zoo|farm/i.test(titleText + ' ' + descText + ' ' + categoryText);
  const isAdventureStory = /adventure|journey|quest|treasure|explore|travel|magic|mystery/i.test(titleText + ' ' + descText + ' ' + categoryText);
  const isFamilyStory = /family|mother|father|parent|home|sister|brother|grandma|grandpa/i.test(titleText + ' ' + descText + ' ' + categoryText);
  const isFriendshipStory = /friend|friendship|school|classmate|playground|together/i.test(titleText + ' ' + descText + ' ' + categoryText);
  
  // Determine main subject
  let subject = 'general';
  if (isAnimalStory) subject = 'animals';
  else if (isAdventureStory) subject = 'adventure';
  else if (isFamilyStory) subject = 'family';
  else if (isFriendshipStory) subject = 'friendship';
  else if (/fairy|magic|princess|wizard|enchant/i.test(titleText + ' ' + descText)) subject = 'fairy_tales';
  
  // Generate characters
  const mainCharacter = extractMainCharacter(title, subject);
  const supportingCharacters = generateSupportingCharacters(subject, isAnimalStory);
  
  // Story structure: Beginning (25%), Middle (50%), End (25%)
  const beginningPages = Math.ceil(targetPages * 0.25);
  const middlePages = Math.ceil(targetPages * 0.5);
  const endPages = targetPages - beginningPages - middlePages;
  
  // BEGINNING - Set up the world and characters
  const openings = {
    'animals': `In a beautiful forest where sunlight danced through the leaves, ${mainCharacter} lived peacefully among all the woodland creatures. This is the heartwarming tale of "${title}" and the special friendship that changed everything.`,
    'adventure': `${mainCharacter} had always been curious about the world beyond their village. Little did they know that today would mark the beginning of the greatest adventure of their life, as chronicled in "${title}".`,
    'family': `${mainCharacter} cherished every moment spent with their loving family. The story of "${title}" reminds us that the strongest bonds are built with love, laughter, and understanding.`,
    'friendship': `${mainCharacter} believed that true friendship was life's greatest treasure. In "${title}", we discover just how powerful the bonds of friendship can be.`,
    'fairy_tales': `Once upon a time, in a realm where magic flowed like rivers and dreams took flight, ${mainCharacter} embarked on an extraordinary journey. This is the enchanting story of "${title}".`,
    'general': `This is the wonderful story of ${mainCharacter}, whose journey in "${title}" teaches us about courage, kindness, and the magic that exists in everyday moments.`
  };
  
  content.push(openings[subject]);
  
  // Character development
  content.push(`${mainCharacter} was beloved by everyone who knew them. With a heart full of compassion and eyes that sparkled with curiosity, they had a special gift for seeing the good in every situation and every person they met.`);
  
  // World building based on actual book description
  if (description && description.length > 100) {
    // Use elements from the real description
    const sentences = description.split(/[.!?]+/).filter(s => s.trim().length > 20);
    if (sentences.length > 0) {
      content.push(`As described in the original tale, ${sentences[0].trim()}.`);
    }
  }
  
  // Add setting
  const settings = {
    'animals': `The forest was a magical place where every creature had a voice and every tree held ancient wisdom. Crystal streams provided fresh water, and meadows bloomed with flowers that seemed to sing in the gentle breeze.`,
    'adventure': `The village where ${mainCharacter} lived was nestled in a valley surrounded by mysterious mountains and enchanted forests. Beyond the familiar paths lay wonders waiting to be discovered by those brave enough to seek them.`,
    'family': `${mainCharacter}'s home was filled with warmth, where the aroma of fresh-baked bread mingled with the sound of gentle laughter. Every room held precious memories, and every corner radiated love.`,
    'friendship': `The neighborhood was a tapestry of diverse families, each contributing their own special traditions and stories. Children's laughter echoed from the playground, and neighbors greeted each other with genuine smiles.`,
    'fairy_tales': `The magical kingdom sparkled with wonder at every turn. Rainbow bridges arched over crystal rivers, and gardens bloomed with flowers that granted wishes to those pure of heart.`,
    'general': `${mainCharacter} lived in a place where every day held the promise of new discoveries and meaningful connections with others.`
  };
  
  content.push(settings[subject]);
  
  // Fill beginning pages
  for (let i = content.length; i < beginningPages; i++) {
    const beginningEvents = [
      `One morning, ${mainCharacter} woke with an unusual feeling of anticipation. The air seemed to shimmer with possibility, and even the birds sang with extra enthusiasm.`,
      `As ${mainCharacter} went about their daily routine, they noticed small signs that today would be different. A butterfly landed on their shoulder, flowers seemed more vibrant, and there was magic in the air.`,
      `${mainCharacter} had learned to trust their instincts, and today those instincts whispered of adventure, discovery, and the chance to make a real difference in someone's life.`
    ];
    
    const eventIndex = (i - 3) % beginningEvents.length;
    if (eventIndex < beginningEvents.length) {
      content.push(beginningEvents[eventIndex]);
    } else {
      content.push(`With a heart full of hope and determination, ${mainCharacter} stepped forward into what would become an unforgettable day.`);
    }
  }
  
  // MIDDLE - The main adventure
  const challenges = {
    'animals': `Suddenly, ${supportingCharacters[1]} came rushing through the forest with urgent news. The Great Oak Tree, which had provided shelter and wisdom for generations, was losing its leaves and growing weak.`,
    'adventure': `While exploring a hidden path, ${mainCharacter} discovered an ancient scroll that spoke of a legendary artifact hidden somewhere in the nearby mountains. This artifact had the power to bring prosperity to their entire village.`,
    'family': `${mainCharacter} noticed that ${supportingCharacters[0]} had been unusually quiet lately. Determined to help, they decided to organize something special that would bring joy back to their beloved family member.`,
    'friendship': `At school, ${mainCharacter} met a new student who seemed lonely and shy. While others were hesitant to approach, ${mainCharacter} saw an opportunity to extend the hand of friendship.`,
    'fairy_tales': `A mysterious messenger arrived with news that the kingdom's source of magic was fading. Only someone with a pure heart and unwavering courage could restore the ancient enchantment.`,
    'general': `${mainCharacter} discovered that someone in their community needed help, and they knew they couldn't turn away from a friend in need.`
  };
  
  content.push(challenges[subject]);
  
  // Journey development
  const journeyEvents = [
    `At first, ${mainCharacter} felt overwhelmed by the magnitude of the challenge. But then they remembered all the lessons about courage and kindness they had learned, and their confidence began to grow.`,
    `${supportingCharacters[0]} offered to join ${mainCharacter} on this important mission. "Together, we can accomplish anything," they said with an encouraging smile that filled ${mainCharacter} with renewed hope.`,
    `As they embarked on their quest, ${mainCharacter} and their companions encountered their first significant challenge. Though it seemed daunting, they approached it with creativity and determination.`,
    `${supportingCharacters[2]} appeared at just the right moment, offering wisdom and assistance. "I've been watching your journey," they said warmly. "Your kindness and perseverance have inspired me to help."`,
    `The path forward required ${mainCharacter} to use not just courage, but also compassion and understanding. They learned that the greatest victories come from lifting others up along the way.`,
    `When faced with a seemingly impossible obstacle, ${mainCharacter} remembered the importance of teamwork and asking for help when needed. Together, they found a solution that none could have discovered alone.`,
    `${supportingCharacters[0]} shared an important truth: "The most valuable treasures aren't things we can hold, but the love we share and the positive impact we have on others' lives."`,
    `As their adventure continued, ${mainCharacter} began to understand that they weren't just solving a problem – they were discovering their own inner strength and the power of believing in themselves.`,
    `Each challenge taught ${mainCharacter} something new about resilience, empathy, and the importance of never giving up on what's right and good.`,
    `The journey was filled with moments of wonder and discovery, reminding ${mainCharacter} to appreciate the beauty in both the destination and the path itself.`
  ];
  
  // Add middle content
  for (let i = content.length; i < beginningPages + middlePages - 3; i++) {
    const eventIndex = (i - beginningPages) % journeyEvents.length;
    content.push(journeyEvents[eventIndex]);
  }
  
  // Climax buildup
  content.push(`As they approached the culmination of their quest, ${mainCharacter} felt a mixture of nervousness and excitement. All their growth, learning, and preparation had led to this pivotal moment.`);
  content.push(`Surrounded by friends who believed in them, ${mainCharacter} realized that they had already succeeded in the most important way – they had grown into someone who could make a real difference in the world.`);
  content.push(`The moment of truth arrived. ${mainCharacter} took a deep breath, drew upon everything they had learned about love, courage, and friendship, and stepped forward with confidence.`);
  
  // END - Resolution
  const resolutions = {
    'animals': `With gentle hands and a loving heart, ${mainCharacter} discovered that the Great Oak needed not magic, but care and community. Together, all the forest creatures worked to nurture their ancient friend back to health.`,
    'adventure': `${mainCharacter} realized that the true treasure had been the journey itself – the friendships forged, the confidence gained, and the knowledge that they could overcome any challenge with determination and heart.`,
    'family': `The surprise ${mainCharacter} organized brought tears of joy to ${supportingCharacters[0]}'s eyes. The house once again filled with laughter, proving that love and thoughtfulness are the strongest family bonds.`,
    'friendship': `${mainCharacter}'s kindness opened the door to a beautiful new friendship. Soon, the once-shy student was laughing and playing with everyone, and the whole class was enriched by their unique perspective.`,
    'fairy_tales': `With a heart pure and true, ${mainCharacter} restored the kingdom's magic not through spells or potions, but through acts of genuine kindness that reminded everyone of the real magic in the world.`,
    'general': `Through compassion, determination, and the support of good friends, ${mainCharacter} found the perfect solution to the challenge they had faced.`
  };
  
  content.push(resolutions[subject]);
  
  // Ending
  content.push(`The community celebrated not just the successful resolution, but the way ${mainCharacter} had approached every challenge with grace, kindness, and an unwavering commitment to doing what was right.`);
  content.push(`${supportingCharacters[0]} looked at ${mainCharacter} with pride and admiration. "You have shown us all what it truly means to be brave, kind, and wise. Your example will inspire others for years to come."`);
  
  // Fill remaining ending pages
  for (let i = content.length; i < targetPages - 1; i++) {
    const endingEvents = [
      `As ${mainCharacter} reflected on their incredible journey, they marveled at how much they had grown. The timid person who had started this adventure was now confident, wise, and deeply connected to their community.`,
      `The friendships ${mainCharacter} had strengthened during this quest would last a lifetime. They had learned that true friends support each other through every challenge and celebrate each other's victories.`,
      `${mainCharacter} looked toward the future with excitement and optimism. They now knew that with courage, kindness, and good friends by their side, any dream was possible.`
    ];
    
    const eventIndex = (i - (targetPages - endPages - 1)) % endingEvents.length;
    if (eventIndex < endingEvents.length) {
      content.push(endingEvents[eventIndex]);
    }
  }
  
  // Final conclusion
  content.push(`And so concludes the inspiring tale of "${title}". ${mainCharacter}'s journey reminds us that within each of us lies the power to make the world a brighter, kinder place through our choices, our actions, and our love for one another.`);
  
  return content.slice(0, targetPages);
}

// 🌐 Fetch books from Google Books API
async function fetchBooksFromGoogleBooks() {
  let totalUploaded = 0;
  
  for (const query of googleBooksQueries) {
    console.log(`📖 Fetching children's books for query: ${query}`);
    
    try {
      const url = `https://www.googleapis.com/books/v1/volumes?q=${query}&maxResults=40&printType=books&langRestrict=en&orderBy=relevance`;
      const response = await fetch(url);
      const data = await response.json();
      const items = data.items || [];
      
      console.log(`Found ${items.length} books for query: ${query}`);
      
      for (const item of items) {
        try {
          const volumeInfo = item.volumeInfo || {};
          const title = volumeInfo.title || 'Untitled Story';
          const authors = volumeInfo.authors || ['Unknown Author'];
          const author = authors[0];
          const description = volumeInfo.description || `A wonderful children's story that will captivate young readers.`;
          const categories = volumeInfo.categories || [];
          const pageCount = volumeInfo.pageCount;
          
          // Get high-quality cover image
          const imageLinks = volumeInfo.imageLinks || {};
          const coverImageUrl = imageLinks.extraLarge || imageLinks.large || imageLinks.medium || imageLinks.thumbnail || null;
          
          // Skip if title is too short or generic
          if (title.length < 3 || title.toLowerCase().includes('untitled')) {
            continue;
          }
          
          // Skip adult content
          const maturityRating = volumeInfo.maturityRating || 'NOT_MATURE';
          if (maturityRating !== 'NOT_MATURE') {
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
          
          // Generate enhanced story content
          console.log(`Generating enhanced content for "${title}" by ${author}...`);
          const bookContent = generateEnhancedStoryContent(title, author, description, categories, pageCount);
          
          // Determine traits based on categories and content
          const categoryText = categories.join(' ').toLowerCase();
          let traits = ['curious', 'imaginative'];
          
          if (/adventure|action/i.test(categoryText)) traits.push('adventurous', 'brave');
          if (/animal|nature/i.test(categoryText)) traits.push('kind', 'caring');
          if (/friend|social/i.test(categoryText)) traits.push('friendly', 'social');
          if (/family/i.test(categoryText)) traits.push('loving', 'caring');
          if (/fantasy|magic/i.test(categoryText)) traits.push('creative', 'imaginative');
          
          // Remove duplicates
          traits = [...new Set(traits)];
          
          // 📚 Build book object
          const book = {
            title: title,
            author: author,
            description: description.length > 500 ? description.substring(0, 500) + '...' : description,
            coverImageUrl: coverImageUrl,
            coverEmoji: coverImageUrl ? null : '📚✨',
            traits: traits,
            ageRating: '6+',
            estimatedReadingTime: Math.max(15, Math.min(45, bookContent.length * 2)),
            content: bookContent,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            // Additional metadata
            source: 'Google Books + Enhanced Generation',
            categories: categories,
            googleBooksId: item.id,
            pageCount: pageCount || bookContent.length,
            hasRealContent: false, // Enhanced generated content
            contentQuality: 'enhanced_generated'
          };
          
          // 📤 Upload to Firestore
          await db.collection('books').add(book);
          console.log(`✅ Uploaded: "${title}" by ${author} - ${bookContent.length} pages - ${coverImageUrl ? 'Google cover' : 'Emoji cover'}`);
          totalUploaded++;
          
          // Add delay to respect rate limits
          await new Promise(resolve => setTimeout(resolve, 200));
          
        } catch (bookError) {
          console.error(`❌ Error processing book: ${bookError.message}`);
          continue;
        }
      }
      
      // Delay between queries
      await new Promise(resolve => setTimeout(resolve, 1000));
      
    } catch (queryError) {
      console.error(`❌ Error fetching query ${query}: ${queryError.message}`);
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
    console.log('🚀 Starting Google Books API integration...');
    console.log('📸 Using high-quality Google Books cover images');
    console.log('📖 Generating rich, coherent stories with 15-40 pages each');
    console.log('🎭 Creating proper character development and story arcs');
    console.log('🔍 Using Google Books metadata for better content quality');
    
    // Uncomment the next line if you want to clear existing books first
    // await clearExistingBooks();
    
    await fetchBooksFromGoogleBooks();
    
    console.log('✨ All done! Your Firebase database now has high-quality children\'s books with enhanced content!');
    
  } catch (error) {
    console.error('💥 Fatal error:', error);
  } finally {
    process.exit(0);
  }
}

// Run the script
main().catch(console.error);
