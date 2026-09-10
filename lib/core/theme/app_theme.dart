import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../constants/app_radius.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.primaryBlue,
      scaffoldBackgroundColor: AppColors.lightBackground,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryBlue,
        onPrimary: AppColors.white,
        secondary: AppColors.cyan,
        onSecondary: AppColors.darkSurface,
        surface: AppColors.surface,
        onSurface: AppColors.primaryText,
        error: AppColors.error,
        onError: AppColors.white,
        outline: AppColors.border,
      ),
      cardColor: AppColors.surface,
      dividerColor: AppColors.border,
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.manrope(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryText,
          letterSpacing: -0.5,
        ),
        headlineLarge: GoogleFonts.manrope(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryText,
          letterSpacing: -0.4,
        ),
        headlineMedium: GoogleFonts.manrope(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryText,
          letterSpacing: -0.3,
        ),
        titleLarge: GoogleFonts.manrope(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryText,
        ),
        titleMedium: GoogleFonts.manrope(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryText,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.primaryText,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.primaryText,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.secondaryText,
        ),
        labelLarge: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.white,
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primaryText,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryText,
        ),
        iconTheme: const IconThemeData(color: AppColors.primaryText),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: AppRadius.roundedLg,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.roundedLg,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.roundedLg,
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.roundedLg,
          borderSide: const BorderSide(color: AppColors.error),
        ),
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.mutedText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: AppColors.white,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.roundedLg,
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primaryBlue,
        unselectedItemColor: AppColors.secondaryText,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primaryBlueLight,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryBlueLight,
        onPrimary: AppColors.white,
        secondary: AppColors.cyan,
        onSecondary: AppColors.darkBackground,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkPrimaryText,
        error: AppColors.error,
        onError: AppColors.white,
        outline: AppColors.darkBorder,
      ),
      cardColor: AppColors.darkSurface,
      dividerColor: AppColors.darkBorder,
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.manrope(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: AppColors.darkPrimaryText,
          letterSpacing: -0.5,
        ),
        headlineLarge: GoogleFonts.manrope(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.darkPrimaryText,
          letterSpacing: -0.4,
        ),
        headlineMedium: GoogleFonts.manrope(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.darkPrimaryText,
          letterSpacing: -0.3,
        ),
        titleLarge: GoogleFonts.manrope(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.darkPrimaryText,
        ),
        titleMedium: GoogleFonts.manrope(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.darkPrimaryText,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.darkPrimaryText,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.darkPrimaryText,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.darkMutedText,
        ),
        labelLarge: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.white,
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkPrimaryText,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.darkPrimaryText,
        ),
        iconTheme: const IconThemeData(color: AppColors.darkPrimaryText),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkElevatedSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: AppRadius.roundedLg,
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.roundedLg,
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.roundedLg,
          borderSide: const BorderSide(color: AppColors.primaryBlueLight, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.roundedLg,
          borderSide: const BorderSide(color: AppColors.error),
        ),
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.darkMutedText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlueLight,
          foregroundColor: AppColors.white,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.roundedLg,
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: AppColors.primaryBlueLight,
        unselectedItemColor: AppColors.darkMutedText,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
