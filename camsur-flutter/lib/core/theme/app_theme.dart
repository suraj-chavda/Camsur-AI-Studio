import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_tokens.dart';
import 'app_typography.dart';
import 'studio_chrome.dart';

/// Builds Material themes. Change tokens in [AppColors] / [AppTypography] / [AppSpace].
class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final surface = AppColors.surface(brightness);
    final surfaceHigh =
        isDark ? AppColors.darkSurfaceHigh : AppColors.lightSurfaceHigh;
    final border = AppColors.border(brightness);
    final text = AppColors.text(brightness);
    final textSecondary = AppColors.textSecondary(brightness);
    final ink = AppColors.ink(brightness);
    final onInk = AppColors.onInk(brightness);
    final accent = AppColors.accentOf(brightness);
    final navBg = isDark
        ? const Color(0xF50A0A0A)
        : const Color(0xF5F5F5F8);

    final scheme = ColorScheme(
      brightness: brightness,
      primary: isDark ? const Color(0xFFE8EDF3) : ink,
      onPrimary: isDark ? const Color(0xFF0C0E12) : onInk,
      secondary: accent,
      onSecondary: isDark ? const Color(0xFF0C0E12) : AppColors.lightOnInk,
      error: AppColors.error,
      onError: Colors.white,
      surface: surface,
      onSurface: text,
      onSurfaceVariant: textSecondary,
      surfaceContainerHighest: surfaceHigh,
      outline: border,
      tertiary: accent,
      onTertiary: onInk,
    );

    final texts = AppTypography.textTheme(brightness).apply(
      bodyColor: textSecondary,
      displayColor: text,
      decoration: TextDecoration.none,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
      textTheme: texts,
      primaryTextTheme: texts,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: text,
        centerTitle: false,
        systemOverlayStyle: StudioChrome.overlayFor(brightness),
        titleTextStyle: texts.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: BorderSide(color: border.withValues(alpha: 0.55)),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh.withValues(alpha: isDark ? 0.85 : 0.95),
        contentPadding: AppSpace.field,
        border: OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: BorderSide(color: border.withValues(alpha: 0.8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        hintStyle: TextStyle(color: AppColors.textMuted(brightness)),
        labelStyle: TextStyle(color: textSecondary),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? const Color(0xFFE8EDF3) : ink,
          foregroundColor: AppColors.ctaForeground(brightness),
          elevation: 0,
          minimumSize: const Size.fromHeight(AppSize.buttonH),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          textStyle: texts.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          minimumSize: const Size.fromHeight(AppSize.buttonH),
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.2)
                : border.withValues(alpha: 0.8),
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          minimumSize: const Size(AppSize.touch, AppSize.touch),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xsAll),
        side: BorderSide(color: border.withValues(alpha: 0.6)),
        labelStyle: texts.labelMedium,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.xs,
          vertical: AppSpace.xxs,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) {
          return s.contains(WidgetState.selected) ? onInk : textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((s) {
          return s.contains(WidgetState.selected) ? ink : border;
        }),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navBg,
        elevation: 0,
        height: AppSize.navH,
        indicatorColor: accent.withValues(alpha: isDark ? 0.18 : 0.16),
        labelTextStyle: WidgetStateProperty.resolveWith((s) {
          final selected = s.contains(WidgetState.selected);
          return texts.labelSmall?.copyWith(
            color: selected ? text : textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((s) {
          final selected = s.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? text : textSecondary,
            size: AppSize.iconMd,
          );
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: navBg,
        selectedItemColor: text,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: navBg,
        selectedIconTheme: IconThemeData(color: text),
        unselectedIconTheme: IconThemeData(color: textSecondary),
        selectedLabelTextStyle: texts.labelMedium?.copyWith(
          color: text,
          fontWeight: FontWeight.w600,
        ),
        indicatorColor: accent.withValues(alpha: isDark ? 0.18 : 0.16),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceHigh,
        contentTextStyle: TextStyle(color: text),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: isDark ? AppColors.accentCoolSoft : AppColors.accentCool,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: isDark ? const Color(0xFFF4F6F8) : ink,
        foregroundColor: isDark ? const Color(0xFF0C0E12) : onInk,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: textSecondary,
        textColor: text,
        minVerticalPadding: AppSpace.xs,
      ),
    );
  }
}
