import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../core/extensions/context_x.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_shimmer.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../data/models/credit_model.dart';
import 'credits_controller.dart';
import '../../core/theme/app_icons.dart';

/// Shell Wallet tab — Top-up plans + activity in one place.
class CreditsView extends GetView<CreditsController> {
  const CreditsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AdaptiveContainer(
        shell: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Obx(
              () => FadeSlideIn(
                child: _WalletBalanceCard(balance: controller.balance.value),
              ),
            ),
            const SizedBox(height: AppSpace.md),
            Obx(() {
              final index = controller.tabIndex.value;
              return _WalletTabs(
                index: index,
                onChanged: controller.setTab,
              );
            }),
            const SizedBox(height: AppSpace.sm),
            Expanded(
              child: Obx(() {
                return IndexedStack(
                  index: controller.tabIndex.value,
                  children: [
                    _TopUpTab(controller: controller),
                    _ActivityTab(controller: controller),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletTabs extends StatelessWidget {
  const _WalletTabs({
    required this.index,
    required this.onChanged,
  });

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final isDark = b == Brightness.dark;
    final accent = AppColors.accentOf(b);

    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: AppRadius.mdAll,
        color: isDark ? const Color(0xFF141518) : const Color(0xFFD8DEE6),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final thumbW = constraints.maxWidth / 2;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: index * thumbW,
                  top: 0,
                  bottom: 0,
                  width: thumbW,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      color: isDark
                          ? const Color(0xFF22262C)
                          : const Color(0xFFF7F8FA),
                      border: Border.all(
                        color: accent.withValues(alpha: isDark ? 0.35 : 0.28),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    _TabChip(
                      label: 'Top-up',
                      icon: AppIcons.credits,
                      selected: index == 0,
                      onTap: () => onChanged(0),
                    ),
                    _TabChip(
                      label: 'Activity',
                      icon: AppIcons.receipt,
                      selected: index == 1,
                      onTap: () => onChanged(1),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final accent = AppColors.accentOf(b);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: AppRadius.smAll,
          splashColor: accent.withValues(alpha: 0.1),
          highlightColor: Colors.transparent,
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                fontFamily: 'Figtree',
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.text(b) : AppColors.textMuted(b),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 17,
                    color: selected ? accent : AppColors.textMuted(b),
                  ),
                  const SizedBox(width: 6),
                  Text(label),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopUpTab extends StatelessWidget {
  const _TopUpTab({required this.controller});

  final CreditsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loading = controller.loading.value;
      final packages = controller.packages.toList();
      final err = controller.error.value;
      final bottom = context.responsive.contentBottom;

      return RefreshIndicator(
        onRefresh: () => controller.load(force: true),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (loading && packages.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(bottom: bottom),
                children: const [_PackagesSkeleton()],
              );
            }
            if (packages.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(bottom: bottom),
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (constraints.maxHeight - bottom)
                          .clamp(0, double.infinity),
                    ),
                    child: Center(
                      child: _EmptyPlans(
                        message: err,
                        onRetry: () => controller.load(force: true),
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(bottom: bottom),
              itemCount: packages.length,
              itemBuilder: (_, i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.sm),
                  child: FadeSlideIn(
                    index: i,
                    maxAnimated: 6,
                    child: _PackageCard(
                      package: packages[i],
                      featured: i == 1 || packages.length == 1,
                      purchasing: controller.purchasingSlug.value ==
                          packages[i].slug,
                      enabled: controller.purchasingSlug.value == null,
                      onBuy: () => controller.purchase(packages[i]),
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
    });
  }
}

class _ActivityTab extends StatelessWidget {
  const _ActivityTab({required this.controller});

  final CreditsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loading = controller.txLoading.value;
      final txs = controller.transactions.toList();
      final err = controller.txError.value;
      final bottom = context.responsive.contentBottom;

      return RefreshIndicator(
        onRefresh: () => controller.loadActivity(force: true),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (loading && txs.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(bottom: bottom),
                children: const [_PackagesSkeleton()],
              );
            }
            if (txs.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(bottom: bottom),
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (constraints.maxHeight - bottom)
                          .clamp(0, double.infinity),
                    ),
                    child: Center(
                      child: _EmptyActivity(
                        message: err,
                        onRetry: err != null
                            ? () => controller.loadActivity(force: true)
                            : null,
                        onTopUp: () => controller.setTab(0),
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(bottom: bottom),
              itemCount: txs.length,
              itemBuilder: (_, i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.sm),
                  child: FadeSlideIn(
                    index: i,
                    maxAnimated: 8,
                    child: _TxCard(tx: txs[i]),
                  ),
                );
              },
            );
          },
        ),
      );
    });
  }
}

class _WalletBalanceCard extends StatelessWidget {
  const _WalletBalanceCard({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final accent = AppColors.accentOf(b);
    final isDark = b == Brightness.dark;

    return AppCard(
      lite: true,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: AppRadius.lgAll,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            accent.withValues(alpha: 0.12),
                            const Color(0xFF101214),
                            const Color(0xFF08090B),
                          ]
                        : [
                            const Color(0xFFE8ECF2),
                            accent.withValues(alpha: 0.08),
                            const Color(0xFFD7DDE6),
                          ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -28,
              top: -36,
              child: IgnorePointer(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        accent.withValues(alpha: isDark ? 0.22 : 0.16),
                        accent.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.lg,
                AppSpace.lg,
                AppSpace.md,
                AppSpace.lg,
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.mdAll,
                      color: accent.withValues(alpha: isDark ? 0.18 : 0.14),
                      border: Border.all(color: accent.withValues(alpha: 0.35)),
                    ),
                    child: Icon(AppIcons.walletFill,
                        color: accent, size: 26),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Wallet balance',
                          style: context.texts.bodySmall?.copyWith(
                            color: AppColors.textSecondary(b),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$balance',
                          style: context.texts.headlineLarge?.copyWith(
                            color: AppColors.text(b),
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Top up anytime · track every credit',
                          style: context.texts.labelSmall?.copyWith(
                            color: AppColors.textMuted(b),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.package,
    required this.onBuy,
    required this.purchasing,
    required this.enabled,
    this.featured = false,
  });

  final CreditPackage package;
  final VoidCallback onBuy;
  final bool purchasing;
  final bool enabled;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final accent = AppColors.accentOf(b);
    final isDark = b == Brightness.dark;
    final perCredit = package.credits > 0
        ? package.priceCents / package.credits / 100
        : 0.0;

    return AppCard(
      lite: true,
      elevated: true,
      padding: const EdgeInsets.fromLTRB(
        AppSpace.lg,
        AppSpace.md,
        AppSpace.md,
        AppSpace.md,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: AppRadius.mdAll,
              color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
            ),
            child: Icon(AppIcons.credits, color: accent, size: 24),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        package.name,
                        style: context.texts.titleMedium?.copyWith(
                          color: AppColors.text(b),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (featured) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: accent.withValues(alpha: 0.16),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          'Popular',
                          style: context.texts.labelSmall?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${package.credits} credits',
                  style: context.texts.bodyMedium?.copyWith(
                    color: AppColors.textSecondary(b),
                  ),
                ),
                Text(
                  '\$${perCredit.toStringAsFixed(3)} / credit',
                  style: context.texts.labelSmall?.copyWith(
                    color: AppColors.textMuted(b),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.xs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                package.priceLabel,
                style: context.texts.titleMedium?.copyWith(
                  color: AppColors.text(b),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              AppButton(
                label: purchasing ? '…' : 'Buy',
                expand: false,
                loading: purchasing,
                onPressed: enabled && !purchasing ? onBuy : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TxCard extends StatelessWidget {
  const _TxCard({required this.tx});

  final CreditTransaction tx;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final accent = AppColors.accentOf(b);
    final isDark = b == Brightness.dark;
    final credit = tx.isCredit;
    final amount = tx.amount.abs();
    final when = tx.createdAt != null
        ? DateFormat.MMMd().add_jm().format(tx.createdAt!.toLocal())
        : '';
    final title = tx.reason?.isNotEmpty == true
        ? tx.reason!
        : (tx.toolSlug ?? tx.type);
    final tone = credit ? AppColors.success : accent;

    return AppCard(
      lite: true,
      elevated: true,
      padding: const EdgeInsets.fromLTRB(
        AppSpace.md,
        AppSpace.md,
        AppSpace.md,
        AppSpace.md,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: AppRadius.smAll,
              color: tone.withValues(alpha: isDark ? 0.18 : 0.12),
              border: Border.all(color: tone.withValues(alpha: 0.35)),
            ),
            child: Icon(
              credit ? AppIcons.add : AppIcons.remove,
              color: tone,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.titleSmall?.copyWith(
                    color: AppColors.text(b),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (when.isNotEmpty)
                  Text(
                    when,
                    style: context.texts.bodySmall?.copyWith(
                      color: AppColors.textSecondary(b),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${credit ? '+' : '−'}$amount',
            style: context.texts.titleMedium?.copyWith(
              color: credit ? AppColors.success : AppColors.text(b),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity({
    this.message,
    this.onRetry,
    required this.onTopUp,
  });

  final String? message;
  final Future<void> Function()? onRetry;
  final VoidCallback onTopUp;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final accent = AppColors.accentOf(b);
    final isDark = b == Brightness.dark;
    final isError = message != null && message!.trim().isNotEmpty;

    return SizedBox(
      width: double.infinity,
      child: AppCard(
        lite: true,
        elevated: true,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: AppSpace.xl,
        ),
        child: SizedBox(
          width: double.infinity,
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
                child: Icon(
                  isError
                      ? AppIcons.refresh
                      : AppIcons.receipt,
                  size: 26,
                  color: accent,
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                isError ? 'Couldn’t load activity' : 'No activity yet',
                textAlign: TextAlign.center,
                style: context.texts.titleMedium?.copyWith(
                  color: AppColors.text(b),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpace.xxs),
              Text(
                isError
                    ? message!
                    : 'Top-ups and generations will show up here once you start using credits.',
                textAlign: TextAlign.center,
                style: context.texts.bodyMedium?.copyWith(
                  color: AppColors.textSecondary(b),
                ),
              ),
              const SizedBox(height: AppSpace.md),
              if (isError && onRetry != null)
                AppButton(
                  label: 'Retry',
                  expand: false,
                  icon: AppIcons.refresh,
                  onPressed: () => onRetry!(),
                )
              else
                AppButton(
                  label: 'Browse top-up plans',
                  expand: false,
                  icon: AppIcons.credits,
                  onPressed: onTopUp,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPlans extends StatelessWidget {
  const _EmptyPlans({this.message, required this.onRetry});

  final String? message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final accent = AppColors.accentOf(b);
    final isDark = b == Brightness.dark;
    final isError = message != null && message!.trim().isNotEmpty;

    return SizedBox(
      width: double.infinity,
      child: AppCard(
        lite: true,
        elevated: true,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: AppSpace.xl,
        ),
        child: SizedBox(
          width: double.infinity,
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
                child: Icon(
                  isError ? AppIcons.offline : AppIcons.credits,
                  size: 26,
                  color: accent,
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                isError ? 'Couldn’t load plans' : 'No plans available',
                textAlign: TextAlign.center,
                style: context.texts.titleMedium?.copyWith(
                  color: AppColors.text(b),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpace.xxs),
              Text(
                isError
                    ? message!
                    : 'Pull to refresh, or try again in a moment.',
                textAlign: TextAlign.center,
                style: context.texts.bodyMedium?.copyWith(
                  color: AppColors.textSecondary(b),
                ),
              ),
              const SizedBox(height: AppSpace.md),
              AppButton(
                label: 'Retry',
                expand: false,
                icon: AppIcons.refresh,
                onPressed: () => onRetry(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PackagesSkeleton extends StatelessWidget {
  const _PackagesSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (_) => const Padding(
          padding: EdgeInsets.only(bottom: AppSpace.sm),
          child: AppShimmerBlock(height: 96, radius: AppRadius.lg),
        ),
      ),
    );
  }
}
