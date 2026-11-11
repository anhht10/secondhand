import 'package:flutter/material.dart';

/// ReMarket Design System Color Palette (Modern White & Royal Blue).
///
/// Aligned with Section 4.1 of `PROJECT_PLAN.md`:
/// - Pure White (`#FFFFFF`) & Soft Cool Surface (`#F8FAFC`)
/// - Royal Blue (`#2563EB`) & Deep Blue (`#1D4ED8`)
/// - Soft Blue Tint (`#EFF6FF` background / `#BFDBFE` & `#93C5FD` border)
/// - Text Hierarchy (`#0F172A`, `#475569`, `#64748B`)
abstract final class AppColors {
  // Brand Primary (Royal Blue)
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color primaryLight = Color(0xFF60A5FA);

  // Soft Blue Tints (AI Cards, Transparency Badges, Info Boxes)
  static const Color primaryTintBg = Color(0xFFEFF6FF);
  static const Color primaryTintBorder = Color(0xFFBFDBFE);
  static const Color primaryTintBorderStrong = Color(0xFF93C5FD);

  // Surfaces & Backgrounds
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFE2E8F0);

  // Text Hierarchy
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Semantic: Success / Verified
  static const Color success = Color(0xFF10B981);
  static const Color successBg = Color(0xFFECFDF5);
  static const Color successBorder = Color(0xFFA7F3D0);
  static const Color successText = Color(0xFF047857);

  // Semantic: Warning / Offline Mode
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningBg = Color(0xFFFFFBEB);
  static const Color warningBorder = Color(0xFFFCD34D);
  static const Color warningText = Color(0xFFB45309);

  // Semantic: Error / Danger / Safety Report
  static const Color error = Color(0xFFEF4444);
  static const Color errorBg = Color(0xFFFEF2F2);
  static const Color errorBorder = Color(0xFFFECACA);
  static const Color errorText = Color(0xFFB91C1C);

  // Semantic aliases used across feature screens
  static const Color primaryGreen = primary;
  static const Color errorRed = error;
  static const Color backgroundLight = background;
  static const Color surfaceWhite = surface;
  static const Color borderLight = border;
}
