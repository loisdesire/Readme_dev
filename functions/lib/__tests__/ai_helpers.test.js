const {
  ALLOWED_TAGS,
  ALLOWED_TRAITS,
  ALLOWED_AGES,
  extractJsonFromAiContent,
  parseAndValidateTaggingResponse,
  fallbackTaggingResult,
  parseRecommendationResponse,
  buildQuizPrompt,
  validateQuizFormat,
  DEFAULT_QUIZ_AGE_RANGE,
} = require('../ai_helpers');

describe('extractJsonFromAiContent', () => {
  test('parses a bare JSON object', () => {
    const result = extractJsonFromAiContent('{"a": 1}', 'object');
    expect(result).toEqual({ a: 1 });
  });

  test('parses a bare JSON array', () => {
    const result = extractJsonFromAiContent('[1, 2, 3]', 'array');
    expect(result).toEqual([1, 2, 3]);
  });

  test('strips a ```json fenced code block', () => {
    const content = 'Sure, here you go:\n```json\n{"a": 1}\n```\nHope that helps!';
    expect(extractJsonFromAiContent(content, 'object')).toEqual({ a: 1 });
  });

  test('strips a bare ``` fenced code block (no "json" tag)', () => {
    const content = '```\n[1, 2]\n```';
    expect(extractJsonFromAiContent(content, 'array')).toEqual([1, 2]);
  });

  test('throws a descriptive error when no JSON is present', () => {
    expect(() => extractJsonFromAiContent('not json at all', 'object')).toThrow(
      /No JSON object found/
    );
  });

  test('throws when the shape does not match what is present', () => {
    // An object is present, but the caller asked for an array.
    expect(() => extractJsonFromAiContent('{"a": 1}', 'array')).toThrow(
      /No JSON array found/
    );
  });
});

describe('parseAndValidateTaggingResponse', () => {
  test('keeps traits/tags that are in the allowed vocabulary', () => {
    const content = JSON.stringify({
      tags: ['adventure', 'friendship'],
      traits: ['curious', 'brave'],
      ageRating: '7+',
    });

    const result = parseAndValidateTaggingResponse(content);

    expect(result).toEqual({
      tags: ['adventure', 'friendship'],
      traits: ['curious', 'brave'],
      ageRating: '7+',
      contentConcern: false,
      concernReason: '',
    });
  });

  test('drops hallucinated traits/tags the model invented outside the '
      + 'allowed vocabulary — the core protection this function exists for',
  () => {
    const content = JSON.stringify({
      tags: ['adventure', 'a-tag-that-does-not-exist'],
      traits: ['curious', 'super-duper-happy'],
      ageRating: '7+',
    });

    const result = parseAndValidateTaggingResponse(content);

    expect(result.tags).toEqual(['adventure']);
    expect(result.traits).toEqual(['curious']);
  });

  test('an invalid ageRating is replaced with the 6+ default', () => {
    const content = JSON.stringify({
      tags: ['adventure'],
      traits: ['curious'],
      ageRating: 'PG-13', // not in ALLOWED_AGES
    });

    const result = parseAndValidateTaggingResponse(content);

    expect(result.ageRating).toBe('6+');
  });

  test('empty/fully-filtered tags or traits fall back to a varied default '
      + 'pair, deterministic via the injected randomFn', () => {
    const content = JSON.stringify({
      tags: ['not-a-real-tag'], // filtered down to empty
      traits: ['not-a-real-trait'],
      ageRating: '6+',
    });

    // Force the "random" pick to always take the first candidate.
    const result = parseAndValidateTaggingResponse(content, () => 0);

    expect(ALLOWED_TAGS).toEqual(expect.arrayContaining(result.tags.slice(0, 1)));
    expect(ALLOWED_TRAITS).toEqual(expect.arrayContaining(result.traits.slice(0, 1)));
    expect(result.tags).toHaveLength(2);
    expect(result.traits).toHaveLength(2);
  });

  test('code-fenced AI responses are handled the same as bare JSON', () => {
    const content = '```json\n' + JSON.stringify({
      tags: ['adventure'],
      traits: ['curious'],
      ageRating: '6+',
    }) + '\n```';

    expect(parseAndValidateTaggingResponse(content)).toEqual({
      tags: ['adventure'],
      traits: ['curious'],
      ageRating: '6+',
      contentConcern: false,
      concernReason: '',
    });
  });

  test('a genuine contentConcern flag and its reason are kept', () => {
    const content = JSON.stringify({
      tags: ['adventure'],
      traits: ['brave'],
      ageRating: '8+',
      contentConcern: true,
      concernReason: 'Depicts a violent battle scene in detail.',
    });

    const result = parseAndValidateTaggingResponse(content);

    expect(result.contentConcern).toBe(true);
    expect(result.concernReason).toBe('Depicts a violent battle scene in detail.');
  });

  test('contentConcern defaults to false, and concernReason to empty, '
      + 'when omitted', () => {
    const content = JSON.stringify({
      tags: ['adventure'],
      traits: ['brave'],
      ageRating: '8+',
    });

    const result = parseAndValidateTaggingResponse(content);

    expect(result.contentConcern).toBe(false);
    expect(result.concernReason).toBe('');
  });

  test('a truthy-but-not-`true` contentConcern (a hallucinated string, '
      + 'say) is treated as no concern rather than guessed at', () => {
    const content = JSON.stringify({
      tags: ['adventure'],
      traits: ['brave'],
      ageRating: '8+',
      contentConcern: 'yes',
    });

    expect(parseAndValidateTaggingResponse(content).contentConcern).toBe(false);
  });

  test('concernReason is discarded when contentConcern is false, even if '
      + 'the model included one anyway', () => {
    const content = JSON.stringify({
      tags: ['adventure'],
      traits: ['brave'],
      ageRating: '8+',
      contentConcern: false,
      concernReason: 'Should not appear.',
    });

    expect(parseAndValidateTaggingResponse(content).concernReason).toBe('');
  });

  test('an oversized concernReason is truncated to 300 characters rather '
      + 'than writing an unbounded string to Firestore', () => {
    const content = JSON.stringify({
      tags: ['adventure'],
      traits: ['brave'],
      ageRating: '8+',
      contentConcern: true,
      concernReason: 'x'.repeat(1000),
    });

    expect(parseAndValidateTaggingResponse(content).concernReason).toHaveLength(300);
  });
});

describe('ALLOWED_AGES', () => {
  test('includes 4+ and 5+ — early-childhood-audit.md finding #4: this '
      + 'used to bottom out at 6+, so a book couldn\'t be classified as '
      + 'suitable for a 4-5-year-old at all', () => {
    expect(ALLOWED_AGES).toContain('4+');
    expect(ALLOWED_AGES).toContain('5+');
  });

  test('a book tagged 4+ is accepted (not silently bumped to the 6+ '
      + 'fallback) by parseAndValidateTaggingResponse', () => {
    const content = JSON.stringify({
      tags: ['friendship'],
      traits: ['kind'],
      ageRating: '4+',
      contentConcern: false,
      concernReason: '',
    });
    expect(parseAndValidateTaggingResponse(content).ageRating).toBe('4+');
  });
});

describe('fallbackTaggingResult', () => {
  test('always returns a valid shape from the allowed vocabularies', () => {
    const result = fallbackTaggingResult();
    expect(ALLOWED_AGES).toContain(result.ageRating);
    result.tags.forEach((tag) => {
      if (tag !== 'teamwork') expect(ALLOWED_TAGS).toContain(tag);
    });
    result.traits.forEach((trait) => {
      if (trait !== 'responsible') expect(ALLOWED_TRAITS).toContain(trait);
    });
  });

  test('flags contentConcern rather than defaulting to "safe" — a failed '
      + 'AI call means the safety check never ran at all, which must not '
      + 'look the same as "the model looked and found nothing"', () => {
    const result = fallbackTaggingResult();
    expect(result.contentConcern).toBe(true);
    expect(result.concernReason).toMatch(/manual review/i);
  });
});

describe('parseRecommendationResponse', () => {
  const availableBooks = [
    { id: 'book-1' },
    { id: 'book-2' },
    { id: 'book-3' },
  ];

  test('keeps only IDs that exist in the available books list', () => {
    const content = JSON.stringify(['book-1', 'book-3']);
    expect(parseRecommendationResponse(content, availableBooks)).toEqual([
      'book-1', 'book-3',
    ]);
  });

  test('filters out a hallucinated or stale ID the model invented — the '
      + 'core protection this function exists for', () => {
    const content = JSON.stringify(['book-1', 'this-book-does-not-exist', 'book-2']);
    expect(parseRecommendationResponse(content, availableBooks)).toEqual([
      'book-1', 'book-2',
    ]);
  });

  test('preserves the model\'s relevance ordering', () => {
    const content = JSON.stringify(['book-3', 'book-1']);
    expect(parseRecommendationResponse(content, availableBooks)).toEqual([
      'book-3', 'book-1',
    ]);
  });

  test('an unparseable response yields an empty list rather than throwing',
      () => {
        expect(parseRecommendationResponse('not json', availableBooks)).toEqual([]);
      });

  test('a well-formed JSON object (not an array) also yields an empty list',
      () => {
        expect(parseRecommendationResponse('{"not": "an array"}', availableBooks)).toEqual([]);
      });
});

describe('buildQuizPrompt', () => {
  test('defaults to the app\'s early-childhood target age range when none is given',
      () => {
        const prompt = buildQuizPrompt('Title', 'Author', 'Some book text.');
        expect(prompt).toContain(DEFAULT_QUIZ_AGE_RANGE);
      });

  test('uses a given targetAgeRange instead of the default', () => {
    const prompt = buildQuizPrompt('Title', 'Author', 'Some book text.', '9 to 11 years old');
    expect(prompt).toContain('9 to 11 years old');
    expect(prompt).not.toContain(DEFAULT_QUIZ_AGE_RANGE);
  });

  test('asks for exactly 3 questions and 3 options — fewer/simpler for '
      + 'the default early-childhood audience', () => {
    const prompt = buildQuizPrompt('Title', 'Author', 'Some book text.');
    expect(prompt).toContain('exactly 3 questions');
    expect(prompt).toContain('exactly 3 answer options');
  });
});

describe('validateQuizFormat', () => {
  const validQuiz = [
    { question: 'Who is the hero?', options: ['A', 'B', 'C', 'D'], correctAnswer: 1 },
  ];

  test('accepts and returns a well-formed 4-option quiz', () => {
    expect(validateQuizFormat(validQuiz)).toBe(validQuiz);
  });

  test('accepts a well-formed 3-option quiz — the early-childhood default '
      + 'shape from buildQuizPrompt', () => {
    const quiz = [{ question: 'Q?', options: ['A', 'B', 'C'], correctAnswer: 2 }];
    expect(validateQuizFormat(quiz)).toBe(quiz);
  });

  test('rejects an empty array', () => {
    expect(() => validateQuizFormat([])).toThrow(/non-empty array/);
  });

  test('rejects a non-array', () => {
    expect(() => validateQuizFormat({ not: 'an array' })).toThrow(/non-empty array/);
  });

  test('rejects a question missing its question text', () => {
    const quiz = [{ options: ['A', 'B', 'C', 'D'], correctAnswer: 0 }];
    expect(() => validateQuizFormat(quiz)).toThrow(/Invalid quiz question format/);
  });

  test('rejects a question with only 1 option — below the 2-option floor', () => {
    const quiz = [{ question: 'Q?', options: ['A'], correctAnswer: 0 }];
    expect(() => validateQuizFormat(quiz)).toThrow(/Invalid quiz question format/);
  });

  test('rejects a question with more than 4 options', () => {
    const quiz = [{ question: 'Q?', options: ['A', 'B', 'C', 'D', 'E'], correctAnswer: 0 }];
    expect(() => validateQuizFormat(quiz)).toThrow(/Invalid quiz question format/);
  });

  test('rejects a non-numeric correctAnswer', () => {
    const quiz = [{ question: 'Q?', options: ['A', 'B', 'C', 'D'], correctAnswer: '1' }];
    expect(() => validateQuizFormat(quiz)).toThrow(/Invalid quiz question format/);
  });

  test('rejects a correctAnswer out of range for a 4-option question', () => {
    const quiz = [{ question: 'Q?', options: ['A', 'B', 'C', 'D'], correctAnswer: 4 }];
    expect(() => validateQuizFormat(quiz)).toThrow(/Invalid quiz question format/);
  });

  test('rejects a correctAnswer out of range for a 3-option question — '
      + 'index 3 was valid under the old fixed 0-3 rule but is now out of '
      + 'bounds for only 3 real options', () => {
    const quiz = [{ question: 'Q?', options: ['A', 'B', 'C'], correctAnswer: 3 }];
    expect(() => validateQuizFormat(quiz)).toThrow(/Invalid quiz question format/);
  });

  test('one bad question fails the whole quiz, even if others are valid',
      () => {
        const quiz = [
          { question: 'Good one?', options: ['A', 'B', 'C', 'D'], correctAnswer: 0 },
          { question: 'Bad one?', options: ['A'], correctAnswer: 0 },
        ];
        expect(() => validateQuizFormat(quiz)).toThrow(/Invalid quiz question format/);
      });
});
