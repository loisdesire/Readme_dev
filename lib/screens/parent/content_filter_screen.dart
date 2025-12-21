// File: lib/screens/parent/content_filter_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/content_filter_service.dart';
import '../../services/logger.dart';
import '../../widgets/app_button.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../theme/app_theme.dart';

class ContentFilterScreen extends StatefulWidget {
  const ContentFilterScreen({super.key});

  @override
  State<ContentFilterScreen> createState() => _ContentFilterScreenState();
}

class _ContentFilterScreenState extends State<ContentFilterScreen> {
  Map<String, bool> contentFilters = {
    'adventure': true,
    'fantasy': true,
    'friendship': true,
    'animals': true,
    'family': true,
    'learning': true,
    'kindness': true,
    'creativity': true,
    'imagination': true,
    'responsibility': true,
    'cooperation': true,
    'resilience': true,
    'bravery': true,
    'sharing': true,
    'art': true,
    'exploration': true,
    'teamwork': true,
    'emotions': true,
    'self-acceptance': true,
    'problem-solving': true,
    'leadership': true,
    'confidence': true,
    'curiosity': true,
  };
  
  bool isLoading = true;
  ContentFilter? currentFilter;

  @override
  void initState() {
    super.initState();
    _loadCurrentFilters();
  }

  Future<void> _loadCurrentFilters() async {
    try {
      final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
      if (authProvider.userId != null) {
        final filter = await ContentFilterService().getContentFilter(authProvider.userId!);
        if (filter != null && mounted) {
          setState(() {
            currentFilter = filter;
            // Update contentFilters map based on allowedCategories
            for (final category in contentFilters.keys) {
              contentFilters[category] = filter.allowedCategories.contains(category);
            }
            isLoading = false;
          });
        }
      }
    } catch (e) {
        appLog('Error loading content filters: $e', level: 'ERROR');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _saveFilters() async {
    try {
      final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
      if (authProvider.userId == null) return;

      // Get allowed categories from the filters
      final allowedCategories = contentFilters.entries
          .where((entry) => entry.value == true)
          .map((entry) => entry.key)
          .toList();

      // Create or update content filter
      final filter = ContentFilter(
        userId: authProvider.userId!,
        allowedCategories: allowedCategories,
        blockedWords: currentFilter?.blockedWords ?? [],
        maxAgeRating: currentFilter?.maxAgeRating ?? '12+',
        enableSafeMode: currentFilter?.enableSafeMode ?? true,
        allowedAuthors: currentFilter?.allowedAuthors ?? [],
        blockedAuthors: currentFilter?.blockedAuthors ?? [],
        maxReadingTimeMinutes: currentFilter?.maxReadingTimeMinutes ?? 60,
        allowedTimes: currentFilter?.allowedTimes ?? ['06:00-22:00'],
        createdAt: currentFilter?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ContentFilterService().updateContentFilter(filter);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Content filters saved successfully!'),
            backgroundColor: Color(0xFF8E44AD),
          ),
        );
        Navigator.pop(context, true); // Return true to indicate filters were updated
      }
    } catch (e) {
        appLog('Error saving filters: $e', level: 'ERROR');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving filters: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Color(0xFF8E44AD)),
        ),
        title: const Text(
          'Content Filters',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8E44AD)))
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose what content your child can access',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Books with disabled genres will be hidden from your child\'s library',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.orange,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Expanded(
                child: ListView.builder(
                  itemCount: contentFilters.length,
                  itemBuilder: (context, index) {
                    final category = contentFilters.keys.elementAt(index);
                    final isEnabled = contentFilters[category]!;
                    
                    // Capitalize first letter for display
                    final displayName = category[0].toUpperCase() + category.substring(1);
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isEnabled 
                              ? AppTheme.primaryPurpleOpaque10
                              : const Color(0x1AFF0000),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isEnabled 
                                ? AppTheme.primaryPurpleOpaque30
                                : const Color(0x4DFF0000),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isEnabled ? Icons.check_circle : Icons.block,
                              color: isEnabled ? AppTheme.primaryPurple : Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                  ),
                                  Text(
                                    isEnabled ? 'Allowed' : 'Blocked',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isEnabled ? AppTheme.primaryPurple : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: isEnabled,
                              onChanged: (value) {
                                setState(() {
                                  contentFilters[category] = value;
                                });
                              },
                              activeThumbColor: AppTheme.primaryPurple,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ),
                  PrimaryButton(
                    text: 'Save Changes',
                    onPressed: _saveFilters,
                  ),
                ],
              ),
            ),
    );
  }
}