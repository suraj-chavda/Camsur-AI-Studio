import 'package:flutter/material.dart';

/// Cool black + steel gray. Light mode is airier; accent is used for focus.
class AppColors {
  AppColors._();

  /// Steel accent — credits, focus rings, subtle highlights (not purple).
  static const accentCool = Color(0xFF7A8FA8);
  static const accentCoolSoft = Color(0xFF9AABBF);
  static const gradientStart = Color(0xFF2E2E32);
  static const gradientEnd = Color(0xFF101012);

  // Dark
  static const darkBg = Color(0xFF080808);
  static const darkBgMid = Color(0xFF0C0C0C);
  static const darkBgDeep = Color(0xFF050505);
  static const darkGlow = Color(0xFF161616);
  static const darkGlowAccent = Color(0xFF1C1C1C);
  static const darkSurface = Color(0xFF181818);
  static const darkSurfaceHigh = Color(0xFF222222);
  static const darkBorder = Color(0xFF333333);
  static const darkText = Color(0xFFF7F7F8);
  static const darkTextSecondary = Color(0xFFD0D0D4);
  static const darkTextMuted = Color(0xFFA3A3AA);
  static const darkInk = Color(0xFFEDEDED);
  static const darkOnInk = Color(0xFF111111);

  // Light — cooler lift so ink stays sharp without muddy wash
  static const lightBg = Color(0xFFE6E6EB);
  static const lightBgMid = Color(0xFFEDEDF1);
  static const lightBgDeep = Color(0xFFDBDBE2);
  static const lightGlow = Color(0xFFF2F2F5);
  static const lightGlowAccent = Color(0xFFD8DCE6);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceHigh = Color(0xFFF5F5F8);
  static const lightBorder = Color(0xFFC2C2CC);
  static const lightText = Color(0xFF0A0A0A);
  static const lightTextSecondary = Color(0xFF2A2A2A);
  static const lightTextMuted = Color(0xFF52525B);
  static const lightInk = Color(0xFF0A0A0A);
  static const lightOnInk = Color(0xFFFAFAFA);

  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFD97706);
  static const error = Color(0xFFDC2626);
  static const info = Color(0xFF64748B);

  static const primary = darkInk;
  static const primaryDark = lightInk;
  static const primaryLight = darkInk;
  static const accent = accentCool;

  static Color ink(Brightness b) =>
      b == Brightness.dark ? darkInk : lightInk;

  static Color onInk(Brightness b) =>
      b == Brightness.dark ? darkOnInk : lightOnInk;

  static Color text(Brightness b) =>
      b == Brightness.dark ? darkText : lightText;

  static Color textSecondary(Brightness b) =>
      b == Brightness.dark ? darkTextSecondary : lightTextSecondary;

  static Color textMuted(Brightness b) =>
      b == Brightness.dark ? darkTextMuted : lightTextMuted;

  static Color surface(Brightness b) =>
      b == Brightness.dark ? darkSurface : lightSurface;

  static Color border(Brightness b) =>
      b == Brightness.dark ? darkBorder : lightBorder;

  static Color accentOf(Brightness b) =>
      b == Brightness.dark ? accentCoolSoft : accentCool;

  /// Primary CTA fill: bright steel on dark, ink on light.
  static LinearGradient ctaGradient(Brightness b) {
    if (b == Brightness.dark) {
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF7F8FA), Color(0xFFD4DCE6)],
      );
    }
    return const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF2A3038), Color(0xFF12151A)],
    );
  }

  static Color ctaForeground(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF0C0E12) : const Color(0xFFF6F7F9);

  static Color ctaBorder(Brightness b) => b == Brightness.dark
      ? const Color(0x66FFFFFF)
      : const Color(0x33000000);

  /// Primary CTA — graphite with a cool steel edge (banners, fallbacks).
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2C3038), Color(0xFF141418), Color(0xFF0C0C0E)],
    stops: [0.0, 0.55, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardSheenDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF17191D), Color(0xFF101214), Color(0xFF0A0B0D)],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient cardSheenLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF2F4F7), Color(0xFFE8ECF1), Color(0xFFDDE3EA)],
    stops: [0.0, 0.55, 1.0],
  );

  /// Metallic rim used as a 1px gradient border around cards/buttons.
  static LinearGradient cardRim(Brightness b) {
    if (b == Brightness.dark) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.34),
          accentCoolSoft.withValues(alpha: 0.22),
          Colors.white.withValues(alpha: 0.06),
          Colors.black.withValues(alpha: 0.55),
        ],
        stops: const [0.0, 0.28, 0.62, 1.0],
      );
    }
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(alpha: 0.95),
        accentCool.withValues(alpha: 0.28),
        Colors.black.withValues(alpha: 0.08),
        Colors.black.withValues(alpha: 0.16),
      ],
      stops: const [0.0, 0.3, 0.7, 1.0],
    );
  }

  /// Bright chrome rim — camera FAB + premium edges (no black ring).
  static LinearGradient chromeRim(Brightness b) {
    if (b == Brightness.dark) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFF0F3F7),
          Color(0xFFB8C0CC),
          Color(0xFFE8ECF2),
          Color(0xFFFFFFFF),
        ],
        stops: [0.0, 0.22, 0.5, 0.78, 1.0],
      );
    }
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFFFFFFF),
        Color(0xFFF7F8FA),
        Color(0xFFC5CCD6),
        Color(0xFFFFFFFF),
      ],
      stops: [0.0, 0.3, 0.65, 1.0],
    );
  }

  static LinearGradient buttonRim(Brightness b) {
    // Same chrome family as the camera — bright white, not a black ring.
    return chromeRim(b);
  }

  static BoxDecoration pageDecoration(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? const [
                Color(0xFF08090B),
                Color(0xFF040506),
                Color(0xFF020203),
              ]
            : const [
                Color(0xFFF4F6F9),
                Color(0xFFE8ECF2),
                Color(0xFFDCE2EA),
              ],
        stops: const [0.0, 0.5, 1.0],
      ),
    );
  }
}
