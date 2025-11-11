import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/auth_provider.dart' as my_auth;
import '../../services/feedback_service.dart';
import '../../widgets/pressable_card.dart';
import '../../theme/app_theme.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  String _selectedAvatar = '👦';
  bool _isSaving = false;

  final List<String> _avatarOptions = [
    '🧒🏽', '👧🏽', '🧑🏽', '👶🏼',
    '🐶', '🐱', '🐻', '🦁',
    '🎀', '✈', '🐯', '🦊',
    '🧠', '🐵', '🦋', '🦉',
    '🦹‍♀️', '⚽', '🎨', '📚',
  ];

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _emailController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  final authProvider = Provider.of<my_auth.AuthProvider>(context, listen: false);
    _usernameController.text = authProvider.userProfile?['username'] ?? '';
    _emailController.text = FirebaseAuth.instance.currentUser?.email ?? '';
    _selectedAvatar = authProvider.userProfile?['avatar'] ?? '🧒';
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_usernameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Username cannot be empty'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Update user profile in Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'username': _usernameController.text.trim(),
          'avatar': _selectedAvatar,
        });

        // Reload auth provider
        if (mounted) {
          await context.read<my_auth.AuthProvider>().reloadUserProfile();
        }

        if (mounted) {
          FeedbackService.instance.playSuccess();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Color(0xFF8E44AD),
            ),
          );

          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Color(0xFF8E44AD)),
        ),
        title: Text(
          'Edit Profile',
          style: AppTheme.heading.copyWith(fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar selection
            Text(
              'Choose Avatar',
              style: AppTheme.heading.copyWith(
                fontSize: 18,
                color: const Color(0xFF8E44AD),
              ),
            ),
            const SizedBox(height: 15),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x1A9E9E9E),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceEvenly,
                spacing: 12,
                runSpacing: 12,
                children: _avatarOptions.map((avatar) {
                  final isSelected = avatar == _selectedAvatar;
                  return GestureDetector(
                    onTap: () {
                      FeedbackService.instance.playTap();
                      setState(() {
                        _selectedAvatar = avatar;
                      });
                    },
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? const Color(0x1A8E44AD)
                            : const Color(0x0A9E9E9E),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF8E44AD)
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          avatar,
                          style: const TextStyle(fontSize: 32),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 30),

            // Username field
            Text(
              'Username',
              style: AppTheme.heading.copyWith(
                fontSize: 18,
                color: const Color(0xFF8E44AD),
              ),
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x1A9E9E9E),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Enter your username',
                  hintStyle: AppTheme.body.copyWith(color: Colors.grey),
                ),
                style: AppTheme.body,
              ),
            ),

            const SizedBox(height: 30),

            // Email field (read-only)
            Text(
              'Email',
              style: AppTheme.heading.copyWith(
                fontSize: 18,
                color: const Color(0xFF8E44AD),
              ),
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: const Color(0xFFE0E0E0),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _emailController.text,
                      style: AppTheme.body.copyWith(color: Colors.grey),
                    ),
                  ),
                  const Icon(Icons.lock_outline, color: Colors.grey),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Email cannot be changed',
              style: AppTheme.bodySmall.copyWith(color: Colors.grey),
            ),

            const SizedBox(height: 40),

            // Save button
            SizedBox(
              width: double.infinity,
              child: PressableCard(
                onTap: _isSaving ? null : _saveProfile,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _isSaving
                        ? Colors.grey
                        : const Color(0xFF8E44AD),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Center(
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Save Changes',
                            style: AppTheme.buttonText,
                          ),
                  ),
                ),
              ),
            ),
            SizedBox(height: bottomPadding),
          ],
        ),
      ),
    );
  }
}
