import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:readme_app/utils/pdf_validation.dart';

void main() {
  group('looksLikePdf', () {
    test('accepts real PDF bytes starting with the %PDF- signature', () {
      final bytes = utf8.encode('%PDF-1.7\n%âãÏÓ\n1 0 obj...');
      expect(looksLikePdf(bytes), isTrue);
    });

    test(
        'rejects an HTML/XML error page — the shape a failed Storage '
        'download or an expired token can come back as', () {
      final bytes = utf8.encode(
          '<?xml version="1.0"?><Error><Code>AccessDenied</Code></Error>');
      expect(looksLikePdf(bytes), isFalse);
    });

    test('rejects an empty file', () {
      expect(looksLikePdf(<int>[]), isFalse);
    });

    test('rejects a truncated/interrupted download shorter than the '
        'signature itself', () {
      expect(looksLikePdf(utf8.encode('%PD')), isFalse);
    });

    test('rejects plain garbage bytes', () {
      expect(looksLikePdf([0x00, 0x01, 0x02, 0x03, 0x04, 0x05]), isFalse);
    });
  });
}
