import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'services/logger.dart';
import 'services/offline_service.dart';
import 'screens/splash_screen.dart';
import 'screens/parent/parent_home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/admin/admin_portal_screen.dart';
import 'services/feedback_service.dart';
import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';
import 'providers/book_provider.dart';
import 'services/notification_service.dart';
import 'services/achievement_service.dart';
import 'widgets/feedback_overlay.dart';
import 'widgets/achievement_listener.dart';
import 'widgets/offline_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Log framework errors with full detail (helps diagnose layout/rendering issues).
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    appLog('FlutterError: ${details.exceptionAsString()}', level: 'ERROR');
    if (details.stack != null) {
      appLog(details.stack.toString(), level: 'ERROR');
    }
    if (details.context != null) {
      appLog('Context: ${details.context}', level: 'ERROR');
    }
  };

  // Catch errors that escape the Flutter framework (including some async/render pipeline errors).
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    appLog('Uncaught error: $error', level: 'ERROR');
    appLog(stack.toString(), level: 'ERROR');
    return true;
  };

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

  runZonedGuarded(() {
    runApp(const ReadMeApp());
  }, (error, stack) {
    appLog('Zone error: $error', level: 'ERROR');
    appLog(stack.toString(), level: 'ERROR');
  });
}

// Initialize all backend services
Future<void> _initializeServices() async {
  try {
    // Initialize offline detection
    await OfflineService.instance.initialize();

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
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => BookProvider()),
        ChangeNotifierProvider(create: (_) => FeedbackService.instance),
        ChangeNotifierProvider(create: (_) => OfflineService.instance),
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
          '/login': (context) => const LoginScreen(),
          // Not linked from anywhere in the app's own UI — reachable only
          // by navigating here directly (e.g. a web deep link to
          // '#/admin', or `flutter run --route=/admin`). The screen
          // itself is the real access gate: it independently checks the
          // signed-in user's Firestore role (or the admins collection
          // fallback) and shows its own sign-in form to anyone who isn't
          // an admin, so exposing the route name costs nothing on its own.
          '/admin': (context) => const AdminPortalScreen(),
        },
        builder: (context, child) {
          // Wrap with AchievementListener to show popups app-wide
          // Then place the feedback overlay above everything so confetti can be
          // triggered from any screen via FeedbackService.
          return AchievementListener(
            navigatorKey: navigatorKey, // Pass navigator key to listener
            child: OfflineBanner(
              child: Stack(
                children: [
                  if (child != null) child,
                  const FeedbackOverlay(),
                ],
              ),
            ),
          );
        },
        home: const SplashScreen(),
      ),
    );
  }
}
