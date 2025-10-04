// File: lib/screens/parent/set_goals_screen.dart
import 'package:flutter/material.dart';

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Color(0xFF8E44AD)),
        ),
        title: const Text(
          'Set Reading Goals',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Help your child build a consistent reading habit',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 30),
              
              // Daily goal section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F9F9),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daily Reading Goal',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${_dailyMinutes.round()} minutes per day',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF8E44AD),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Slider(
                      value: _dailyMinutes,
                      min: 5.0,
                      max: 60.0,
                      divisions: 11,
                      activeColor: const Color(0xFF8E44AD),
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
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          '60 min',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Reminders section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F9F9),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reading Reminders',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 15),
                    
                    // Enable reminders toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Daily reminders',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        Switch(
                          value: _enableReminders,
                          onChanged: (value) {
                            setState(() {
                              _enableReminders = value;
                            });
                          },
                          activeThumbColor: const Color(0xFF8E44AD),
                        ),
                      ],
                    ),
                    
                    if (_enableReminders) ...[
                      const SizedBox(height: 20),
                      // Reminder time
                      GestureDetector(
                        onTap: () async {
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
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                color: Color(0xFF8E44AD),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Reminder time',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                    Text(
                                      _reminderTime.format(context),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFF8E44AD),
                                        fontWeight: FontWeight.w600,
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
              const Text(
                'Quick Presets',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 15),
              
              // Fixed preset buttons with proper spacing
              LayoutBuilder(
                builder: (context, constraints) {
                  final buttonWidth = (constraints.maxWidth - 24) / 3; // Account for spacing
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8E44AD),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Goal set to ${_dailyMinutes.round()} minutes per day!',
                        ),
                        backgroundColor: const Color(0xFF8E44AD),
                      ),
                    );
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Save Goal',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
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
    return GestureDetector(
      onTap: () {
        setState(() {
          _dailyMinutes = minutes;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF8E44AD) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? const Color(0xFF8E44AD) : Colors.grey[300]!,
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
    );
  }
}










// // File: lib/screens/parent/set_goals_screen.dart
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
//                   const SizedBox(height: 10),
//                   Text(
//                     '${_dailyMinutes.round()} minutes per day',
//                     style: const TextStyle(
//                       fontSize: 16,
//                       color: Color(0xFF8E44AD),
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//                   const SizedBox(height: 20),
//                   Slider(
//                     value: _dailyMinutes,
//                     min: 5.0,
//                     max: 60.0,
//                     divisions: 11,
//                     activeColor: const Color(0xFF8E44AD),
//                     onChanged: (value) {
//                       setState(() {
//                         _dailyMinutes = value;
//                       });
//                     },
//                   ),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Text(
//                         '5 min',
//                         style: TextStyle(
//                           fontSize: 12,
//                           color: Colors.grey[600],
//                         ),
//                       ),
//                       Text(
//                         '60 min',
//                         style: TextStyle(
//                           fontSize: 12,
//                           color: Colors.grey[600],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
            
//             const SizedBox(height: 30),
            
//             // Reminders section
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
//                     'Reading Reminders',
//                     style: TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.black,
//                     ),
//                   ),
//                   const SizedBox(height: 15),
                  
//                   // Enable reminders toggle
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       const Text(
//                         'Daily reminders',
//                         style: TextStyle(
//                           fontSize: 16,
//                           color: Colors.black,
//                         ),
//                       ),
//                       Switch(
//                         value: _enableReminders,
//                         onChanged: (value) {
//                           setState(() {
//                             _enableReminders = value;
//                           });
//                         },
//                         activeColor: const Color(0xFF8E44AD),
//                       ),
//                     ],
//                   ),
                  
//                   if (_enableReminders) ...[
//                     const SizedBox(height: 20),
//                     // Reminder time
//                     GestureDetector(
//                       onTap: () async {
//                         final time = await showTimePicker(
//                           context: context,
//                           initialTime: _reminderTime,
//                         );
//                         if (time != null) {
//                           setState(() {
//                             _reminderTime = time;
//                           });
//                         }
//                       },
//                       child: Container(
//                         padding: const EdgeInsets.all(16),
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(12),
//                           border: Border.all(color: Colors.grey[300]!),
//                         ),
//                         child: Row(
//                           children: [
//                             const Icon(
//                               Icons.access_time,
//                               color: Color(0xFF8E44AD),
//                             ),
//                             const SizedBox(width: 12),
//                             Expanded(
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   const Text(
//                                     'Reminder time',
//                                     style: TextStyle(
//                                       fontSize: 14,
//                                       fontWeight: FontWeight.w600,
//                                       color: Colors.black,
//                                     ),
//                                   ),
//                                   Text(
//                                     _reminderTime.format(context),
//                                     style: const TextStyle(
//                                       fontSize: 16,
//                                       color: Color(0xFF8E44AD),
//                                       fontWeight: FontWeight.w600,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                             const Icon(
//                               Icons.chevron_right,
//                               color: Colors.grey,
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ],
//                 ],
//               ),
//             ),
            
//             const SizedBox(height: 30),
            
//             // Quick preset buttons
//             const Text(
//               'Quick Presets',
//               style: TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.black,
//               ),
//             ),
//             const SizedBox(height: 15),
//             Row(
//               children: [
//                 Expanded(
//                   child: _buildPresetButton('Beginner\n5 min', 5.0),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: _buildPresetButton('Regular\n15 min', 15.0),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: _buildPresetButton('Advanced\n30 min', 30.0),
//                 ),
//               ],
//             ),
            
//             const Spacer(),
            
//             // Save button
//             SizedBox(
//               width: double.infinity,
//               child: ElevatedButton(
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: const Color(0xFF8E44AD),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(15),
//                   ),
//                   padding: const EdgeInsets.symmetric(vertical: 16),
//                 ),
//                 onPressed: () {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(
//                       content: Text(
//                         'Goal set to ${_dailyMinutes.round()} minutes per day!',
//                       ),
//                       backgroundColor: const Color(0xFF8E44AD),
//                     ),
//                   );
//                   Navigator.pop(context);
//                 },
//                 child: const Text(
//                   'Save Goal',
//                   style: TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.w600,
//                     color: Colors.white,
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildPresetButton(String text, double minutes) {
//     final isActive = _dailyMinutes == minutes;
//     return GestureDetector(
//       onTap: () {
//         setState(() {
//           _dailyMinutes = minutes;
//         });
//       },
//       child: Container(
//         padding: const EdgeInsets.symmetric(vertical: 16),
//         decoration: BoxDecoration(
//           color: isActive ? const Color(0xFF8E44AD) : Colors.white,
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(
//             color: isActive ? const Color(0xFF8E44AD) : Colors.grey[300]!,
//           ),
//         ),
//         child: Text(
//           text,
//           textAlign: TextAlign.center,
//           style: TextStyle(
//             fontSize: 14,
//             fontWeight: FontWeight.w600,
//             color: isActive ? Colors.white : Colors.grey[600],
//           ),
//         ),
//       ),
//     );
//   }
// }