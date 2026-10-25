import 'package:flutter/material.dart';

import '../extensions/context_x.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'app_card.dart';
import 'app_network_image.dart';
import 'fade_slide_in.dart';
import '../../core/theme/app_icons.dart';

/// Compact horizontal tool row — image left, copy + credits right.
class ToolCard extends StatelessWidget {
  const ToolCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.imageUrl,
    this.creditCost,
    this.onTap,
    this.index = 0,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? imageUrl;
  final int? creditCost;
  final VoidCallback? onTap;
  final int index;

  static const double rowHeight = 88;
  static const double imageSize = 72;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final accent = AppColors.accentOf(b);
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return FadeSlideIn(
      index: index,
      maxAnimated: 8,
      child: AppCard(
        onTap: onTap,
        lite: true,
        elevated: true,
        padding: const EdgeInsets.all(AppSpace.xs),
        child: SizedBox(
          height: rowHeight - 8,
          child: Row(
            children: [
              ClipRRect(
                borderRadius: AppRadius.smAll,
                child: SizedBox(
                  width: imageSize,
                  height: imageSize,
                  child: hasImage
                      ? AppNetworkImage(
                          url: imageUrl,
                          fit: BoxFit.cover,
                          width: imageSize,
                          height: imageSize,
                          displayWidth: 240,
                          logicalWidth: imageSize,
                          error: _IconFallback(icon: icon, brightness: b),
                        )
                      : _IconFallback(icon: icon, brightness: b),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpace.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.titleSmall?.copyWith(
                          color: AppColors.text(b),
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                      if (subtitle.trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.texts.bodySmall?.copyWith(
                            height: 1.25,
                            color: AppColors.textSecondary(b),
                          ),
                        ),
                      ],
                      if (creditCost != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          '$creditCost credits',
                          style: context.texts.labelSmall?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Icon(
                AppIcons.chevronRight,
                size: 20,
                color: AppColors.textMuted(b),
              ),
              const SizedBox(width: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconFallback extends StatelessWidget {
  const _IconFallback({required this.icon, required this.brightness});

  final IconData icon;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final isDark = brightness == Brightness.dark;
    return ColoredBox(
      color: isDark ? const Color(0xFF161616) : const Color(0xFFF0F0F4),
      child: Center(
        child: Icon(
          icon,
          color: AppColors.text(brightness),
          size: AppSize.iconMd,
        ),
      ),
    );
  }
}
