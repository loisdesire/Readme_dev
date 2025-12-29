import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import 'widgets/admin_dashboard.dart';
import 'widgets/book_upload_form.dart';
import 'widgets/books_table.dart';
import 'widgets/cloud_functions_panel.dart';

class AdminPortalScreen extends StatefulWidget {
  const AdminPortalScreen({super.key});

  @override
  State<AdminPortalScreen> createState() => _AdminPortalScreenState();
}

class _AdminPortalScreenState extends State<AdminPortalScreen> {
  int _selectedIndex = 0;
  bool _isCheckingAdmin = true;
  bool _isAdmin = false;
  String? _error;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isCheckingAdmin = false;
        _isAdmin = false;
      });
      return;
    }

    try {
      // Check if user has admin role
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists && userDoc.data()?['role'] == 'admin') {
        setState(() {
          _isAdmin = true;
          _isCheckingAdmin = false;
        });
      } else {
        // Check admins collection as fallback
        final adminDoc = await FirebaseFirestore.instance
            .collection('admins')
            .doc(user.uid)
            .get();

        if (adminDoc.exists && adminDoc.data()?['role'] == 'admin') {
          setState(() {
            _isAdmin = true;
            _isCheckingAdmin = false;
          });
        } else {
          await FirebaseAuth.instance.signOut();
          setState(() {
            _isAdmin = false;
            _isCheckingAdmin = false;
            _error = 'Access denied: Admin role required';
          });
        }
      }
    } catch (e) {
      setState(() {
        _isCheckingAdmin = false;
        _isAdmin = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _signIn() async {
    setState(() {
      _error = null;
      _isCheckingAdmin = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      await _checkAdminStatus();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isCheckingAdmin = false;
        _isAdmin = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAdmin) {
      return Scaffold(
        backgroundColor: AppTheme.lightGray,
        body: Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryPurple,
          ),
        ),
      );
    }

    if (!_isAdmin) {
      return Scaffold(
        backgroundColor: AppTheme.lightGray,
        body: Center(
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.elevatedCardShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin Sign In',
                  style: AppTheme.logoSmall.copyWith(
                    color: AppTheme.primaryPurple,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.borderGray),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.primaryPurple, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.borderGray),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.primaryPurple, width: 2),
                    ),
                  ),
                  onSubmitted: (_) => _signIn(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(color: AppTheme.errorRed, fontSize: 12),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                PrimaryButton(
                  text: 'Sign In',
                  onPressed: _signIn,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.lightGray,
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 260,
            color: AppTheme.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'ReadMe Admin',
                    style: AppTheme.heading.copyWith(
                      color: AppTheme.primaryPurple,
                      fontSize: 20,
                    ),
                  ),
                ),
                const Divider(height: 1),
                _NavItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  selected: _selectedIndex == 0,
                  onTap: () => setState(() => _selectedIndex = 0),
                ),
                _NavItem(
                  icon: Icons.upload_file_rounded,
                  label: 'Upload Book',
                  selected: _selectedIndex == 1,
                  onTap: () => setState(() => _selectedIndex = 1),
                ),
                _NavItem(
                  icon: Icons.library_books_rounded,
                  label: 'Manage Books',
                  selected: _selectedIndex == 2,
                  onTap: () => setState(() => _selectedIndex = 2),
                ),
                _NavItem(
                  icon: Icons.functions_rounded,
                  label: 'Cloud Functions',
                  selected: _selectedIndex == 3,
                  onTap: () => setState(() => _selectedIndex = 3),
                ),
                const Spacer(),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: AppTextButton(
                    text: 'Sign Out',
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      setState(() {
                        _isAdmin = false;
                      });
                    },
                    icon: Icons.logout_rounded,
                  ),
                ),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: _buildContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return const AdminDashboard();
      case 1:
        return const BookUploadForm();
      case 2:
        return const BooksTable();
      case 3:
        return const CloudFunctionsPanel();
      default:
        return const AdminDashboard();
    }
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.primaryPurpleOpaque10 : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? AppTheme.primaryPurple : AppTheme.textGray,
                size: 22,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? AppTheme.primaryPurple : AppTheme.textGray,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
