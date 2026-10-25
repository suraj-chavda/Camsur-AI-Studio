import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_constants.dart';
import '../../core/extensions/context_x.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/studio_chrome.dart';
import '../../core/widgets/credit_chip.dart';
import '../../core/widgets/noise_overlay.dart';
import '../../core/widgets/theme_switcher.dart';
import '../credits/credits_controller.dart';
import '../home/home_controller.dart';
import 'shell_binding.dart';
import 'shell_controller.dart';

/// Shared sticky header — same outer rim + shadow language as [AppCard].
class StudioTopBar extends StatelessWidget {
  const StudioTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final b = Theme.of(context).brightness;
    final top = MediaQuery.paddingOf(context).top;
    final radius = BorderRadius.vertical(
      bottom: Radius.circular(StudioChrome.barRadius),
    );
    final rim = StudioChrome.rimWidth;
    final innerRadius = BorderRadius.vertical(
      bottom: Radius.circular(
        (StudioChrome.barRadius - rim).clamp(0, StudioChrome.barRadius),
      ),
    );

    // Mirror AppCard: shadow → gradient rim → inset face + center shine on bottom.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: StudioChrome.headerShadow(b),
      ),
      child: Stack(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: StudioChrome.barRim(b),
            ),
            // Outer borders: left + right + bottom (no top vs status bar).
            child: Padding(
              padding: EdgeInsets.fromLTRB(rim, 0, rim, rim),
              child: ClipRRect(
                borderRadius: innerRadius,
                child: DecoratedBox(
                  decoration: StudioChrome.panelFace(b),
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: NoiseOverlay(
                          opacity: NoiseOverlay.defaultOpacity,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          r.pagePadding,
                          top + AppSpace.sm,
                          r.pagePadding,
                          AppSpace.sm,
                        ),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: AppConstants.maxContentWidth,
                            ),
                            child: Obx(() {
                              final shell = Get.find<ShellController>();
                              final index = shell.index.value;
                              final copy = _copyFor(index);
                              final bal = _balance();

                              return Row(
                                children: [
                                  if (index == 0) ...[
                                    _Logo(brightness: b),
                                    const SizedBox(width: AppSpace.sm),
                                  ],
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          copy.$1,
                                          style: context.texts.titleLarge
                                              ?.copyWith(
                                                color: AppColors.text(b),
                                                fontWeight: FontWeight.w600,
                                                height: 1.15,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          copy.$2,
                                          style: context.texts.bodySmall
                                              ?.copyWith(
                                                color: AppColors.textSecondary(
                                                  b,
                                                ),
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const ThemeSwitcher(compact: true),
                                  const SizedBox(width: 8),
                                  CreditChip(
                                    balance: bal,
                                    onTap: () {
                                      ensureShellTab(2);
                                      Get.find<ShellController>().setIndex(2);
                                    },
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Shine peaking at the center of the bottom border.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: StudioChrome.centerEdgeShine(b),
          ),
        ],
      ),
    );
  }

  (String, String) _copyFor(int index) {
    switch (index) {
      case 1:
        return ('History', 'Your recent creations');
      case 2:
        return ('Wallet', 'Top-ups & activity');
      case 3:
        return ('Profile', 'Account & preferences');
      default:
        final name = Get.isRegistered<HomeController>()
            ? (Get.find<HomeController>().user.value?.greetingName ?? 'Creator')
            : 'Creator';
        return ('Hello, $name', 'Ready when you are');
    }
  }

  int _balance() {
    if (Get.isRegistered<HomeController>()) {
      return Get.find<HomeController>().balance.value;
    }
    if (Get.isRegistered<CreditsController>()) {
      return Get.find<CreditsController>().balance.value;
    }
    return 0;
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.brightness});

  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final isDark = brightness == Brightness.dark;
    return Container(
      width: 40,
      height: 40,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: AppRadius.mdAll,
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Image.asset(AppConstants.logoAsset, fit: BoxFit.contain),
    );
  }
}
