import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../../core/theme/app_icons.dart';

class CreditChip extends StatelessWidget {
  const CreditChip({super.key, required this.balance, this.onTap});

  final int balance;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final isDark = b == Brightness.dark;
    final accent = AppColors.accentOf(b);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap?.call();
        },
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSize.touch),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              color: isDark
                  ? const Color(0xFF181818)
                  : const Color(0xFFFFFFFF),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF2E2E2E)
                    : Colors.black.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.credits, size: 16, color: accent),
                const SizedBox(width: 6),
                Text(
                  '$balance',
                  style: TextStyle(
                    fontFamily: 'Figtree',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.text(b),
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
