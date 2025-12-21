import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Privacy Policy',
          style: AppTheme.heading.copyWith(color: Colors.black87),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(25),
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
                    const Icon(
                      Icons.privacy_tip,
                      size: 60,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'Your Privacy Matters',
                      style: AppTheme.heading.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Last Updated: December 2025',
                      style:
                          AppTheme.bodyMedium.copyWith(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              _buildSection(
                'Introduction',
                'ReadMe is committed to protecting the privacy of our young readers. This Privacy Policy explains how we collect, use, and protect information when children use our reading application.',
              ),

              _buildSection(
                'Information We Collect',
                'We collect minimal information necessary to provide a personalized reading experience:\n\n'
                    '• Username and age group (for age-appropriate content)\n'
                    '• Personality quiz responses (to recommend suitable books)\n'
                    '• Reading progress and history (books read, pages completed)\n'
                    '• Achievement and points data (for gamification features)\n'
                    '• Book ratings and favorites (to improve recommendations)\n\n'
                    'We DO NOT collect:\n'
                    '• Real names or personal identifiers\n'
                    '• Contact information\n'
                    '• Location data\n'
                    '• Payment information (from children)',
              ),

              _buildSection(
                'How We Use Information',
                'The information we collect is used solely to:\n\n'
                    '• Provide personalized book recommendations\n'
                    '• Track reading progress and achievements\n'
                    '• Display leaderboards and reading statistics\n'
                    '• Improve our book matching algorithm\n'
                    '• Ensure age-appropriate content filtering',
              ),

              _buildSection(
                'Parental Control',
                'Parents have full control over their child\'s account:\n\n'
                    '• Access child\'s reading history and progress\n'
                    '• Manage content filtering settings\n'
                    '• Delete account and all associated data\n'
                    '• Request data export at any time\n\n'
                    'Parents can access controls using the Parent PIN feature in the settings.',
              ),

              _buildSection(
                'Data Security',
                'We take data security seriously:\n\n'
                    '• All data is encrypted in transit and at rest\n'
                    '• No third-party advertising or tracking\n'
                    '• Regular security audits and updates\n'
                    '• Data is stored on secure Firebase servers\n'
                    '• Staff access to data is strictly limited',
              ),

              _buildSection(
                'Children\'s Privacy (COPPA Compliance)',
                'ReadMe is designed for children ages 8-14. We comply with the Children\'s Online Privacy Protection Act (COPPA):\n\n'
                    '• Parental consent is required for account creation\n'
                    '• We collect only necessary information\n'
                    '• No behavioral advertising or profiling\n'
                    '• Parents can review and delete child data anytime',
              ),

              _buildSection(
                'Data Retention',
                'We retain user data only as long as the account is active:\n\n'
                    '• Reading history: Kept while account is active\n'
                    '• Quiz responses: Kept until retaken or account deleted\n'
                    '• Achievements: Kept while account is active\n'
                    '• Deleted accounts: All data permanently removed within 30 days',
              ),

              _buildSection(
                'Third-Party Services',
                'ReadMe uses the following trusted services:\n\n'
                    '• Firebase (Google): Data storage and authentication\n'
                    '• OpenAI: AI-powered book recommendations (anonymized data only)\n\n'
                    'These services have their own privacy policies and security measures.',
              ),

              _buildSection(
                'Your Rights',
                'You have the right to:\n\n'
                    '• Access your child\'s data\n'
                    '• Correct inaccurate information\n'
                    '• Delete the account and all data\n'
                    '• Export data in a portable format\n'
                    '• Withdraw consent at any time\n\n'
                    'To exercise these rights, contact us at privacy@readmeapp.com',
              ),

              _buildSection(
                'Changes to This Policy',
                'We may update this Privacy Policy from time to time. We will notify users of significant changes through the app or via email. Continued use of the app after changes constitutes acceptance of the updated policy.',
              ),

              _buildSection(
                'Contact Us',
                'If you have questions or concerns about privacy:\n\n'
                    'Email: privacy@readmeapp.com\n'
                    'Support: support@readmeapp.com\n\n'
                    'We aim to respond to all privacy inquiries within 48 hours.',
              ),

              const SizedBox(height: 20),

              // Trust Badges
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurpleOpaque10,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: AppTheme.primaryPurpleOpaque30,
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.verified_user,
                      size: 50,
                      color: Color(0xFF8E44AD),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'COPPA Compliant',
                      style: AppTheme.heading.copyWith(
                        color: const Color(0xFF8E44AD),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ReadMe follows strict privacy guidelines to protect children online.',
                      style:
                          AppTheme.bodyMedium.copyWith(color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: const Color(0x1A9E9E9E),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTheme.heading.copyWith(
              fontSize: 18,
              color: const Color(0xFF8E44AD),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: AppTheme.body.copyWith(
              color: Colors.black87,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
