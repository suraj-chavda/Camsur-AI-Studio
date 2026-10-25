import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/extensions/context_x.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/root_pop_scope.dart';
import '../../data/models/tool_model.dart';
import 'onboarding_controller.dart';
import '../../core/theme/app_icons.dart';

class OnboardingView extends GetView<OnboardingController> {
  const OnboardingView({super.key});

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final ink = AppColors.text(b);
    final muted = AppColors.textSecondary(b);
    final accent = AppColors.accentOf(b);

    return RootPopScope(
      child: Scaffold(
      body: SafeArea(
        child: AdaptiveContainer(
          child: Obx(() {
            final slides = controller.slides;
            if (slides.isEmpty) return const SizedBox.shrink();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.xs,
                    AppSpace.xs,
                    AppSpace.xs,
                    0,
                  ),
                  child: Row(
                    children: [
                      const AppLogo(
                        size: 36,
                        showGlow: false,
                      ),
                      const SizedBox(width: AppSpace.sm),
                      Text(
                        'Camsur',
                        style: context.texts.titleMedium?.copyWith(color: ink),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: controller.finish,
                        style: TextButton.styleFrom(
                          foregroundColor: muted,
                          minimumSize: const Size(AppSize.touch, AppSize.touch),
                        ),
                        child: const Text('Skip'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                Expanded(
                  child: PageView.builder(
                    controller: controller.pageController,
                    itemCount: slides.length,
                    onPageChanged: controller.onPageChanged,
                    itemBuilder: (_, index) {
                      return _HeroFrame(
                        index: index,
                        imageUrl: controller.imageUrlFor(slides[index]),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                _CopyAndActions(
                  slides: slides,
                  ink: ink,
                  muted: muted,
                  accent: accent,
                ),
              ],
            );
          }),
        ),
      ),
    ),
    );
  }
}

class _CopyAndActions extends GetView<OnboardingController> {
  const _CopyAndActions({
    required this.slides,
    required this.ink,
    required this.muted,
    required this.accent,
  });

  final List<OnboardingSlideModel> slides;
  final Color ink;
  final Color muted;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final i = controller.page.value.clamp(0, slides.length - 1);
      final last = i == slides.length - 1;
      final slide = slides[i];

      return Column(
        children: [
          _StepBar(
            count: slides.length,
            index: i,
            accent: accent,
            ink: ink,
          ),
          const SizedBox(height: AppSpace.lg),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) {
              return FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              );
            },
            child: Padding(
              key: ValueKey(slide.slug),
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
              child: Column(
                children: [
                  Text(
                    slide.title,
                    textAlign: TextAlign.center,
                    style: context.texts.headlineLarge?.copyWith(
                      color: ink,
                      fontWeight: FontWeight.w600,
                      height: 1.18,
                    ),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    slide.subtitle,
                    textAlign: TextAlign.center,
                    style: context.texts.bodyLarge?.copyWith(
                      color: muted,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              0,
              AppSpace.lg,
              AppSpace.md,
            ),
            child: AppButton(
              label: last ? 'Get Started' : 'Continue',
              icon: last
                  ? AppIcons.sparkleFill
                  : AppIcons.arrowForward,
              onPressed: controller.next,
            ),
          ),
        ],
      );
    });
  }
}

class _HeroFrame extends StatelessWidget {
  const _HeroFrame({
    required this.index,
    required this.imageUrl,
  });

  final int index;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.text(Theme.of(context).brightness);

    return Obx(() {
      final c = Get.find<OnboardingController>();
      final delta = (c.pageOffset.value - index).clamp(-1.0, 1.0);

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
        child: AppCard(
          lite: true,
          elevated: true,
          padding: EdgeInsets.zero,
          radius: 28,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Transform.translate(
              offset: Offset(-delta * 28, 0),
              child: Transform.scale(
                scale: 1.08,
                child: imageUrl == null
                    ? ColoredBox(color: ink.withValues(alpha: 0.04))
                    : AppNetworkImage(
                        url: imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        displayWidth: 900,
                        logicalWidth: 720,
                        placeholder: ColoredBox(
                          color: ink.withValues(alpha: 0.04),
                        ),
                        error: ColoredBox(
                          color: ink.withValues(alpha: 0.04),
                        ),
                      ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _StepBar extends StatelessWidget {
  const _StepBar({
    required this.count,
    required this.index,
    required this.accent,
    required this.ink,
  });

  final int count;
  final int index;
  final Color accent;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.xxl),
      child: Row(
        children: List.generate(count, (i) {
          final on = i == index;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  color: on ? accent : ink.withValues(alpha: 0.14),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
