// File: lib/screens/child/change_avatar_screen.dart
import 'package:flutter/material.dart';
import '../../widgets/pressable_card.dart';
import '../../widgets/app_button.dart';
import '../../services/feedback_service.dart';
import '../../theme/app_theme.dart';

class ChangeAvatarScreen extends StatefulWidget {
  const ChangeAvatarScreen({super.key});

  @override
  State<ChangeAvatarScreen> createState() => _ChangeAvatarScreenState();
}

class _ChangeAvatarScreenState extends State<ChangeAvatarScreen> {
  String _selectedAvatar = '👩🏽‍🎓'; // Default avatar

  // Available avatars
  final List<String> _avatars = [
    '🧒🏽',
    '👧🏽',
    '🧑🏽',
    '👶🏼',
    '🐶',
    '🐱',
    '🐻',
    '🦁',
    '🎀',
    '✈',
    '🐯',
    '🦊',
    '🧠',
    '🐵',
    '🦋',
    '🦉',
    '🦹‍♀️',
    '⚽',
    '🎨',
    '📚',
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppTheme.primaryPurple,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Choose Your Avatar',
                      style: AppTheme.heading.copyWith(fontSize: 20),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 48), // Balance the back button
                ],
              ),
            ),

            // Current avatar preview
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF8E44AD),
                    Color(0xFFA062BA),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    'Your Avatar',
                    style: AppTheme.heading.copyWith(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.blackOpaque20,
                          spreadRadius: 2,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _selectedAvatar,
                        style: const TextStyle(fontSize: 50),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Avatar categories
            Expanded(
              child: DefaultTabController(
                length: 4,
                child: Column(
                  children: [
                    // Tabs
                    TabBar(
                      tabs: const [
                        Tab(text: 'People'),
                        Tab(text: 'Faces'),
                        Tab(text: 'Heroes'),
                        Tab(text: 'Animals'),
                      ],
                    ),

                    // Tab content
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildAvatarGrid(_avatars.sublist(0, 8)),
                          _buildAvatarGrid(_avatars.sublist(8, 16)),
                          _buildAvatarGrid(_avatars.sublist(16, 24)),
                          _buildAvatarGrid(_avatars.sublist(24, 32)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Save button
            Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomPadding),
              child: PrimaryButton(
                text: 'Save Avatar',
                icon: Icons.check,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Avatar saved! $_selectedAvatar')),
                  );
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarGrid(List<String> avatars) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 1.0,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: avatars.length,
        itemBuilder: (context, index) {
          final avatar = avatars[index];
          final isSelected = avatar == _selectedAvatar;

          return PressableCard(
            onTap: () {
              FeedbackService.instance.playTap();
              setState(() {
                _selectedAvatar = avatar;
              });
            },
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? AppTheme.primaryPurpleOpaque10
                    : Colors.grey[100],
                border: Border.all(
                  color:
                      isSelected ? AppTheme.primaryPurple : Colors.transparent,
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
        },
      ),
    );
  }
}
