import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF0F9D75);
  static const Color primaryDark = Color(0xFF0A7A5B);
  static const Color secondary = Color(0xFF2DBE8E);
  static const Color primarySoft = Color(0xFFDDF4EA);
  static const Color primaryFaint = Color(0xFFF1FAF6);

  // Surfaces
  static const Color background = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFF7F8F9);
  static const Color cardAlt = Color(0xFFEFF1F3);
  static const Color border = Color(0xFFE9ECEF);
  static const Color white = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF5B6678);
  static const Color textTertiary = Color(0xFF94A3B8);

  // Status
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerSoft = Color(0xFFFEE2E2);
  static const Color warning = Color(0xFFD97706);
  static const Color warningSoft = Color(0xFFFEF3C7);

  // Dark accents
  static const Color ink = Color(0xFF0B1F18);
  static const Color inkSoft = Color(0xFF14463A);

  static const LinearGradient hero = LinearGradient(
    colors: <Color>[Color(0xFF0B1F18), Color(0xFF0F7A5C), Color(0xFF1DB98A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const List<BoxShadow> softShadow = <BoxShadow>[];
  static const Color overlay = Color(0x99000000);
}
