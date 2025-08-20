// File: lib/providers/auth_provider.dart
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  AuthStatus _status = AuthStatus.initial;
  User? _user;
  String? _errorMessage;
  Map<String, dynamic>? _userProfile;

  // Getters
  AuthStatus get status => _status;
  User? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated && _user != null;
  String? get userId => _user?.uid;
  Map<String, dynamic>? get userProfile => _userProfile;

  AuthProvider() {
    _init();
  }

  // Initialize auth state listener
  void _init() {
    _auth.authStateChanges().listen((User? user) async {
      _user = user;
      if (user != null) {
        _status = AuthStatus.authenticated;
        await _loadUserProfile();
      } else {
        _status = AuthStatus.unauthenticated;
        _userProfile = null;
      }
      Future.delayed(Duration.zero, () => notifyListeners());
    });
  }

  // Load user profile from Firestore
  Future<void> _loadUserProfile() async {
    if (_user == null) return;
    
    try {
      final doc = await _firestore.collection('users').doc(_user!.uid).get();
      if (doc.exists) {
        _userProfile = doc.data();
      }
    } catch (e) {
      print('Error loading user profile: $e');
    }
  }

  // Sign up with email and password
  Future<bool> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      _status = AuthStatus.loading;
      _errorMessage = null;
      Future.delayed(Duration.zero, () => notifyListeners());

      // Create user with Firebase Auth
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        // Create user profile in Firestore
        await _createUserProfile(result.user!, username);
        
        _user = result.user;
        _status = AuthStatus.authenticated;
        Future.delayed(Duration.zero, () => notifyListeners());
        return true;
      }
    } on FirebaseAuthException catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _getAuthErrorMessage(e.code);
      Future.delayed(Duration.zero, () => notifyListeners());
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = 'An unexpected error occurred';
      Future.delayed(Duration.zero, () => notifyListeners());
    }
    return false;
  }

  // Sign in with email and password
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _status = AuthStatus.loading;
      _errorMessage = null;
      Future.delayed(Duration.zero, () => notifyListeners());

      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        _user = result.user;
        await _loadUserProfile();
        _status = AuthStatus.authenticated;
        Future.delayed(Duration.zero, () => notifyListeners());
        return true;
      }
    } on FirebaseAuthException catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _getAuthErrorMessage(e.code);
      Future.delayed(Duration.zero, () => notifyListeners());
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = 'An unexpected error occurred';
      Future.delayed(Duration.zero, () => notifyListeners());
    }
    return false;
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _user = null;
      _userProfile = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
      Future.delayed(Duration.zero, () => notifyListeners());
    } catch (e) {
      _errorMessage = 'Error signing out';
      Future.delayed(Duration.zero, () => notifyListeners());
    }
  }

  // Create user profile in Firestore
  Future<void> _createUserProfile(User user, String username) async {
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'username': username,
        'createdAt': FieldValue.serverTimestamp(),
        'hasCompletedQuiz': false,
        'personalityTraits': [],
        'children': [], // For parent accounts
      });
      
      await _loadUserProfile();
    } catch (e) {
      print('Error creating user profile: $e');
    }
  }

  // Save quiz results
  Future<bool> saveQuizResults({
    required List<String> selectedAnswers,
    required Map<String, int> traitScores,
    required List<String> dominantTraits,
  }) async {
    if (_user == null) return false;

    try {
      await _firestore.collection('users').doc(_user!.uid).update({
        'hasCompletedQuiz': true,
        'personalityTraits': dominantTraits,
        'traitScores': traitScores,
        'quizAnswers': selectedAnswers,
        'quizCompletedAt': FieldValue.serverTimestamp(),
      });
      
      await _loadUserProfile();
      return true;
    } catch (e) {
      print('Error saving quiz results: $e');
      return false;
    }
  }

  // Check if user has completed quiz
  bool hasCompletedQuiz() {
    return _userProfile?['hasCompletedQuiz'] ?? false;
  }

  // Get user's personality traits
  List<String> getPersonalityTraits() {
    final traits = _userProfile?['personalityTraits'];
    if (traits is List) {
      return List<String>.from(traits);
    }
    return [];
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    Future.delayed(Duration.zero, () => notifyListeners());
  }

  // Helper method to get user-friendly error messages
  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'user-not-found':
        return 'No user found for this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}