import 'package:flutter/material.dart';

class AppShadows {
  AppShadows._();

  static const List<BoxShadow> subtle = [
    BoxShadow(
      color: Color(0x0A0F172A),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0F0F172A),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> elevated = [
    BoxShadow(
      color: Color(0x1A0F172A),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> primaryButton = [
    BoxShadow(
      color: Color(0x40075FEA),
      blurRadius: 14,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> callGlow = [
    BoxShadow(
      color: Color(0x6600CFF3),
      blurRadius: 24,
      spreadRadius: 2,
    ),
  ];
}
