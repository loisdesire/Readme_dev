import 'dart:math';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A lightweight "grown-ups only" check shown before an account-level
/// action (sign out, edit profile, reveal the parent-linking PIN) — see
/// early-childhood audit finding #5 in SECURITY.md. With a 4-7-year-old
/// often operating the app unsupervised, a bare tap on these was enough
/// to sign the account out or change the profile; this puts one small,
/// deliberate obstacle in front of that.
///
/// This is the standard "parental gate" pattern used across children's
/// apps generally — a simple arithmetic problem a young child can't
/// reliably solve, not a real authentication mechanism. It's
/// deliberately NOT the account-model redesign the audit's finding #2
/// calls for (parent-owned accounts with credential-free child
/// profiles) — that's a bigger, separate decision. This gate is a
/// small, self-contained guard that still makes sense whatever that
/// redesign eventually looks like, so it isn't worth waiting on.
///
/// Returns true once answered correctly, false if cancelled, dismissed,
/// or answered wrong.
Future<bool> showParentalGate(BuildContext context) async {
  final random = Random();
  final a = 10 + random.nextInt(10); // 10-19
  final b = 10 + random.nextInt(10); // 10-19
  final correct = a + b;

  // Plausible-but-wrong distractors near the real answer, so a random
  // guess isn't a 1-in-4 coin flip toward the obviously-different one.
  final wrongOptions = <int>{};
  while (wrongOptions.length < 3) {
    final offset = 1 + random.nextInt(6);
    final candidate = random.nextBool() ? correct + offset : correct - offset;
    if (candidate != correct && candidate > 0) wrongOptions.add(candidate);
  }
  final options = [correct, ...wrongOptions]..shuffle(random);

  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Grown-ups Only!'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ask a grown-up to answer this to continue:'),
          const SizedBox(height: 12),
          Text(
            '$a + $b = ?',
            style: AppTheme.heading.copyWith(fontSize: 22),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: options.map((option) {
              return OutlinedButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, option == correct),
                child: Text('$option'),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );

  return result ?? false;
}
