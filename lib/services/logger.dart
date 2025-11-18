// Centralized logger with automatic release mode silencing
// Debug logs are only printed during development (kDebugMode)
// In production (kReleaseMode), all logs are suppressed for performance
import 'package:flutter/foundation.dart';

/// Log levels for categorizing messages
enum LogLevel {
  debug,   // Detailed debugging information
  info,    // General informational messages
  warning, // Warning messages
  error,   // Error messages
}

/// Centralized logging function
/// 
/// Usage:
/// ```dart
/// appLog('User logged in', level: 'INFO');
/// appLog('Error loading data: $error', level: 'ERROR');
/// appLog('Debug: Current state = $state', level: 'DEBUG');
/// ```
/// 
/// Note: All logs are automatically suppressed in release builds
void appLog(Object? message, {String level = 'INFO'}) {
  // In release builds, suppress all logs for performance
  // This check happens at compile time, so there's zero overhead in production
  if (kReleaseMode) return;
  
  final ts = DateTime.now().toIso8601String();
  final formattedLevel = level.toUpperCase().padRight(7);
  
  // ignore: avoid_print
  print('[$ts] [$formattedLevel] $message');
}

/// Alternative structured logging (if needed in future)
/// Uncomment if you need more sophisticated logging
/*
class AppLogger {
  static final AppLogger _instance = AppLogger._();
  static AppLogger get instance => _instance;
  AppLogger._();
  
  final List<String> _logBuffer = [];
  static const int _maxBufferSize = 100;
  
  void log(Object? message, {LogLevel level = LogLevel.info}) {
    if (kReleaseMode) return;
    
    final ts = DateTime.now().toIso8601String();
    final logEntry = '[$ts] [${level.name.toUpperCase()}] $message';
    
    // Print to console
    print(logEntry);
    
    // Store in buffer for debugging
    if (_logBuffer.length >= _maxBufferSize) {
      _logBuffer.removeAt(0);
    }
    _logBuffer.add(logEntry);
  }
  
  List<String> getRecentLogs() => List.unmodifiable(_logBuffer);
  void clearLogs() => _logBuffer.clear();
}
*/

