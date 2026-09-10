import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// ConnectCall Typography Hierarchy using Manrope (Primary) & Inter (Secondary)
class AppTextStyles {
  AppTextStyles._();

  // Display (32 / 700)
  static TextStyle display({Color color = AppColors.primaryText}) =>
      GoogleFonts.manrope(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.5,
      );

  // H1 (28 / 700)
  static TextStyle h1({Color color = AppColors.primaryText}) =>
      GoogleFonts.manrope(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.4,
      );

  // H2 (24 / 700)
  static TextStyle h2({Color color = AppColors.primaryText}) =>
      GoogleFonts.manrope(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.3,
      );

  // H3 (20 / 600)
  static TextStyle h3({Color color = AppColors.primaryText}) =>
      GoogleFonts.manrope(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: -0.2,
      );

  // Title (18 / 600)
  static TextStyle title({Color color = AppColors.primaryText}) =>
      GoogleFonts.manrope(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: color,
      );

  // Body (14 / 400)
  static TextStyle body({Color color = AppColors.primaryText}) =>
      GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.45,
      );

  // Body Medium (14 / 500)
  static TextStyle bodyMedium({Color color = AppColors.primaryText}) =>
      GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: color,
        height: 1.45,
      );

  // Caption (12 / 400)
  static TextStyle caption({Color color = AppColors.secondaryText}) =>
      GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: color,
      );

  // Button (14 / 600)
  static TextStyle button({Color color = AppColors.white}) =>
      GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0.2,
      );

  // Call Duration (28 / 600)
  static TextStyle callDuration({Color color = AppColors.white}) =>
      GoogleFonts.manrope(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 1.0,
      );
}
