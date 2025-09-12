// File: lib/services/notification_service.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Initialize notification service
  Future<void> initialize() async {
    try {
      // Request notification permissions (would be implemented with firebase_messaging)
      await _requestPermissions();
      
      // Set up notification listeners
      await _setupNotificationListeners();
    } catch (e) {
      print('Error initializing notification service: $e');
    }
  }

  // Request notification permissions
  Future<void> _requestPermissions() async {
    // In a real implementation, you would use firebase_messaging
    // For now, we'll just store the permission status locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', true);
  }

  // Set up notification listeners
  Future<void> _setupNotificationListeners() async {
    // This would typically set up FCM listeners
    // For now, we'll just log that it's set up
    print('Notification listeners set up');
  }

  // Schedule reading reminder
  Future<void> scheduleReadingReminder({
    required String time, // Format: "HH:mm"
    required List<String> days, // ["monday", "tuesday", etc.]
    String? customMessage,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('reading_reminders').doc(user.uid).set({
        'userId': user.uid,
        'time': time,
        'days': days,
        'customMessage': customMessage ?? "Time to read! 📚",
        'isEnabled': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // In a real implementation, you would schedule local notifications here
      await _scheduleLocalNotifications(time, days, customMessage);
      
    } catch (e) {
      print('Error scheduling reading reminder: $e');
    }
  }

  // Schedule local notifications (placeholder implementation)
  Future<void> _scheduleLocalNotifications(String time, List<String> days, String? message) async {
    // This would use a package like flutter_local_notifications
    // For now, we'll just store the schedule locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reminder_time', time);
    await prefs.setStringList('reminder_days', days);
    await prefs.setString('reminder_message', message ?? "Time to read! 📚");
    
    print('Local notifications scheduled for $time on ${days.join(', ')}');
  }

  // Send achievement notification
  Future<void> sendAchievementNotification({
    required String achievementName,
    required String description,
    String? emoji,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Store notification in Firestore
      await _firestore.collection('notifications').add({
        'userId': user.uid,
        'type': 'achievement',
        'title': 'Achievement Unlocked! ${emoji ?? '🏆'}',
        'body': '$achievementName - $description',
        'data': {
          'achievementName': achievementName,
          'description': description,
          'emoji': emoji,
        },
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Send push notification (in real implementation)
      await _sendPushNotification(
        title: 'Achievement Unlocked! ${emoji ?? '🏆'}',
        body: achievementName,
        data: {'type': 'achievement'},
      );
    } catch (e) {
      print('Error sending achievement notification: $e');
    }
  }

  // Send reading streak notification
  Future<void> sendStreakNotification({
    required int streakDays,
    String? encouragementMessage,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final message = encouragementMessage ?? _getStreakMessage(streakDays);
      
      await _firestore.collection('notifications').add({
        'userId': user.uid,
        'type': 'streak',
        'title': 'Reading Streak! 🔥',
        'body': '$streakDays days in a row! $message',
        'data': {
          'streakDays': streakDays,
          'message': message,
        },
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _sendPushNotification(
        title: 'Reading Streak! 🔥',
        body: '$streakDays days in a row!',
        data: {'type': 'streak', 'days': streakDays.toString()},
      );
    } catch (e) {
      print('Error sending streak notification: $e');
    }
  }

  // Send book recommendation notification
  Future<void> sendBookRecommendation({
    required String bookTitle,
    required String bookId,
    String? reason,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final message = reason ?? "We found a book you might love!";
      
      await _firestore.collection('notifications').add({
        'userId': user.uid,
        'type': 'recommendation',
        'title': 'New Book Recommendation! 📖',
        'body': '$bookTitle - $message',
        'data': {
          'bookId': bookId,
          'bookTitle': bookTitle,
          'reason': reason,
        },
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _sendPushNotification(
        title: 'New Book Recommendation! 📖',
        body: bookTitle,
        data: {'type': 'recommendation', 'bookId': bookId},
      );
    } catch (e) {
      print('Error sending book recommendation: $e');
    }
  }

  // Send parent notification about child's progress
  Future<void> sendParentProgressNotification({
    required String parentUserId,
    required String childName,
    required String progressType, // 'book_completed', 'streak_milestone', 'achievement'
    required Map<String, dynamic> progressData,
  }) async {
    try {
      String title = '';
      String body = '';

      switch (progressType) {
        case 'book_completed':
          title = '$childName finished a book! 🎉';
          body = 'They completed "${progressData['bookTitle']}"';
          break;
        case 'streak_milestone':
          title = '$childName is on a reading streak! 🔥';
          body = '${progressData['days']} days in a row!';
          break;
        case 'achievement':
          title = '$childName earned an achievement! 🏆';
          body = progressData['achievementName'];
          break;
      }

      await _firestore.collection('notifications').add({
        'userId': parentUserId,
        'type': 'parent_update',
        'title': title,
        'body': body,
        'data': {
          'childName': childName,
          'progressType': progressType,
          ...progressData,
        },
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _sendPushNotification(
        title: title,
        body: body,
        data: {'type': 'parent_update'},
      );
    } catch (e) {
      print('Error sending parent notification: $e');
    }
  }

  // Get user notifications
  Future<List<Map<String, dynamic>>> getUserNotifications({int limit = 20}) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final query = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return query.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      print('Error getting user notifications: $e');
      return [];
    }
  }

  // Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  Future<void> markAllNotificationsAsRead() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final query = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in query.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  // Get unread notification count
  Future<int> getUnreadNotificationCount() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    try {
      final query = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('isRead', isEqualTo: false)
          .get();

      return query.docs.length;
    } catch (e) {
      print('Error getting unread notification count: $e');
      return 0;
    }
  }

  // Update notification preferences
  Future<void> updateNotificationPreferences({
    required bool readingReminders,
    required bool achievements,
    required bool recommendations,
    required bool parentUpdates,
    String? reminderTime,
    List<String>? reminderDays,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('notification_preferences').doc(user.uid).set({
        'userId': user.uid,
        'readingReminders': readingReminders,
        'achievements': achievements,
        'recommendations': recommendations,
        'parentUpdates': parentUpdates,
        'reminderTime': reminderTime,
        'reminderDays': reminderDays,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update local preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_reading_reminders', readingReminders);
      await prefs.setBool('notifications_achievements', achievements);
      await prefs.setBool('notifications_recommendations', recommendations);
      await prefs.setBool('notifications_parent_updates', parentUpdates);
    } catch (e) {
      print('Error updating notification preferences: $e');
    }
  }

  // Get notification preferences
  Future<Map<String, dynamic>> getNotificationPreferences() async {
    final user = _auth.currentUser;
    if (user == null) return _getDefaultPreferences();

    try {
      final doc = await _firestore.collection('notification_preferences').doc(user.uid).get();
      
      if (doc.exists) {
        return doc.data() ?? _getDefaultPreferences();
      } else {
        return _getDefaultPreferences();
      }
    } catch (e) {
      print('Error getting notification preferences: $e');
      return _getDefaultPreferences();
    }
  }

  // Get default notification preferences
  Map<String, dynamic> _getDefaultPreferences() {
    return {
      'readingReminders': true,
      'achievements': true,
      'recommendations': true,
      'parentUpdates': true,
      'reminderTime': '18:00',
      'reminderDays': ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'],
    };
  }

  // Send push notification (placeholder implementation)
  Future<void> _sendPushNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    // In a real implementation, this would use Firebase Cloud Messaging
    if (kDebugMode) {
      print('Push Notification: $title - $body');
      if (data != null) {
        print('Data: $data');
      }
    }
  }

  // Get streak encouragement message
  String _getStreakMessage(int days) {
    if (days == 1) return "Great start! Keep it up! 🌟";
    if (days == 3) return "Three days strong! You're building a habit! 💪";
    if (days == 7) return "A whole week! You're amazing! 🎉";
    if (days == 14) return "Two weeks of reading! Incredible! 🚀";
    if (days == 30) return "A month of daily reading! You're a reading champion! 👑";
    if (days % 10 == 0) return "What an achievement! Keep the streak alive! ⭐";
    return "Keep up the fantastic work! 📚";
  }

  // Clean up old notifications (call this periodically)
  Future<void> cleanupOldNotifications() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      final query = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('createdAt', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      final batch = _firestore.batch();
      for (final doc in query.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      print('Cleaned up ${query.docs.length} old notifications');
    } catch (e) {
      print('Error cleaning up old notifications: $e');
    }
  }
}
