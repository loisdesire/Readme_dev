// File: lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'onboarding/onboarding_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/book_provider.dart';
import '../providers/user_provider.dart';
import '../screens/child/child_root.dart';
import '../theme/app_theme.dart';
import '../services/logger.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateAfterDelay();
  }

  void _navigateAfterDelay() async {
    try {
      // Initialize app data
      final bookProvider = Provider.of<BookProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      
      // Load existing books from backend (60+ books)
      try {
        appLog('Loading existing books from backend...', level: 'DEBUG');
        await bookProvider.loadAllBooks();
        appLog('Successfully loaded ${bookProvider.allBooks.length} books from backend', level: 'DEBUG');
        
        if (bookProvider.allBooks.isEmpty) {
          appLog('WARNING: No books found in backend! Check Firebase permissions and data.', level: 'WARN');
        }
      } catch (e) {
        appLog('Error loading books from backend: $e', level: 'ERROR');
        appLog('This might be due to Firebase permissions or network issues.', level: 'WARN');
        // Don't initialize sample books - user has real books in backend
      }
      
      await Future.delayed(const Duration(milliseconds: 3000));
      
      if (!mounted) return;
      
      // FIXED: Check both isAuthenticated AND user object to ensure proper auth state
  appLog('Auth Status: isAuthenticated=${authProvider.isAuthenticated}, user=${authProvider.user?.uid}', level: 'DEBUG');
      
      // Check authentication status and navigate accordingly
      if (authProvider.isAuthenticated && authProvider.user != null) {
  appLog('User is authenticated: ${authProvider.user!.uid}', level: 'DEBUG');
        try {
          // Load user data
          await userProvider.loadUserData(authProvider.userId!);
          
            if (authProvider.hasCompletedQuiz()) {
            appLog('User has completed quiz, loading dashboard...', level: 'DEBUG');
            // User has completed quiz, load recommendations and go to dashboard
            await bookProvider.loadRecommendedBooks(authProvider.getPersonalityTraits());
            await bookProvider.loadUserProgress(authProvider.userId!);
            
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChildRoot(),
                  ),
                );
              }
          } else {
            appLog('User needs to complete quiz', level: 'WARN');
            // User needs to complete quiz
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const OnboardingScreen(),
                ),
              );
            }
          }
        } catch (e) {
          appLog('Error loading user data: $e', level: 'ERROR');
          // Navigate to onboarding on error
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const OnboardingScreen(),
              ),
            );
          }
        }
      } else {
        appLog('User is NOT authenticated, going to onboarding', level: 'DEBUG');
        // Navigate to onboarding for new users
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const OnboardingScreen(),
            ),
          );
        }
      }
    } catch (e) {
      appLog('Critical error in splash navigation: $e', level: 'ERROR');
      // Fallback navigation
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const OnboardingScreen(),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.splashGradient,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'ReadMe',
                style: AppTheme.logoLarge,
              ),
              const SizedBox(height: 40),
              // Debug image button removed
            ],
          ),
        ),
      ),
    );
  }
}
