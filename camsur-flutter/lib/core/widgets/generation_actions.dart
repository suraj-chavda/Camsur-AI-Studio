import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../extensions/context_x.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../utils/generation_media.dart';
import '../utils/tool_icons.dart';
import '../../data/models/generation_model.dart';
import '../../core/theme/app_icons.dart';

/// Full-width Share / Save row for result & detail screens.
class GenerationActionBar extends StatelessWidget {
  const GenerationActionBar({
    super.key,
    required this.generation,
    this.dense = false,
  });

  final GenerationModel generation;
  final bool dense;

  String? get _url => generation.outputImageUrl;

  String get _fileName =>
      'camsur_${generation.toolSlug}_${generation.id}'.clampName();

  @override
  Widget build(BuildContext context) {
    final url = _url;
    final enabled = GenerationMedia.hasImage(url);

    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            label: 'Share',
            icon: AppIcons.share,
            primary: true,
            dense: dense,
            enabled: enabled,
            onTap: () {
              HapticFeedback.selectionClick();
              GenerationMedia.run(
              busyLabel: 'Preparing share',
              action: () => GenerationMedia.share(
                url!,
                fileName: _fileName,
                text: 'Made with Camsur Pro · ${toolTitleFor(generation.toolSlug)}',
              ),
            );
            },
          ),
        ),
        SizedBox(width: dense ? AppSpace.xs : AppSpace.sm),
        Expanded(
          child: _ActionButton(
            label: 'Save',
            icon: AppIcons.download,
            primary: false,
            dense: dense,
            enabled: enabled,
            onTap: () {
              HapticFeedback.selectionClick();
              GenerationMedia.run(
                busyLabel: 'Saving photo',
                doneLabel: 'Saved to Photos · Camsur Pro',
                action: () => GenerationMedia.saveToGallery(
                  url!,
                  fileName: _fileName,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Compact glass chips for grid / thumb overlays.
class GenerationActionChips extends StatelessWidget {
  const GenerationActionChips({
    super.key,
    required this.generation,
  });

  final GenerationModel generation;

  String? get _url => generation.outputImageUrl;

  String get _fileName =>
      'camsur_${generation.toolSlug}_${generation.id}'.clampName();

  @override
  Widget build(BuildContext context) {
    final url = _url;
    if (!GenerationMedia.hasImage(url)) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ChipButton(
          icon: AppIcons.share,
          tooltip: 'Share',
          onTap: () {
            HapticFeedback.selectionClick();
            GenerationMedia.run(
              busyLabel: 'Preparing share',
              action: () => GenerationMedia.share(
                url!,
                fileName: _fileName,
                text:
                    'Made with Camsur Pro · ${toolTitleFor(generation.toolSlug)}',
              ),
            );
          },
        ),
        const SizedBox(width: 6),
        _ChipButton(
          icon: AppIcons.download,
          tooltip: 'Save',
          onTap: () {
            HapticFeedback.selectionClick();
            GenerationMedia.run(
              busyLabel: 'Saving photo',
              doneLabel: 'Saved to Photos · Camsur Pro',
              action: () => GenerationMedia.saveToGallery(
                url!,
                fileName: _fileName,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.primary,
    required this.enabled,
    required this.onTap,
    this.dense = false,
  });

  final String label;
  final IconData icon;
  final bool primary;
  final bool enabled;
  final bool dense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final fg = primary
        ? AppColors.ctaForeground(b)
        : AppColors.text(b);
    final height = dense ? 42.0 : AppSize.buttonH;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: AppRadius.mdAll,
          child: Ink(
            height: height,
            decoration: BoxDecoration(
              borderRadius: AppRadius.mdAll,
              gradient: primary ? AppColors.ctaGradient(b) : null,
              color: primary
                  ? null
                  : (b == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.white),
              border: Border.all(
                color: primary
                    ? AppColors.ctaBorder(b)
                    : AppColors.border(b).withValues(alpha: 0.7),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: context.texts.labelLarge?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
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

class _ChipButton extends StatelessWidget {
  const _ChipButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(icon, size: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

extension on String {
  String clampName() {
    final cleaned = replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    return cleaned.length <= 48 ? cleaned : cleaned.substring(0, 48);
  }
}
