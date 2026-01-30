const admin = require('firebase-admin');

// ⚠️ WARNING: This script imports users from readme-40267 to readmev2
// Only run if you want to RESTORE users from backup
// To prevent accidental reimports, authentication is now required.

console.log('\n⚠️  WARNING: This script will import users from readme-40267 to readmev2');
console.log('This should only be run if you explicitly want to restore deleted users.');
console.log('Type "yes" to proceed, or press Ctrl+C to cancel.\n');

// Prompt for confirmation
const readline = require('readline');
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

rl.question('Do you want to proceed? (type "yes" to confirm): ', async (answer) => {
  rl.close();
  
  if (answer !== 'yes') {
    console.log('❌ Import cancelled.');
    process.exit(0);
  }

  // Initialize source database (readme-40267)
  const sourceServiceAccount = require('./serviceAccountKey.json');
  const sourceApp = admin.initializeApp({
    credential: admin.credential.cert(sourceServiceAccount),
    projectId: 'readme-40267'
  }, 'source');
  const sourceDb = sourceApp.firestore();

  // Initialize target database (readmev2)
  const targetServiceAccount = require('./serviceAccountKey_1.json');
  const targetApp = admin.initializeApp({
    credential: admin.credential.cert(targetServiceAccount),
    projectId: 'readmev2'
  }, 'target');
  const targetDb = targetApp.firestore();

async function importUsers() {
  try {
    const fs = require('fs');
    const timestamp = new Date().toISOString();
    
    console.log('🔄 Starting user import from readme-40267 to readmev2...\n');
    console.log(`⏰ Import started at: ${timestamp}\n`);

    // Fetch all users from source database
    const usersSnapshot = await sourceDb.collection('users').get();
    console.log(`📊 Found ${usersSnapshot.size} users in source database\n`);

    let imported = 0;
    let skipped = 0;
    let errors = 0;

    for (const doc of usersSnapshot.docs) {
      try {
        const userId = doc.id;
        const userData = doc.data();

        // Check if user already exists in target
        const existingUser = await targetDb.collection('users').doc(userId).get();
        
        if (existingUser.exists) {
          console.log(`⏭️  Skipping ${userData.username || userId} (already exists)`);
          skipped++;
          continue;
        }

        // Add leaderboard fields if they don't exist
        const enrichedUserData = {
          ...userData,
          totalAchievementPoints: userData.totalAchievementPoints || 0,
          weeklyPoints: userData.weeklyPoints || 0,
          monthlyPoints: userData.monthlyPoints || 0,
          lastWeekRank: userData.lastWeekRank || null,
          weeklyChampionBadge: userData.weeklyChampionBadge || null,
          totalBooksRead: userData.totalBooksRead || 0,
          currentStreak: userData.currentStreak || 0,
        };

        // Import to target database
        await targetDb.collection('users').doc(userId).set(enrichedUserData);
        console.log(`✅ Imported ${userData.username || userId}`);
        imported++;

      } catch (error) {
        console.error(`❌ Error importing user ${doc.id}:`, error.message);
        errors++;
      }
    }

    const endTime = new Date().toISOString();
    const logEntry = `[${timestamp} to ${endTime}] Imported: ${imported}, Skipped: ${skipped}, Errors: ${errors}, Total: ${usersSnapshot.size}\n`;
    
    // Append to audit log for tracking
    fs.appendFileSync('import_users_log.txt', logEntry);

    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('📈 Import Summary:');
    console.log(`   ✅ Imported: ${imported}`);
    console.log(`   ⏭️  Skipped: ${skipped}`);
    console.log(`   ❌ Errors: ${errors}`);
    console.log(`   📊 Total: ${usersSnapshot.size}`);
    console.log(`   📝 Logged to: import_users_log.txt`);
    console.log(`   ⏰ Ended at: ${endTime}`);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  } catch (error) {
    console.error('❌ Fatal error during import:', error);
  } finally {
    await sourceApp.delete();
    await targetApp.delete();
    process.exit(0);
  }
}

importUsers();
