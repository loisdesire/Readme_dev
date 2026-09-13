/**
 * Orchestrates AI tagging for a single book: download its PDF, extract
 * text, ask the model to tag it (see ai_helpers.js for that validation
 * boundary), and write the result to Firestore.
 *
 * Every external effect (HTTP fetch, PDF parsing, the OpenAI call itself,
 * Firestore) is taken as a parameter so this can be tested with fakes —
 * no real network, Storage, or OpenAI calls needed to verify the
 * orchestration logic (sequencing, the update payload's shape, the
 * 8000-character excerpt limit, and that a failure anywhere returns
 * `false` instead of throwing).
 */

const defaultFetch = require('node-fetch');

/**
 * Downloads a PDF from a (Storage-hosted) URL as a Buffer.
 *
 * @param {string} pdfUrl
 * @param {typeof fetch} [fetchImpl] Injectable fetch implementation
 *   (defaults to node-fetch, i.e. real production behavior).
 * @returns {Promise<Buffer>}
 * @throws {Error} if the download fails.
 */
async function downloadPdfFromStorage(pdfUrl, fetchImpl = defaultFetch) {
  const response = await fetchImpl(pdfUrl);
  if (!response.ok) {
    throw new Error(`Failed to download PDF: ${response.statusText}`);
  }
  return Buffer.from(await response.arrayBuffer());
}

/**
 * @param {string} bookId
 * @param {{title: string, author: string, description?: string, pdfUrl: string}} bookData
 * @param {{
 *   db: FirebaseFirestore.Firestore,
 *   downloadPdf: (url: string) => Promise<Buffer>,
 *   parsePdf: (buffer: Buffer) => Promise<{text: string}>,
 *   callOpenAIForTagging: (title: string, author: string, bookText: string, description: string) => Promise<{traits: string[], tags: string[], ageRating: string}>,
 *   log?: {info: Function, error: Function},
 * }} deps
 * @returns {Promise<boolean>} Whether tagging succeeded. Never throws —
 *   matches the original's "log and return false" behavior, since this is
 *   called in a loop over many books and one failure shouldn't halt the rest.
 */
async function processBookForTagging(bookId, bookData, deps) {
  const { db, downloadPdf, parsePdf, callOpenAIForTagging, log = console } = deps;

  try {
    log.info(`Processing book: ${bookData.title}`);

    const pdfBuffer = await downloadPdf(bookData.pdfUrl);
    const pdfData = await parsePdf(pdfBuffer);
    const bookText = pdfData.text.substring(0, 8000); // First 8000 characters

    const aiResponse = await callOpenAIForTagging(
      bookData.title,
      bookData.author,
      bookText,
      bookData.description
    );

    const updateData = {
      traits: aiResponse.traits,
      tags: aiResponse.tags,
      needsTagging: false,
      taggedAt: new Date(),
    };

    // Only update age rating if we got a valid one.
    if (aiResponse.ageRating && aiResponse.ageRating.length > 0) {
      updateData.ageRating = aiResponse.ageRating;
    }

    // Content safety: this AI call is the only automated point in the
    // whole pipeline that ever reads the book's actual text — tagging
    // alone (picking a genre/age rating) never screened for content a
    // parent wouldn't expect. A flagged book is pulled back from children
    // pending human review rather than left instantly visible the moment
    // tagging completes. See SECURITY.md.
    if (aiResponse.contentConcern) {
      updateData.needsReview = true;
      updateData.isVisible = false;
      if (aiResponse.concernReason) {
        updateData.concernReason = aiResponse.concernReason;
      }
    }

    await db.collection('books').doc(bookId).update(updateData);

    log.info(`Successfully tagged: ${bookData.title}`);
    return true;
  } catch (error) {
    log.error(`Error processing book ${bookData.title}:`, error);
    return false;
  }
}

module.exports = { processBookForTagging, downloadPdfFromStorage };
