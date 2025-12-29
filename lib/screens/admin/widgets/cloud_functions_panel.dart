import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_button.dart';

class CloudFunctionsPanel extends StatefulWidget {
  const CloudFunctionsPanel({super.key});

  @override
  State<CloudFunctionsPanel> createState() => _CloudFunctionsPanelState();
}

class _CloudFunctionsPanelState extends State<CloudFunctionsPanel> {
  final Map<String, bool> _loading = {};
  final Map<String, String?> _results = {};
  final Map<String, String?> _errors = {};
  final Map<String, bool> _enabled = {
    'triggerAiTagging': true,
    'triggerAiRecommendations': true,
    'healthCheck': true,
  };

  @override
  void initState() {
    super.initState();
    _loadFunctionStates();
  }

  Future<void> _loadFunctionStates() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('cloud_functions')
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _enabled['triggerAiTagging'] = data['aiTaggingEnabled'] ?? true;
          _enabled['triggerAiRecommendations'] = data['aiRecommendationsEnabled'] ?? true;
          _enabled['healthCheck'] = data['healthCheckEnabled'] ?? true;
        });
      }
    } catch (e) {
      // Ignore errors loading settings
    }
  }

  Future<void> _toggleFunction(String functionName, bool enabled) async {
    setState(() {
      _enabled[functionName] = enabled;
    });

    try {
      final settingsMap = {
        'aiTaggingEnabled': _enabled['triggerAiTagging'],
        'aiRecommendationsEnabled': _enabled['triggerAiRecommendations'],
        'healthCheckEnabled': _enabled['healthCheck'],
      };

      await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('cloud_functions')
          .set(settingsMap, SetOptions(merge: true));
    } catch (e) {
      setState(() {
        _errors[functionName] = 'Failed to save setting: ${e.toString()}';
      });
    }
  }

  Future<void> _triggerFunction(String functionName, String displayName) async {
    if (_enabled[functionName] != true) {
      setState(() {
        _errors[functionName] = 'This function is currently disabled';
      });
      return;
    }

    setState(() {
      _loading[functionName] = true;
      _results[functionName] = null;
      _errors[functionName] = null;
    });

    try {
      // Use Firebase callable functions (handles CORS automatically)
      final callable = FirebaseFunctions.instance.httpsCallable(functionName);
      final result = await callable.call();

      setState(() {
        final message = result.data is Map 
            ? (result.data['message'] ?? '$displayName completed successfully')
            : '$displayName completed successfully';
        _results[functionName] = message;
        _loading[functionName] = false;
      });
    } catch (e) {
      setState(() {
        _errors[functionName] = 'Error: ${e.toString()}';
        _loading[functionName] = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cloud Functions',
          style: AppTheme.logoSmall.copyWith(color: AppTheme.black87),
        ),
        const SizedBox(height: 4),
        Text(
          'Trigger and manage Firebase Cloud Functions for AI processing',
          style: AppTheme.bodySmall.copyWith(color: AppTheme.textGray),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚡ About Cloud Functions',
                      style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'These functions run automatically on schedule, but you can manually trigger them here for testing or immediate execution.',
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.textGray),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _FunctionCard(
                title: 'AI Tagging',
                description: 'Automatically tag books with traits, themes, and age ratings using OpenAI. Processes books that need tagging (needsTagging: true).',
                functionName: 'triggerAiTagging',
                icon: Icons.auto_awesome_rounded,
                color: AppTheme.primaryPurple,
                loading: _loading['triggerAiTagging'] ?? false,
                result: _results['triggerAiTagging'],
                error: _errors['triggerAiTagging'],
                enabled: _enabled['triggerAiTagging'] ?? true,
                onTrigger: () => _triggerFunction('triggerAiTagging', 'AI Tagging'),
                onToggle: (value) => _toggleFunction('triggerAiTagging', value),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _FunctionCard(
                title: 'AI Recommendations',
                description: 'Generate personalized book recommendations for all users based on their personality quiz results and reading history using OpenAI.',
                functionName: 'triggerAiRecommendations',
                icon: Icons.recommend_rounded,
                color: AppTheme.successGreen,
                loading: _loading['triggerAiRecommendations'] ?? false,
                result: _results['triggerAiRecommendations'],
                error: _errors['triggerAiRecommendations'],
                enabled: _enabled['triggerAiRecommendations'] ?? true,
                onTrigger: () => _triggerFunction('triggerAiRecommendations', 'AI Recommendations'),
                onToggle: (value) => _toggleFunction('triggerAiRecommendations', value),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _FunctionCard(
                title: 'Health Check',
                description: 'Verify that all Cloud Functions are properly deployed and responding. Returns the status and list of available functions.',
                functionName: 'healthCheck',
                icon: Icons.health_and_safety_rounded,
                color: Colors.blue.shade600,
                loading: _loading['healthCheck'] ?? false,
                result: _results['healthCheck'],
                error: _errors['healthCheck'],
                enabled: _enabled['healthCheck'] ?? true,
                onTrigger: () => _triggerFunction('healthCheck', 'Health Check'),
                onToggle: (value) => _toggleFunction('healthCheck', value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.lightGray,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderGray),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '📋 Scheduled Functions',
                style: AppTheme.heading.copyWith(color: AppTheme.black87),
              ),
              const SizedBox(height: 16),
              Text(
                'The following functions run automatically on schedule:',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.textGray),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryPurple,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Daily @ 3 AM UTC',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'AI Tagging',
                          style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.successGreen,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Daily @ 3 AM UTC',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'AI Recommendations',
                          style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '💡 Tip: Manual triggers are useful for immediate execution or testing without waiting for the scheduled run.',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textGray,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FunctionCard extends StatelessWidget {
  final String title;
  final String description;
  final String functionName;
  final IconData icon;
  final Color color;
  final bool loading;
  final String? result;
  final String? error;
  final bool enabled;
  final VoidCallback onTrigger;
  final ValueChanged<bool> onToggle;

  const _FunctionCard({
    required this.title,
    required this.description,
    required this.functionName,
    required this.icon,
    required this.color,
    required this.loading,
    required this.result,
    required this.error,
    required this.enabled,
    required this.onTrigger,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderGray),
        boxShadow: AppTheme.defaultCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: AppTheme.heading.copyWith(color: AppTheme.black87),
                ),
              ),
              Transform.scale(
                scale: 0.9,
                child: Switch(
                  value: enabled,
                  onChanged: onToggle,
                  activeColor: AppTheme.successGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (enabled ? AppTheme.successGreen : AppTheme.textGray).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  enabled ? 'Enabled' : 'Disabled',
                  style: AppTheme.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: enabled ? AppTheme.successGreen : AppTheme.textGray,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textGray,
              height: 1.5,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          if (result != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: AppTheme.successGreen, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      result!,
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.successGreen),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: AppTheme.errorRed, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      error!,
                      style: AppTheme.bodySmall.copyWith(color: AppTheme.errorRed),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          PrimaryButton(
            text: loading ? 'Running...' : 'Trigger $title',
            onPressed: (loading || !enabled) ? null : onTrigger,
            height: 48,
          ),
          if (loading)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Text(
                  'This may take a few minutes...',
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.textGray,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
