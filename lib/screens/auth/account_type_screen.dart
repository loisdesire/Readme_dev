import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pressable_card.dart';
import '../../widgets/app_button.dart';
import 'register_screen.dart';
import '../../utils/page_transitions.dart';

class AccountTypeScreen extends StatelessWidget {
  const AccountTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 48,
            ),
            child: Column(
              children: [
                const SizedBox(height: 40),

              // Logo/Header
              Text(
                'Welcome to ReadMe!',
                style: AppTheme.heading.copyWith(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF8E44AD),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              Text(
                'Who will be using this account?',
                style: AppTheme.body.copyWith(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Child Account Card
              PressableCard(
                onTap: () {
                  Navigator.push(
                    context,
                    FadeRoute(page: const RegisterScreen(
                        initialAccountType: 'child',
                      ),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF8E44AD),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x1A9E9E9E),
                        spreadRadius: 2,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0x1A8E44AD),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.child_care,
                          size: 48,
                          color: Color(0xFF8E44AD),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'I\'m a Child',
                        style: AppTheme.heading.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF8E44AD),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Discover amazing books and track my reading journey',
                        style: AppTheme.body.copyWith(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Parent Account Card
              PressableCard(
                onTap: () {
                  Navigator.push(
                    context,
                    FadeRoute(page: const RegisterScreen(
                        initialAccountType: 'parent',
                      ),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF8E44AD),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x1A9E9E9E),
                        spreadRadius: 2,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0x1A8E44AD),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.family_restroom,
                          size: 48,
                          color: Color(0xFF8E44AD),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'I\'m a Parent',
                        style: AppTheme.heading.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF8E44AD),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Monitor my child\'s reading progress and achievements',
                        style: AppTheme.body.copyWith(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Already have account
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account?',
                    style: AppTheme.body.copyWith(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  AppTextButton(
                    text: 'Sign In',
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                  ),
                ],
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}

