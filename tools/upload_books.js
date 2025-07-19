const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// ✅ Only keep books with these tags
const allowedTags = [
  'adventure',
  'animals',
  'fairy_tales',
  'friendship',
  'science_fiction',
  'school',
];

async function deleteBooksWithoutAllowedTags() {
  const snapshot = await db.collection('books').get();
  let deleteCount = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const tags = data.tags || [];

    // 🛑 Delete if NONE of the book's tags are in the allowed list
    const hasAllowedTag = tags.some(tag => allowedTags.includes(tag));

    if (!hasAllowedTag) {
      await db.collection('books').doc(doc.id).delete();
      console.log(`🗑️ Deleted book: "${data.title}" by ${data.author}`);
      deleteCount++;
    }
  }

  console.log(`✅ Cleanup complete. ${deleteCount} book(s) deleted.`);
}

deleteBooksWithoutAllowedTags().catch(console.error);







// const admin = require('firebase-admin');
// const fetch = (...args) => import('node-fetch').then(({ default: fetch }) => fetch(...args));
// const serviceAccount = require('./serviceAccountKey.json');

// // 🔐 Initialize Firebase Admin SDK
// admin.initializeApp({
//   credential: admin.credential.cert(serviceAccount),
// });

// const db = admin.firestore();

// // 📚 Genre tags to fetch books from
// const subjects = [
//   'adventure',
//   'animals',
//   'fairy_tales',
//   'friendship',
//   'science_fiction',
//   'school',
// ];

// async function uploadBooks() {
//   for (const subject of subjects) {
//     console.log(`📖 Fetching books for subject: ${subject}`);
//     const url = `https://openlibrary.org/subjects/${subject}.json?limit=10`;
//     const res = await fetch(url);
//     const data = await res.json();
//     const works = data.works || [];

//     for (const work of works) {
//       const title = work.title || 'Untitled';
//       const author = work.authors?.[0]?.name || 'Unknown Author';
//       const coverId = work.cover_id;
//       const coverUrl = coverId
//         ? `https://covers.openlibrary.org/b/id/${coverId}-L.jpg`
//         : '';

//       const isbn = work.key || `${title}-${author}`;

//       // 🛑 Check Firestore for duplicates by title and author
//       const existing = await db.collection('books')
//         .where('title', '==', title)
//         .where('author', '==', author)
//         .get();

//       if (!existing.empty) {
//         console.log(`⚠️ Skipping duplicate: "${title}" by ${author}`);
//         continue;
//       }

//       // ✅ Build book object
//       const book = {
//         title,
//         author,
//         isbn,
//         coverUrl,
//         content: `📖 This is a placeholder story for "${title}". TTS will read this aloud.`,
//         readingLevel: '6-12',
//         tags: [subject],
//         createdAt: admin.firestore.FieldValue.serverTimestamp(),
//       };

//       // 📤 Upload to Firestore
//       await db.collection('books').add(book);
//       console.log(`✅ Uploaded: "${title}" (${subject})`);
//     }
//   }

//   console.log('🎉 All books uploaded successfully!');
// }

// uploadBooks().catch(console.error);
