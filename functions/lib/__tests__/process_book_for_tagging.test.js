const {
  processBookForTagging,
  downloadPdfFromStorage,
} = require('../process_book_for_tagging');

const quietLog = { info: () => {}, error: () => {} };

/** A minimal fake Firestore `db` that just records the last update() call. */
function fakeDb() {
  let lastUpdate = null;
  return {
    collection: () => ({
      doc: () => ({
        update: async (data) => {
          lastUpdate = data;
        },
      }),
    }),
    getLastUpdate: () => lastUpdate,
  };
}

describe('processBookForTagging', () => {
  const bookData = {
    title: 'Test Book',
    author: 'Test Author',
    description: 'A book about testing.',
    pdfUrl: 'https://example.com/book.pdf',
  };

  test('happy path: downloads, parses, tags, and writes the expected '
      + 'Firestore update', async () => {
    const db = fakeDb();
    const result = await processBookForTagging('book-1', bookData, {
      db,
      downloadPdf: async (url) => {
        expect(url).toBe(bookData.pdfUrl);
        return Buffer.from('fake pdf bytes');
      },
      parsePdf: async () => ({ text: 'Once upon a time...' }),
      callOpenAIForTagging: async () => ({
        traits: ['curious', 'kind'],
        tags: ['adventure'],
        ageRating: '7+',
      }),
      log: quietLog,
    });

    expect(result).toBe(true);
    expect(db.getLastUpdate()).toEqual({
      traits: ['curious', 'kind'],
      tags: ['adventure'],
      needsTagging: false,
      taggedAt: expect.any(Date),
      ageRating: '7+',
    });
  });

  test('a contentConcern flag pulls the book back from children and '
      + 'records why, instead of leaving it visible pending review',
  async () => {
    const db = fakeDb();
    await processBookForTagging('book-1', bookData, {
      db,
      downloadPdf: async () => Buffer.from(''),
      parsePdf: async () => ({ text: 'text' }),
      callOpenAIForTagging: async () => ({
        traits: ['brave'],
        tags: ['adventure'],
        ageRating: '8+',
        contentConcern: true,
        concernReason: 'Contains a detailed violent scene.',
      }),
      log: quietLog,
    });

    expect(db.getLastUpdate()).toMatchObject({
      needsReview: true,
      isVisible: false,
      concernReason: 'Contains a detailed violent scene.',
    });
  });

  test('no contentConcern means no needsReview/isVisible/concernReason '
      + 'fields are written at all — the common case stays untouched',
  async () => {
    const db = fakeDb();
    await processBookForTagging('book-1', bookData, {
      db,
      downloadPdf: async () => Buffer.from(''),
      parsePdf: async () => ({ text: 'text' }),
      callOpenAIForTagging: async () => ({
        traits: ['brave'],
        tags: ['adventure'],
        ageRating: '8+',
        contentConcern: false,
      }),
      log: quietLog,
    });

    const update = db.getLastUpdate();
    expect(update).not.toHaveProperty('needsReview');
    expect(update).not.toHaveProperty('isVisible');
    expect(update).not.toHaveProperty('concernReason');
  });

  test('an empty ageRating from the AI response is omitted from the update '
      + '(existing ageRating is left alone) rather than overwritten with '
      + 'an empty value', async () => {
    const db = fakeDb();
    await processBookForTagging('book-1', bookData, {
      db,
      downloadPdf: async () => Buffer.from(''),
      parsePdf: async () => ({ text: 'text' }),
      callOpenAIForTagging: async () => ({
        traits: ['curious'],
        tags: ['adventure'],
        ageRating: '', // empty
      }),
      log: quietLog,
    });

    expect(db.getLastUpdate()).not.toHaveProperty('ageRating');
  });

  test('the extracted text is truncated to 8000 characters before being '
      + 'sent to the tagging call', async () => {
    const longText = 'a'.repeat(10000);
    let receivedText;
    const db = fakeDb();

    await processBookForTagging('book-1', bookData, {
      db,
      downloadPdf: async () => Buffer.from(''),
      parsePdf: async () => ({ text: longText }),
      callOpenAIForTagging: async (title, author, bookText) => {
        receivedText = bookText;
        return { traits: [], tags: [], ageRating: '' };
      },
      log: quietLog,
    });

    expect(receivedText).toHaveLength(8000);
  });

  test('the book\'s title/author/description are forwarded to the tagging '
      + 'call unchanged', async () => {
    let receivedArgs;
    await processBookForTagging('book-1', bookData, {
      db: fakeDb(),
      downloadPdf: async () => Buffer.from(''),
      parsePdf: async () => ({ text: 'text' }),
      callOpenAIForTagging: async (title, author, bookText, description) => {
        receivedArgs = { title, author, description };
        return { traits: [], tags: [], ageRating: '' };
      },
      log: quietLog,
    });

    expect(receivedArgs).toEqual({
      title: bookData.title,
      author: bookData.author,
      description: bookData.description,
    });
  });

  test.each([
    ['the PDF download', { downloadPdf: async () => { throw new Error('download failed'); } }],
    ['PDF parsing', { parsePdf: async () => { throw new Error('parse failed'); } }],
    ['the OpenAI call', { callOpenAIForTagging: async () => { throw new Error('AI failed'); } }],
    ['the Firestore write', {
      db: { collection: () => ({ doc: () => ({ update: async () => { throw new Error('write failed'); } }) }) },
    }],
  ])('a failure during %s returns false instead of throwing (this runs in '
     + 'a loop over many books — one bad book must not stop the rest)',
  async (label, overrides) => {
    const result = await processBookForTagging('book-1', bookData, {
      db: fakeDb(),
      downloadPdf: async () => Buffer.from(''),
      parsePdf: async () => ({ text: 'text' }),
      callOpenAIForTagging: async () => ({ traits: [], tags: [], ageRating: '' }),
      log: quietLog,
      ...overrides,
    });

    expect(result).toBe(false);
  });
});

describe('downloadPdfFromStorage', () => {
  test('returns the response body as a Buffer on success', async () => {
    const fakeFetch = async (url) => {
      expect(url).toBe('https://example.com/book.pdf');
      return {
        ok: true,
        // NOT Buffer.from(str).buffer: for small strings that shares
        // Node's internal memory pool and isn't sized to just this
        // string, so a Buffer built from it can be padded with unrelated
        // bytes. TextEncoder gives an ArrayBuffer sized to exactly this
        // content, matching what a real fetch response.arrayBuffer() returns.
        arrayBuffer: async () => new TextEncoder().encode('pdf content').buffer,
      };
    };

    const result = await downloadPdfFromStorage('https://example.com/book.pdf', fakeFetch);

    expect(Buffer.isBuffer(result)).toBe(true);
    expect(result.toString()).toBe('pdf content');
  });

  test('throws a descriptive error when the response is not ok', async () => {
    const fakeFetch = async () => ({ ok: false, statusText: 'Not Found' });

    await expect(
      downloadPdfFromStorage('https://example.com/missing.pdf', fakeFetch)
    ).rejects.toThrow(/Not Found/);
  });
});
