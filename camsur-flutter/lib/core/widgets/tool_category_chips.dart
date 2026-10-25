import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../utils/tool_icons.dart';
import '../../data/models/tool_model.dart';
import '../theme/app_icons.dart';

/// Horizontal category filter — single selection, includes "All".
/// Keeps browse to one tools list (no stacked sections / duplicates).
class ToolCategoryChips extends StatelessWidget {
  const ToolCategoryChips({
    super.key,
    required this.categories,
    required this.selectedSlug,
    required this.onSelect,
    this.padding,
  });

  final List<ToolCategoryModel> categories;
  final String? selectedSlug; // null = All
  final ValueChanged<String?> onSelect;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    final b = Theme.of(context).brightness;
    final chips = <({String? slug, String label, IconData icon})>[
      (slug: null, label: 'All', icon: AppIcons.tools),
      for (final c in categories)
        (
          slug: c.slug,
          label: c.name,
          icon: categoryIconFor(icon: c.icon, slug: c.slug),
        ),
    ];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding ?? EdgeInsets.zero,
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final chip = chips[i];
          final selected = chip.slug == selectedSlug;
          return _CategoryChip(
            label: chip.label,
            icon: chip.icon,
            selected: selected,
            brightness: b,
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(chip.slug);
            },
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.brightness,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Brightness brightness;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = brightness == Brightness.dark;
    final accent = AppColors.accentOf(brightness);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.pillAll,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
          decoration: BoxDecoration(
            borderRadius: AppRadius.pillAll,
            color: selected
                ? accent.withValues(alpha: isDark ? 0.16 : 0.1)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.03)),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: isDark ? 0.5 : 0.4)
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06)),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: isDark ? 0.18 : 0.14),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? accent
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.05)),
                ),
                child: Icon(
                  icon,
                  size: 15,
                  color: selected
                      ? Colors.white
                      : AppColors.textMuted(brightness),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Figtree',
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? AppColors.text(brightness)
                      : AppColors.textMuted(brightness),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
