import 'package:flutter/material.dart';

/// Soft layered elevation — cards & controls lift cleanly without muddy blobs.
class AppElevation {
  AppElevation._();

  static List<BoxShadow> surface({
    required bool isDark,
    bool pressed = false,
    bool focused = false,
    bool lite = false,
  }) {
    if (pressed) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
          blurRadius: 10,
          offset: const Offset(0, 4),
          spreadRadius: -2,
        ),
      ];
    }

    if (lite) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.1),
          blurRadius: isDark ? 22 : 18,
          offset: const Offset(0, 10),
          spreadRadius: -6,
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.55),
          blurRadius: 0,
          offset: const Offset(0, -0.6),
        ),
      ];
    }

    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.62 : 0.12),
        blurRadius: isDark ? 32 : 26,
        offset: const Offset(0, 16),
        spreadRadius: -8,
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
        blurRadius: 12,
        offset: const Offset(0, 6),
        spreadRadius: -2,
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.05),
        blurRadius: 3,
        offset: const Offset(0, 1),
      ),
      BoxShadow(
        color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.75),
        blurRadius: 0,
        offset: const Offset(0, -0.8),
      ),
      if (focused)
        BoxShadow(
          color: (isDark ? Colors.white : Colors.black)
              .withValues(alpha: isDark ? 0.12 : 0.08),
          blurRadius: 18,
        ),
    ];
  }

  /// Steel-tinted glow under primary CTAs.
  static List<BoxShadow> cta({
    required bool isDark,
    bool pressed = false,
  }) {
    if (pressed) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.16),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ];
    }
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
        blurRadius: 20,
        offset: const Offset(0, 10),
        spreadRadius: -4,
      ),
      BoxShadow(
        color: (isDark ? const Color(0xFF9AABBF) : const Color(0xFF7A8FA8))
            .withValues(alpha: isDark ? 0.18 : 0.14),
        blurRadius: 16,
        offset: const Offset(0, 6),
        spreadRadius: -4,
      ),
    ];
  }
}
