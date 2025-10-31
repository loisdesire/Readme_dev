// File: lib/services/firebase_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Centralized Firebase service providing single instances of Firebase services.
///
/// This singleton pattern ensures:
/// - Consistent instance management across the app
/// - Easier testing and mocking
/// - Single source of truth for Firebase instances
///
/// Usage:
/// ```dart
/// final firebaseService = FirebaseService();
/// final user = firebaseService.currentUser;
/// final doc = await firebaseService.firestore.collection('users').doc(userId).get();
/// ```
class FirebaseService {
  // Singleton pattern
  static final FirebaseService _instance = FirebaseService._internal();

  /// Get the singleton instance of FirebaseService
  factory FirebaseService() => _instance;

  FirebaseService._internal();

  // Firebase instances
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;

  // Convenient getters

  /// Get the currently authenticated user (null if not authenticated)
  User? get currentUser => auth.currentUser;

  /// Get the current user's ID (null if not authenticated)
  String? get currentUserId => auth.currentUser?.uid;

  /// Check if a user is currently authenticated
  bool get isAuthenticated => auth.currentUser != null;

  /// Get the current user's email (null if not authenticated)
  String? get currentUserEmail => auth.currentUser?.email;

  /// Get the current user's display name (null if not set)
  String? get currentUserDisplayName => auth.currentUser?.displayName;

  // Stream getters for reactive authentication state

  /// Stream of authentication state changes
  Stream<User?> get authStateChanges => auth.authStateChanges();

  /// Stream of user changes (includes profile updates)
  Stream<User?> get userChanges => auth.userChanges();

  /// Stream of ID token changes
  Stream<User?> get idTokenChanges => auth.idTokenChanges();
}
