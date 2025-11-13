// File: lib/providers/auth_provider.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/logger.dart';
import 'base_provider.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends BaseProvider {
  AuthStatus _status = AuthStatus.initial;
  User? _user;
  String? _errorMessage;
  Map<String, dynamic>? _userProfile;

  // Getters
  AuthStatus get status => _status;
  User? get user => _user;
  @override
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated && _user != null;
  String? get userId => _user?.uid;
  Map<String, dynamic>? get userProfile => _userProfile;

  AuthProvider() {
    _init();
  }

  // Initialize auth state listener
  void _init() {
    auth.authStateChanges().listen((User? user) async {
      _user = user;
      if (user != null) {
        _status = AuthStatus.authenticated;
        await _loadUserProfile();
      } else {
        _status = AuthStatus.unauthenticated;
        _userProfile = null;
      }
      safeNotify();
    });
  }

  // Load user profile from Firestore
  Future<void> _loadUserProfile() async {
    if (_user == null) return;

    print('=== LOADING USER PROFILE ===');
    print('User ID: ${_user!.uid}');

    final result = await executeWithHandling<DocumentSnapshot>(
      () => firestore.collection('users').doc(_user!.uid).get(),
      operationName: 'load user profile',
      showLoading: false,
    );

    if (result?.exists == true) {
      _userProfile = result!.data() as Map<String, dynamic>?;
      print('Profile loaded: $_userProfile');
      print('hasCompletedQuiz: ${_userProfile?['hasCompletedQuiz']}');
    } else {
      print('Profile does not exist!');
      _userProfile = null;
    }
    print('============================');
  }

  // Public method to reload user profile (for profile updates)
  Future<void> reloadUserProfile() async {
    await _loadUserProfile();
    notifyListeners();
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
      safeNotify();

      // Create user with Firebase Auth
      final UserCredential result = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        // Create user profile in Firestore
        await _createUserProfile(result.user!, username);
        
        _user = result.user;
        _status = AuthStatus.authenticated;
        safeNotify();
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
      print('=== SIGNING IN ===');
      print('Email: $email');
      _status = AuthStatus.loading;
      _errorMessage = null;
      Future.delayed(Duration.zero, () => notifyListeners());

      final UserCredential result = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        print('Firebase Auth success: ${result.user!.uid}');
        _user = result.user;
        await _loadUserProfile();
        _status = AuthStatus.authenticated;
        print('Sign in complete');
        print('==================');
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
      print('=== SIGNING OUT ===');
      print('Clearing user: ${_user?.uid}');
      await auth.signOut();
      _user = null;
      _userProfile = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
      print('User and profile cleared');
      print('===================');
      Future.delayed(Duration.zero, () => notifyListeners());
    } catch (e) {
      _errorMessage = 'Error signing out';
      Future.delayed(Duration.zero, () => notifyListeners());
    }
  }

  // Create user profile in Firestore
  Future<void> _createUserProfile(User user, String username) async {
    try {
      await firestore.collection('users').doc(user.uid).set({
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
  appLog('Error creating user profile: $e', level: 'ERROR');
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
      await firestore.collection('users').doc(_user!.uid).update({
        'hasCompletedQuiz': true,
        'personalityTraits': dominantTraits,
        'traitScores': traitScores,
        'quizAnswers': selectedAnswers,
        'quizCompletedAt': FieldValue.serverTimestamp(),
      });
      
      await _loadUserProfile();
      return true;
    } catch (e) {
  appLog('Error saving quiz results: $e', level: 'ERROR');
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
  @override
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