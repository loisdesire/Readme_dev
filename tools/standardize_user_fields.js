/**
 * Standardize User Fields Script
 * 
 * This script ensures all user documents have consistent fields based on their account type.
 * Run this to clean up messy/inconsistent field structures in Firestore.
 * 
 * Usage: node standardize_user_fields.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Standard fields for ALL users
const COMMON_FIELDS = {
  uid: null,              // Set from document ID
  email: '',
  username: '',
  accountType: '',        // 'child' or 'parent'
  createdAt: null,        // Timestamp
  avatar: '👦',
  isAccountRemoved: false,
};

// Additional fields for CHILD accounts
const CHILD_FIELDS = {
  hasCompletedQuiz: false,
  personalityTraits: [],
  traitScores: {},
  quizAnswers: [],
  quizCompletedAt: null,
  parentIds: [],          // Array of parent UIDs (updated from old parentId)
  parentAccessPin: null,
  totalBooksRead: 0,
  currentStreak: 0,
  totalAchievementPoints: 0,
  achievements: [],
};

// Additional fields for PARENT accounts
const PARENT_FIELDS = {
  children: [],           // Array of child UIDs
};

// Fields to REMOVE (legacy/unused fields)
const DEPRECATED_FIELDS = [
  'parentId',             // Replaced by parentIds array
  'children_count',
  'last_login',
  'profile_completed',
  'isRemoved',           // Replaced by isAccountRemoved
];

async function standardizeUserFields() {
  try {
    console.log('🔧 Starting user field standardization...\n');

    const usersSnapshot = await db.collection('users').get();
    let childCount = 0;
    let parentCount = 0;
    let errorCount = 0;

    for (const doc of usersSnapshot.docs) {
      try {
        const userId = doc.id;
        const data = doc.data();
        const accountType = data.accountType || 'child'; // Default to child if not set

        console.log(`Processing: ${data.username || userId} (${accountType})`);

        // Build standardized document
        const standardizedDoc = {
          ...COMMON_FIELDS,
          uid: userId,
          email: data.email || '',
          username: data.username || 'Anonymous',
          accountType: accountType,
          createdAt: data.createdAt || admin.firestore.FieldValue.serverTimestamp(),
          avatar: data.avatar || '👦',
          isAccountRemoved: data.isAccountRemoved || data.isRemoved || false,
        };

        if (accountType === 'child') {
          // Migrate old parentId to parentIds array
          let parentIds = data.parentIds || [];
          if (data.parentId && !parentIds.includes(data.parentId)) {
            parentIds.push(data.parentId);
          }

          standardizedDoc.hasCompletedQuiz = data.hasCompletedQuiz || false;
          standardizedDoc.personalityTraits = data.personalityTraits || [];
          standardizedDoc.traitScores = data.traitScores || {};
          standardizedDoc.quizAnswers = data.quizAnswers || [];
          standardizedDoc.quizCompletedAt = data.quizCompletedAt || null;
          standardizedDoc.parentIds = parentIds;
          standardizedDoc.parentAccessPin = data.parentAccessPin || null;
          standardizedDoc.totalBooksRead = data.totalBooksRead || 0;
          standardizedDoc.currentStreak = data.currentStreak || 0;
          standardizedDoc.totalAchievementPoints = data.totalAchievementPoints || 0;
          standardizedDoc.achievements = data.achievements || [];
          
          childCount++;
        } else if (accountType === 'parent') {
          standardizedDoc.children = data.children || [];
          parentCount++;
        }

        // Update the document
        await db.collection('users').doc(userId).set(standardizedDoc, { merge: false });

        // Remove deprecated fields explicitly
        const updates = {};
        for (const field of DEPRECATED_FIELDS) {
          if (data[field] !== undefined) {
            updates[field] = admin.firestore.FieldValue.delete();
          }
        }
        if (Object.keys(updates).length > 0) {
          await db.collection('users').doc(userId).update(updates);
        }

        console.log(`✅ Standardized: ${data.username || userId}\n`);

      } catch (err) {
        console.error(`❌ Error processing ${doc.id}:`, err.message);
        errorCount++;
      }
    }

    console.log('\n📊 Standardization Complete!');
    console.log(`✅ Child accounts: ${childCount}`);
    console.log(`✅ Parent accounts: ${parentCount}`);
    if (errorCount > 0) {
      console.log(`❌ Errors: ${errorCount}`);
    }
    console.log('\n🎉 All user documents now have consistent fields!');

  } catch (error) {
    console.error('❌ Fatal error:', error);
  } finally {
    process.exit();
  }
}

standardizeUserFields();
