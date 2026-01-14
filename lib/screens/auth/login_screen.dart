// File: lib/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../utils/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../child/child_home_screen.dart';
import '../quiz/quiz_screen.dart';
import '../parent/parent_home_screen.dart';
import 'register_screen.dart';
import '../../widgets/pressable_card.dart';
import '../../widgets/app_button.dart';
import '../../services/feedback_service.dart';
import '../../utils/page_transitions.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isLoginSelected = true;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final success = await authProvider.signIn(
        email: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      // Don't touch the widget tree if the State object was disposed while awaiting
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (success) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Welcome back'),
            backgroundColor: AppTheme.primaryPurple,
          ),
        );

        // Navigate based on account type
        Future.delayed(AppConstants.postAuthNavigationDelay, () {
          if (mounted) {
            final accountType = authProvider.userProfile?['accountType'];

            if (accountType == 'parent') {
              // Parent account - go to parent home
              Navigator.pushReplacement(
                context,
                FadeRoute(page: const ParentHomeScreen(),
                ),
              );
            } else {
              // Child account - check if quiz completed
              final hasQuiz = authProvider.hasCompletedQuiz();

              if (hasQuiz) {
                // User has completed quiz, go to dashboard
                Navigator.pushReplacement(
                  context,
                  FadeRoute(page: const ChildHomeScreen(),
                  ),
                );
              } else {
                // User needs to complete quiz first
                Navigator.pushReplacement(
                  context,
                  FadeRoute(page: const QuizScreen(),
                  ),
                );
              }
            }
          }
        });
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'Login failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryPurple,
              AppTheme.primaryLight,
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Status Bar Space
              const SizedBox(height: 20),

              // Tab Buttons
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: PressableCard(
                        onTap: () {
                          FeedbackService.instance.playTap();
                          Navigator.pushReplacement(
                            context,
                            FadeRoute(page: const RegisterScreen(),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: !_isLoginSelected
                                ? Colors.white
                                : const Color(0x4DD6BCE1),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              bottomLeft: Radius.circular(20),
                            ),
                          ),
                          child: Text(
                            'Join the Adventure',
                            style: AppTheme.heading.copyWith(
                              color: !_isLoginSelected
                                  ? AppTheme.black
                                  : const Color(0xB3FFFFFF),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: PressableCard(
                        onTap: () => setState(() => _isLoginSelected = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: _isLoginSelected
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(20),
                              bottomRight: Radius.circular(20),
                            ),
                          ),
                          child: Text(
                            'Sign In',
                            style: AppTheme.heading.copyWith(
                              color: _isLoginSelected
                                  ? AppTheme.black
                                  : const Color(0xB3FFFFFF),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // White Container with Form
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          const SizedBox(height: 40),

                          // Illustration (SVG)
                          SvgPicture.asset(
                            'assets/illustrations/login_wormies.svg',
                            height: AppConstants.illustrationSize,
                            width: AppConstants.illustrationSize,
                            fit: BoxFit.contain,
                            placeholderBuilder: (context) => Container(
                              height: AppConstants.illustrationSize,
                              width: AppConstants.illustrationSize,
                              color: Colors.grey[200],
                              child: const Icon(
                                Icons.image,
                                size: 50,
                                color: Colors.grey,
                              ),
                            ),
                          ),

                          const SizedBox(height: 60),

                          // Email Field
                          TextFormField(
                            controller: _usernameController,
                            style: AppTheme.body,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              hintText: 'Your Email',
                              hintStyle:
                                  AppTheme.body.copyWith(color: Colors.grey),
                              filled: true,
                              fillColor: AppTheme.lightGray,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                    AppConstants.standardBorderRadius),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'We need your email to continue';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          // Password Field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: AppTheme.body,
                            decoration: InputDecoration(
                              hintText: 'Your Password',
                              hintStyle:
                                  AppTheme.body.copyWith(color: Colors.grey),
                              filled: true,
                              fillColor: AppTheme.lightGray,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                    AppConstants.standardBorderRadius),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                    AppConstants.standardBorderRadius),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                    AppConstants.standardBorderRadius),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Don\'t forget your password';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 60),

                          // Login Button
                          PrimaryButton(
                            text: 'Let\'s Go',
                            onPressed: _handleLogin,
                            isLoading: _isLoading,
                            icon: Icons.arrow_forward,
                          ),

                          // Bottom padding that adapts to device (gesture nav or not)
                          SizedBox(height: 20 + bottomPadding),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

