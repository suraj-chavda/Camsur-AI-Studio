import 'package:flutter/material.dart';

import '../extensions/context_x.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'app_button.dart';
import 'app_card.dart';
import 'app_shimmer.dart';
import '../../core/theme/app_icons.dart';

/// Home-aligned empty / error / loading surface used across studio tabs.
class StudioStateCard extends StatelessWidget {
  const StudioStateCard({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.onRetry,
    this.retryLabel = 'Retry',
    this.compact = false,
  });

  factory StudioStateCard.empty({
    Key? key,
    required String title,
    required String message,
    IconData icon = AppIcons.empty,
    VoidCallback? onRetry,
    String retryLabel = 'Retry',
  }) =>
      StudioStateCard(
        key: key,
        title: title,
        message: message,
        icon: icon,
        onRetry: onRetry,
        retryLabel: retryLabel,
      );

  factory StudioStateCard.error({
    Key? key,
    required String message,
    VoidCallback? onRetry,
    String title = 'Something went wrong',
  }) =>
      StudioStateCard(
        key: key,
        title: title,
        message: message,
        icon: AppIcons.offline,
        onRetry: onRetry,
      );

  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onRetry;
  final String retryLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final accent = AppColors.accentOf(b);
    final isDark = b == Brightness.dark;

    return SizedBox(
      width: double.infinity,
      child: AppCard(
        lite: true,
        elevated: true,
        padding: EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: compact ? AppSpace.lg : AppSpace.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: AppRadius.mdAll,
                color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
                border: Border.all(color: accent.withValues(alpha: 0.35)),
              ),
              child: Icon(icon, size: 26, color: accent),
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.texts.titleMedium?.copyWith(
                color: AppColors.text(b),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpace.xxs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.texts.bodyMedium?.copyWith(
                color: AppColors.textSecondary(b),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpace.md),
              AppButton(
                label: retryLabel,
                expand: false,
                icon: AppIcons.refresh,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Lightweight loading block matching home shimmer language.
class StudioLoadingBlock extends StatelessWidget {
  const StudioLoadingBlock({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpace.lg),
      child: Column(
        children: [
          AppShimmerBlock(height: 96, radius: AppRadius.lg),
          SizedBox(height: AppSpace.sm),
          AppShimmerBlock(height: 96, radius: AppRadius.lg),
          SizedBox(height: AppSpace.sm),
          AppShimmerBlock(height: 96, radius: AppRadius.lg),
        ],
      ),
    );
  }
}
