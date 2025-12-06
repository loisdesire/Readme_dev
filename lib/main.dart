// File: lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'services/logger.dart';
import 'screens/splash_screen.dart';
import 'screens/parent/parent_home_screen.dart';
import 'services/feedback_service.dart';
import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';
import 'providers/book_provider.dart';
import 'services/notification_service.dart';
import 'services/achievement_service.dart';
import 'widgets/feedback_overlay.dart';
import 'widgets/achievement_listener.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize backend services
  await _initializeServices();
  // Load persisted feedback preferences
  await FeedbackService.instance.loadPreferences();
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  runApp(const ReadMeApp());
}

// Initialize all backend services
Future<void> _initializeServices() async {
      try {
    // Initialize notification service
    await NotificationService().initialize();
    
    // Initialize achievements
    await AchievementService().initializeAchievements();
    
    appLog('Backend services initialized successfully', level: 'DEBUG');
  } catch (e) {
    appLog('Error initializing backend services: $e', level: 'ERROR');
  }
}

class ReadMeApp extends StatelessWidget {
  const ReadMeApp({super.key});

  // Global navigator key for accessing Navigator from anywhere
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => BookProvider()),
        ChangeNotifierProvider(create: (_) => FeedbackService.instance),
      ],
      child: MaterialApp(
        title: 'ReadMe - Personalized Reading for Kids',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey, // Add navigator key
        theme: ThemeData(
          primarySwatch: Colors.purple,
          primaryColor: const Color(0xFF8E44AD),
        ),
        routes: {
          '/parent_home': (context) => const ParentHomeScreen(),
        },
        builder: (context, child) {
          // Wrap with AchievementListener to show popups app-wide
          // Then place the feedback overlay above everything so confetti can be
          // triggered from any screen via FeedbackService.
          return AchievementListener(
            navigatorKey: navigatorKey, // Pass navigator key to listener
            child: Stack(
              children: [
                if (child != null) child,
                const FeedbackOverlay(),
              ],
            ),
          );
        },
        home: const SplashScreen(),
      ),
    );
  }
}
