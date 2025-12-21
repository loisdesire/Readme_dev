// File: lib/screens/parent/add_child_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';
import '../../theme/app_theme.dart';
import '../../services/feedback_service.dart';
import '../../services/logger.dart';
import '../../utils/app_constants.dart';
import 'qr_scanner_widget.dart';

class AddChildScreen extends StatefulWidget {
  const AddChildScreen({super.key});

  @override
  State<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends State<AddChildScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Link existing tab
  final _pinController = TextEditingController();
  bool _isLinking = false;

  // Create tab
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pinController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _linkChildWithPin() async {
    final pin = _pinController.text.trim();
    if (pin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a PIN'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLinking = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Search for child by PIN
      final snapshot = await authProvider.firestore
          .collection('users')
          .where('accountType', isEqualTo: 'child')
          .where('parentAccessPin', isEqualTo: pin)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        if (!mounted) return;
        setState(() => _isLinking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No child found with this PIN'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final childData = snapshot.docs.first.data();
      final childUid = childData['uid'];

      // NEW: Support multiple parents - check parentIds array
      final List<dynamic> existingParents = childData['parentIds'] ?? [];

      // Check if already linked to THIS parent
      if (existingParents.contains(authProvider.userId)) {
        if (!mounted) return;
        setState(() => _isLinking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This child is already linked to your account'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Check if account is removed
      if (childData['isRemoved'] == true) {
        if (!mounted) return;
        setState(() => _isLinking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'This child account has been removed. Please restore it first.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Link child to parent (add to both arrays)
      await authProvider.firestore
          .collection('users')
          .doc(authProvider.userId)
          .update({
        'children': FieldValue.arrayUnion([childUid]),
      });

      await authProvider.firestore.collection('users').doc(childUid).update({
        'parentIds': FieldValue.arrayUnion([authProvider.userId]),
      });

      await authProvider.reloadUserProfile();

      if (!mounted) return;
      setState(() => _isLinking = false);

      FeedbackService.instance.playSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${childData['username']} linked successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLinking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to link child: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _createChild() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final childEmail = _emailController.text.trim();
      final childPassword = _passwordController.text;
      final childUsername = _usernameController.text.trim();

      // Call Cloud Function to create child account
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('createChildAccount');

      await callable.call({
        'email': childEmail,
        'password': childPassword,
        'username': childUsername,
        'parentId': authProvider.userId,
      });

      // Reload parent profile to get updated children list
      await authProvider.reloadUserProfile();

      if (!mounted) return;
      setState(() => _isCreating = false);

      FeedbackService.instance.playSuccess();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Child Created! 🎉'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Account created for $childUsername'),
              const SizedBox(height: 16),
              Text('Email: $childEmail', style: const TextStyle(fontSize: 12)),
              Text('Password: $childPassword',
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              const Text(
                'Save these credentials!',
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ],
          ),
          actions: [
            PrimaryButton(
              text: 'Done',
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context, true); // Go back to parent home
              },
              height: 45,
            ),
          ],
        ),
      );
    } catch (e, stackTrace) {
      appLog('ERROR creating child: $e\n$stackTrace', level: 'ERROR');

      if (!mounted) return;
      setState(() => _isCreating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create child: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF8E44AD),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: Text(
          'Add Child',
          style: AppTheme.heading.copyWith(color: Colors.white, fontSize: 20),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code_scanner), text: 'Scan QR'),
            Tab(icon: Icon(Icons.pin), text: 'Enter PIN'),
            Tab(icon: Icon(Icons.add), text: 'Create New'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildQRScanTab(),
          _buildLinkTab(),
          _buildCreateTab(),
        ],
      ),
    );
  }

  Widget _buildQRScanTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          color: const Color(0xFFF5F5F5),
          child: Row(
            children: [
              const Icon(Icons.info_outline,
                  color: Color(0xFF8E44AD), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Ask your child to show their QR code from Settings → Parent Access',
                  style: AppTheme.body.copyWith(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const Expanded(
          child: QRScannerWidget(),
        ),
      ],
    );
  }

  Widget _buildLinkTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          SvgPicture.asset(
            'assets/illustrations/signup_wormies.svg',
            height: 150,
            width: 150,
          ),
          const SizedBox(height: 30),
          Text(
            'Enter Child\'s Parent Access PIN',
            style: AppTheme.heading.copyWith(fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Your child can find this PIN in their settings under "Parent Access"',
            style:
                AppTheme.body.copyWith(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: AppTheme.body,
            decoration: InputDecoration(
              hintText: '6-digit PIN',
              hintStyle: AppTheme.body.copyWith(color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFFF9F9F9),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppConstants.standardBorderRadius),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            text: 'Link Child',
            onPressed: _linkChildWithPin,
            isLoading: _isLinking,
          ),
        ],
      ),
    );
  }

  Widget _buildCreateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            const SizedBox(height: 20),
            SvgPicture.asset(
              'assets/illustrations/signup_wormies.svg',
              height: AppConstants.illustrationSize,
              width: AppConstants.illustrationSize,
            ),
            const SizedBox(height: 30),
            TextFormField(
              controller: _usernameController,
              style: AppTheme.body,
              decoration: InputDecoration(
                hintText: 'Username',
                hintStyle: AppTheme.body.copyWith(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF9F9F9),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.standardBorderRadius),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Please enter a username'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: AppTheme.body,
              decoration: InputDecoration(
                hintText: 'Email Address',
                hintStyle: AppTheme.body.copyWith(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF9F9F9),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.standardBorderRadius),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty)
                  return 'Please enter an email address';
                if (!value.contains('@'))
                  return 'Please enter a valid email address';
                return null;
              },
            ),
            const SizedBox(height: 16),
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
                  borderRadius:
                      BorderRadius.circular(AppConstants.standardBorderRadius),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty)
                  return 'Please enter a password';
                if (value.length < 6)
                  return 'Password must be at least 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              obscureText: true,
              style: AppTheme.body,
              decoration: InputDecoration(
                hintText: 'Confirm Password',
                hintStyle: AppTheme.body.copyWith(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF9F9F9),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.standardBorderRadius),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty)
                  return 'Please confirm your password';
                if (value != _passwordController.text)
                  return 'Passwords do not match';
                return null;
              },
            ),
            const SizedBox(height: 32),
            PrimaryButton(
              text: 'Create Child Account',
              onPressed: _createChild,
              isLoading: _isCreating,
            ),
          ],
        ),
      ),
    );
  }
}
