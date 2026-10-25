import 'package:flutter/material.dart';

import '../extensions/context_x.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final accent = AppColors.accentOf(b);

    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          margin: const EdgeInsets.only(right: AppSpace.xs),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                accent.withValues(alpha: 0.9),
                accent.withValues(alpha: 0.35),
              ],
            ),
          ),
        ),
        Expanded(
          child: Text(
            title,
            style: context.texts.titleMedium?.copyWith(
              color: AppColors.text(b),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.xs,
                vertical: AppSpace.xs,
              ),
              minimumSize: const Size(AppSize.touch, AppSize.touch),
              foregroundColor: accent,
            ),
            child: Text(
              actionLabel!,
              style: context.texts.labelLarge?.copyWith(
                color: accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
