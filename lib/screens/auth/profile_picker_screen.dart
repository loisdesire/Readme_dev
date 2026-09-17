// File: lib/screens/auth/profile_picker_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/device_child_profile_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/page_transitions.dart';
import '../../widgets/app_button.dart';
import '../../widgets/common/user_avatar.dart';
import '../child/child_home_screen.dart';
import '../quiz/quiz_screen.dart';
import 'login_screen.dart';

/// "Who's reading?" — shown instead of the marketing onboarding screen when
/// this device already has one or more children remembered on it (see
/// docs/child-account-model-design.md, "Option B"). Tapping an avatar signs
/// in with that child's stored credentials; nobody types anything.
class ProfilePickerScreen extends StatefulWidget {
  // Not test-only: SplashScreen passes its own instance down here so both
  // share the same (possibly test-injected) storage backend.
  final DeviceChildProfileService? deviceChildProfileService;

  const ProfilePickerScreen({super.key, this.deviceChildProfileService});

  @override
  State<ProfilePickerScreen> createState() => _ProfilePickerScreenState();
}

class _ProfilePickerScreenState extends State<ProfilePickerScreen> {
  late final DeviceChildProfileService _service;
  List<RememberedChildProfile> _profiles = [];
  bool _isLoading = true;
  String? _signingInUid;

  @override
  void initState() {
    super.initState();
    _service = widget.deviceChildProfileService ?? DeviceChildProfileService();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final profiles = await _service.getRememberedChildren();
    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _isLoading = false;
    });
  }

  Future<void> _signInAs(RememberedChildProfile profile) async {
    setState(() => _signingInUid = profile.uid);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.signIn(
      email: profile.email,
      password: profile.password,
    );

    if (!mounted) return;

    if (!success) {
      setState(() => _signingInUid = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Couldn\'t sign in as ${profile.username}. Ask a parent for help.',
          ),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      // A stored password that no longer works (changed or reset elsewhere)
      // would otherwise just fail silently forever — drop it so the picker
      // stops offering a profile that can never sign in again.
      await _service.forgetChild(profile.uid);
      await _loadProfiles();
      return;
    }

    final hasQuiz = authProvider.hasCompletedQuiz();
    Navigator.pushReplacement(
      context,
      FadeRoute(page: hasQuiz ? const ChildHomeScreen() : const QuizScreen()),
    );
  }

  Future<void> _confirmForget(RememberedChildProfile profile) async {
    final shouldForget = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove profile?'),
        content: Text(
          'Remove ${profile.username} from this device? A parent can add '
          'them back later from Settings.',
        ),
        actions: [
          AppTextButton(
            text: 'Cancel',
            onPressed: () => Navigator.pop(context, false),
          ),
          AppTextButton(
            text: 'Remove',
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (shouldForget == true) {
      await _service.forgetChild(profile.uid);
      await _loadProfiles();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    Text(
                      'Who\'s reading?',
                      style: AppTheme.heading.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF8E44AD),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap your picture to start reading',
                      style: AppTheme.body.copyWith(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    Wrap(
                      spacing: 24,
                      runSpacing: 24,
                      alignment: WrapAlignment.center,
                      children: _profiles.map(_buildProfileTile).toList(),
                    ),
                    const SizedBox(height: 48),
                    AppTextButton(
                      text: 'Not your profile? Sign in or add a child',
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          FadeRoute(page: const LoginScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildProfileTile(RememberedChildProfile profile) {
    final isSigningIn = _signingInUid == profile.uid;
    return GestureDetector(
      onTap: isSigningIn ? null : () => _signInAs(profile),
      onLongPress: isSigningIn ? null : () => _confirmForget(profile),
      child: Column(
        children: [
          isSigningIn
              ? const SizedBox(
                  width: 72,
                  height: 72,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                )
              : UserAvatar(avatar: profile.avatar, size: 72, fontSize: 32),
          const SizedBox(height: 8),
          SizedBox(
            width: 88,
            child: Text(
              profile.username,
              style: AppTheme.body.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
