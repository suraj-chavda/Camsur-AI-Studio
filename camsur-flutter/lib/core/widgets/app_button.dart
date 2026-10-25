import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_elevation.dart';
import '../theme/app_tokens.dart';
import 'noise_overlay.dart';

class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.gradient = true,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool gradient;
  final IconData? icon;
  final bool expand;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final isDark = b == Brightness.dark;
    final enabled = widget.onPressed != null && !widget.loading;
    final primary = widget.gradient;
    final fg = primary ? AppColors.ctaForeground(b) : AppColors.text(b);
    final radius = AppRadius.mdAll;
    final innerRadius = BorderRadius.circular(AppRadius.md - 1);

    final child = widget.loading
        ? SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(
              strokeWidth: 1.7,
              color: fg,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 16, color: fg),
                const SizedBox(width: 7),
              ],
              Text(widget.label),
            ],
          );

    final face = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: !enabled
            ? null
            : () {
                HapticFeedback.lightImpact();
                widget.onPressed!();
              },
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        borderRadius: innerRadius,
        splashColor: primary
            ? (isDark
                ? Colors.black.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.12))
            : AppColors.accentOf(b).withValues(alpha: 0.12),
        highlightColor: Colors.transparent,
        child: Ink(
          width: widget.expand ? double.infinity : null,
          height: AppSize.buttonH,
          padding: widget.expand
              ? null
              : const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            borderRadius: innerRadius,
            gradient: primary ? AppColors.ctaGradient(b) : null,
            color: primary
                ? null
                : (isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.03)),
          ),
          child: ClipRRect(
            borderRadius: innerRadius,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Positioned.fill(
                  child: NoiseOverlay(opacity: NoiseOverlay.defaultOpacity),
                ),
                if (primary)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 22,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(
                                alpha: isDark ? 0.55 : 0.16,
                              ),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                DefaultTextStyle(
                  style: TextStyle(
                    color: fg,
                    fontFamily: 'Figtree',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    letterSpacing: 0.15,
                    height: 1,
                  ),
                  child: IconTheme(
                    data: IconThemeData(color: fg, size: 16),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return AnimatedScale(
      scale: _pressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOutCubic,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: primary && enabled
                ? AppElevation.cta(isDark: isDark, pressed: _pressed)
                : null,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: primary
                  ? AppColors.buttonRim(b)
                  : AppColors.cardRim(b),
            ),
            child: Padding(
              padding: const EdgeInsets.all(1.15),
              child: face,
            ),
          ),
        ),
      ),
    );
  }
}
