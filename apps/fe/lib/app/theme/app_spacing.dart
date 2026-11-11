import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Spacing, Border Radius, and Elevation/Shadow tokens for ReMarket.
abstract final class AppSpacing {
  // Spacing scale (4pt grid)
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;

  // Screen padding
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: lg,
  );

  // Border Radius tokens
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusPill = 999.0;

  static const BorderRadius borderRadiusSm =
      BorderRadius.all(Radius.circular(radiusSm));
  static const BorderRadius borderRadiusMd =
      BorderRadius.all(Radius.circular(radiusMd));
  static const BorderRadius borderRadiusLg =
      BorderRadius.all(Radius.circular(radiusLg));
  static const BorderRadius borderRadiusXl =
      BorderRadius.all(Radius.circular(radiusXl));

  // Responsive max content width for tablets/web
  static const double maxAuthCardWidth = 440.0;
  static const double maxContentWidth = 960.0;

  // Soft shadows
  static const List<BoxShadow> cardShadow = <BoxShadow>[
    BoxShadow(
      color: Color(0x0A0F172A),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static final BoxDecoration aiTintBoxDecoration = BoxDecoration(
    color: AppColors.primaryTintBg,
    borderRadius: borderRadiusMd,
    border: Border.all(color: AppColors.primaryTintBorder),
  );
}
