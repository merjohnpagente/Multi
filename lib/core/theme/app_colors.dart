import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF0F9D75);
  static const Color primaryDark = Color(0xFF047857);
  static const Color secondary = Color(0xFF10B981);
  static const Color primarySoft = Color(0xFFD1FAE5);
  static const Color primaryFaint = Color(0xFFEAF8F2);
  static const Color background = Color(0xFFF4F7F5);
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardAlt = Color(0xFFEBF1EE);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color border = Color(0xFFE2E9E5);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerSoft = Color(0xFFFEE2E2);
  static const Color warning = Color(0xFFD97706);
  static const Color warningSoft = Color(0xFFFEF3C7);
  static const Color white = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF0C241C);
  static const Color inkSoft = Color(0xFF14463A);
  static const LinearGradient hero = LinearGradient(
    colors: <Color>[Color(0xFF0C241C), Color(0xFF0F7A5C), Color(0xFF1DB98A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const List<BoxShadow> softShadow = <BoxShadow>[
    BoxShadow(color: Color(0x120C241C), blurRadius: 22, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x080C241C), blurRadius: 4, offset: Offset(0, 1)),
  ];
  static const Color overlay = Color(0x99000000);
}
