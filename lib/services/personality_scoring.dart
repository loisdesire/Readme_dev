// File: lib/services/personality_scoring.dart
//
// Pure, side-effect-free scoring logic for the BFI-C (Big Five Inventory for
// Children) personality quiz. Extracted from quiz_result_screen.dart so it
// can be unit-tested without spinning up widgets or Firebase — this is the
// "core innovation" the app is built around, so it deserves real test
// coverage.
//
// Behavior here is intentionally unchanged from the original
// _QuizResultScreenState methods it replaces (_calculateOceanScores,
// _mapOceanToSubTraits, _getTopTraits, _getAllTraits) — this is a pure
// extraction, not a redesign. See personality_scoring_test.dart for the
// characterization tests that pin down current behavior (including a couple
// of quirks worth knowing about — documented below).

/// The five OCEAN dimension keys used throughout the quiz data.
const List<String> oceanDimensions = ['O', 'C', 'E', 'A', 'N'];

/// Each OCEAN dimension's three display sub-traits, used both for the
/// "Your Top Traits" UI and for book-matching tags saved to Firestore.
const Map<String, List<String>> oceanToSubTraits = {
  'O': ['curious', 'creative', 'imaginative'],
  'C': ['responsible', 'organized', 'persistent'],
  'E': ['social', 'enthusiastic', 'outgoing'],
  'A': ['kind', 'cooperative', 'caring'],
  'N': ['resilient', 'calm', 'positive'],
};

/// Sums Likert answers (1-5) into a raw score per OCEAN dimension.
///
/// `questions[i]['dimension']` (a String key from [oceanDimensions]) says
/// which dimension answers[i] belongs to; `questions[i]['isReversed']`
/// (bool, defaults to false) flips the score via `6 - score` for
/// reverse-keyed items. Extra/missing entries beyond the shorter of the two
/// lists are ignored, matching the original screen's behavior.
Map<String, int> calculateOceanScores({
  required List<int> answers,
  required List<Map<String, dynamic>> questions,
}) {
  final oceanScores = <String, int>{for (final d in oceanDimensions) d: 0};

  final count = answers.length < questions.length
      ? answers.length
      : questions.length;

  for (var i = 0; i < count; i++) {
    final dimension = questions[i]['dimension'] as String;
    final score = answers[i];
    final isReversed = questions[i]['isReversed'] as bool? ?? false;

    final adjustedScore = isReversed ? (6 - score) : score;
    oceanScores[dimension] = (oceanScores[dimension] ?? 0) + adjustedScore;
  }

  return oceanScores;
}

/// Maps OCEAN scores to exactly 5 sub-traits, used for both display and
/// book-matching.
///
/// Normal case: 3 traits from the highest-scoring dimension + 2 from the
/// second-highest. If every dimension tied (e.g. the child picked the same
/// Likert answer throughout), traits are instead spread round-robin across
/// all 5 dimensions so the result isn't just one dimension's traits.
///
/// Tie-break note (verified, not guessed — see personality_scoring_test.dart):
/// when two dimensions tie for first/second place, the winner is whichever
/// one appears first in the *input map's iteration order* (List.sort keeps
/// equal elements in their original relative order in this SDK). Because
/// [calculateOceanScores] always builds its map in [oceanDimensions] order
/// (O, C, E, A, N), a real quiz result's ties are always resolved toward the
/// earlier dimension in that order — deterministic in practice, though not
/// something to rely on if this map's construction ever changes.
List<String> mapOceanToSubTraits(Map<String, int> oceanScores) {
  final sortedDimensions = oceanScores.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final allScoresIdentical = sortedDimensions
      .every((entry) => entry.value == sortedDimensions[0].value);

  final assignedTraits = <String>[];

  if (allScoresIdentical) {
    for (var i = 0; i < 5 && i < sortedDimensions.length; i++) {
      final dimension = sortedDimensions[i % sortedDimensions.length];
      final traits = oceanToSubTraits[dimension.key] ?? [];
      if (traits.isNotEmpty) {
        assignedTraits.add(traits[i ~/ sortedDimensions.length]);
      }
    }
  } else {
    final topDimension = sortedDimensions[0];
    final secondDimension =
        sortedDimensions.length > 1 ? sortedDimensions[1] : null;

    assignedTraits.addAll(oceanToSubTraits[topDimension.key] ?? []);

    if (secondDimension != null) {
      assignedTraits.addAll((oceanToSubTraits[secondDimension.key] ?? []).take(2));
    }
  }

  return assignedTraits.take(5).toList();
}

/// The 3 traits shown to the child on the results screen.
List<String> getTopTraits(Map<String, int> oceanScores) {
  return mapOceanToSubTraits(oceanScores).take(3).toList();
}

/// All 5 traits saved to Firestore for book matching.
List<String> getAllTraits(Map<String, int> oceanScores) {
  return mapOceanToSubTraits(oceanScores);
}
