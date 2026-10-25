import 'package:flutter/material.dart';

import '../extensions/context_x.dart';
import '../theme/app_colors.dart';
import '../theme/app_elevation.dart';
import '../theme/app_tokens.dart';
import 'noise_overlay.dart';

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.prefixIcon,
    this.suffix,
    this.onChanged,
    this.textInputAction,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final IconData? prefixIcon;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final FocusNode _focus = FocusNode()..addListener(_onFocus);
  bool _focused = false;

  void _onFocus() {
    setState(() => _focused = _focus.hasFocus);
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final b = Theme.of(context).brightness;
    final radiusGeo = AppRadius.mdAll;
    final accent = AppColors.accentOf(b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: context.texts.titleSmall?.copyWith(
              color: AppColors.text(b),
            ),
          ),
          const SizedBox(height: AppSpace.xs),
        ],
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: radiusGeo,
            boxShadow: AppElevation.surface(
              isDark: isDark,
              focused: _focused,
            ),
          ),
          child: ClipRRect(
            borderRadius: radiusGeo,
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: isDark
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF1C1C1C), Color(0xFF121212)],
                            )
                          : const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFFFFFFF), Color(0xFFF4F4F7)],
                            ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: NoiseOverlay(
                    opacity: NoiseOverlay.defaultOpacity,
                    borderRadius: radiusGeo,
                  ),
                ),
                TextFormField(
                  focusNode: _focus,
                  controller: widget.controller,
                  obscureText: widget.obscure,
                  keyboardType: widget.keyboardType,
                  validator: widget.validator,
                  onChanged: widget.onChanged,
                  textInputAction: widget.textInputAction,
                  style: context.texts.titleMedium?.copyWith(
                    color: AppColors.text(b),
                  ),
                  cursorColor: accent,
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    filled: true,
                    fillColor: Colors.transparent,
                    prefixIcon: widget.prefixIcon != null
                        ? Icon(widget.prefixIcon, size: 20)
                        : null,
                    suffixIcon: widget.suffix,
                    contentPadding: AppSpace.field,
                    border: OutlineInputBorder(
                      borderRadius: radiusGeo,
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: radiusGeo,
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.08),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: radiusGeo,
                      borderSide: BorderSide(color: accent, width: 1.5),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: radiusGeo,
                      borderSide: const BorderSide(color: AppColors.error),
                    ),
                    hintStyle: TextStyle(color: AppColors.textMuted(b)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
