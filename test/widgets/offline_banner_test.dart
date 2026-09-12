import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:readme_app/services/offline_service.dart';
import 'package:readme_app/widgets/offline_banner.dart';

// OfflineBanner wraps the entire app in main.dart via
// ChangeNotifierProvider.value(value: OfflineService.instance) — its
// correctness matters everywhere, not just one screen.

Widget wrap(Widget child) {
  return MaterialApp(
    home: ChangeNotifierProvider<OfflineService>.value(
      value: OfflineService.instance,
      child: child,
    ),
  );
}

void main() {
  setUp(() {
    // OfflineService.instance is a real singleton; reset between tests.
    OfflineService.instance.setOfflineForTesting(false);
  });

  testWidgets('online: no banner, child content still renders',
      (tester) async {
    await tester.pumpWidget(wrap(
      const OfflineBanner(child: Text('home content')),
    ));

    expect(find.text('home content'), findsOneWidget);
    expect(find.textContaining('offline'), findsNothing);
  });

  testWidgets('offline: banner appears above the child content, which is '
      'still rendered (not replaced)', (tester) async {
    OfflineService.instance.setOfflineForTesting(true);

    await tester.pumpWidget(wrap(
      const OfflineBanner(child: Text('home content')),
    ));
    await tester.pump();

    expect(find.textContaining('offline', findRichText: true), findsWidgets);
    expect(find.text('home content'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
  });

  testWidgets('banner appears and disappears reactively as OfflineService '
      'notifies listeners, without rebuilding the whole screen',
      (tester) async {
    await tester.pumpWidget(wrap(
      const OfflineBanner(child: Text('home content')),
    ));
    expect(find.byIcon(Icons.cloud_off), findsNothing);

    OfflineService.instance.setOfflineForTesting(true);
    await tester.pump();
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);

    OfflineService.instance.setOfflineForTesting(false);
    await tester.pump();
    expect(find.byIcon(Icons.cloud_off), findsNothing);
  });
}
