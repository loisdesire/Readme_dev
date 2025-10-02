// ai_tagging.js
// Script to extract text from PDFs in Firebase Storage, send to OpenAI, and update Firestore with tags/traits

const admin = require('firebase-admin');
const fetch = (...args) => import('node-fetch').then(({ default: fetch }) => fetch(...args));
const pdfParse = require('pdf-parse');
const serviceAccount = require('./serviceAccountKey.json');
const { Storage } = require('@google-cloud/storage');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin SDK
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'readme-40267.appspot.com' // e.g. 'your-app.appspot.com'
});
const db = admin.firestore();
const bucket = admin.storage().bucket();

// OpenAI API key
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;

async function getBooksNeedingTagging() {
  const snapshot = await db.collection('books').where('needsTagging', '==', true).get();
  return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
}

async function downloadPdf(pdfUrl, localPath) {
  const file = bucket.file(pdfUrl.replace(`https://storage.googleapis.com/${bucket.name}/`, ''));
  await file.download({ destination: localPath });
}

async function extractTextFromPdf(localPath) {
  const dataBuffer = fs.readFileSync(localPath);
  const data = await pdfParse(dataBuffer);
  return data.text.slice(0, 8000); // Limit to first 8000 chars for OpenAI
}

async function getTagsTraitsFromAI(text, title, author, description) {
  const allowedTags = [
    'adventure', 'fantasy', 'friendship', 'animals', 'family', 'learning', 'kindness', 'creativity', 'imagination'
  ];
  const allowedTraits = [
    'adventurous', 'curious', 'imaginative', 'creative', 'kind', 'brave', 'friendly', 'thoughtful', 'social', 'caring'
  ];
  const allowedAges = ['6+', '7+', '8+', '9+', '10+'];
  const prompt = `You are an expert children's librarian and educational content specialist. Analyze this children's book and provide accurate metadata.

Book Information:
Title: ${title}
Author: ${author}
Description: ${description}
Content Sample: ${text}

Instructions:
1. TAGS: Select 2-4 most relevant themes/topics from this list only: ${allowedTags.join(", ")}
2. TRAITS: Choose 2-3 personality traits that would appeal to children with similar characteristics from this list only: ${allowedTraits.join(", ")}
3. AGE RATING: Determine the most appropriate age rating based on vocabulary complexity, sentence structure, themes, and content difficulty from this list only: ${allowedAges.join(", ")}

Consider:
- Reading level (simple vs complex vocabulary and sentences)
- Emotional maturity needed for themes
- Attention span required
- Educational value and concepts presented

Return ONLY a valid JSON object with exactly these fields: 'tags', 'traits', 'ageRating'
Example: {"tags": ["adventure", "friendship"], "traits": ["brave", "curious"], "ageRating": "7+"}`;
  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${OPENAI_API_KEY}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      model: 'gpt-4',
      messages: [
        { role: 'system', content: 'You are an expert children\'s book classifier.' },
        { role: 'user', content: prompt }
      ]
    })
  });
  const data = await response.json();
  // Parse JSON from OpenAI response
  const match = data.choices[0].message.content.match(/\{[\s\S]*\}/);
  if (match) {
    return JSON.parse(match[0]);
  }
  return { tags: [], traits: [], ageRating: '' };
}

async function updateBookTagsTraits(bookId, tags, traits, ageRating, existingAgeRating) {
  const updateData = { tags, traits, needsTagging: false };
  // Only update age rating if book doesn't already have one
  if (ageRating && ageRating.length > 0 && (!existingAgeRating || existingAgeRating.length === 0)) {
    updateData.ageRating = ageRating;
  }
  await db.collection('books').doc(bookId).update(updateData);
}

async function main() {
  const books = await getBooksNeedingTagging();
  for (const book of books) {
    const localPdfPath = path.join(__dirname, `${book.id}.pdf`);
    await downloadPdf(book.pdfUrl, localPdfPath);
    const text = await extractTextFromPdf(localPdfPath);
    const aiResult = await getTagsTraitsFromAI(text, book.title, book.author, book.description);
    await updateBookTagsTraits(book.id, aiResult.tags, aiResult.traits, aiResult.ageRating, book.ageRating);
    fs.unlinkSync(localPdfPath); // Clean up
    console.log(`Updated book ${book.title} with tags/traits.`);
  }
}

main().catch(console.error);
