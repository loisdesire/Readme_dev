/// The PDF file signature every valid PDF starts with: the ASCII bytes
/// for "%PDF-" (the version number follows, e.g. "1.7").
const List<int> _pdfSignature = [0x25, 0x50, 0x44, 0x46, 0x2D];

/// Whether `bytes` starts with the PDF file signature.
///
/// Used before trusting a cached or freshly-downloaded file as "the
/// book" — a download can be interrupted, or a server can briefly
/// return something that isn't the PDF at all, and neither an HTTP 200
/// nor a file simply existing on disk guarantees the bytes are actually
/// a PDF. See `PdfReadingScreenSyncfusion`'s cache-handling and
/// SECURITY.md for the real bug this closes: a cache entry poisoned by
/// bad bytes was never re-validated, so it failed to load forever.
bool looksLikePdf(List<int> bytes) {
  if (bytes.length < _pdfSignature.length) return false;
  for (var i = 0; i < _pdfSignature.length; i++) {
    if (bytes[i] != _pdfSignature[i]) return false;
  }
  return true;
}
