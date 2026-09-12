const {
  ALLOWED_TAGS,
  ALLOWED_TRAITS,
  ALLOWED_AGES,
  extractJsonFromAiContent,
  parseAndValidateTaggingResponse,
  fallbackTaggingResult,
  parseRecommendationResponse,
  validateQuizFormat,
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
    });
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

describe('validateQuizFormat', () => {
  const validQuiz = [
    { question: 'Who is the hero?', options: ['A', 'B', 'C', 'D'], correctAnswer: 1 },
  ];

  test('accepts and returns a well-formed quiz', () => {
    expect(validateQuizFormat(validQuiz)).toBe(validQuiz);
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

  test('rejects a question without exactly 4 options', () => {
    const quiz = [{ question: 'Q?', options: ['A', 'B', 'C'], correctAnswer: 0 }];
    expect(() => validateQuizFormat(quiz)).toThrow(/Invalid quiz question format/);
  });

  test('rejects a non-numeric correctAnswer', () => {
    const quiz = [{ question: 'Q?', options: ['A', 'B', 'C', 'D'], correctAnswer: '1' }];
    expect(() => validateQuizFormat(quiz)).toThrow(/Invalid quiz question format/);
  });

  test('rejects a correctAnswer out of the valid 0-3 range', () => {
    const quiz = [{ question: 'Q?', options: ['A', 'B', 'C', 'D'], correctAnswer: 4 }];
    expect(() => validateQuizFormat(quiz)).toThrow(/Invalid quiz question format/);
  });

  test('one bad question fails the whole quiz, even if others are valid',
      () => {
        const quiz = [
          { question: 'Good one?', options: ['A', 'B', 'C', 'D'], correctAnswer: 0 },
          { question: 'Bad one?', options: ['A', 'B'], correctAnswer: 0 },
        ];
        expect(() => validateQuizFormat(quiz)).toThrow(/Invalid quiz question format/);
      });
});
