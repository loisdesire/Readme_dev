// ai_tagging_fixed.js
// Fixed version that properly updates traits (not tags) and handles errors better

const admin = require('firebase-admin');
const fetch = (...args) => import('node-fetch').then(({ default: fetch }) => fetch(...args));
const pdfParse = require('pdf-parse');
const fs = require('fs');
const path = require('path');

// Load environment variables from .env file
require('dotenv').config();

// Validate environment variables
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
if (!OPENAI_API_KEY) {
  console.error('❌ Error: OPENAI_API_KEY environment variable is required');
  console.error('   Set it using: $env:OPENAI_API_KEY="your-api-key-here"');
  process.exit(1);
}

// Initialize Firebase Admin SDK
let db, bucket;
try {
  const serviceAccount = require('./serviceAccountKey.json');
  
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'readme-40267',
    storageBucket: 'readme-40267.firebasestorage.app',
    databaseURL: 'https://readme-40267-default-rtdb.firebaseio.com'
  });
  
  db = admin.firestore();
  bucket = admin.storage().bucket();
  console.log('✅ Firebase Admin SDK initialized successfully\n');
} catch (error) {
  console.error('❌ Error initializing Firebase Admin SDK:', error);
  process.exit(1);
}

async function getBooksNeedingTagging() {
  try {
    console.log('📚 Fetching books that need tagging...');
    const snapshot = await db.collection('books').where('needsTagging', '==', true).get();
    const books = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    console.log(`   Found ${books.length} books needing tagging\n`);
    return books;
  } catch (error) {
    console.error('❌ Error fetching books from Firestore:', error);
    throw error;
  }
}

async function downloadPdf(pdfUrl, localPath) {
  try {
    console.log(`   📥 Downloading PDF...`);
    
    // Extract the file path from the Firebase Storage URL
    let filePath;
    if (pdfUrl.includes('googleapis.com')) {
      // URL format: https://storage.googleapis.com/bucket-name/path/to/file.pdf?params
      // We need to extract: path/to/file.pdf
      const urlParts = pdfUrl.split('googleapis.com/')[1]; // Get everything after googleapis.com/
      const pathWithParams = urlParts.split('?')[0]; // Remove query params
      // Remove bucket name (first part after googleapis.com/)
      const pathParts = pathWithParams.split('/');
      pathParts.shift(); // Remove bucket name
      filePath = pathParts.join('/'); // Rejoin the rest
      filePath = decodeURIComponent(filePath);
      
      console.log(`   📂 File path: ${filePath}`);
    } else if (pdfUrl.includes('firebaseapp.com') || pdfUrl.includes('storage.firebase.com')) {
      const match = pdfUrl.match(/\/o\/(.+?)\?/);
      if (match) {
        filePath = decodeURIComponent(match[1]);
      } else {
        throw new Error('Could not parse Firebase Storage URL');
      }
    } else {
      throw new Error('Unsupported URL format');
    }
    
    const file = bucket.file(filePath);
    
    const [exists] = await file.exists();
    if (!exists) {
      throw new Error(`File does not exist in storage: ${filePath}`);
    }
    
    await file.download({ destination: localPath });
    console.log(`   ✅ Downloaded successfully`);
  } catch (error) {
    console.error(`   ❌ Error downloading PDF: ${error.message}`);
    throw error;
  }
}

async function extractTextFromPdf(localPath) {
  try {
    console.log(`   📄 Extracting text from PDF...`);
    const dataBuffer = fs.readFileSync(localPath);
    const data = await pdfParse(dataBuffer);
    const text = data.text.slice(0, 8000); // Limit to first 8000 chars for OpenAI
    console.log(`   ✅ Extracted ${text.length} characters`);
    return text;
  } catch (error) {
    console.error(`   ❌ Error extracting text from PDF: ${error.message}`);
    throw error;
  }
}

async function getTraitsFromAI(text, title, author, description) {
  // Both tags and traits for the Book model
  const allowedTags = [
    'adventure', 'fantasy', 'friendship', 'animals', 'family', 
    'learning', 'kindness', 'creativity', 'imagination'
  ];
  const allowedTraits = [
    'adventurous', 'curious', 'imaginative', 'creative', 'kind', 
    'brave', 'friendly', 'thoughtful', 'social', 'caring'
  ];
  const allowedAges = ['6+', '7+', '8+', '9+', '10+', '11+', '12+'];
  
  const prompt = `Analyze this children's book and suggest tags, personality traits, and age rating.

Title: ${title}
Author: ${author}
Description: ${description}
Content excerpt: ${text.substring(0, 2000)}

Based on this book:
1. Select 2-4 TAGS that categorize the book's themes/genre from: ${allowedTags.join(", ")}
2. Select 2-4 TRAITS that match children who would enjoy this book from: ${allowedTraits.join(", ")}
3. Suggest an appropriate age rating from: ${allowedAges.join(", ")}

Return ONLY a JSON object with this exact format:
{
  "tags": ["tag1", "tag2"],
  "traits": ["trait1", "trait2", "trait3"],
  "ageRating": "6+"
}`;
  
  try {
    console.log(`   🤖 Requesting AI analysis...`);
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${OPENAI_API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: 'gpt-3.5-turbo',  // Changed from gpt-4 to gpt-3.5-turbo (available on all API keys)
        messages: [
          { 
            role: 'system', 
            content: 'You are an expert children\'s book classifier. Return only valid JSON with no additional text.' 
          },
          { role: 'user', content: prompt }
        ],
        temperature: 0.7
      })
    });
    
    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`OpenAI API error: ${response.status} - ${errorText}`);
    }
    
    const data = await response.json();
    
    // Check if we got a valid response
    if (!data.choices || !data.choices[0] || !data.choices[0].message) {
      console.error('   ❌ Invalid OpenAI response structure:', JSON.stringify(data));
      throw new Error('Invalid OpenAI response structure');
    }
    
    const content = data.choices[0].message.content.trim();
    console.log(`   📝 Raw AI Response: ${content}`);
    
    // Parse JSON from OpenAI response
    const jsonMatch = content.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      console.error('   ❌ No JSON found in AI response');
      throw new Error('No JSON found in AI response');
    }
    
    const result = JSON.parse(jsonMatch[0]);
    console.log(`   🔍 Parsed result:`, JSON.stringify(result, null, 2));
    
    // Validate the result
    let hasIssues = false;
    if (!result.tags || !Array.isArray(result.tags) || result.tags.length === 0) {
      console.warn('   ⚠️  AI returned empty/invalid tags, using defaults');
      result.tags = ['adventure', 'friendship'];
      hasIssues = true;
    }
    if (!result.traits || !Array.isArray(result.traits) || result.traits.length === 0) {
      console.warn('   ⚠️  AI returned empty/invalid traits, using defaults');
      result.traits = ['curious', 'imaginative'];
      hasIssues = true;
    }
    if (!result.ageRating) {
      console.warn('   ⚠️  AI returned empty age rating, using default');
      result.ageRating = '6+';
      hasIssues = true;
    }
    
    if (hasIssues) {
      console.log(`   ⚠️  Final result after applying defaults:`, JSON.stringify(result, null, 2));
    } else {
      console.log(`   ✅ AI analysis completed successfully`);
    }
    
    return result;
  } catch (error) {
    console.error(`   ❌ Error getting AI analysis: ${error.message}`);
    // Return defaults on error
    return { tags: ['adventure', 'friendship'], traits: ['curious', 'imaginative'], ageRating: '6+' };
  }
}

async function updateBookTraits(bookId, tags, traits, ageRating) {
  try {
    console.log(`   💾 Updating book in Firestore...`);
    const updateData = { 
      tags: tags,      // Update tags field (for categorization)
      traits: traits,  // Update traits field (for personality matching)
      needsTagging: false  // Mark as tagged
    };
    
    // Only update age rating if we got a valid one
    if (ageRating && ageRating.length > 0) {
      updateData.ageRating = ageRating;
    }
    
    await db.collection('books').doc(bookId).update(updateData);
    console.log(`   ✅ Book updated successfully`);
  } catch (error) {
    console.error(`   ❌ Error updating book: ${error.message}`);
    throw error;
  }
}

async function main() {
  try {
    console.log('🚀 Starting AI tagging process...\n');
    
    const books = await getBooksNeedingTagging();
    
    if (books.length === 0) {
      console.log('✅ No books need tagging. All done!');
      return;
    }
    
    let successCount = 0;
    let failCount = 0;
    
    for (let i = 0; i < books.length; i++) {
      const book = books[i];
      console.log(`\n📖 Processing book ${i + 1}/${books.length}: "${book.title}"`);
      
      try {
        if (!book.pdfUrl) {
          console.log(`   ⚠️  Skipping - no PDF URL`);
          failCount++;
          continue;
        }
        
        const localPdfPath = path.join(__dirname, `temp_${book.id}.pdf`);
        
        await downloadPdf(book.pdfUrl, localPdfPath);
        const text = await extractTextFromPdf(localPdfPath);
        const aiResult = await getTraitsFromAI(
          text, 
          book.title, 
          book.author || 'Unknown', 
          book.description || ''
        );
        await updateBookTraits(book.id, aiResult.tags, aiResult.traits, aiResult.ageRating);
        
        // Clean up temporary file
        if (fs.existsSync(localPdfPath)) {
          fs.unlinkSync(localPdfPath);
        }
        
        console.log(`   🏷️  Tags: ${aiResult.tags.join(', ')}`);
        console.log(`   ✨ Traits: ${aiResult.traits.join(', ')}`);
        console.log(`   📅 Age Rating: ${aiResult.ageRating}`);
        console.log(`   ✅ Completed "${book.title}"`);
        
        successCount++;
        
      } catch (error) {
        console.error(`   ❌ Failed to process "${book.title}": ${error.message}`);
        failCount++;
      }
    }
    
    console.log(`\n${'='.repeat(50)}`);
    console.log(`📊 Summary:`);
    console.log(`   ✅ Successfully tagged: ${successCount} books`);
    console.log(`   ❌ Failed: ${failCount} books`);
    console.log(`${'='.repeat(50)}\n`);
    console.log('✨ AI tagging process completed!');
  } catch (error) {
    console.error('❌ Error in main function:', error);
  }
}

// Run the script
main().catch(console.error);
