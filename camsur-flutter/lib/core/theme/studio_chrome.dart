import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

/// Quiet dark chrome for sticky header + bottom nav — matches app near-black.
abstract final class StudioChrome {
  static const darkPanel = Color(0xFF0C0C0C);
  static const darkPanelLift = Color(0xFF121212);
  static const lightPanel = Color(0xFFF2F2F5);
  static const lightPanelLift = Color(0xFFF8F8FA);

  /// Shared corner radius for header / nav soft edges.
  static const double barRadius = 28;

  /// Same crisp rim inset as [AppCard].
  static const double rimWidth = 1.1;

  static SystemUiOverlayStyle overlayFor(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: isDark ? darkPanel : lightPanel,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    );
  }

  static Color panelFaceTop(Brightness brightness) =>
      brightness == Brightness.dark ? darkPanelLift : lightPanelLift;

  static Color panelFaceBottom(Brightness brightness) =>
      brightness == Brightness.dark ? darkPanel : lightPanel;

  static Color borderColor(Brightness brightness) =>
      brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.12)
          : Colors.black.withValues(alpha: 0.08);

  /// Metallic rim for header/nav — vertical so left & right sides match
  /// (cardRim is diagonal and over-brightens the left).
  static LinearGradient barRim(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    if (isDark) {
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.32),
          AppColors.accentCoolSoft.withValues(alpha: 0.2),
          Colors.white.withValues(alpha: 0.14),
          Colors.white.withValues(alpha: 0.22),
        ],
        stops: const [0.0, 0.35, 0.7, 1.0],
      );
    }
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white.withValues(alpha: 0.85),
        AppColors.accentCool.withValues(alpha: 0.22),
        Colors.black.withValues(alpha: 0.08),
        Colors.white.withValues(alpha: 0.45),
      ],
      stops: const [0.0, 0.35, 0.7, 1.0],
    );
  }

  /// Face fill behind the rim inset.
  static BoxDecoration panelFace(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? const [darkPanelLift, darkPanel]
            : const [lightPanelLift, lightPanel],
      ),
    );
  }

  /// Soft depth under the header bottom edge — elegant, not heavy.
  static List<BoxShadow> headerShadow(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.38 : 0.08),
        blurRadius: 16,
        offset: const Offset(0, 8),
        spreadRadius: -4,
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
        blurRadius: 4,
        offset: const Offset(0, 2),
      ),
      // Subtle bottom-edge lift (specular, no blur).
      BoxShadow(
        color: Colors.white.withValues(alpha: isDark ? 0.07 : 0.4),
        blurRadius: 0,
        offset: const Offset(0, 0.7),
      ),
    ];
  }

  /// Soft depth above the nav top edge — mirrors the header.
  /// Prefer [PhysicalShape] elevation on the nav for notch-accurate shadows.
  static List<BoxShadow> navShadow(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.38 : 0.08),
        blurRadius: 16,
        offset: const Offset(0, -8),
        spreadRadius: -4,
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
        blurRadius: 4,
        offset: const Offset(0, -2),
      ),
    ];
  }

  /// Center shine on a horizontal rim (header bottom edge).
  static Widget centerEdgeShine(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colors = isDark
        ? [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0.7),
            AppColors.accentCoolSoft.withValues(alpha: 0.4),
            Colors.white.withValues(alpha: 0.7),
            Colors.white.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0),
          ]
        : [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.35),
            Colors.white.withValues(alpha: 0.95),
            AppColors.accentCool.withValues(alpha: 0.35),
            Colors.white.withValues(alpha: 0.95),
            Colors.white.withValues(alpha: 0.35),
            Colors.white.withValues(alpha: 0),
          ];

    return IgnorePointer(
      child: SizedBox(
        height: rimWidth,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: colors,
              stops: const [0.0, 0.2, 0.4, 0.5, 0.6, 0.8, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}
