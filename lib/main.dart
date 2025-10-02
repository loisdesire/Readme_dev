// File: lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';
import 'providers/book_provider.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize backend services
  await _initializeServices();
  
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
    // await AchievementService().initializeAchievements();
    
    // Initialize sample books with proper format
    try {
      final bookProvider = BookProvider();
      await bookProvider.initializeSampleBooks();
      print('Sample books initialized successfully');
    } catch (bookError) {
      print('Error initializing sample books: $bookError');
      // Continue even if book initialization fails
    }
    
    print('Backend services initialized successfully');
  } catch (e) {
    print('Error initializing backend services: $e');
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
      ],
      child: MaterialApp(
        title: 'ReadMe - Personalized Reading for Kids',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.purple,
          primaryColor: const Color(0xFF8E44AD),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
