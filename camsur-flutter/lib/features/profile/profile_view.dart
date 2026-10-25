import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/extensions/context_x.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../core/widgets/section_header.dart';
import 'profile_controller.dart';
import '../../core/theme/app_icons.dart';

class ProfileView extends GetView<ProfileController> {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AdaptiveContainer(
        shell: true,
        child: ListView(
          padding: EdgeInsets.only(bottom: context.responsive.contentBottom),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            FadeSlideIn(child: _AccountHero(controller: controller)),
            const SizedBox(height: AppSpace.section),
            const SectionHeader(title: 'Appearance'),
            const SizedBox(height: AppSpace.listGap),
            const FadeSlideIn(index: 1, child: _AppearanceCard()),
            const SizedBox(height: AppSpace.section),
            const SectionHeader(title: 'Preferences'),
            const SizedBox(height: AppSpace.listGap),
            FadeSlideIn(
              index: 2,
              child: _PrefGroup(
                children: [
                  _PrefRow(
                    icon: AppIcons.bell,
                    title: 'Notifications',
                    subtitle: 'Generation and credit alerts',
                    onTap: () => Get.snackbar(
                      'Coming soon',
                      'Notification preferences will land next.',
                      snackPosition: SnackPosition.BOTTOM,
                    ),
                  ),
                  _PrefRow(
                    icon: AppIcons.language,
                    title: 'App language',
                    subtitle: 'English',
                    onTap: () => Get.snackbar(
                      'Coming soon',
                      'More languages are on the way.',
                      snackPosition: SnackPosition.BOTTOM,
                    ),
                  ),
                  _PrefRow(
                    icon: AppIcons.lock,
                    title: 'Security',
                    subtitle: 'Password & sessions',
                    onTap: () => Get.snackbar(
                      'Coming soon',
                      'Security controls will land next.',
                      snackPosition: SnackPosition.BOTTOM,
                    ),
                    showDivider: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.section),
            const SectionHeader(title: 'More'),
            const SizedBox(height: AppSpace.listGap),
            FadeSlideIn(
              index: 3,
              child: _PrefGroup(
                children: [
                  _PrefRow(
                    icon: AppIcons.help,
                    title: 'Help & Support',
                    subtitle: 'Guides and contact',
                    onTap: () => Get.toNamed(AppRoutes.support),
                  ),
                  _PrefRow(
                    icon: AppIcons.gift,
                    title: 'Refer & Earn',
                    subtitle: 'Invite friends for credits',
                    onTap: () => Get.snackbar(
                      'Coming soon',
                      'Referral rewards are next.',
                      snackPosition: SnackPosition.BOTTOM,
                    ),
                  ),
                  _PrefRow(
                    icon: AppIcons.logout,
                    title: 'Log out',
                    subtitle: 'Sign out of this device',
                    danger: true,
                    onTap: controller.logout,
                    showDivider: false,
                  ),
                ],
              ),
            ),
            SizedBox(height: AppSpace.section),
          ],
        ),
      ),
    );
  }
}

class _AccountHero extends StatelessWidget {
  const _AccountHero({required this.controller});

  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final b = Theme.of(context).brightness;
      final accent = AppColors.accentOf(b);
      final isDark = b == Brightness.dark;
      final u = controller.user.value;
      final name = u?.displayName ?? u?.greetingName ?? 'Account';
      final email = u?.email ?? '';
      final initial = (u?.greetingName ?? 'G')[0].toUpperCase();

      return AppCard(
        lite: true,
        elevated: true,
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg - 1),
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
                              accent.withValues(alpha: 0.18),
                              const Color(0xFF16181C),
                              const Color(0xFF0C0D10),
                            ]
                          : [
                              Colors.white,
                              accent.withValues(alpha: 0.1),
                              const Color(0xFFEEF1F5),
                            ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -36,
                top: -48,
                child: IgnorePointer(
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          accent.withValues(alpha: isDark ? 0.28 : 0.18),
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
                  AppSpace.xl,
                  AppSpace.md,
                  AppSpace.xl,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: AppRadius.mdAll,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            accent.withValues(alpha: isDark ? 0.28 : 0.2),
                            accent.withValues(alpha: isDark ? 0.1 : 0.08),
                          ],
                        ),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.45),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.18),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Text(
                        initial,
                        style: context.texts.headlineSmall?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: context.texts.titleLarge?.copyWith(
                              color: AppColors.text(b),
                              fontWeight: FontWeight.w600,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: AppSpace.xxs),
                          Text(
                            email.isEmpty ? 'Signed in' : email,
                            style: context.texts.bodySmall?.copyWith(
                              color: AppColors.textSecondary(b),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Manage account & studio preferences',
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
    });
  }
}

class _AppearanceCard extends StatelessWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final theme = Get.find<ThemeController>();

    return AppCard(
      lite: true,
      elevated: true,
      padding: const EdgeInsets.all(AppSpace.sm),
      child: Obx(() {
        final mode = theme.mode.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.xs,
                AppSpace.xxs,
                AppSpace.xs,
                AppSpace.sm,
              ),
              child: Text(
                'Theme',
                style: context.texts.titleSmall?.copyWith(
                  color: AppColors.text(b),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Row(
              children: [
                _ThemeSeg(
                  icon: AppIcons.sun,
                  label: 'Light',
                  selected: mode == ThemeMode.light,
                  onTap: () => theme.setMode(ThemeMode.light),
                ),
                const SizedBox(width: AppSpace.xs),
                _ThemeSeg(
                  icon: AppIcons.moon,
                  label: 'Dark',
                  selected: mode == ThemeMode.dark,
                  onTap: () => theme.setMode(ThemeMode.dark),
                ),
                const SizedBox(width: AppSpace.xs),
                _ThemeSeg(
                  icon: AppIcons.themeAuto,
                  label: 'Auto',
                  selected: mode == ThemeMode.system,
                  onTap: () => theme.setMode(ThemeMode.system),
                ),
              ],
            ),
          ],
        );
      }),
    );
  }
}

class _ThemeSeg extends StatelessWidget {
  const _ThemeSeg({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final accent = AppColors.accentOf(b);
    final isDark = b == Brightness.dark;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: AppRadius.smAll,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: AppRadius.smAll,
              gradient: selected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accent.withValues(alpha: isDark ? 0.28 : 0.2),
                        accent.withValues(alpha: isDark ? 0.12 : 0.08),
                      ],
                    )
                  : null,
              color: selected
                  ? null
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.035)
                      : Colors.black.withValues(alpha: 0.03)),
              border: Border.all(
                width: selected ? 1.2 : 1,
                color: selected
                    ? accent.withValues(alpha: 0.55)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.07)),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: isDark ? 0.2 : 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? accent : AppColors.textMuted(b),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: context.texts.labelMedium?.copyWith(
                    color: selected ? AppColors.text(b) : AppColors.textMuted(b),
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

class _PrefGroup extends StatelessWidget {
  const _PrefGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      lite: true,
      elevated: true,
      padding: EdgeInsets.zero,
      child: Column(children: children),
    );
  }
}

class _PrefRow extends StatelessWidget {
  const _PrefRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final accent = AppColors.accentOf(b);
    final isDark = b == Brightness.dark;
    final tone = danger ? AppColors.error : accent;
    final divider = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.06);

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.md,
                AppSpace.md,
                AppSpace.sm,
                AppSpace.md,
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.smAll,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          tone.withValues(alpha: isDark ? 0.22 : 0.14),
                          tone.withValues(alpha: isDark ? 0.08 : 0.05),
                        ],
                      ),
                      border: Border.all(
                        color: tone.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(icon, color: tone, size: 22),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: context.texts.titleSmall?.copyWith(
                            color:
                                danger ? AppColors.error : AppColors.text(b),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: context.texts.bodySmall?.copyWith(
                            color: AppColors.textSecondary(b),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    AppIcons.chevronRight,
                    color: AppColors.textMuted(b),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 72),
            child: Divider(height: 1, thickness: 1, color: divider),
          ),
      ],
    );
  }
}
