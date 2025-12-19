/**
 * Analyze Database Collections Script
 * 
 * This script lists all collections in Firestore and analyzes their usage.
 * It will help identify which collections are needed vs unused/legacy.
 * 
 * Usage: node analyze_database_collections.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function analyzeCollections() {
  try {
    console.log('🔍 Analyzing Firestore database...\n');
    console.log('═'.repeat(70));

    // Get all collections
    const collections = await db.listCollections();
    
    console.log(`\n📊 Found ${collections.length} collections:\n`);

    for (const collection of collections) {
      const collectionName = collection.id;
      const snapshot = await collection.limit(5).get();
      const count = snapshot.size;
      
      // Get total count (expensive but necessary)
      const allDocs = await collection.count().get();
      const totalCount = allDocs.data().count;

      console.log(`\n📁 Collection: ${collectionName}`);
      console.log(`   Documents: ${totalCount}`);
      
      if (count > 0) {
        console.log(`   Sample data (first doc):`);
        const firstDoc = snapshot.docs[0];
        const data = firstDoc.data();
        const fields = Object.keys(data);
        console.log(`   Fields: ${fields.join(', ')}`);
        
        // Show a couple of field values for context
        const sampleFields = fields.slice(0, 3);
        sampleFields.forEach(field => {
          let value = data[field];
          if (typeof value === 'object' && value !== null) {
            if (value.toDate && typeof value.toDate === 'function') {
              value = `[Timestamp: ${value.toDate().toISOString()}]`;
            } else if (Array.isArray(value)) {
              value = `[Array: ${value.length} items]`;
            } else {
              value = '[Object]';
            }
          }
          console.log(`      ${field}: ${value}`);
        });
      } else {
        console.log(`   ⚠️  Empty collection`);
      }
      console.log('   ' + '─'.repeat(66));
    }

    console.log('\n' + '═'.repeat(70));
    console.log('\n📝 Collection Analysis:\n');

    // Analyze each collection's purpose
    const analysis = {
      core: [],
      possible_unused: [],
      empty: []
    };

    for (const collection of collections) {
      const name = collection.id;
      const allDocs = await collection.count().get();
      const totalCount = allDocs.data().count;

      // Core collections that should exist
      if (['users', 'books', 'reading_progress', 'favorites'].includes(name)) {
        analysis.core.push({ name, count: totalCount, status: '✅ CORE - Required' });
      }
      // Empty collections
      else if (totalCount === 0) {
        analysis.empty.push({ name, count: totalCount, status: '🗑️ EMPTY - Can be deleted' });
      }
      // Other collections - needs investigation
      else {
        analysis.possible_unused.push({ name, count: totalCount, status: '⚠️ INVESTIGATE - May be unused' });
      }
    }

    console.log('✅ CORE COLLECTIONS (DO NOT DELETE):');
    analysis.core.forEach(c => {
      console.log(`   ${c.name.padEnd(25)} ${c.count.toString().padStart(6)} docs - ${c.status}`);
    });

    if (analysis.possible_unused.length > 0) {
      console.log('\n⚠️  COLLECTIONS TO INVESTIGATE:');
      analysis.possible_unused.forEach(c => {
        console.log(`   ${c.name.padEnd(25)} ${c.count.toString().padStart(6)} docs - ${c.status}`);
      });
    }

    if (analysis.empty.length > 0) {
      console.log('\n🗑️  EMPTY COLLECTIONS (SAFE TO DELETE):');
      analysis.empty.forEach(c => {
        console.log(`   ${c.name.padEnd(25)} ${c.count.toString().padStart(6)} docs - ${c.status}`);
      });
    }

    console.log('\n' + '═'.repeat(70));
    console.log('\n💡 Recommendations:');
    console.log('   1. Keep all CORE collections (users, books, reading_progress, favorites)');
    console.log('   2. Review INVESTIGATE collections - check if used in code');
    console.log('   3. Safe to delete EMPTY collections');
    console.log('\n📌 Next steps:');
    console.log('   - Review the list above');
    console.log('   - Run: node cleanup_unused_collections.js <collection_name>');
    console.log('   - Or provide list of collections to delete\n');

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit();
  }
}

analyzeCollections();
