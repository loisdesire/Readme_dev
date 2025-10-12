// Simple centralized logger that can be silenced in release builds
import 'package:flutter/foundation.dart';

void appLog(Object? message, {String level = 'INFO'}) {
  // In release builds, avoid printing unless needed
  if (kReleaseMode) return;
  final ts = DateTime.now().toIso8601String();
  // ignore: avoid_print
  print('[$ts] [$level] $message');
}
