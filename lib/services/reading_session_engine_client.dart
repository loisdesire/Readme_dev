// File: lib/services/reading_session_engine_client.dart
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import 'points_engine_client.dart' show PointsFunctionCaller;

/// Seam for the two server-timestamped reading-session Cloud Functions
/// (see functions/lib/reading_sessions.js and
/// docs/reading-session-integrity-design.md, "Option B"). Mirrors
/// PointsEngineClient's shape (a `.withCaller()` test override, since
/// cloud_functions has no official fake/mock package) but is kept as its
/// own class rather than folded into PointsEngineClient — starting/ending
/// a reading session isn't a point award, it's the evidence a later point
/// award gets verified against.
class ReadingSessionEngineClient {
  static final ReadingSessionEngineClient _instance =
      ReadingSessionEngineClient._internal();
  factory ReadingSessionEngineClient() => _instance;
  ReadingSessionEngineClient._internal() : _caller = null;

  @visibleForTesting
  ReadingSessionEngineClient.withCaller(PointsFunctionCaller caller)
      : _caller = caller;

  final PointsFunctionCaller? _caller;

  // FirebaseFunctions.instance is resolved lazily, on first real call —
  // see PointsEngineClient's identical comment for why (it throws
  // immediately pre-Firebase-init, unlike Firestore/Auth's lazy proxies).
  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    if (_caller != null) return _caller!(name, data);
    final result = await FirebaseFunctions.instance.httpsCallable(name).call(data);
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>> startReadingSession({
    required String bookId,
    required String bookTitle,
  }) =>
      _call('startReadingSession', {'bookId': bookId, 'bookTitle': bookTitle});

  Future<Map<String, dynamic>> endReadingSession({
    required String sessionId,
  }) =>
      _call('endReadingSession', {'sessionId': sessionId});
}
