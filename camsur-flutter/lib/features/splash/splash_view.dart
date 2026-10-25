import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_constants.dart';
import '../../core/extensions/context_x.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_logo.dart';
import 'splash_controller.dart';

/// Studio splash — same cool steel stage as Home, brand-first, light motion.
class SplashView extends GetView<SplashController> {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _SplashStage(controller: controller),
    );
  }
}

class _SplashStage extends StatefulWidget {
  const _SplashStage({required this.controller});

  final SplashController controller;

  @override
  State<_SplashStage> createState() => _SplashStageState();
}

class _SplashStageState extends State<_SplashStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter;
  late final Animation<double> _fadeMark;
  late final Animation<Offset> _riseMark;
  late final Animation<double> _fadeCopy;
  late final Animation<double> _fadeDock;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 880),
    );

    _fadeMark = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
    );
    _riseMark = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _enter,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
      ),
    );
    _fadeCopy = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.22, 0.68, curve: Curves.easeOutCubic),
    );
    _fadeDock = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.48, 1.0, curve: Curves.easeOutCubic),
    );

    _enter.forward();
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final isDark = b == Brightness.dark;
    final ink = AppColors.text(b);
    final muted = AppColors.textMuted(b);
    final secondary = AppColors.textSecondary(b);
    final accent = AppColors.accentOf(b);

    return SafeArea(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Static steel wash — Home-family atmosphere (no extra ticker).
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.35),
                  radius: 0.95,
                  colors: [
                    accent.withValues(alpha: isDark ? 0.14 : 0.10),
                    accent.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: _fadeMark,
                      child: SlideTransition(
                        position: _riseMark,
                        child: const _BrandMark(),
                      ),
                    ),
                    const SizedBox(height: AppSpace.xl),
                    FadeTransition(
                      opacity: _fadeCopy,
                      child: Column(
                        children: [
                          Text(
                            AppConstants.shortName,
                            textAlign: TextAlign.center,
                            style: context.texts.headlineLarge?.copyWith(
                              color: ink,
                              letterSpacing: -0.6,
                              fontWeight: FontWeight.w700,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: AppSpace.xs),
                          Text(
                            'AI STUDIO',
                            textAlign: TextAlign.center,
                            style: context.texts.titleSmall?.copyWith(
                              color: accent,
                              letterSpacing: 2.6,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppSpace.sm),
                          Text(
                            'Studio-quality photos, made simple',
                            textAlign: TextAlign.center,
                            style: context.texts.bodyMedium?.copyWith(
                              color: muted,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: AppSpace.lg,
            right: AppSpace.lg,
            bottom: AppSpace.xl,
            child: FadeTransition(
              opacity: _fadeDock,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: Obx(() {
                    final p = widget.controller.progress.value.clamp(0.0, 1.0);
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _StudioProgress(
                          progress: p,
                          accent: accent,
                          ink: ink,
                        ),
                        const SizedBox(height: AppSpace.sm),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child: Text(
                            widget.controller.label.value,
                            key: ValueKey(widget.controller.label.value),
                            textAlign: TextAlign.center,
                            style: context.texts.labelSmall?.copyWith(
                              color: secondary,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Logo in a steel plate — mirrors Home credit / tool card framing.
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final isDark = b == Brightness.dark;
    final accent = AppColors.accentOf(b);

    return RepaintBoundary(
      child: SizedBox(
        width: 132,
        height: 132,
        child: Stack(
          alignment: Alignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accent.withValues(alpha: isDark ? 0.28 : 0.18),
                    accent.withValues(alpha: 0),
                  ],
                ),
              ),
              child: const SizedBox.expand(),
            ),
            Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                borderRadius: AppRadius.lgAll,
                gradient: isDark
                    ? AppColors.cardSheenDark
                    : AppColors.cardSheenLight,
                border: Border.all(
                  color: accent.withValues(alpha: isDark ? 0.38 : 0.32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: const Center(
                child: AppLogo(
                  size: 72,
                  showGlow: false,
                  shape: AppLogoShape.raw,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudioProgress extends StatelessWidget {
  const _StudioProgress({
    required this.progress,
    required this.accent,
    required this.ink,
  });

  final double progress;
  final Color accent;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final track = ink.withValues(alpha: 0.12);
    final value = progress < 0.06 ? 0.06 : progress;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: SizedBox(
        height: 3,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: track),
            Align(
              alignment: Alignment.centerLeft,
              child: AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutCubic,
                widthFactor: value,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    gradient: LinearGradient(
                      colors: [
                        accent,
                        Color.lerp(accent, ink, 0.55) ?? ink,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
