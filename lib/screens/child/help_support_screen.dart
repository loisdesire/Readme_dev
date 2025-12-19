import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@readmeapp.com',
      query: 'subject=ReadMe App Support Request',
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

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
          'Help & Support',
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
                      Icons.support_agent,
                      size: 60,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'We\'re Here to Help!',
                      style: AppTheme.heading.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Find answers or get in touch with us',
                      style: AppTheme.body.copyWith(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // FAQs Section
              Text(
                'Frequently Asked Questions',
                style: AppTheme.heading.copyWith(
                  fontSize: 20,
                  color: const Color(0xFF8E44AD),
                ),
              ),
              const SizedBox(height: 15),

              _buildFAQCard(
                'How do I take the personality quiz?',
                'When you first sign up, you\'ll take a short personality quiz. This helps us recommend books that match your interests!',
              ),
              _buildFAQCard(
                'Why can\'t I see some books?',
                'Books are filtered based on your age to ensure age-appropriate content. As you grow, more books will become available!',
              ),
              _buildFAQCard(
                'How do I earn points and achievements?',
                'Finish reading books and maintain daily reading streaks! Check the Leaderboard to see your progress.',
              ),
              _buildFAQCard(
                'How do I track my reading progress?',
                'Your reading progress is automatically saved. You can see how far you\'ve read in any book from your Library.',
              ),
              _buildFAQCard(
                'How do I add books to favorites?',
                'Tap the heart icon on any book card to save it to your favorites. You can find all your favorite books in the Library tab.',
              ),
              _buildFAQCard(
                'Can I read offline?',
                'Once you\'ve opened a book, it\'s cached for offline reading. Make sure to open books while online first!',
              ),

              const SizedBox(height: 30),

              // Contact Support Section
              Text(
                'Still Need Help?',
                style: AppTheme.heading.copyWith(
                  fontSize: 20,
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
                child: Column(
                  children: [
                    const Icon(
                      Icons.email,
                      size: 50,
                      color: Color(0xFF8E44AD),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'Contact Support',
                      style: AppTheme.heading.copyWith(
                        color: const Color(0xFF8E44AD),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Have a question? Our support team is ready to help!',
                      style: AppTheme.bodyMedium.copyWith(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8E44AD),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        onPressed: _launchEmail,
                        icon: const Icon(Icons.send),
                        label: Text(
                          'Email Support',
                          style: AppTheme.heading.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Tips Section
              Text(
                'Reading Tips',
                style: AppTheme.heading.copyWith(
                  fontSize: 20,
                  color: const Color(0xFF8E44AD),
                ),
              ),
              const SizedBox(height: 15),

              _buildTipCard(
                Icons.lightbulb,
                'Build a Reading Habit',
                'Try to read for at least 15 minutes every day. You\'ll be surprised how many books you can finish!',
              ),
              _buildTipCard(
                Icons.stars,
                'Explore New Genres',
                'Don\'t just stick to one type of book. Try different genres recommended for you!',
              ),
              _buildTipCard(
                Icons.emoji_events,
                'Track Your Achievements',
                'Check the leaderboard to see how you rank with other readers. Compete with friends and earn badges!',
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFAQCard(String question, String answer) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(18),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.help_outline,
                color: Color(0xFF8E44AD),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  question,
                  style: AppTheme.heading.copyWith(
                    fontSize: 16,
                    color: const Color(0xFF8E44AD),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Text(
              answer,
              style: AppTheme.body.copyWith(
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard(IconData icon, String title, String description) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.primaryPurpleOpaque10,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AppTheme.primaryPurpleOpaque30,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF8E44AD),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.heading.copyWith(
                    fontSize: 16,
                    color: const Color(0xFF8E44AD),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: AppTheme.bodyMedium.copyWith(
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
