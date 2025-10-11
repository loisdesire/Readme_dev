// File: lib/screens/parent/parent_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'content_filter_screen.dart';
import 'reading_history_screen.dart';
import 'set_goals_screen.dart';
import '../../services/api_service.dart';
import '../../services/analytics_service.dart';
import '../../services/content_filter_service.dart';
import '../../providers/auth_provider.dart' as app_auth;

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  String? selectedChildId;
  String selectedChildName = "Child";
  Map<String, dynamic>? analytics;
  List<dynamic> recentHistory = [];
  List<String> allowedCategories = [];
  int readingGoal = 0;
  int todayMinutes = 0;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _initializeAndLoadData();
  }

  Future<void> _initializeAndLoadData() async {
    // Get the current authenticated user
    final currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser != null) {
      // For now, use the current user as the child
      // In a full implementation, you would fetch the parent's children from Firestore
      setState(() {
        selectedChildId = currentUser.uid;
        selectedChildName = currentUser.displayName ?? currentUser.email?.split('@')[0] ?? "Child";
      });
      await _loadDashboardData();
    } else {
      setState(() {
        error = "No user authenticated. Please log in.";
        isLoading = false;
      });
    }
  }

  Future<void> _loadDashboardData() async {
    if (selectedChildId == null) {
      setState(() {
        error = "No child selected";
        isLoading = false;
      });
      return;
    }

    setState(() {
      isLoading = true;
      error = null;
    });
    
    try {
      final analyticsData = await AnalyticsService().getParentAnalytics(selectedChildId!);
      final contentFilter = await ContentFilterService().getContentFilter(selectedChildId!);
      final todayMinutesVal = await ContentFilterService().getDailyReadingTime(selectedChildId!);
      
      setState(() {
        analytics = analyticsData;
        recentHistory = analyticsData['recentBooks'] ?? [];
        allowedCategories = contentFilter?.allowedCategories ?? [];
        readingGoal = contentFilter?.maxReadingTimeMinutes ?? 0;
        todayMinutes = todayMinutesVal;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading dashboard data: $e');
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error: $error',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _initializeAndLoadData,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(
                                  Icons.arrow_back,
                                  color: Color(0xFF8E44AD),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Viewing',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      "$selectedChildName's reading journey",
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Child avatar
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF8E44AD).withOpacity(0.1),
                                  border: Border.all(
                                    color: const Color(0xFF8E44AD),
                                    width: 2,
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.person,
                                    size: 28,
                                    color: Color(0xFF8E44AD),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Reading Stats Summary
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9F9F9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Reading stats summary',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildStatCard(
                                      Icons.menu_book,
                                      'Books read',
                                      '${analytics?['uniqueBooksRead'] ?? 0} books completed',
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: _buildStatCard(
                                      Icons.access_time,
                                      'Minutes read',
                                      '${analytics?['totalReadingTimeMinutes'] ?? 0} mins total',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 15),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildStatCard(
                                      Icons.local_fire_department,
                                      'Current streak',
                                      '${analytics?['currentStreak'] ?? 0}-day streak',
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: _buildStatCard(
                                      Icons.star,
                                      'Avg. session',
                                      '${analytics?['averageSessionLengthSeconds'] ?? 0}s',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 30),
                        
                        // Daily Reading Goal
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9F9F9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Set daily reading goal',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Text(
                                    '$todayMinutes/$readingGoal min',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF8E44AD),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    readingGoal > 0 ? '${((todayMinutes / readingGoal) * 100).round()}%' : '0%',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              LinearProgressIndicator(
                                value: readingGoal > 0 ? (todayMinutes / readingGoal).clamp(0.0, 1.0) : 0.0,
                                backgroundColor: Colors.grey[300],
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8E44AD)),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  _buildGoalButton('5mins', readingGoal == 5, 5),
                                  const SizedBox(width: 8),
                                  _buildGoalButton('10mins', readingGoal == 10, 10),
                                  const SizedBox(width: 8),
                                  _buildGoalButton('15mins', readingGoal == 15, 15),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 30),
                        
                        // Content Control
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9F9F9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Content control',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: allowedCategories.map((cat) => _buildContentTag(cat, true)).toList(),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFF8E44AD)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const ContentFilterScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'Manage Content Filters',
                                    style: TextStyle(
                                      color: Color(0xFF8E44AD),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 30),
                        
                        // Reading History
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Reading history',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const ReadingHistoryScreen(),
                                        ),
                                      );
                                    },
                                    child: const Text(
                                      'See all >',
                                      style: TextStyle(
                                        color: Color(0xFF8E44AD),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 15),
                              
                              // Recent reading items
                              if (recentHistory.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Center(
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.history,
                                          size: 48,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'No reading history yet',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                ...recentHistory.map((session) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildHistoryItem(
                                    session['bookTitle'] ?? 'Unknown',
                                    session['lastReadAt']?.toString() ?? '',
                                    (session['progressPercentage'] ?? 0.0) >= 1.0 ? 'Completed' : 'Ongoing',
                                    '',
                                  ),
                                )),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 30),
                        
                        // Settings
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Settings',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 15),
                              
                              _buildSettingsItem(
                                Icons.refresh,
                                'Reset app',
                                'Clear all data and start fresh',
                                onTap: () {
                                  _showResetDialog();
                                },
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF8E44AD), size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalButton(String text, bool isActive, int minutes) {
    return GestureDetector(
      onTap: () async {
        if (!isActive && selectedChildId != null) {
          final filter = await ContentFilterService().getContentFilter(selectedChildId!);
          if (filter != null) {
            final updated = ContentFilter(
              userId: filter.userId,
              allowedCategories: filter.allowedCategories,
              blockedWords: filter.blockedWords,
              maxAgeRating: filter.maxAgeRating,
              enableSafeMode: filter.enableSafeMode,
              allowedAuthors: filter.allowedAuthors,
              blockedAuthors: filter.blockedAuthors,
              maxReadingTimeMinutes: minutes,
              allowedTimes: filter.allowedTimes,
              createdAt: filter.createdAt,
              updatedAt: DateTime.now(),
            );
            await ContentFilterService().updateContentFilter(updated);
            await _loadDashboardData();
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF8E44AD) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isActive ? null : Border.all(color: Colors.grey[300]!),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildContentTag(String text, bool isEnabled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isEnabled ? const Color(0xFF8E44AD).withOpacity(0.1) : Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isEnabled ? const Color(0xFF8E44AD) : Colors.grey[300]!,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isEnabled ? const Color(0xFF8E44AD) : Colors.grey[600],
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            isEnabled ? Icons.check_circle : Icons.remove_circle,
            size: 16,
            color: isEnabled ? const Color(0xFF8E44AD) : Colors.grey[400],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(String title, String time, String status, String emoji) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF8E44AD).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(Icons.menu_book, color: Color(0xFF8E44AD), size: 28),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: status == 'Completed' ? Colors.green.withOpacity(0.1) : const Color(0xFF8E44AD).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: status == 'Completed' ? Colors.green : const Color(0xFF8E44AD),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF8E44AD)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset App'),
        content: const Text('Are you sure you want to reset all data? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('App reset functionality coming soon!'),
                  backgroundColor: Color(0xFF8E44AD),
                ),
              );
            },
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
