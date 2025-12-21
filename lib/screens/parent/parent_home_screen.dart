// File: lib/screens/parent/parent_home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pressable_card.dart';
import '../../widgets/app_button.dart';
import '../../services/feedback_service.dart';
import 'add_child_screen.dart';
import 'parent_dashboard_screen.dart';
import '../auth/login_screen.dart';

class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  List<Map<String, dynamic>> _children = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Set status bar to light icons for dark purple app bar
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _loadChildren();
  }

  @override
  void dispose() {
    // Reset to default when leaving
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    super.dispose();
  }

  Future<void> _loadChildren() async {
    setState(() => _isLoading = true);
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final children = await authProvider.getChildrenProfiles();
    
    if (mounted) {
      setState(() {
        _children = children;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF8E44AD),
        elevation: 0,
        title: Text(
          'Parent Dashboard',
          style: AppTheme.heading.copyWith(
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              await authProvider.signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout, color: Colors.white),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: Color(0xFF8E44AD),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back,',
                          style: AppTheme.body.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          authProvider.userProfile?['username'] ?? 'Parent',
                          style: AppTheme.heading.copyWith(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${_children.length} ${_children.length == 1 ? 'child' : 'children'} registered',
                          style: AppTheme.body.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Children List
                  Expanded(
                    child: _children.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(20),
                            itemCount: _children.length,
                            itemBuilder: (context, index) {
                              final child = _children[index];
                              return _buildChildCard(child);
                            },
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          FeedbackService.instance.playTap();
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddChildScreen()),
          );
          
          if (result == true) {
            _loadChildren();
          }
        },
        backgroundColor: const Color(0xFF8E44AD),
        icon: const Icon(Icons.add),
        label: const Text('Add Child'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF8E44AD).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.child_care,
                size: 60,
                color: Color(0xFF8E44AD),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No children added yet',
              style: AppTheme.heading.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tap the button below to add your first child and start tracking their reading journey!',
              style: AppTheme.body.copyWith(
                fontSize: 14,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChildCard(Map<String, dynamic> child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: PressableCard(
        onTap: () {
          FeedbackService.instance.playTap();
          // Navigate to parent dashboard for this specific child
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ParentDashboardScreen(childId: child['uid']),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF8E44AD).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF8E44AD),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    child['avatar'] ?? '👦',
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Child info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child['username'] ?? 'Child',
                      style: AppTheme.heading.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      child['email'] ?? '',
                      style: AppTheme.body.copyWith(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              
              // Delete button
              IconButton(
                onPressed: () => _showDeleteDialog(child),
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                ),
              ),
              
              // Arrow
              const Icon(
                Icons.arrow_forward_ios,
                color: Color(0xFF8E44AD),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(Map<String, dynamic> child) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Child?'),
        content: Text(
          'Are you sure you want to remove ${child['username']}? This action cannot be undone.',
        ),
        actions: [
          AppTextButton(
            text: 'Cancel',
            onPressed: () => Navigator.pop(context),
          ),
          CompactButton(
            text: 'Remove',
            backgroundColor: Colors.red,
            onPressed: () async {
              Navigator.pop(context);
              await _deleteChild(child['uid']);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteChild(String childUid) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.removeChildAccount(childUid);

    if (!mounted) return;

    Navigator.pop(context); // Close loading

    if (success) {
      FeedbackService.instance.playSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Child removed successfully'),
          backgroundColor: Colors.green,
        ),
      );
      _loadChildren(); // Reload list
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to remove child'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
