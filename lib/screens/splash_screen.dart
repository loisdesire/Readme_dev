// File: lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'onboarding/onboarding_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/book_provider.dart';
import '../providers/user_provider.dart';
import '../screens/child/child_home_screen.dart';

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
      
      // Load books (initialize sample books if needed)
      try {
        await bookProvider.loadAllBooks();
        if (bookProvider.allBooks.isEmpty) {
          await bookProvider.initializeSampleBooks();
          await bookProvider.loadAllBooks();
        }
      } catch (e) {
        print('Error loading books in splash: $e');
        // Continue with navigation even if book loading fails
      }
      
      await Future.delayed(const Duration(milliseconds: 3000));
      
      if (!mounted) return;
      
      // Check authentication status and navigate accordingly
      if (authProvider.isAuthenticated) {
        try {
          // Load user data
          await userProvider.loadUserData(authProvider.userId!);
          
          if (authProvider.hasCompletedQuiz()) {
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
          print('Error loading user data: $e');
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
      print('Critical error in splash navigation: $e');
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
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF8E44AD),
              Color(0xFFA062BA),
              Color(0xFFB280C7),
            ],
          ),
        ),
        child: const Center(
          child: Text(
            'ReadMe',
            style: TextStyle(
              fontSize: 46,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}