import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../extensions/context_x.dart';
import '../theme/app_colors.dart';
import '../theme/app_elevation.dart';
import '../theme/app_tokens.dart';
import 'noise_overlay.dart';

/// Modern surface with metallic rim, soft depth, and press feedback.
/// Use [lite] for scroll grids — skips grain/bevels for cheaper paint.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = AppSpace.card,
    this.radius = AppRadius.lg,
    this.noiseOpacity = NoiseOverlay.defaultOpacity,
    this.elevated = true,
    this.lite = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double noiseOpacity;
  final bool elevated;
  final bool lite;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (widget.onTap == null) return;
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final brightness = Theme.of(context).brightness;
    final radiusGeo = BorderRadius.circular(widget.radius);
    final innerRadius = BorderRadius.circular(
      (widget.radius - 1).clamp(0, widget.radius),
    );
    final lite = widget.lite;
    // Grain on all cards (including lite) — texture only.
    final showNoise = widget.noiseOpacity > 0.001;
    final depth = _pressed ? 0.985 : 1.0;
    final accent = AppColors.accentOf(brightness);

    final face = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                widget.onTap!();
              },
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        borderRadius: innerRadius,
        splashColor: accent.withValues(alpha: 0.1),
        highlightColor: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: innerRadius,
            gradient: isDark
                ? AppColors.cardSheenDark
                : AppColors.cardSheenLight,
          ),
          child: ClipRRect(
            borderRadius: innerRadius,
            child: Stack(
              children: [
                // Soft steel wash in the top-left corner
                Positioned(
                  top: -40,
                  left: -30,
                  child: IgnorePointer(
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            accent.withValues(alpha: isDark ? 0.06 : 0.05),
                            accent.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (showNoise)
                  Positioned.fill(
                    child: NoiseOverlay(
                      opacity: widget.noiseOpacity,
                      borderRadius: innerRadius,
                    ),
                  ),
                // Specular top edge
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: lite ? 14 : 22,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(
                              alpha: isDark ? (lite ? 0.04 : 0.07) : 0.35,
                            ),
                            Colors.white.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Depth wash at bottom so faces read richer
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: lite ? 28 : 36,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(
                              alpha: isDark ? 0.35 : 0.06,
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: widget.padding,
                  // Force full card width so centered Columns aren't stuck left
                  // (Stack otherwise sizes to intrinsic child width at top-left).
                  child: SizedBox(
                    width: double.infinity,
                    child: DefaultTextStyle.merge(
                      style: TextStyle(color: AppColors.text(brightness)),
                      child: IconTheme.merge(
                        data: IconThemeData(
                          color: AppColors.textSecondary(brightness),
                        ),
                        child: widget.child,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return RepaintBoundary(
      child: AnimatedScale(
        scale: depth,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radiusGeo,
            boxShadow: widget.elevated
                ? AppElevation.surface(
                    isDark: isDark,
                    pressed: _pressed,
                    lite: lite,
                  )
                : null,
          ),
          // Gradient rim (shiny border) → inset face
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radiusGeo,
              gradient: AppColors.cardRim(brightness),
            ),
            child: Padding(
              padding: const EdgeInsets.all(1.1),
              child: face,
            ),
          ),
        ),
      ),
    );
  }
}
