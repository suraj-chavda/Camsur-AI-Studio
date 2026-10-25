import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/extensions/context_x.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/photo_pick.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/tool_icons.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_shimmer.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../core/widgets/studio_bottom_bar.dart';
import '../../core/widgets/tool_card.dart';
import '../shell/capture_sheet.dart';
import 'photo_preview_controller.dart';
import '../../core/theme/app_icons.dart';

/// After capture/select — preview up to 5 photos and choose a conversion tool.
class PhotoPreviewView extends GetView<PhotoPreviewController> {
  const PhotoPreviewView({super.key});

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final b = Theme.of(context).brightness;

    return Scaffold(
      appBar: AppBar(
        title: Obx(() {
          final n = controller.photos.length;
          return Text(n <= 1 ? 'Your photo' : 'Your photos ($n)');
        }),
        actions: [
          TextButton(
            onPressed: () => showCaptureToolbar(),
            child: const Text('Retake'),
          ),
        ],
      ),
      body: Obx(() {
        final files = controller.photos.toList();
        if (files.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AppIcons.photoBroken,
                    size: 48,
                    color: AppColors.textMuted(b),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    'No photo selected',
                    style: context.texts.titleMedium,
                  ),
                  const SizedBox(height: AppSpace.md),
                  AppButton(
                    label: 'Choose photos',
                    expand: false,
                    onPressed: () => showCaptureToolbar(),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            Expanded(
              child: AdaptiveContainer(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: AppSpace.xs),
                          FadeSlideIn(
                            child: _PhotoStage(
                              files: files,
                              source: controller.source.value,
                              onRemoveAt: controller.removeAt,
                            ),
                          ),
                          const SizedBox(height: AppSpace.sm),
                          Text(
                            'Up to ${PhotoPick.maxCount} photos · same person, different angles',
                            style: context.texts.labelSmall?.copyWith(
                              color: AppColors.textMuted(b),
                            ),
                          ),
                          const SizedBox(height: AppSpace.xl),
                          Text(
                            'Choose a tool',
                            style: context.texts.titleMedium?.copyWith(
                              color: AppColors.text(b),
                            ),
                          ),
                          const SizedBox(height: AppSpace.xxs),
                          Text(
                            '1 photo works · up to ${PhotoPick.maxCount} helps identity',
                            style: context.texts.bodyMedium?.copyWith(
                              color: AppColors.textSecondary(b),
                            ),
                          ),
                          const SizedBox(height: AppSpace.md),
                        ],
                      ),
                    ),
                    _toolsSliver(context, r),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpace.md),
                    ),
                  ],
                ),
              ),
            ),
            StudioBottomBar(
              hint: controller.canAddMore
                  ? 'Add more angles anytime'
                  : 'Photo limit reached',
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Gallery',
                      gradient: false,
                      icon: AppIcons.gallery,
                      onPressed: controller.canAddMore
                          ? controller.addFromGallery
                          : null,
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: AppButton(
                      label: 'Camera',
                      gradient: false,
                      icon: AppIcons.camera,
                      onPressed: controller.canAddMore
                          ? controller.addFromCamera
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _toolsSliver(BuildContext context, Responsive r) {
    return Obx(() {
      if (controller.loadingTools.value && controller.tools.isEmpty) {
        return SliverList.separated(
          itemCount: 4,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpace.listGap),
          itemBuilder: (_, _) => const _ToolPickSkeleton(),
        );
      }

      if (controller.tools.isEmpty) {
        return SliverToBoxAdapter(
          child: AppCard(
            lite: true,
            child: Column(
              children: [
                Text(
                  controller.toolsError.value ?? 'No tools available',
                  style: context.texts.bodyMedium,
                ),
                TextButton(
                  onPressed: controller.retryTools,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      }

      final photoCount = controller.photos.length;
      return SliverList.separated(
        itemCount: controller.tools.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpace.listGap),
        itemBuilder: (_, i) {
          final t = controller.tools[i];
          final need = t.minInputImages.clamp(1, PhotoPick.maxCount);
          final ready = photoCount >= need;
          return ToolCard(
            index: i,
            title: t.name,
            subtitle: ready
                ? t.description
                : 'Needs $need photo${need == 1 ? '' : 's'}',
            icon: toolIconFor(t.slug),
            imageUrl: t.imageUrl,
            creditCost: t.creditCost,
            onTap: () => controller.continueWithTool(t),
          );
        },
      );
    });
  }
}

class _PhotoStage extends StatelessWidget {
  const _PhotoStage({
    required this.files,
    required this.source,
    required this.onRemoveAt,
  });

  final List<File> files;
  final String source;
  final void Function(int index) onRemoveAt;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final main = files.first;

    return AppCard(
      padding: EdgeInsets.zero,
      lite: true,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: files.length > 1
                ? const BorderRadius.vertical(top: Radius.circular(AppRadius.lg))
                : AppRadius.lgAll,
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    main,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                  ),
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        color: Colors.black.withValues(alpha: 0.55),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              source == 'camera'
                                  ? AppIcons.cameraFill
                                  : AppIcons.galleryFill,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${files.length}/${PhotoPick.maxCount}',
                              style: context.texts.labelSmall?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(
                              alpha: b == Brightness.dark ? 0.12 : 0.04,
                            ),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.28),
                          ],
                          stops: const [0, 0.45, 1],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (files.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: files.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    return _Thumb(
                      file: files[i],
                      label: i == 0 ? 'Main' : '${i + 1}',
                      onRemove: () => onRemoveAt(i),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.file,
    required this.label,
    required this.onRemove,
  });

  final File file;
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: AppRadius.smAll,
              child: Image.file(file, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            left: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              onPressed: onRemove,
              icon: const Icon(AppIcons.close, size: 14),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
                minimumSize: const Size(24, 24),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolPickSkeleton extends StatelessWidget {
  const _ToolPickSkeleton();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      lite: true,
      padding: const EdgeInsets.all(AppSpace.xs),
      child: SizedBox(
        height: ToolCard.rowHeight - 8,
        child: Row(
          children: [
            const AppShimmerBlock(
              height: ToolCard.imageSize,
              width: ToolCard.imageSize,
              radius: AppRadius.sm,
            ),
            const SizedBox(width: AppSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  AppShimmerBlock(height: 14, width: 120),
                  SizedBox(height: 8),
                  AppShimmerBlock(height: 12, width: double.infinity),
                  SizedBox(height: 6),
                  AppShimmerBlock(height: 12, width: 64),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
