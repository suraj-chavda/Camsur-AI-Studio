import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Outfit + Figtree, bundled as assets (no runtime font download).
class AppTypography {
  AppTypography._();

  static TextTheme textTheme(Brightness brightness) {
    final primary = AppColors.text(brightness);
    final secondary = AppColors.textSecondary(brightness);
    final muted = AppColors.textMuted(brightness);

    final geometry = brightness == Brightness.dark
        ? Typography.whiteMountainView
        : Typography.blackMountainView;

    TextStyle d({
      required double size,
      required FontWeight w,
      double? ls,
      double h = 1.25,
    }) {
      return geometry.bodyLarge!.copyWith(
        fontFamily: 'Outfit',
        fontSize: size,
        fontWeight: w,
        letterSpacing: ls,
        height: h,
        color: primary,
        decoration: TextDecoration.none,
      );
    }

    TextStyle b({
      required double size,
      required FontWeight w,
      required Color color,
      double h = 1.5,
    }) {
      return geometry.bodyLarge!.copyWith(
        fontFamily: 'Figtree',
        fontSize: size,
        fontWeight: w,
        height: h,
        color: color,
        decoration: TextDecoration.none,
      );
    }

    return TextTheme(
      displayLarge: d(size: 36, w: FontWeight.w600, ls: -1.0, h: 1.15),
      displayMedium: d(size: 30, w: FontWeight.w600, ls: -0.6, h: 1.2),
      displaySmall: d(size: 26, w: FontWeight.w600, ls: -0.4, h: 1.22),
      headlineLarge: d(size: 24, w: FontWeight.w600, ls: -0.3, h: 1.25),
      headlineMedium: d(size: 20, w: FontWeight.w600, ls: -0.2, h: 1.3),
      headlineSmall: d(size: 18, w: FontWeight.w600, ls: -0.1, h: 1.3),
      titleLarge: d(size: 17, w: FontWeight.w600, h: 1.3),
      titleMedium: d(size: 15, w: FontWeight.w600, h: 1.35),
      titleSmall: d(size: 14, w: FontWeight.w600, h: 1.35),
      bodyLarge: b(size: 16, w: FontWeight.w400, color: secondary),
      bodyMedium: b(size: 14, w: FontWeight.w400, color: secondary),
      bodySmall: b(size: 12.5, w: FontWeight.w400, color: muted, h: 1.45),
      labelLarge: b(size: 14, w: FontWeight.w600, color: primary),
      labelMedium: b(size: 12, w: FontWeight.w600, color: primary),
      labelSmall: b(size: 11, w: FontWeight.w500, color: muted, h: 1.4),
    );
  }
}
