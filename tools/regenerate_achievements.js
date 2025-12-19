/**
 * Regenerate Achievements Collection
 * 
 * This script recreates the achievements collection by analyzing user data
 * and recalculating what achievements each user should have earned.
 * 
 * Usage: node regenerate_achievements.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Achievement definitions (from achievement_service.dart)
const ACHIEVEMENTS = [
  // Reading achievements
  { id: 'first_book', name: 'First Steps', description: 'Complete your first book', requiredValue: 1, type: 'books_read', category: 'reading', emoji: 'book', points: 10 },
  { id: 'three_books', name: 'Getting Started', description: 'Complete 3 books', requiredValue: 3, type: 'books_read', category: 'reading', emoji: 'menu_book', points: 15 },
  { id: 'book_lover', name: 'Book Lover', description: 'Complete 5 books', requiredValue: 5, type: 'books_read', category: 'reading', emoji: 'favorite', points: 25 },
  { id: 'bookworm', name: 'Bookworm', description: 'Complete 10 books', requiredValue: 10, type: 'books_read', category: 'reading', emoji: 'auto_stories', points: 40 },
  { id: 'fifteen_books', name: 'Reading Enthusiast', description: 'Complete 15 books', requiredValue: 15, type: 'books_read', category: 'reading', emoji: 'import_contacts', points: 60 },
  { id: 'twenty_books', name: 'Avid Reader', description: 'Complete 20 books', requiredValue: 20, type: 'books_read', category: 'reading', emoji: 'library_books', points: 80 },
  { id: 'thirty_books', name: 'Reading Star', description: 'Complete 30 books', requiredValue: 30, type: 'books_read', category: 'reading', emoji: 'star', points: 120 },
  { id: 'forty_books', name: 'Book Champion', description: 'Complete 40 books', requiredValue: 40, type: 'books_read', category: 'reading', emoji: 'emoji_events', points: 160 },
  { id: 'fifty_books', name: 'Super Reader', description: 'Complete 50 books', requiredValue: 50, type: 'books_read', category: 'reading', emoji: 'stars', points: 200 },
  { id: 'seventyfive_books', name: 'Reading Master', description: 'Complete 75 books', requiredValue: 75, type: 'books_read', category: 'reading', emoji: 'workspace_premium', points: 300 },
  { id: 'hundred_books', name: 'Century Reader', description: 'Complete 100 books', requiredValue: 100, type: 'books_read', category: 'reading', emoji: 'military_tech', points: 400 },
  { id: 'hundred_fifty_books', name: 'Reading Legend', description: 'Complete 150 books', requiredValue: 150, type: 'books_read', category: 'reading', emoji: 'diamond', points: 600 },
  { id: 'twohundred_books', name: 'Ultimate Reader', description: 'Complete 200 books', requiredValue: 200, type: 'books_read', category: 'reading', emoji: 'crown', points: 1000 },

  // Streak achievements
  { id: 'streak_starter', name: 'Streak Starter', description: 'Read for 3 days in a row', requiredValue: 3, type: 'reading_streak', category: 'streak', emoji: 'local_fire_department', points: 15 },
  { id: 'five_day_streak', name: 'Getting Hot', description: 'Read for 5 days in a row', requiredValue: 5, type: 'reading_streak', category: 'streak', emoji: 'local_fire_department', points: 25 },
  { id: 'week_warrior', name: 'Week Warrior', description: 'Read for 7 days in a row', requiredValue: 7, type: 'reading_streak', category: 'streak', emoji: 'whatshot', points: 35 },
  { id: 'two_week_streak', name: 'On Fire', description: 'Read for 14 days in a row', requiredValue: 14, type: 'reading_streak', category: 'streak', emoji: 'whatshot', points: 60 },
  { id: 'three_week_streak', name: 'Unstoppable', description: 'Read for 21 days in a row', requiredValue: 21, type: 'reading_streak', category: 'streak', emoji: 'bolt', points: 80 },
  { id: 'month_master', name: 'Month Master', description: 'Read for 30 days in a row', requiredValue: 30, type: 'reading_streak', category: 'streak', emoji: 'bolt', points: 100 },
  { id: 'fifty_day_streak', name: 'Streak Champion', description: 'Read for 50 days in a row', requiredValue: 50, type: 'reading_streak', category: 'streak', emoji: 'stars', points: 150 },
  { id: 'hundred_day_streak', name: 'Streak Legend', description: 'Read for 100 days in a row', requiredValue: 100, type: 'reading_streak', category: 'streak', emoji: 'diamond', points: 300 },

  // Time achievements
  { id: 'half_hour_reader', name: 'Getting Started', description: 'Read for 30 minutes total', requiredValue: 30, type: 'reading_time', category: 'time', emoji: 'schedule', points: 10 },
  { id: 'hour_hero', name: 'Hour Hero', description: 'Read for 60 minutes total', requiredValue: 60, type: 'reading_time', category: 'time', emoji: 'schedule', points: 20 },
  { id: 'two_hour_reader', name: 'Time Keeper', description: 'Read for 2 hours total', requiredValue: 120, type: 'reading_time', category: 'time', emoji: 'access_time', points: 35 },
  { id: 'time_traveler', name: 'Time Traveler', description: 'Read for 5 hours total', requiredValue: 300, type: 'reading_time', category: 'time', emoji: 'access_time', points: 60 },
  { id: 'marathon_reader', name: 'Marathon Reader', description: 'Read for 10 hours total', requiredValue: 600, type: 'reading_time', category: 'time', emoji: 'timer', points: 100 },
  { id: 'time_master', name: 'Time Master', description: 'Read for 20 hours total', requiredValue: 1200, type: 'reading_time', category: 'time', emoji: 'timer', points: 150 },
  { id: 'time_champion', name: 'Time Champion', description: 'Read for 50 hours total', requiredValue: 3000, type: 'reading_time', category: 'time', emoji: 'hourglass_full', points: 250 },

  // Session achievements
  { id: 'first_session', name: 'First Session', description: 'Complete your first reading session', requiredValue: 1, type: 'reading_sessions', category: 'sessions', emoji: 'play_circle', points: 5 },
  { id: 'five_sessions', name: 'Getting into it', description: 'Complete 5 reading sessions', requiredValue: 5, type: 'reading_sessions', category: 'sessions', emoji: 'play_circle', points: 15 },
  { id: 'session_starter', name: 'Session Starter', description: 'Complete 10 reading sessions', requiredValue: 10, type: 'reading_sessions', category: 'sessions', emoji: 'play_circle', points: 25 },
  { id: 'regular_reader', name: 'Regular Reader', description: 'Complete 25 reading sessions', requiredValue: 25, type: 'reading_sessions', category: 'sessions', emoji: 'verified', points: 50 },
  { id: 'dedicated_reader', name: 'Dedicated Reader', description: 'Complete 50 reading sessions', requiredValue: 50, type: 'reading_sessions', category: 'sessions', emoji: 'verified', points: 80 },
  { id: 'session_master', name: 'Session Master', description: 'Complete 100 reading sessions', requiredValue: 100, type: 'reading_sessions', category: 'sessions', emoji: 'workspace_premium', points: 150 },
  { id: 'session_champion', name: 'Session Champion', description: 'Complete 200 reading sessions', requiredValue: 200, type: 'reading_sessions', category: 'sessions', emoji: 'military_tech', points: 250 },
];

async function regenerateAchievements() {
  try {
    console.log('🔄 Regenerating achievements collections...\n');
    console.log('═'.repeat(70));

    // Step 1: Populate the achievements collection (master list)
    console.log('\n📚 Creating achievement definitions...\n');
    for (const achievement of ACHIEVEMENTS) {
      await db.collection('achievements').doc(achievement.id).set({
        id: achievement.id,
        name: achievement.name,
        description: achievement.description,
        emoji: achievement.emoji,
        category: achievement.category,
        requiredValue: achievement.requiredValue,
        type: achievement.type,
        points: achievement.points,
      });
      console.log(`   ✅ ${achievement.name}`);
    }
    console.log(`\n✅ Created ${ACHIEVEMENTS.length} achievement definitions\n`);
    console.log('═'.repeat(70));

    // Step 2: Award achievements to users based on their progress
    console.log('\n🎖️  Awarding achievements to users...\n');
    
    // Get all users
    const usersSnapshot = await db.collection('users').get();
    let totalAchievements = 0;
    let processedUsers = 0;

    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      const userData = userDoc.data();
      
      // Skip parent accounts
      if (userData.accountType === 'parent') {
        continue;
      }

      console.log(`\nProcessing: ${userData.username || userId}`);

      // Get user's completed books count
      const progressSnapshot = await db.collection('reading_progress')
        .where('userId', '==', userId)
        .where('isCompleted', '==', true)
        .get();
      
      const booksCompleted = progressSnapshot.size;
      
      // Get user's reading sessions count
      const sessionsSnapshot = await db.collection('reading_sessions')
        .where('userId', '==', userId)
        .get();
      
      const sessionsCount = sessionsSnapshot.size;
      
      // Calculate total reading time from sessions (sessionDurationSeconds)
      let totalReadingTime = 0;
      sessionsSnapshot.forEach(session => {
        const data = session.data();
        if (data.sessionDurationSeconds) {
          totalReadingTime += Math.floor(data.sessionDurationSeconds / 60); // convert seconds to minutes
        }
      });

      const currentStreak = userData.currentStreak || 0;

      console.log(`   Books completed: ${booksCompleted}`);
      console.log(`   Current streak: ${currentStreak} days`);
      console.log(`   Reading sessions: ${sessionsCount}`);
      console.log(`   Total reading time: ${totalReadingTime} minutes`);

      let userPoints = 0;
      let achievementCount = 0;
      const earnedAchievementIds = [];

      // Check each achievement
      for (const achievement of ACHIEVEMENTS) {
        let earned = false;
        let currentValue = 0;

        if (achievement.type === 'books_read') {
          currentValue = booksCompleted;
          earned = booksCompleted >= achievement.requiredValue;
        } else if (achievement.type === 'reading_streak') {
          currentValue = currentStreak;
          earned = currentStreak >= achievement.requiredValue;
        } else if (achievement.type === 'reading_time') {
          currentValue = totalReadingTime;
          earned = totalReadingTime >= achievement.requiredValue;
        } else if (achievement.type === 'reading_sessions') {
          currentValue = sessionsCount;
          earned = sessionsCount >= achievement.requiredValue;
        }

        if (earned) {
          // Create achievement document in user_achievements subcollection
          await db.collection('user_achievements').add({
            userId: userId,
            achievementId: achievement.id,
            name: achievement.name,
            description: achievement.description,
            emoji: achievement.emoji,
            category: achievement.category,
            points: achievement.points,
            earnedAt: admin.firestore.FieldValue.serverTimestamp(),
            type: achievement.type,
            requiredValue: achievement.requiredValue,
            currentValue: currentValue,
          });

          userPoints += achievement.points;
          achievementCount++;
          totalAchievements++;
          earnedAchievementIds.push(achievement.id);
        }
      }

      // Update user document
      await db.collection('users').doc(userId).update({
        totalAchievementPoints: userPoints,
        achievements: earnedAchievementIds,
      });

      console.log(`   ✅ Awarded ${achievementCount} achievements (${userPoints} points)`);
      processedUsers++;
    }

    console.log('\n' + '═'.repeat(70));
    console.log(`\n🎉 Achievement regeneration complete!`);
    console.log(`   Users processed: ${processedUsers}`);
    console.log(`   Total achievements created: ${totalAchievements}\n`);

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit();
  }
}

regenerateAchievements();
