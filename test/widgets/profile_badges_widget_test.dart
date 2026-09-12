import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/services/achievement_service.dart';
import 'package:readme_app/widgets/profile_badges_widget.dart';

Achievement achievement({
  required String id,
  required String name,
  bool isUnlocked = false,
  int requiredValue = 1,
}) {
  return Achievement(
    id: id,
    name: name,
    description: 'desc',
    emoji: 'book',
    category: 'general',
    requiredValue: requiredValue,
    type: 'books_read',
    points: 10,
    isUnlocked: isUnlocked,
  );
}

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('no achievements: shows the empty-state message, no grid',
      (tester) async {
    await tester.pumpWidget(wrap(const ProfileBadgesWidget(achievements: [])));

    expect(find.textContaining('No badges yet'), findsOneWidget);
    expect(find.byType(GridView), findsNothing);
  });

  testWidgets('unlocked badges are sorted before locked ones', (tester) async {
    await tester.pumpWidget(wrap(ProfileBadgesWidget(achievements: [
      achievement(id: 'locked', name: 'Locked One', isUnlocked: false),
      achievement(id: 'unlocked', name: 'Unlocked One', isUnlocked: true),
    ])));

    // Both render (only 2, under the default maxCount of 4) — check the
    // unlocked one visually leads by locating it first in the grid's
    // child list order.
    final badgeTexts = tester
        .widgetList<Text>(find.descendant(
          of: find.byType(GridView),
          matching: find.byType(Text),
        ))
        .map((t) => t.data)
        .toList();
    expect(badgeTexts.indexOf('Unlocked One'), lessThan(badgeTexts.indexOf('Locked One')));
  });

  testWidgets('among locked badges, the most achievable (lowest '
      'requiredValue) sorts first', (tester) async {
    await tester.pumpWidget(wrap(ProfileBadgesWidget(achievements: [
      achievement(id: 'far', name: 'Far Off', requiredValue: 100),
      achievement(id: 'near', name: 'Almost There', requiredValue: 2),
    ])));

    final badgeTexts = tester
        .widgetList<Text>(find.descendant(
          of: find.byType(GridView),
          matching: find.byType(Text),
        ))
        .map((t) => t.data)
        .toList();
    expect(badgeTexts.indexOf('Almost There'), lessThan(badgeTexts.indexOf('Far Off')));
  });

  testWidgets('maxCount limits how many badges render when showAll is false',
      (tester) async {
    await tester.pumpWidget(wrap(ProfileBadgesWidget(
      achievements: List.generate(6, (i) => achievement(id: 'a$i', name: 'Badge $i')),
      maxCount: 4,
    )));

    expect(find.textContaining('Badge '), findsNWidgets(4));
  });

  testWidgets('showAll: true renders every achievement, ignoring maxCount',
      (tester) async {
    await tester.pumpWidget(wrap(ProfileBadgesWidget(
      achievements: List.generate(6, (i) => achievement(id: 'a$i', name: 'Badge $i')),
      maxCount: 4,
      showAll: true,
    )));

    expect(find.textContaining('Badge '), findsNWidgets(6));
  });

  testWidgets('tapping a badge opens a dialog naming it, showing "Locked" '
      'only when it is not unlocked', (tester) async {
    await tester.pumpWidget(wrap(ProfileBadgesWidget(achievements: [
      achievement(id: 'locked', name: 'Locked Badge', isUnlocked: false),
    ])));

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(find.text('Locked'), findsOneWidget);
    // The badge name now appears twice: once in the grid tile behind the
    // dialog, once in the dialog's own title.
    expect(find.text('Locked Badge'), findsNWidgets(2));
  });
}
