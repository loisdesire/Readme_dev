// File: lib/screens/auth/register_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../quiz/quiz_screen.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pressable_card.dart';
import '../../services/feedback_service.dart';
import '../../utils/app_constants.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUpSelected = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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
      );

      // Don't touch the widget tree if the State object was disposed while awaiting
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (success) {
        // Show success and navigate to quiz (new user needs personality assessment)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully! 🎉'),
            backgroundColor: Color(0xFF8E44AD),
          ),
        );
        
        // Navigate to personality quiz
        Future.delayed(AppConstants.postAuthNavigationDelay, () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const QuizScreen(),
              ),
            );
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
      MaterialPageRoute(builder: (context) => const LoginScreen()),
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
                            color: _isSignUpSelected ? Colors.white : Colors.transparent,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              bottomLeft: Radius.circular(20),
                            ),
                          ),
                          child: Text(
                            'Sign Up',
                            style: AppTheme.heading.copyWith(
                              color: _isSignUpSelected ? AppTheme.black : const Color(0xB3FFFFFF),
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
                            color: !_isSignUpSelected ? Colors.white : const Color(0x4DD6BCE1),
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(20),
                              bottomRight: Radius.circular(20),
                            ),
                          ),
                          child: Text(
                            'Login',
                            style: AppTheme.heading.copyWith(
                              color: !_isSignUpSelected ? AppTheme.black : const Color(0xB3FFFFFF),
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
                          
                          const SizedBox(height: 40),
                          
                          // Username Field
                          TextFormField(
                            controller: _usernameController,
                            style: AppTheme.body,
                            decoration: InputDecoration(
                              hintText: 'Username',
                              hintStyle: AppTheme.body.copyWith(color: Colors.grey),
                              filled: true,
                              fillColor: const Color(0xFFF9F9F9),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppConstants.standardBorderRadius),
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
                              hintText: 'Email',
                              hintStyle: AppTheme.body.copyWith(color: Colors.grey),
                              filled: true,
                              fillColor: const Color(0xFFF9F9F9),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppConstants.standardBorderRadius),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter an email';
                              }
                              if (!value.contains('@')) {
                                return 'Please enter a valid email';
                              }
                              return null;
                            },
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Password Field
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            style: AppTheme.body,
                            decoration: InputDecoration(
                              hintText: 'Password',
                              hintStyle: AppTheme.body.copyWith(color: Colors.grey),
                              filled: true,
                              fillColor: const Color(0xFFF9F9F9),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppConstants.standardBorderRadius),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          
                          const SizedBox(height: 60),
                          
                          // Sign Up Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8E44AD),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppConstants.standardBorderRadius),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              onPressed: _isLoading ? null : _handleSignUp,
                              child: _isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Sign up',
                                          style: AppTheme.buttonText,
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.arrow_forward, size: 20),
                                      ],
                                    ),
                            ),
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
