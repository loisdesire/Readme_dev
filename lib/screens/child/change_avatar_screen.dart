// File: lib/screens/child/change_avatar_screen.dart
import 'package:flutter/material.dart';
import '../../widgets/pressable_card.dart';
import '../../services/feedback_service.dart';
import '../../theme/app_theme.dart';

class ChangeAvatarScreen extends StatefulWidget {
  const ChangeAvatarScreen({super.key});

  @override
  State<ChangeAvatarScreen> createState() => _ChangeAvatarScreenState();
}

class _ChangeAvatarScreenState extends State<ChangeAvatarScreen> {
  String _selectedAvatar = '👦'; // Default avatar
  
  // Available avatars
  final List<String> _avatars = [
    '👦', '👧', '🧒', '👶', '🧑', '👨', '👩', '🧓',
    '🙂', '😊', '😄', '🤓', '😎', '🤔', '🥰', '😇',
    '🦸‍♂️', '🦸‍♀️', '🧙‍♂️', '🧙‍♀️', '🧚‍♂️', '🧚‍♀️', '🧜‍♂️', '🧜‍♀️',
    '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼',
    '🦁', '🐯', '🐸', '🐵', '🐔', '🐧', '🦉', '🦄',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
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
                      color: Color(0xFF8E44AD),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Choose Your Avatar',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
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
                  const Text(
                    'Your Avatar',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
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
                    const TabBar(
                      indicatorColor: Color(0xFF8E44AD),
                      labelColor: Color(0xFF8E44AD),
                      unselectedLabelColor: Colors.grey,
                      labelStyle: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      tabs: [
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
              padding: const EdgeInsets.all(20.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8E44AD),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () {
                    // Save avatar and go back
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Avatar saved! $_selectedAvatar'),
                        backgroundColor: const Color(0xFF8E44AD),
                      ),
                    );
                    Navigator.pop(context);
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Save Avatar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

  Widget _buildAvatarGrid(List<String> avatars) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
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
                  color: isSelected 
                    ? AppTheme.primaryPurple
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
        },
      ),
    );
  }
}