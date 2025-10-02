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
  const allowedAges = ['6+', '7+', '8+', '9+', '10+', '11+', '12+'];
  const prompt = `Title: ${title}\nAuthor: ${author}\nDescription: ${description}\nContent: ${text}\nSuggest relevant tags, traits, and an age rating for this children's book. Only use tags from this list: ${allowedTags.join(", ")}. Only use traits from this list: ${allowedTraits.join(", ")}. Only use age ratings from this list: ${allowedAges.join(", ")}. Return JSON with 'tags', 'traits', and 'ageRating' fields.`;
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

async function updateBookTagsTraits(bookId, tags, traits, ageRating) {
  const updateData = { tags, traits, needsTagging: false };
  if (ageRating && ageRating.length > 0) {
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
  await updateBookTagsTraits(book.id, aiResult.tags, aiResult.traits, aiResult.ageRating);
    fs.unlinkSync(localPdfPath); // Clean up
    console.log(`Updated book ${book.title} with tags/traits.`);
  }
}

main().catch(console.error);
