// File: lib/screens/onboarding/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart'; // Add this at the top with other imports
import '../../theme/app_theme.dart';
import '../../utils/app_constants.dart';
import '../auth/register_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    // ReadMe Logo
                    Text(
                      'ReadMe',
                      style: AppTheme.logoSmall,
                    ),
                    const SizedBox(height: 40),
                    // App Description
                    Text(
                      'A persuasive reading app\nfor kids',
                      style: AppTheme.heading,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 50),
                    // Illustration - no background or box
                    SvgPicture.asset(
                      'assets/illustrations/library_wormies.svg',
                      height: AppConstants.illustrationSize,
                      width: AppConstants.illustrationSize,
                      fit: BoxFit.contain,
                      placeholderBuilder: (context) => SizedBox(
                        height: AppConstants.illustrationSize,
                        width: AppConstants.illustrationSize,
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8E44AD)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Motivational Text
                    Text(
                      'Discover and read books that are\nas unique as you',
                      style: AppTheme.body.copyWith(
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textGray,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 32, left: 24, right: 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8E44AD),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.standardBorderRadius),
                    ),
                    padding: EdgeInsets.symmetric(
                      vertical: AppConstants.buttonVerticalPadding,
                      horizontal: AppConstants.buttonHorizontalPadding,
                    ),
                  ),
                  onPressed: () {
                    // Navigate to signup screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterScreen(),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Get started',
                        style: AppTheme.buttonText,
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}