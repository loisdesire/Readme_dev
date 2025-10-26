import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/logger.dart';

/// Base provider class with common functionality to reduce code duplication
abstract class BaseProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Protected getter for subclasses
  FirebaseFirestore get firestore => _firestore;
  
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
}