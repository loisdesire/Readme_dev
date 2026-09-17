// File: lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'onboarding/onboarding_screen.dart';
import 'auth/profile_picker_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/book_provider.dart';
import '../providers/user_provider.dart';
import '../screens/child/child_home_screen.dart';
import '../services/device_child_profile_service.dart';
import '../theme/app_theme.dart';
import '../services/app_readiness_tracker.dart';
import '../services/logger.dart';
import '../../utils/page_transitions.dart';
import '../widgets/branding/app_logo.dart';

class SplashScreen extends StatefulWidget {
  final DeviceChildProfileService? deviceChildProfileService;

  const SplashScreen({
    super.key,
    @visibleForTesting this.deviceChildProfileService,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final DeviceChildProfileService _deviceChildProfileService;

  @override
  void initState() {
    super.initState();
    _deviceChildProfileService =
        widget.deviceChildProfileService ?? DeviceChildProfileService();
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
        appLog(
            'Successfully loaded ${bookProvider.allBooks.length} books from backend',
            level: 'DEBUG');

        if (bookProvider.allBooks.isEmpty) {
          appLog(
              'WARNING: No books found in backend! Check Firebase permissions and data.',
              level: 'WARN');
        }
      } catch (e) {
        appLog('Error loading books from backend: $e', level: 'ERROR');
        appLog('This might be due to Firebase permissions or network issues.',
            level: 'WARN');
        // Don't initialize sample books - user has real books in backend
      }

      await Future.delayed(const Duration(milliseconds: 3000));

      if (!mounted) return;

      // FIXED: Check both isAuthenticated AND user object to ensure proper auth state
      appLog(
          'Auth Status: isAuthenticated=${authProvider.isAuthenticated}, user=${authProvider.user?.uid}',
          level: 'DEBUG');

      // Check authentication status and navigate accordingly
      if (authProvider.isAuthenticated && authProvider.user != null) {
        appLog('User is authenticated: ${authProvider.user!.uid}',
            level: 'DEBUG');
        try {
          // Load user data
          await userProvider.loadUserData(authProvider.userId!);

          // Check if parent account
          if (authProvider.isParentAccount) {
            appLog('Parent account detected, going to parent dashboard',
                level: 'DEBUG');
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/parent_home');
            }
          } else if (authProvider.hasCompletedQuiz()) {
            appLog('User has completed quiz, loading dashboard...',
                level: 'DEBUG');
            // User has completed quiz, load recommendations and go to dashboard
            await bookProvider
                .loadRecommendedBooks(authProvider.getPersonalityTraits());
            await bookProvider.loadUserProgress(authProvider.userId!);

            if (mounted) {
              Navigator.pushReplacement(
                context,
                FadeRoute(
                  page: const ChildHomeScreen(),
                ),
              );
            }
          } else {
            appLog('User needs to complete quiz', level: 'WARN');
            // User needs to complete quiz
            if (mounted) {
              Navigator.pushReplacement(
                context,
                FadeRoute(
                  page: const OnboardingScreen(),
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
              FadeRoute(
                page: const OnboardingScreen(),
              ),
            );
          }
        }
      } else {
        // A device this family has already set up (Option B — see
        // docs/child-account-model-design.md) shows the "Who's reading?"
        // avatar picker instead of the marketing onboarding screen, so a
        // child can tap their own profile instead of a parent typing their
        // email/password in every time.
        final rememberedChildren =
            await _deviceChildProfileService.getRememberedChildren();

        if (!mounted) return;

        if (rememberedChildren.isNotEmpty) {
          appLog(
              'User is NOT authenticated, but this device has remembered '
              'children — going to profile picker',
              level: 'DEBUG');
          Navigator.pushReplacement(
            context,
            FadeRoute(
              page: ProfilePickerScreen(
                deviceChildProfileService: _deviceChildProfileService,
              ),
            ),
          );
        } else {
          appLog('User is NOT authenticated, going to onboarding',
              level: 'DEBUG');
          Navigator.pushReplacement(
            context,
            FadeRoute(
              page: const OnboardingScreen(),
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
          FadeRoute(
            page: const OnboardingScreen(),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    // Fires on every exit branch below — they're all pushReplacement,
    // which disposes this screen — so this is the one choke point that
    // reliably marks "splash is done" regardless of which branch ran.
    AppReadinessTracker.splashFinished();
    super.dispose();
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
              const AppLogo(
                showWordmark: true,
                size: 148,
                wordmarkSpacing: 2,
                assetPath: 'assets/branding/logo_white_transparent.png',
              ),
              const SizedBox(height: 18),
                    ],
          ),
        ),
      ),
    );
  }
}
