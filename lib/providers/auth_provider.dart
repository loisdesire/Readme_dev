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
  bool get isParentAccount => _userProfile?['accountType'] == 'parent';
  bool get isChildAccount => _userProfile?['accountType'] == 'child';
  
  // Support multiple parents per child
  List<String> get parentIds {
    final parents = _userProfile?['parentIds'];
    if (parents is List) {
      return List<String>.from(parents);
    }
    // Fallback for old data structure with single parentId
    final oldParentId = _userProfile?['parentId'];
    if (oldParentId != null && oldParentId.toString().isNotEmpty) {
      return [oldParentId.toString()];
    }
    return [];
  }
  
  List<String> get childrenIds {
    final children = _userProfile?['children'];
    if (children is List) {
      return List<String>.from(children);
    }
    return [];
  }
  
  // Check if account is removed by parent
  bool get isAccountRemoved => _userProfile?['isRemoved'] == true;

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

    final result = await executeWithHandling<DocumentSnapshot>(
      () => firestore.collection('users').doc(_user!.uid).get(),
      operationName: 'load user profile',
      showLoading: false,
    );

    if (result?.exists == true) {
      _userProfile = result!.data() as Map<String, dynamic>?;
      
      // SECURITY: Check if account has been removed by parent
      if (_userProfile?['isRemoved'] == true) {
        appLog('[AUTH] Account has been removed by parent', level: 'WARN');
        _errorMessage = 'This account has been removed by a parent. Please contact support.';
        await signOut();
        return;
      }
    } else {
      appLog('[AUTH] Profile does not exist for user: ${_user!.uid}', level: 'WARN');
      _userProfile = null;
    }
  }

  // Public method to reload user profile (for profile updates)
  Future<void> reloadUserProfile() async {
    await _loadUserProfile();
    notifyListeners();
  }

  // Sign up with email and password (for parent accounts)
  Future<bool> signUp({
    required String email,
    required String password,
    required String username,
    String accountType = 'parent', // 'parent' or 'child'
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
        await _createUserProfile(result.user!, username, accountType);
        
        _user = result.user;
        _status = AuthStatus.authenticated;
        safeNotify();
        return true;
      }
    } on FirebaseAuthException catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _getAuthErrorMessage(e.code);
      safeNotify();
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = 'Oops! Something went wrong. Please try again.';
      safeNotify();
    }
    return false;
  }

  // Sign in with email and password
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    try {
      appLog('[AUTH] Signing in with email: $email', level: 'INFO');
      _status = AuthStatus.loading;
      _errorMessage = null;
      safeNotify();

      final UserCredential result = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        appLog('[AUTH] Firebase Auth success - User ID: ${result.user!.uid}', level: 'INFO');
        _user = result.user;
        await _loadUserProfile();
        _status = AuthStatus.authenticated;
        appLog('[AUTH] Sign in complete', level: 'INFO');
        safeNotify();
        return true;
      }
    } on FirebaseAuthException catch (e) {
      _status = AuthStatus.error;
      _errorMessage = _getAuthErrorMessage(e.code);
      safeNotify();
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = 'Oops! Something went wrong. Please try again.';
      safeNotify();
    }
    return false;
  }

  // Sign out
  Future<void> signOut() async {
    try {
      appLog('[AUTH] Signing out user: ${_user?.uid}', level: 'INFO');
      await auth.signOut();
      _user = null;
      _userProfile = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
      appLog('[AUTH] User and profile cleared successfully', level: 'INFO');
      safeNotify();
    } catch (e) {
      appLog('[AUTH] Error signing out: $e', level: 'ERROR');
      _errorMessage = 'Error signing out';
      safeNotify();
    }
  }

  // Create user profile in Firestore
  Future<void> _createUserProfile(User user, String username, String accountType) async {
    try {
      await firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'username': username,
        'accountType': accountType, // 'parent' or 'child'
        'createdAt': FieldValue.serverTimestamp(),
        'hasCompletedQuiz': false,
        'personalityTraits': [],
        'children': [], // For parent accounts - stores child UIDs
        'parentId': null, // For child accounts - stores parent UID
        'avatar': '👦',
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

  // Get children profiles (for parent dashboard)
  Future<List<Map<String, dynamic>>> getChildrenProfiles() async {
    if (!isParentAccount) return [];

    try {
      final childProfiles = <Map<String, dynamic>>[];
      
      for (final childId in childrenIds) {
        final childDoc = await firestore.collection('users').doc(childId).get();
        if (childDoc.exists) {
          final childData = childDoc.data() as Map<String, dynamic>;
          // Filter out removed children
          if (childData['isRemoved'] != true) {
            childProfiles.add(childData);
          }
        }
      }
      
      return childProfiles;
    } catch (e) {
      appLog('Error fetching children profiles: $e', level: 'ERROR');
      return [];
    }
  }

  // Remove child account (soft delete)
  Future<bool> removeChildAccount(String childUid) async {
    if (_user == null || !isParentAccount) return false;

    try {
      // Remove from parent's children list
      await firestore.collection('users').doc(_user!.uid).update({
        'children': FieldValue.arrayRemove([childUid]),
      });

      // Remove this parent from child's parentIds
      await firestore.collection('users').doc(childUid).update({
        'parentIds': FieldValue.arrayRemove([_user!.uid]),
      });
      
      // Check if child has any other parents
      final childDoc = await firestore.collection('users').doc(childUid).get();
      final childData = childDoc.data() as Map<String, dynamic>?;
      final remainingParents = (childData?['parentIds'] as List?)?.length ?? 0;
      
      // Only mark as removed if no other parents are linked
      if (remainingParents == 0) {
        await firestore.collection('users').doc(childUid).update({
          'isRemoved': true,
          'removedAt': FieldValue.serverTimestamp(),
          'removedBy': _user!.uid,
        });
      }

      await _loadUserProfile();
      return true;
    } catch (e) {
      appLog('Error removing child account: $e', level: 'ERROR');
      return false;
    }
  }
  
  // Restore removed child account
  Future<bool> restoreChildAccount(String childUid) async {
    if (_user == null || !isParentAccount) return false;

    try {
      // Add back to parent's children list
      await firestore.collection('users').doc(_user!.uid).update({
        'children': FieldValue.arrayUnion([childUid]),
      });

      // Add parent back to child's parentIds
      await firestore.collection('users').doc(childUid).update({
        'parentIds': FieldValue.arrayUnion([_user!.uid]),
        'isRemoved': false,
        'restoredAt': FieldValue.serverTimestamp(),
        'restoredBy': _user!.uid,
      });

      await _loadUserProfile();
      return true;
    } catch (e) {
      appLog('Error restoring child account: $e', level: 'ERROR');
      return false;
    }
  }
  
  // Permanently delete child account
  Future<bool> permanentlyDeleteChildAccount(String childUid) async {
    if (_user == null || !isParentAccount) return false;

    try {
      // Remove from parent's children list
      await firestore.collection('users').doc(_user!.uid).update({
        'children': FieldValue.arrayRemove([childUid]),
      });
      
      // Delete child's data (use Cloud Function for complete cleanup)
      // For now, just delete the user document
      await firestore.collection('users').doc(childUid).delete();
      
      // Note: In production, trigger Cloud Function to delete:
      // - reading_progress
      // - user_achievements 
      // - reading_sessions
      // - quiz_attempts
      // etc.

      await _loadUserProfile();
      return true;
    } catch (e) {
      appLog('Error permanently deleting child account: $e', level: 'ERROR');
      return false;
    }
  }

  // Clear error message
  @override
  void clearError() {
    _errorMessage = null;
    safeNotify();
  }

  // Helper method to get child-friendly error messages
  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'Please choose a stronger password with more characters.';
      case 'email-already-in-use':
        return 'This email is already registered. Try logging in instead!';
      case 'user-not-found':
        return 'We couldn\'t find an account with this email. Try signing up!';
      case 'wrong-password':
        return 'Oops! That password doesn\'t match. Please try again.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many tries! Please wait a moment and try again.';
      default:
        return 'Oops! Something went wrong. Please try again.';
    }
  }
}