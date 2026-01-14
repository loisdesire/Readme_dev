// File: lib/screens/auth/register_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../quiz/quiz_screen.dart';
import '../parent/parent_home_screen.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pressable_card.dart';
import '../../widgets/app_button.dart';
import '../../services/feedback_service.dart';
import '../../utils/app_constants.dart';
import 'login_screen.dart';
import '../../utils/page_transitions.dart';

class RegisterScreen extends StatefulWidget {
  final String? initialAccountType;

  const RegisterScreen({super.key, this.initialAccountType});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUpSelected = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  late String _accountType; // 'child' or 'parent'

  @override
  void initState() {
    super.initState();
    _accountType = widget.initialAccountType ?? 'child';
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleSignUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final success = await authProvider.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        username: _usernameController.text.trim(),
        accountType: _accountType,
      );

      // Don't touch the widget tree if the State object was disposed while awaiting
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (success) {
        // Show success and navigate based on account type
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your reading adventure begins now'),
            backgroundColor: Color(0xFF8E44AD),
          ),
        );

        // Navigate based on account type
        Future.delayed(AppConstants.postAuthNavigationDelay, () {
          if (mounted) {
            if (_accountType == 'parent') {
              // Parents go straight to dashboard (no quiz)
              Navigator.pushReplacement(
                context,
                FadeRoute(page: const ParentHomeScreen(),
                ),
              );
            } else {
              // Children go to quiz
              Navigator.pushReplacement(
                context,
                FadeRoute(page: const QuizScreen(),
                ),
              );
            }
          }
        });
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'Sign up failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _switchToLogin() {
    Navigator.pushReplacement(
      context,
      FadeRoute(page: const LoginScreen()),
    );
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
              Color(0xFF8E44AD),
              Color(0xFFA062BA),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Tab Buttons
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: PressableCard(
                        onTap: () => setState(() => _isSignUpSelected = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: _isSignUpSelected
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              bottomLeft: Radius.circular(20),
                            ),
                          ),
                          child: Text(
                            'Join the Adventure',
                            style: AppTheme.heading.copyWith(
                              color: _isSignUpSelected
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
                        onTap: () {
                          FeedbackService.instance.playTap();
                          _switchToLogin();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: !_isSignUpSelected
                                ? Colors.white
                                : const Color(0x4DD6BCE1),
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(20),
                              bottomRight: Radius.circular(20),
                            ),
                          ),
                          child: Text(
                            'Sign In',
                            style: AppTheme.heading.copyWith(
                              color: !_isSignUpSelected
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
                          const SizedBox(height: 20),

                          // Illustration (SVG)
                          Center(
                            child: SvgPicture.asset(
                              'assets/illustrations/signup_wormies.svg',
                              height: AppConstants.illustrationSize,
                              width: AppConstants.illustrationSize,
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Username Field
                          TextFormField(
                            controller: _usernameController,
                            style: AppTheme.body,
                            decoration: InputDecoration(
                              hintText: 'Choose Your Reader Name',
                              hintStyle:
                                  AppTheme.body.copyWith(color: Colors.grey),
                              filled: true,
                              fillColor: const Color(0xFFF9F9F9),
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
                                return 'Please enter a username';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          // Email Field
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: AppTheme.body,
                            decoration: InputDecoration(
                              hintText: 'Your Email Address',
                              hintStyle:
                                  AppTheme.body.copyWith(color: Colors.grey),
                              filled: true,
                              fillColor: const Color(0xFFF9F9F9),
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
                                return 'We\'ll need your email to get started';
                              }
                              if (!value.contains('@')) {
                                return 'Check that email address again';
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
                              hintText: 'Create a Password',
                              hintStyle:
                                  AppTheme.body.copyWith(color: Colors.grey),
                              filled: true,
                              fillColor: const Color(0xFFF9F9F9),
                              border: OutlineInputBorder(
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
                                return 'Create a password to protect your account';
                              }
                              if (value.length < 6) {
                                return 'Make your password at least 6 characters long';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          // Confirm Password Field
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            style: AppTheme.body,
                            decoration: InputDecoration(
                              hintText: 'Confirm Your Password',
                              hintStyle:
                                  AppTheme.body.copyWith(color: Colors.grey),
                              filled: true,
                              fillColor: const Color(0xFFF9F9F9),
                              border: OutlineInputBorder(
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
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirmPassword =
                                        !_obscureConfirmPassword;
                                  });
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Type your password again to confirm';
                              }
                              if (value != _passwordController.text) {
                                return 'These passwords don\'t match—try again';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 60),

                          // Sign Up Button
                          PrimaryButton(
                            text: 'Start Reading',
                            onPressed: _handleSignUp,
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

