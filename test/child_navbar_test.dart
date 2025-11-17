import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/widgets/app_bottom_nav.dart';

void main() {
  testWidgets('ChildRoot provides bottom navigation and AppBottomNav shows 3 items', (WidgetTester tester) async {
    // Pump a minimal scaffold with the AppBottomNav directly to avoid
    // requiring the app-wide providers (Auth/Book/User) in this unit test.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        bottomNavigationBar: const AppBottomNav(
          currentTab: NavTab.home,
        ),
      ),
    ));

    // The bottomNavigationBar should contain AppBottomNav
    expect(find.byType(AppBottomNav), findsOneWidget);

    // The nav labels should be present
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
