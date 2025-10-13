// File: lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'services/logger.dart';
import 'screens/splash_screen.dart';
import 'services/feedback_service.dart';
import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';
import 'providers/book_provider.dart';
import 'services/notification_service.dart';
import 'services/achievement_service.dart';
import 'widgets/feedback_overlay.dart';

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
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(const ReadMeApp());
}

// Initialize all backend services
Future<void> _initializeServices() async {
      try {
    // Initialize notification service
    await NotificationService().initialize();
    
    // Initialize achievements (uncomment when ready to populate)
    await AchievementService().initializeAchievements();
    
    // Initialize sample books with proper format
      try {
      final bookProvider = BookProvider();
      await bookProvider.initializeSampleBooks();
      appLog('Sample books initialized successfully', level: 'DEBUG');
    } catch (bookError) {
      appLog('Error initializing sample books: $bookError', level: 'ERROR');
      // Continue even if book initialization fails
    }
    
    appLog('Backend services initialized successfully', level: 'DEBUG');
  } catch (e) {
    appLog('Error initializing backend services: $e', level: 'ERROR');
  }
}

class ReadMeApp extends StatelessWidget {
  const ReadMeApp({super.key});

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
        theme: ThemeData(
          primarySwatch: Colors.purple,
          primaryColor: const Color(0xFF8E44AD),
        ),
        builder: (context, child) {
          // Place the feedback overlay above everything so confetti can be
          // triggered from any screen via FeedbackService.
          return Stack(
            children: [
              if (child != null) child,
              const FeedbackOverlay(),
            ],
          );
        },
        home: const SplashScreen(),
      ),
    );
  }
}
