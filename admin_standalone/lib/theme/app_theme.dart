// File: lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Primary Colors from Figma
  static const Color primaryPurple = Color(0xFF8E44AD);
  static const Color primaryLight = Color(0xFFA062BA);
  static const Color primaryLighter = Color(0xFFD6BCE1);
  static const Color secondaryYellow = Color(0xFFF7DC6F);
  
  // Additional purple shade for gradients
  static const Color primaryMediumLight = Color(0xFFB280C7);
  
  // Status colors
  static const Color errorRed = Color(0xFFE74C3C);
  static const Color successGreen = Color(0xFF27AE60);
  static const Color warningOrange = Color(0xFFF39C12);
  
  // Common non-opaque colors
  static const Color green = Color(0xFF00FF00);
  static const Color amber = Color(0xFFFFBF00);
  static const Color blackOpaque20 = Color(0x33000000);
  
  // Common opaque variants (used to replace withOpacity calls)
  static const Color primaryPurpleOpaque10 = Color(0x1A8E44AD);
  static const Color primaryPurpleOpaque30 = Color(0x4D8E44AD);
  static const Color greyOpaque10 = Color(0x1A9E9E9E);
  static const Color greenOpaque10 = Color(0x1A00FF00);
  static const Color amberOpaque10 = Color(0x1AFFBF00);
  
  // Basic Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color black87 = Color(0xDD000000);
  static const Color lightGray = Color(0xFFF9F9F9);
  static const Color textGray = Color(0xFF666666);
  static const Color borderGray = Color(0xFFE0E0E0);
  static const Color disabledGray = Color(0xFF757575);
  
  // Common shadows and styling
  static const List<BoxShadow> defaultCardShadow = [
    BoxShadow(
      color: Color(0x1A9E9E9E),
      spreadRadius: 1,
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];
  
  static const List<BoxShadow> elevatedCardShadow = [
    BoxShadow(
      color: Color(0x1A9E9E9E),
      spreadRadius: 2,
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];
  
  // Gradient for Splash Screen
  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF8E44AD),
      Color(0xFFA062BA),
      Color(0xFFB280C7),
    ],
    stops: [0.0, 0.5, 1.0],
  );
  
  // Text Styles with fallbacks - Using DM Sans throughout for consistency
  static TextStyle get logoLarge {
    try {
      return GoogleFonts.dmSans(
        fontSize: 46,
        fontWeight: FontWeight.w700,
        color: white,
      );
    } catch (e) {
      return const TextStyle(
        fontSize: 46,
        fontWeight: FontWeight.w700,
        color: white,
        fontFamily: 'sans-serif',
      );
    }
  }

  static TextStyle get logoSmall {
    try {
      return GoogleFonts.dmSans(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: black,
      );
    } catch (e) {
      return const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: black,
        fontFamily: 'sans-serif',
      );
    }
  }

  static TextStyle get heading {
    try {
      return GoogleFonts.dmSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: black,
      );
    } catch (e) {
      return const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: black,
        fontFamily: 'sans-serif',
      );
    }
  }

  static TextStyle get body {
    try {
      return GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: black,
      );
    } catch (e) {
      return const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: black,
        fontFamily: 'sans-serif',
      );
    }
  }

  static TextStyle get bodyMedium {
    try {
      return GoogleFonts.dmSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: black,
      );
    } catch (e) {
      return const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: black,
        fontFamily: 'sans-serif',
      );
    }
  }

  static TextStyle get bodySmall {
    try {
      return GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: textGray,
      );
    } catch (e) {
      return const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: textGray,
        fontFamily: 'sans-serif',
      );
    }
  }

  static TextStyle get buttonText {
    try {
      return GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: white,
      );
    } catch (e) {
      return const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: white,
        fontFamily: 'sans-serif',
      );
    }
  }

  /// Button text style for use on colored backgrounds (purple buttons, etc.)
  /// This is an alias for buttonText but makes intent clearer in code.
  /// Use this instead of AppTheme.heading.copyWith(color: Colors.white)
  static TextStyle get buttonTextOnColor => buttonText;

  /// Large button text for prominent CTAs
  static TextStyle get buttonTextLarge {
    try {
      return GoogleFonts.dmSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: white,
      );
    } catch (e) {
      return const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: white,
        fontFamily: 'sans-serif',
      );
    }
  }
  
  // App Theme
  static ThemeData get lightTheme => ThemeData(
    primarySwatch: _createMaterialColor(primaryPurple),
    primaryColor: primaryPurple,
    scaffoldBackgroundColor: white,
    
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryPurple,
        foregroundColor: white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        minimumSize: const Size(100, 56),
        elevation: 2,
      ),
    ),
    
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryPurple,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryPurple,
        side: const BorderSide(color: primaryPurple, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        minimumSize: const Size(100, 56),
      ),
    ),
    
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: textGray,
        iconSize: 24,
      ),
    ),
  );
  
  // Helper to create MaterialColor
  static MaterialColor _createMaterialColor(Color color) {
    Map<int, Color> swatch = {};
  // Extract RGB components from the non-deprecated ARGB integer.
  final int c = color.toARGB32();
  final int red = (c >> 16) & 0xFF;
  final int green = (c >> 8) & 0xFF;
  final int blue = c & 0xFF;

    // Generate swatch entries for 100..900 (using conventional keys)
    final strengths = [0.05, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9];
    for (int i = 0; i < strengths.length; i++) {
      final double strength = strengths[i];
      final int r = red + ((255 - red) * (1 - strength)).round();
      final int g = green + ((255 - green) * (1 - strength)).round();
      final int b = blue + ((255 - blue) * (1 - strength)).round();
      swatch[(i + 1) * 100] = Color.fromRGBO(r, g, b, 1);
    }

    // Use toARGB32 for an explicit, non-deprecated integer representation of the color
    final int colorInt = color.toARGB32();
    return MaterialColor(colorInt, swatch);
  }
}