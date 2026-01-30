import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? extractSessionTimeForBucketing(Map<String, dynamic> data) {
  final clientStartTime = (data['clientStartTime'] as Timestamp?)?.toDate();
  if (clientStartTime != null) return clientStartTime;

  final sessionStart = (data['sessionStart'] as Timestamp?)?.toDate();
  if (sessionStart != null) return sessionStart;

  final startTime = (data['startTime'] as Timestamp?)?.toDate();
  if (startTime != null) return startTime;

  final createdAtClient = (data['createdAtClient'] as Timestamp?)?.toDate();
  if (createdAtClient != null) return createdAtClient;

  final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
  if (createdAt != null) return createdAt;

  return null;
}

int extractSessionMinutes(Map<String, dynamic> data) {
  final durationMinutes = (data['durationMinutes'] as num?)?.toInt() ?? 0;
  if (durationMinutes > 0) return durationMinutes;

  final sessionDurationMinutes =
      (data['sessionDurationMinutes'] as num?)?.toInt() ?? 0;
  if (sessionDurationMinutes > 0) return sessionDurationMinutes;

  final seconds = (data['sessionDurationSeconds'] as num?)?.toInt() ?? 0;
  return seconds > 0 ? ((seconds + 59) ~/ 60) : 0;
}

bool progressIndicatesReading(Map<String, dynamic> data) {
  final progressPercent = (data['progressPercentage'] as num?)?.toDouble() ?? 0.0;
  final readingTimeMinutes = (data['readingTimeMinutes'] as num?)?.toInt() ?? 0;

  // For PDFs we treat "any real progress" OR "tracked reading time" as activity.
  return progressPercent > 0.0 || readingTimeMinutes > 0;
}
