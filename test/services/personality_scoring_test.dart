import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/services/personality_scoring.dart';

/// Builds a 10-question, 2-per-dimension question list matching the real
/// quiz_screen.dart layout: O, C, E, A, N, O, C, E, A, N.
List<Map<String, dynamic>> _standardQuestions({
  List<bool>? reversedFlags,
}) {
  const dims = ['O', 'C', 'E', 'A', 'N', 'O', 'C', 'E', 'A', 'N'];
  return List.generate(
    dims.length,
    (i) => {
      'question': 'q$i',
      'dimension': dims[i],
      'isReversed': reversedFlags != null ? reversedFlags[i] : false,
    },
  );
}

void main() {
  group('calculateOceanScores', () {
    test('sums two Likert answers per dimension with no reversal', () {
      final questions = _standardQuestions();
      // O C E A N O C E A N
      final answers = [5, 4, 3, 2, 1, 5, 4, 3, 2, 1];

      final scores = calculateOceanScores(answers: answers, questions: questions);

      expect(scores['O'], 10); // 5 + 5
      expect(scores['C'], 8); // 4 + 4
      expect(scores['E'], 6); // 3 + 3
      expect(scores['A'], 4); // 2 + 2
      expect(scores['N'], 2); // 1 + 1
    });

    test('reversed items are scored as 6 - answer', () {
      final questions = _standardQuestions(
        reversedFlags: [false, false, false, false, true, false, false, false, false, true],
      );
      final answers = [3, 3, 3, 3, 5, 3, 3, 3, 3, 1]; // N answers: 5 then 1

      final scores = calculateOceanScores(answers: answers, questions: questions);

      // N: (6-5) + (6-1) = 1 + 5 = 6
      expect(scores['N'], 6);
      // Unaffected dimensions still sum normally.
      expect(scores['O'], 6);
    });

    test('every dimension defaults to present with score 0', () {
      final scores = calculateOceanScores(answers: const [], questions: const []);
      expect(scores.keys.toSet(), {'O', 'C', 'E', 'A', 'N'});
      expect(scores.values.every((v) => v == 0), isTrue);
    });

    test('mismatched answers/questions length only scores the overlap', () {
      final questions = _standardQuestions().take(3).toList(); // O, C, E
      final answers = [5, 5, 5, 5, 5]; // extra answers beyond questions

      final scores = calculateOceanScores(answers: answers, questions: questions);

      expect(scores['O'], 5);
      expect(scores['C'], 5);
      expect(scores['E'], 5);
      expect(scores['A'], 0);
      expect(scores['N'], 0);
    });
  });

  group('mapOceanToSubTraits — normal (non-tied) case', () {
    // Always all 3 of the top dimension's traits — no dimension has more
    // than 3 to give, so "the top dimension dominates" can never be
    // reflected by giving it *more* than 3; the only lever for how
    // decisively it won is how the remaining 2 slots split among the
    // dimensions behind it (see the D'Hondt group below).
    test('a clearly-separated runner-up (more than double the 3rd-place '
        'score) still gets both remaining slots', () {
      final scores = {'O': 20, 'C': 5, 'E': 1, 'A': 1, 'N': 1};

      final traits = mapOceanToSubTraits(scores);

      expect(traits, [
        'curious', 'creative', 'imaginative', // all of O
        'responsible', 'organized', // both remaining slots: C, not shared
      ]);
    });

    test('getTopTraits returns exactly the first 3 (from the top dimension)', () {
      final scores = {'A': 10, 'N': 8, 'O': 6, 'C': 4, 'E': 2};
      expect(getTopTraits(scores), ['kind', 'cooperative', 'caring']);
    });

    test('getTopTraits is unaffected by how the remaining 2 slots split '
        'among lower dimensions', () {
      // Same scores as the D'Hondt-sharing example below, where traits
      // #4-5 come from two different dimensions instead of one — the top
      // 3 shown to the child should be identical regardless.
      final scores = {'O': 10, 'C': 8, 'E': 6, 'A': 4, 'N': 2};
      expect(getTopTraits(scores), ['curious', 'creative', 'imaginative']);
    });
  });

  group('mapOceanToSubTraits — D\'Hondt allocation of the remaining 2 slots',
      () {
    // The remaining 2 slots (after the top dimension's guaranteed 3) are
    // allocated among every other dimension via D'Hondt (the same
    // divisor-based method used for allocating seats by vote share):
    // repeatedly award the next slot to whichever contender currently has
    // the highest score / (slots it already holds + 1). A dimension needs
    // its own score to exceed half of a rival's to take a slot away from
    // it — so a runner-up who's more than double the 3rd-place score (the
    // group above) keeps both, but a 3rd place within striking distance
    // of 2nd now earns a share instead of being ignored just for being
    // one rank behind.
    test('a 3rd-place dimension within striking distance of 2nd shares one '
        'of the 2 remaining slots instead of being shut out entirely', () {
      final scores = {'O': 10, 'C': 8, 'E': 6, 'A': 4, 'N': 2};

      final traits = mapOceanToSubTraits(scores);

      expect(traits, [
        'curious', 'creative', 'imaginative', // all of O (top, always 3)
        'responsible', // 1 slot to C (8/1=8 wins round 1)
        'social', // 1 slot to E: C's 2nd-round quotient (8/2=4) < E's (6/1=6)
      ]);
    });

    test('getAllTraits returns exactly 5, split across 3 dimensions when '
        'that reflects the actual score spread', () {
      final scores = {'E': 10, 'A': 8, 'O': 6, 'C': 4, 'N': 2};
      final all = getAllTraits(scores);
      expect(all.length, 5);
      expect(all, ['social', 'enthusiastic', 'outgoing', 'kind', 'curious']);
    });

    test('a tie between two contenders for a D\'Hondt slot resolves toward '
        'whichever appears earlier in the input map, same convention as '
        'the top-place tie-break', () {
      // C and E tie at quotient 5 in round 2 (C: 10/2=5, E: 5/1=5) — C
      // appears first in this map's insertion order, matching the
      // documented top-place tie-break convention below.
      final scores = {'O': 20, 'C': 10, 'E': 5, 'A': 3, 'N': 1};
      final traits = mapOceanToSubTraits(scores);
      expect(traits, [
        'curious', 'creative', 'imaginative', // O
        'responsible', 'organized', // both slots to C, tie-break over E
      ]);
    });
  });

  group('mapOceanToSubTraits — all-scores-identical fallback', () {
    test('spreads traits round-robin across all 5 dimensions when tied', () {
      final scores = {'O': 5, 'C': 5, 'E': 5, 'A': 5, 'N': 5};

      final traits = mapOceanToSubTraits(scores);

      expect(traits.length, 5);
      // One trait pulled from each dimension, in Map iteration order.
      final dims = scores.keys.toList();
      final expected = [
        for (var i = 0; i < 5; i++) oceanToSubTraits[dims[i]]![0],
      ];
      expect(traits, expected);
    });

    test('a flat zero score (unanswered quiz) still returns 5 distinct traits', () {
      final scores = {'O': 0, 'C': 0, 'E': 0, 'A': 0, 'N': 0};
      final traits = mapOceanToSubTraits(scores);
      expect(traits.length, 5);
      expect(traits.toSet().length, 5); // all distinct, one per dimension
    });
  });

  group('mapOceanToSubTraits — documents current tie-break behavior', () {
    // Not asserting this is "correct" in some abstract sense — pinning the
    // actual, verified behavior so a future change to the sort/map
    // construction is a conscious decision, not an accidental regression.
    test('a tie is resolved toward whichever dimension appears earlier '
        'in the input map', () {
      final oWins = mapOceanToSubTraits({'O': 10, 'C': 10, 'E': 5, 'A': 3, 'N': 1});
      expect(oWins.take(3), ['curious', 'creative', 'imaginative']); // O's traits

      final cWins = mapOceanToSubTraits({'C': 10, 'O': 10, 'E': 5, 'A': 3, 'N': 1});
      expect(cWins.take(3), ['responsible', 'organized', 'persistent']); // C's traits
    });

    test('end-to-end via calculateOceanScores: a real tie between O and C '
        'always resolves to O, since that map is always built in OCEAN '
        'order', () {
      // O and C both score 10 (2 questions x Likert 5), tying for first.
      final questions = _standardQuestions(); // O C E A N O C E A N
      final answers = [5, 5, 1, 1, 1, 5, 5, 1, 1, 1];

      final scores = calculateOceanScores(answers: answers, questions: questions);
      expect(scores['O'], 10);
      expect(scores['C'], 10);

      final traits = getAllTraits(scores);
      expect(traits.take(3), ['curious', 'creative', 'imaginative']); // O wins
    });
  });
}
