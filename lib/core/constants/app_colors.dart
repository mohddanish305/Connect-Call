import 'package:flutter/material.dart';

/// ConnectCall Brand Palette & UI/UX Cheat Sheet Tokens
class AppColors {
  AppColors._();

  // Primary Brand Colors
  static const Color primaryBlue = Color(0xFF075FEA);
  static const Color primaryBlueDark = Color(0xFF0647C7);
  static const Color primaryBlueLight = Color(0xFF3B82F6);
  static const Color primarySoft = Color(0xFFEAF2FF);

  // Cyan Accents
  static const Color cyan = Color(0xFF00CFF3);
  static const Color cyanDark = Color(0xFF00A9CC);
  static const Color cyanSoft = Color(0xFFE6FAFF);

  // Neutral / Light Theme
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSecondary = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE2E8F0);

  // Text Colors (Light Mode)
  static const Color primaryText = Color(0xFF0F172A);
  static const Color secondaryText = Color(0xFF64748B);
  static const Color mutedText = Color(0xFF94A3B8);

  // Dark Theme Tokens
  static const Color darkBackground = Color(0xFF07111F);
  static const Color darkSurface = Color(0xFF0D1B2A);
  static const Color darkElevatedSurface = Color(0xFF13253A);
  static const Color darkBorder = Color(0xFF24364A);

  // Text Colors (Dark Mode)
  static const Color darkPrimaryText = Color(0xFFF8FAFC);
  static const Color darkSecondaryText = Color(0xFF94A3B8);
  static const Color darkMutedText = Color(0xFF94A3B8);

  // Functional / Status Colors
  static const Color success = Color(0xFF22C55E); // Online / Call Accept
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);   // End Call / Decline / Error

  // Branded Gradients
  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF061022),
      Color(0xFF071B5C),
      Color(0xFF075FEA),
      Color(0xFF00D8F5),
    ],
    stops: [0.0, 0.35, 0.75, 1.0],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryBlue, primaryBlueLight],
  );

  static const LinearGradient callGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF07111F),
      Color(0xFF0D1B2A),
      Color(0xFF07111F),
    ],
  );
}
