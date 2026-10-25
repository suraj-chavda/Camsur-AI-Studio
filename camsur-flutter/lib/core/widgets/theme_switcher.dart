import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../extensions/context_x.dart';
import '../theme/app_colors.dart';
import '../theme/theme_controller.dart';
import 'app_card.dart';
import '../../core/theme/app_icons.dart';

/// Compact dark / light / system control.
class ThemeSwitcher extends StatelessWidget {
  const ThemeSwitcher({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Get.find<ThemeController>();

    return Obx(() {
      final mode = theme.mode.value;

      if (compact) {
        final b = Theme.of(context).brightness;
        final isDark = b == Brightness.dark;
        return Tooltip(
          message: 'Toggle theme',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                theme.toggleDarkLight();
              },
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isDark
                      ? const Color(0xFF181818)
                      : const Color(0xFFFFFFFF),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF2E2E2E)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                child: Icon(
                  theme.isDark
                      ? AppIcons.sun
                      : AppIcons.moon,
                  size: 20,
                  color: AppColors.text(b),
                ),
              ),
            ),
          ),
        );
      }

      return AppCardLike(
        child: Row(
          children: [
            _seg(
              context,
              icon: AppIcons.sun,
              label: 'Light',
              selected: mode == ThemeMode.light,
              onTap: () => theme.setMode(ThemeMode.light),
            ),
            _seg(
              context,
              icon: AppIcons.moon,
              label: 'Dark',
              selected: mode == ThemeMode.dark,
              onTap: () => theme.setMode(ThemeMode.dark),
            ),
            _seg(
              context,
              icon: AppIcons.themeAuto,
              label: 'Auto',
              selected: mode == ThemeMode.system,
              onTap: () => theme.setMode(ThemeMode.system),
            ),
          ],
        ),
      );
    });
  }

  Widget _seg(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final isDark = context.isDark;
    return Expanded(
      child: Material(
        color: selected
            ? (isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.06))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? (isDark ? Colors.white : Colors.black)
                      : context.colors.onSurface.withValues(alpha: 0.55),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: context.texts.labelMedium?.copyWith(
                    color: selected
                        ? (isDark ? Colors.white : Colors.black)
                        : null,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Thin noisy shell for the theme switcher.
class AppCardLike extends StatelessWidget {
  const AppCardLike({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(4),
      radius: 16,
      child: child,
    );
  }
}
