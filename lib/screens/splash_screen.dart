// File: lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'onboarding/onboarding_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/book_provider.dart';
import '../providers/user_provider.dart';
import '../screens/child/child_home_screen.dart';
import '../theme/app_theme.dart';

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
        print('Loading existing books from backend...');
        await bookProvider.loadAllBooks();
        print('Successfully loaded ${bookProvider.allBooks.length} books from backend');
        
        if (bookProvider.allBooks.isEmpty) {
          print('WARNING: No books found in backend! Check Firebase permissions and data.');
        }
      } catch (e) {
        print('Error loading books from backend: $e');
        print('This might be due to Firebase permissions or network issues.');
        // Don't initialize sample books - user has real books in backend
      }
      
      await Future.delayed(const Duration(milliseconds: 3000));
      
      if (!mounted) return;
      
      // FIXED: Check both isAuthenticated AND user object to ensure proper auth state
      print('🔐 Auth Status: isAuthenticated=${authProvider.isAuthenticated}, user=${authProvider.user?.uid}');
      
      // Check authentication status and navigate accordingly
      if (authProvider.isAuthenticated && authProvider.user != null) {
        print('✅ User is authenticated: ${authProvider.user!.uid}');
        try {
          // Load user data
          await userProvider.loadUserData(authProvider.userId!);
          
          if (authProvider.hasCompletedQuiz()) {
            print('✅ User has completed quiz, loading dashboard...');
            // User has completed quiz, load recommendations and go to dashboard
            await bookProvider.loadRecommendedBooks(authProvider.getPersonalityTraits());
            await bookProvider.loadUserProgress(authProvider.userId!);
            
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChildHomeScreen(),
                ),
              );
            }
          } else {
            print('⚠️ User needs to complete quiz');
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
          print('❌ Error loading user data: $e');
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
        print('🚫 User is NOT authenticated, going to onboarding');
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
      print('❌ Critical error in splash navigation: $e');
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
