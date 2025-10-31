import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/logger.dart';
import '../services/firebase_service.dart';

/// Base provider class with common functionality to reduce code duplication.
///
/// This class provides:
/// - Centralized Firebase service access
/// - Safe notification management (avoids build-phase issues)
/// - Automatic loading and error state management
/// - Generic error handling
/// - Disposal tracking
///
/// Usage:
/// ```dart
/// class MyProvider extends BaseProvider {
///   Future<void> loadData() async {
///     await executeWithState(() async {
///       // Your loading logic here
///       final data = await firestore.collection('items').get();
///       // Process data
///     }, errorMessage: 'Failed to load data');
///   }
/// }
/// ```
abstract class BaseProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();

  // Protected getters for subclasses
  FirebaseFirestore get firestore => _firebaseService.firestore;
  FirebaseAuth get auth => _firebaseService.auth;
  User? get currentUser => _firebaseService.currentUser;
  String? get currentUserId => _firebaseService.currentUserId;
  
  /// Safe notifyListeners call that avoids issues with build phase
  void safeNotify() {
    if (!disposed) {
      Future.delayed(Duration.zero, () {
        if (!disposed) {
          notifyListeners();
        }
      });
    }
  }
  
  /// Track disposal status
  bool _disposed = false;
  bool get disposed => _disposed;
  
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
  
  /// Generic error handler for Firestore operations
  void handleError(String operation, dynamic error, {String level = 'ERROR'}) {
    appLog('Error in $operation: $error', level: level);
  }
  
  /// Generic loading state management
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  
  void setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      safeNotify();
    }
  }
  
  /// Generic error message management  
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  
  void setError(String? message) {
    if (_errorMessage != message) {
      _errorMessage = message;
      safeNotify();
    }
  }
  
  void clearError() => setError(null);
  
  /// Execute async operation with automatic loading and error handling
  Future<T?> executeWithHandling<T>(
    Future<T> Function() operation, {
    String operationName = 'operation',
    bool showLoading = true,
  }) async {
    try {
      if (showLoading) setLoading(true);
      clearError();

      final result = await operation();
      return result;
    } catch (error) {
      handleError(operationName, error);
      setError('Failed to $operationName');
      return null;
    } finally {
      if (showLoading) setLoading(false);
    }
  }

  /// Execute async operation with automatic state management (enhanced version)
  ///
  /// This is an enhanced version of executeWithHandling that provides:
  /// - Automatic loading state management
  /// - Error handling with custom error messages
  /// - Optional success callback
  /// - Disposal-safe execution
  ///
  /// Example:
  /// ```dart
  /// await executeWithState(
  ///   () async {
  ///     final data = await fetchData();
  ///     return data;
  ///   },
  ///   errorMessage: 'Failed to load data',
  ///   onSuccess: () {
  ///     appLog('Data loaded successfully');
  ///   },
  /// );
  /// ```
  Future<T?> executeWithState<T>(
    Future<T> Function() operation, {
    String? errorMessage,
    void Function()? onSuccess,
    bool showLoading = true,
  }) async {
    if (_disposed) {
      appLog('Attempted to execute operation on disposed provider', level: 'WARN');
      return null;
    }

    try {
      if (showLoading) setLoading(true);
      clearError();

      final result = await operation();

      if (!_disposed) {
        if (onSuccess != null) onSuccess();
      }

      return result;
    } catch (error) {
      if (!_disposed) {
        appLog('Operation failed: $error', level: 'ERROR');
        setError(errorMessage ?? 'An error occurred: $error');
      }
      return null;
    } finally {
      if (!_disposed && showLoading) {
        setLoading(false);
      }
    }
  }

  /// Set loading state and notify
  ///
  /// Automatically notifies listeners when loading state changes.
  void setLoadingWithNotify(bool loading) {
    _isLoading = loading;
    safeNotify();
  }

  /// Set error and stop loading
  ///
  /// Convenience method that sets error message and turns off loading.
  void setErrorAndStopLoading(String? message) {
    _errorMessage = message;
    _isLoading = false;
    safeNotify();
  }
}