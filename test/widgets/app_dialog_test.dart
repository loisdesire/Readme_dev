import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/widgets/app_dialog.dart';

Widget wrap(Widget dialog) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: GestureDetector(
            onTap: () => showDialog<void>(
              context: context,
              builder: (_) => dialog,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  // Regression for the parental gate: `primaryLabel: ' '` with a no-op
  // onPrimary was meant to "hide" the primary button, but AppDialog always
  // rendered a real, tappable, full-color ElevatedButton whenever
  // secondaryLabel was set — it just had blank text. A dialog that only
  // needs one action (secondaryLabel, no primaryLabel) must render just
  // that one button, not a second decoy. See SECURITY.md.
  testWidgets(
      'secondaryLabel with no primaryLabel renders only the secondary '
      'button — no blank/decoy primary button', (tester) async {
    await tester.pumpWidget(wrap(AppDialog(
      icon: Icons.lock_outline,
      title: 'Grown-ups Only!',
      secondaryLabel: 'Cancel',
      onSecondary: () {},
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, 'Cancel'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
  });

  testWidgets('primaryLabel with no secondaryLabel renders only the '
      'primary button', (tester) async {
    await tester.pumpWidget(wrap(AppDialog(
      icon: Icons.check,
      title: 'Done',
      primaryLabel: 'OK',
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ElevatedButton, 'OK'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  // Regression for the filter dialog: migrating from a 3-action AlertDialog
  // (Clear All / Cancel / Apply) to AppDialog's 2-slot footer silently
  // dropped the explicit Cancel. showCloseButton restores an explicit,
  // discoverable way to back out without applying when a dialog genuinely
  // needs a third, non-destructive action. See SECURITY.md.
  testWidgets('showCloseButton renders a close affordance that pops the '
      'dialog', (tester) async {
    await tester.pumpWidget(wrap(AppDialog(
      icon: Icons.tune,
      title: 'Filter Books',
      secondaryLabel: 'Clear All',
      onSecondary: () {},
      primaryLabel: 'Apply',
      onPrimary: () {},
      showCloseButton: true,
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Filter Books'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Filter Books'), findsNothing);
  });

  testWidgets('showCloseButton defaults to false — no close icon for a '
      'plain two-action dialog', (tester) async {
    await tester.pumpWidget(wrap(AppDialog(
      icon: Icons.delete_outline,
      title: 'Delete Book',
      secondaryLabel: 'Cancel',
      onSecondary: () {},
      primaryLabel: 'Delete',
      onPrimary: () {},
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close), findsNothing);
  });
}
