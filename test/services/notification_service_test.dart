import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:readme_app/services/notification_service.dart';

NotificationService buildService({
  required MockFirebaseAuth auth,
  required FakeFirebaseFirestore firestore,
}) {
  return NotificationService.withInstances(auth: auth, firestore: firestore);
}

MockFirebaseAuth signedInAs(String uid) => MockFirebaseAuth(
      mockUser: MockUser(uid: uid, email: '$uid@example.com'),
      signedIn: true,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('NotificationService — write paths no-op when signed out', () {
    test('sendAchievementNotification writes nothing without a user', () async {
      final firestore = FakeFirebaseFirestore();
      final service = buildService(auth: MockFirebaseAuth(), firestore: firestore);

      await service.sendAchievementNotification(
        achievementName: 'First Book',
        description: 'desc',
      );

      expect((await firestore.collection('notifications').get()).docs, isEmpty);
    });
  });

  group('NotificationService.getUserNotifications / markAllNotificationsAsRead', () {
    test('getUserNotifications only returns the signed-in user\'s notifications',
        () async {
      final firestore = FakeFirebaseFirestore();
      final auth = signedInAs('u1');
      final service = buildService(auth: auth, firestore: firestore);
      await firestore.collection('notifications').add({
        'userId': 'u1',
        'createdAt': DateTime.now(),
        'title': 'mine',
      });
      await firestore.collection('notifications').add({
        'userId': 'u2',
        'createdAt': DateTime.now(),
        'title': 'not mine',
      });

      final result = await service.getUserNotifications();

      expect(result, hasLength(1));
      expect(result.first['title'], 'mine');
    });

    test('markAllNotificationsAsRead flips every unread notification for '
        'the user, and leaves already-read and other-user docs alone',
        () async {
      final firestore = FakeFirebaseFirestore();
      final auth = signedInAs('u1');
      final service = buildService(auth: auth, firestore: firestore);
      final unread1 = await firestore.collection('notifications').add({
        'userId': 'u1',
        'isRead': false,
      });
      final unread2 = await firestore.collection('notifications').add({
        'userId': 'u1',
        'isRead': false,
      });
      final alreadyRead = await firestore.collection('notifications').add({
        'userId': 'u1',
        'isRead': true,
      });
      final otherUser = await firestore.collection('notifications').add({
        'userId': 'u2',
        'isRead': false,
      });

      await service.markAllNotificationsAsRead();

      expect((await unread1.get()).data()!['isRead'], true);
      expect((await unread2.get()).data()!['isRead'], true);
      expect((await alreadyRead.get()).data()!['isRead'], true);
      expect((await otherUser.get()).data()!['isRead'], false);
    });

    test('getUnreadNotificationCount counts only this user\'s unread notifications',
        () async {
      final firestore = FakeFirebaseFirestore();
      final auth = signedInAs('u1');
      final service = buildService(auth: auth, firestore: firestore);
      await firestore.collection('notifications').add({'userId': 'u1', 'isRead': false});
      await firestore.collection('notifications').add({'userId': 'u1', 'isRead': true});
      await firestore.collection('notifications').add({'userId': 'u2', 'isRead': false});

      expect(await service.getUnreadNotificationCount(), 1);
    });
  });

  group('NotificationService.cleanupOldNotifications', () {
    test('deletes only notifications older than 30 days for this user',
        () async {
      final firestore = FakeFirebaseFirestore();
      final auth = signedInAs('u1');
      final service = buildService(auth: auth, firestore: firestore);
      final old = await firestore.collection('notifications').add({
        'userId': 'u1',
        'createdAt': DateTime.now().subtract(const Duration(days: 40)),
      });
      final recent = await firestore.collection('notifications').add({
        'userId': 'u1',
        'createdAt': DateTime.now().subtract(const Duration(days: 1)),
      });

      await service.cleanupOldNotifications();

      expect((await old.get()).exists, isFalse);
      expect((await recent.get()).exists, isTrue);
    });
  });

  group('NotificationService.getNotificationPreferences', () {
    test('returns sensible defaults when nothing has been saved', () async {
      final service = buildService(auth: signedInAs('u1'), firestore: FakeFirebaseFirestore());

      final prefs = await service.getNotificationPreferences();

      expect(prefs['readingReminders'], true);
      expect(prefs['achievements'], true);
      expect(prefs['reminderTime'], '18:00');
    });

    test('updateNotificationPreferences persists and round-trips', () async {
      final firestore = FakeFirebaseFirestore();
      final service = buildService(auth: signedInAs('u1'), firestore: firestore);

      await service.updateNotificationPreferences(
        readingReminders: false,
        achievements: true,
        recommendations: false,
        parentUpdates: true,
        reminderTime: '20:00',
        reminderDays: ['saturday'],
      );
      final prefs = await service.getNotificationPreferences();

      expect(prefs['readingReminders'], false);
      expect(prefs['reminderTime'], '20:00');
      expect(prefs['reminderDays'], ['saturday']);
    });
  });
}
