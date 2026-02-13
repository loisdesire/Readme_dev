// File: lib/screens/parent/set_goals_screen.dart
import 'package:flutter/material.dart';
import '../../widgets/pressable_card.dart';
import '../../widgets/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../services/feedback_service.dart';
import '../../theme/app_theme.dart';

class SetGoalsScreen extends StatefulWidget {
  const SetGoalsScreen({super.key});

  @override
  State<SetGoalsScreen> createState() => _SetGoalsScreenState();
}

class _SetGoalsScreenState extends State<SetGoalsScreen> {
  double _dailyMinutes = 15.0;
  bool _enableReminders = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 18, minute: 0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryPurple),
        ),
        title: Text(
          'Set Reading Goals',
          style: AppTheme.heading.copyWith(fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Help your child build a consistent reading habit',
                style: AppTheme.bodyMedium,
              ),
              const SizedBox(height: 30),

              // Daily goal section
              AppCard(
                padding: const EdgeInsets.all(20),
                backgroundColor: AppTheme.lightGray,
                borderRadius: BorderRadius.circular(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Reading Goal',
                      style: AppTheme.heading,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${_dailyMinutes.round()} minutes per day',
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryPurple,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Slider(
                      value: _dailyMinutes,
                      min: 5.0,
                      max: 60.0,
                      divisions: 11,
                      activeColor: AppTheme.primaryPurple,
                      onChanged: (value) {
                        setState(() {
                          _dailyMinutes = value;
                        });
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '5 min',
                          style: AppTheme.bodySmall,
                        ),
                        Text(
                          '60 min',
                          style: AppTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Reminders section
              AppCard(
                padding: const EdgeInsets.all(20),
                backgroundColor: AppTheme.lightGray,
                borderRadius: BorderRadius.circular(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reading Reminders',
                      style: AppTheme.heading,
                    ),
                    const SizedBox(height: 15),

                    // Enable reminders toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Daily reminders',
                            style: AppTheme.body,
                          ),
                        ),
                        Switch(
                          value: _enableReminders,
                          onChanged: (value) {
                            setState(() {
                              _enableReminders = value;
                            });
                          },
                          activeThumbColor: AppTheme.primaryPurple,
                        ),
                      ],
                    ),

                    if (_enableReminders) ...[
                      const SizedBox(height: 20),
                      // Reminder time
                      PressableCard(
                        onTap: () async {
                          FeedbackService.instance.playTap();
                          final time = await showTimePicker(
                            context: context,
                            initialTime: _reminderTime,
                          );
                          if (time != null) {
                            setState(() {
                              _reminderTime = time;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                color: AppTheme.primaryPurple,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Reminder time',
                                      style: AppTheme.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      _reminderTime.format(context),
                                      style: AppTheme.body.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primaryPurple,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Quick preset buttons
              Text(
                'Quick Presets',
                style: AppTheme.heading,
              ),
              const SizedBox(height: 15),

              // Fixed preset buttons with proper spacing
              LayoutBuilder(
                builder: (context, constraints) {
                  final buttonWidth =
                      (constraints.maxWidth - 24) / 3; // Account for spacing
                  return Row(
                    children: [
                      SizedBox(
                        width: buttonWidth,
                        child: _buildPresetButton('Beginner\n5 min', 5.0),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: buttonWidth,
                        child: _buildPresetButton('Regular\n15 min', 15.0),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: buttonWidth,
                        child: _buildPresetButton('Advanced\n30 min', 30.0),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 40),

              // Save button
              PrimaryButton(
                text: 'Save Goal',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Goal set to ${_dailyMinutes.round()} minutes per day!',
                      ),
                      backgroundColor: AppTheme.primaryPurple,
                    ),
                  );
                  Navigator.pop(context);
                },
              ),

              // Add bottom padding for safe area
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetButton(String text, double minutes) {
    final isActive = _dailyMinutes == minutes;
    return PressableCard(
      onTap: () {
        FeedbackService.instance.playTap();
        setState(() {
          _dailyMinutes = minutes;
        });
      },
      child: Builder(
        builder: (context) => Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.primaryPurple
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? AppTheme.primaryPurple
                  : Theme.of(context).dividerColor,
            ),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }
}
// import 'package:flutter/material.dart';

// class SetGoalsScreen extends StatefulWidget {
//   const SetGoalsScreen({super.key});

//   @override
//   State<SetGoalsScreen> createState() => _SetGoalsScreenState();
// }

// class _SetGoalsScreenState extends State<SetGoalsScreen> {
//   double _dailyMinutes = 15.0;
//   bool _enableReminders = true;
//   TimeOfDay _reminderTime = const TimeOfDay(hour: 18, minute: 0);

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0,
//         leading: IconButton(
//           onPressed: () => Navigator.pop(context),
//           icon: const Icon(Icons.arrow_back, color: Color(0xFF8E44AD)),
//         ),
//         title: const Text(
//           'Set Reading Goals',
//           style: TextStyle(
//             fontSize: 20,
//             fontWeight: FontWeight.bold,
//             color: Colors.black,
//           ),
//         ),
//         centerTitle: true,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(20),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text(
//               'Help your child build a consistent reading habit',
//               style: TextStyle(
//                 fontSize: 16,
//                 color: Colors.grey,
//               ),
//             ),
//             const SizedBox(height: 30),

//             // Daily goal section
//             Container(
//               padding: const EdgeInsets.all(20),
//               decoration: BoxDecoration(
//                 color: const Color(0xFFF9F9F9),
//                 borderRadius: BorderRadius.circular(15),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text(
//                     'Daily Reading Goal',
//                     style: TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.black,
//                     ),
//                   ),
