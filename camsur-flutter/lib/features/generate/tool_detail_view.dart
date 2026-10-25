import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/routes/nav.dart';
import '../../core/extensions/context_x.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/tool_icons.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_state_view.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../core/widgets/generation_actions.dart';
import '../../core/widgets/result_originals_compare.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/studio_bottom_bar.dart';
import '../../data/models/tool_model.dart';
import 'tool_detail_controller.dart';
import '../../core/theme/app_icons.dart';

class ToolDetailView extends GetView<ToolDetailController> {
  const ToolDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Obx(() => Text(controller.tool.value?.name ?? 'Tool')),
        actions: [
          Obx(() {
            if (controller.phase.value != StudioPhase.result) {
              return const SizedBox.shrink();
            }
            return TextButton(
              onPressed: () => popOrShell(),
              child: Text(
                'Done',
                style: context.texts.labelLarge?.copyWith(
                  color: AppColors.accentOf(b),
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }),
        ],
      ),
      body: Obx(() {
        return switch (controller.phase.value) {
          StudioPhase.loading => const AppStateView.loading(),
          StudioPhase.failed when controller.tool.value == null =>
            AppStateView.error(
              message: controller.errorMessage.value,
              onRetry: controller.retry,
            ),
          StudioPhase.processing => _ProcessingPane(controller: controller),
          StudioPhase.result => _ResultPane(controller: controller),
          StudioPhase.failed => _FailedPane(controller: controller),
          _ => _ReadyPane(controller: controller),
        };
      }),
    );
  }
}

class _ReadyPane extends StatelessWidget {
  const _ReadyPane({required this.controller});

  final ToolDetailController controller;

  @override
  Widget build(BuildContext context) {
    final t = controller.tool.value!;
    final b = Theme.of(context).brightness;

    return Column(
      children: [
        Expanded(
          child: AdaptiveContainer(
            child: ListView(
              padding: const EdgeInsets.only(
                top: AppSpace.pageTop,
                bottom: AppSpace.md,
              ),
              children: [
                FadeSlideIn(child: _ToolHero(tool: t)),
                const SizedBox(height: AppSpace.section),
                Obx(() {
                  final max = controller.maxPhotos;
                  final min = controller.minPhotos;
                  final together = controller.isTogetherTool;
                  final title = max <= 1
                      ? 'Your photo'
                      : together
                          ? 'Photos ($min–$max)'
                          : min >= 2
                              ? 'People ($min–$max)'
                              : 'Your photos (1–$max)';
                  return SectionHeader(title: title);
                }),
                if (t.maxInputImages > 1) ...[
                  const SizedBox(height: 4),
                  Text(
                    controller.isTogetherTool
                        ? 'Best results: one clear photo per person (you + wife + baby = 3 photos). Extra angles of the same person only if you switch Options → “Extra photos are same-person refs”.'
                        : t.minInputImages >= 2
                            ? 'Add ${t.minInputImages}–${t.maxInputImages} people · clear front-facing faces work best · Photo 1 = main person/scene'
                            : 'One photo is enough · extra angles help identity',
                    style: context.texts.bodySmall?.copyWith(
                      color: AppColors.textMuted(b),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpace.listGap),
                Obx(() {
                  final list = controller.photos.toList();
                  final max = controller.maxPhotos;
                  return FadeSlideIn(
                    index: 1,
                    child: _PhotoSlotGrid(
                      files: list,
                      maxSlots: max,
                      personLabels: t.minInputImages >= 2 && !controller.isTogetherTool,
                      onAddGallery: () =>
                          controller.pick(ImageSource.gallery),
                      onAddCamera: () =>
                          controller.pick(ImageSource.camera),
                      onRemoveAt: controller.removePhotoAt,
                    ),
                  );
                }),
                if (t.settings.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.section),
                  FadeSlideIn(
                    index: 2,
                    child: _OptionalExpandable(
                      title: 'Options',
                      subtitle: 'Tune look & style',
                      child: Column(
                        children: [
                          for (var i = 0; i < t.settings.length; i++) ...[
                            if (i > 0)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppSpace.sm,
                                ),
                                child: Divider(
                                  height: 1,
                                  color: AppColors.border(b)
                                      .withValues(alpha: 0.45),
                                ),
                              ),
                            Obx(
                              () => _SettingRow(
                                setting: t.settings[i],
                                selected:
                                    controller.selected[t.settings[i].key],
                                onSelect: (v) => controller.selectOption(
                                  t.settings[i].key,
                                  v,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpace.section),
                FadeSlideIn(
                  index: 3,
                  child: _OptionalExpandable(
                    title: 'Style notes',
                    subtitle: t.minInputImages >= 2
                        ? 'Background, mood, poses…'
                        : 'Lighting, mood, attire…',
                    child: TextField(
                      controller: controller.notesCtrl,
                      maxLines: 3,
                      maxLength: 500,
                      style: context.texts.bodyMedium?.copyWith(
                        color: AppColors.text(b),
                      ),
                      decoration: InputDecoration(
                        hintText: t.minInputImages >= 2
                            ? 'e.g. soft home interior, both smiling gently…'
                            : 'Add any details you want…',
                        hintStyle: context.texts.bodyMedium?.copyWith(
                          color: AppColors.textMuted(b),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        counterStyle: context.texts.labelSmall?.copyWith(
                          color: AppColors.textMuted(b),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.md),
              ],
            ),
          ),
        ),
        _BottomBar(tool: t, controller: controller),
      ],
    );
  }
}

/// Collapsible optional block — header always visible with Optional chip.
class _OptionalExpandable extends StatefulWidget {
  const _OptionalExpandable({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  State<_OptionalExpandable> createState() => _OptionalExpandableState();
}

class _OptionalExpandableState extends State<_OptionalExpandable> {
  bool _open = false;

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() => _open = !_open);
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final accent = AppColors.accentOf(b);
    final isDark = b == Brightness.dark;

    return AppCard(
      lite: true,
      elevated: true,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggle,
              borderRadius: AppRadius.lgAll,
              splashColor: accent.withValues(alpha: 0.08),
              highlightColor: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.md,
                  AppSpace.md,
                  AppSpace.sm,
                  AppSpace.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.title,
                                  style: context.texts.titleSmall?.copyWith(
                                    color: AppColors.text(b),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: accent.withValues(
                                    alpha: isDark ? 0.16 : 0.12,
                                  ),
                                  border: Border.all(
                                    color: accent.withValues(alpha: 0.32),
                                  ),
                                ),
                                child: Text(
                                  'Optional',
                                  style: context.texts.labelSmall?.copyWith(
                                    color: accent,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (widget.subtitle != null && !_open) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.texts.bodySmall?.copyWith(
                                color: AppColors.textMuted(b),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        AppIcons.chevronDown,
                        color: AppColors.textMuted(b),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.md,
                      0,
                      AppSpace.md,
                      AppSpace.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Divider(
                          height: 1,
                          color: AppColors.border(b).withValues(alpha: 0.45),
                        ),
                        const SizedBox(height: AppSpace.sm),
                        widget.child,
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// Same visual family as Home’s balance card — accent wash, clear cost.
class _ToolHero extends StatelessWidget {
  const _ToolHero({required this.tool});

  final ToolModel tool;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final accent = AppColors.accentOf(b);
    final isDark = b == Brightness.dark;

    return AppCard(
      lite: true,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: AppRadius.lgAll,
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
                            accent.withValues(alpha: 0.14),
                            const Color(0xFF141418),
                            const Color(0xFF0E1014),
                          ]
                        : [
                            Colors.white,
                            accent.withValues(alpha: 0.08),
                            const Color(0xFFF3F5F8),
                          ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.mdAll,
                      color: accent.withValues(
                        alpha: isDark ? 0.18 : 0.14,
                      ),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(
                      toolIconFor(tool.slug),
                      color: accent,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tool.name,
                          style: context.texts.titleMedium?.copyWith(
                            color: AppColors.text(b),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tool.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.texts.bodySmall?.copyWith(
                            color: AppColors.textSecondary(b),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.smAll,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${tool.creditCost}',
                          style: context.texts.titleMedium?.copyWith(
                            color: AppColors.text(b),
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'credits',
                          style: context.texts.labelSmall?.copyWith(
                            color: AppColors.textMuted(b),
                            fontSize: 10,
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
  }
}

class _PhotoEmpty extends StatelessWidget {
  const _PhotoEmpty({
    required this.onGallery,
    required this.onCamera,
  });

  final VoidCallback onGallery;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final accent = AppColors.accentOf(b);
    final isDark = b == Brightness.dark;

    return AppCard(
      lite: true,
      elevated: true,
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: AppRadius.mdAll,
              color: accent.withValues(alpha: isDark ? 0.16 : 0.12),
              border: Border.all(color: accent.withValues(alpha: 0.32)),
            ),
            child: Icon(
              AppIcons.photoAdd,
              size: 30,
              color: accent,
            ),
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            'Add a photo to begin',
            textAlign: TextAlign.center,
            style: context.texts.titleSmall?.copyWith(
              color: AppColors.text(b),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Clear face, good light works best',
            textAlign: TextAlign.center,
            style: context.texts.bodySmall?.copyWith(
              color: AppColors.textMuted(b),
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          Row(
            children: [
              Expanded(
                child: _SourceButton(
                  icon: AppIcons.galleryFill,
                  label: 'Gallery',
                  primary: true,
                  onTap: onGallery,
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: _SourceButton(
                  icon: AppIcons.cameraFill,
                  label: 'Camera',
                  primary: false,
                  onTap: onCamera,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  const _SourceButton({
    required this.icon,
    required this.label,
    required this.primary,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final fg = primary
        ? AppColors.ctaForeground(b)
        : AppColors.text(b);
    final border = primary
        ? AppColors.ctaBorder(b)
        : AppColors.border(b).withValues(alpha: 0.7);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: AppRadius.mdAll,
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdAll,
            gradient: primary ? AppColors.ctaGradient(b) : null,
            color: primary
                ? null
                : (b == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white),
            border: Border.all(color: border),
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
    );
  }
}

class _PhotoSlotGrid extends StatelessWidget {
  const _PhotoSlotGrid({
    required this.files,
    required this.maxSlots,
    required this.onAddGallery,
    required this.onAddCamera,
    required this.onRemoveAt,
    this.personLabels = false,
  });

  final List<File> files;
  final int maxSlots;
  final VoidCallback onAddGallery;
  final VoidCallback onAddCamera;
  final void Function(int index) onRemoveAt;
  final bool personLabels;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final accent = AppColors.accentOf(b);
    final slots = maxSlots.clamp(1, 5);

    if (slots == 1) {
      if (files.isEmpty) {
        return _PhotoEmpty(onGallery: onAddGallery, onCamera: onAddCamera);
      }
      return _PhotoPreview(
        file: files.first,
        onClear: () => onRemoveAt(0),
        onReplace: onAddGallery,
      );
    }

    return AppCard(
      lite: true,
      elevated: true,
      padding: const EdgeInsets.all(AppSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: slots,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              if (index < files.length) {
                return _FilledPhotoSlot(
                  file: files[index],
                  index: index,
                  personLabels: personLabels,
                  onRemove: () => onRemoveAt(index),
                );
              }
              final isNext = index == files.length;
              return _EmptyPhotoSlot(
                enabled: isNext,
                label: personLabels
                    ? (index == 0 ? 'Person 1' : 'Person ${index + 1}')
                    : 'Photo ${index + 1}',
                onTap: isNext ? onAddGallery : null,
              );
            },
          ),
          const SizedBox(height: AppSpace.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: files.length < slots ? onAddGallery : null,
                  icon: const Icon(AppIcons.gallery, size: 18),
                  label: const Text('Gallery'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: files.length < slots ? onAddCamera : null,
                  icon: const Icon(AppIcons.camera, size: 18),
                  label: const Text('Camera'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            personLabels
                ? '${files.length}/$slots people'
                : '${files.length}/$slots photos',
            textAlign: TextAlign.center,
            style: context.texts.labelSmall?.copyWith(
              color: files.length >= slots
                  ? accent
                  : AppColors.textMuted(b),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilledPhotoSlot extends StatelessWidget {
  const _FilledPhotoSlot({
    required this.file,
    required this.index,
    required this.onRemove,
    this.personLabels = false,
  });

  final File file;
  final int index;
  final VoidCallback onRemove;
  final bool personLabels;

  @override
  Widget build(BuildContext context) {
    final badge = personLabels
        ? (index == 0 ? 'Person 1' : 'Person ${index + 1}')
        : (index == 0 ? 'Photo 1' : 'Photo ${index + 1}');
    return ClipRRect(
      borderRadius: AppRadius.smAll,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(file, fit: BoxFit.cover),
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: IconButton(
              onPressed: onRemove,
              icon: const Icon(AppIcons.close, size: 16),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
                minimumSize: const Size(28, 28),
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

class _EmptyPhotoSlot extends StatelessWidget {
  const _EmptyPhotoSlot({
    required this.enabled,
    required this.label,
    this.onTap,
  });

  final bool enabled;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final border = AppColors.border(b);
    return Material(
      color: AppColors.surface(b),
      borderRadius: AppRadius.smAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.smAll,
        child: CustomPaint(
          painter: _DashBorderPainter(
            color: border.withValues(alpha: enabled ? 0.9 : 0.35),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  AppIcons.photoAdd,
                  size: 22,
                  color: enabled
                      ? AppColors.accentOf(b)
                      : AppColors.textMuted(b),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: context.texts.labelSmall?.copyWith(
                    color: AppColors.textMuted(b),
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

class _DashBorderPainter extends CustomPainter {
  _DashBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    const dash = 4.0;
    const gap = 3.0;
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.6, 0.6, size.width - 1.2, size.height - 1.2),
      const Radius.circular(AppRadius.sm),
    );
    final path = Path()..addRRect(r);
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final next = (dist + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(dist, next), paint);
        dist = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({
    required this.file,
    required this.onClear,
    required this.onReplace,
  });

  final File file;
  final VoidCallback onClear;
  final VoidCallback onReplace;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final accent = AppColors.accentOf(b);

    return AppCard(
      lite: true,
      elevated: true,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.lg - 1),
            ),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.file(file, fit: BoxFit.cover),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.md,
              AppSpace.sm,
              AppSpace.md,
              AppSpace.md,
            ),
            child: Row(
              children: [
                Icon(AppIcons.checkCircle, size: 18, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Photo ready',
                    style: context.texts.titleSmall?.copyWith(
                      color: AppColors.text(b),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onReplace,
                  style: TextButton.styleFrom(
                    foregroundColor: accent,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(44, 40),
                  ),
                  child: Text(
                    'Replace',
                    style: context.texts.labelLarge?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onClear,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMuted(b),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(44, 40),
                  ),
                  child: Text(
                    'Remove',
                    style: context.texts.labelLarge?.copyWith(
                      color: AppColors.textMuted(b),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.setting,
    required this.selected,
    required this.onSelect,
  });

  final ToolSetting setting;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                setting.label,
                style: context.texts.titleSmall?.copyWith(
                  color: AppColors.text(b),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (setting.locked)
              Text(
                'Locked',
                style: context.texts.labelSmall?.copyWith(
                  color: AppColors.textMuted(b),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: setting.options.map((o) {
            final active = selected == o.value;
            return _OptionChip(
              label: o.label,
              active: active,
              enabled: !setting.locked,
              onTap: () => onSelect(o.value),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final isDark = b == Brightness.dark;
    final fg = active
        ? AppColors.ctaForeground(b)
        : AppColors.textSecondary(b);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: !enabled
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap();
              },
        borderRadius: AppRadius.smAll,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: AppRadius.smAll,
            gradient: active ? AppColors.ctaGradient(b) : null,
            color: active
                ? null
                : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white),
            border: Border.all(
              color: active
                  ? AppColors.ctaBorder(b)
                  : AppColors.border(b).withValues(alpha: 0.65),
            ),
          ),
          child: Text(
            label,
            style: context.texts.labelLarge?.copyWith(
              color: fg,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.tool,
    required this.controller,
  });

  final ToolModel tool;
  final ToolDetailController controller;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final accent = AppColors.accentOf(b);

    return StudioBottomBar(
      child: Obx(() {
        final ready = controller.hasRequiredPhotos;
        final bal = controller.balance.value;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppButton(
              label: ready
                  ? 'Generate · ${tool.creditCost} credits'
                  : 'Add a photo to generate',
              icon: ready
                  ? AppIcons.sparkleFill
                  : AppIcons.photoAdd,
              loading: controller.submitting.value,
              onPressed: ready ? controller.generate : null,
            ),
            const SizedBox(height: 8),
            Text(
              ready
                  ? (controller.maxPhotos > 1 &&
                          controller.photos.length < controller.maxPhotos
                      ? 'Balance $bal · optional: add up to ${controller.maxPhotos}'
                      : 'Balance $bal · uses ${tool.creditCost} credits')
                  : 'Choose Gallery or Camera above',
              textAlign: TextAlign.center,
              style: context.texts.labelSmall?.copyWith(
                color: ready ? AppColors.textMuted(b) : accent,
                fontWeight: ready ? FontWeight.w500 : FontWeight.w600,
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _ProcessingPane extends StatelessWidget {
  const _ProcessingPane({required this.controller});

  final ToolDetailController controller;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final accent = AppColors.accentOf(b);
    final ink = AppColors.text(b);
    final muted = AppColors.textSecondary(b);
    final toolName = controller.tool.value?.name ?? 'photo';
    final file = controller.photo;

    return AdaptiveContainer(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.lg,
            AppSpace.pageTop,
            AppSpace.lg,
            AppSpace.xxl,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FadeSlideIn(
                  child: AppCard(
                    lite: true,
                    elevated: true,
                    padding: EdgeInsets.zero,
                    child: ClipRRect(
                      borderRadius: AppRadius.lgAll,
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (file != null)
                              Image.file(
                                file,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.medium,
                              )
                            else
                              ColoredBox(
                                color: AppColors.surface(b),
                                child: Icon(
                                  AppIcons.photo,
                                  size: 48,
                                  color: muted,
                                ),
                              ),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.08),
                                    Colors.black.withValues(alpha: 0.55),
                                  ],
                                ),
                              ),
                            ),
                            const Positioned.fill(
                              child: _ProcessingScanLine(),
                            ),
                            Positioned(
                              left: AppSpace.md,
                              right: AppSpace.md,
                              bottom: AppSpace.md,
                              child: Obx(() {
                                final p = controller.progress.value.clamp(0.0, 1.0);
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      controller.statusLabel.value,
                                      style: context.texts.titleSmall?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpace.xs),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.pill,
                                      ),
                                      child: SizedBox(
                                        height: 4,
                                        child: Stack(
                                          children: [
                                            const ColoredBox(
                                              color: Color(0x33FFFFFF),
                                              child: SizedBox.expand(),
                                            ),
                                            AnimatedFractionallySizedBox(
                                              duration: const Duration(
                                                milliseconds: 280,
                                              ),
                                              curve: Curves.easeOutCubic,
                                              widthFactor: p.clamp(0.04, 1),
                                              heightFactor: 1,
                                              alignment: Alignment.centerLeft,
                                              child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    AppRadius.pill,
                                                  ),
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      accent,
                                                      Colors.white,
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${(p * 100).round()}%',
                                      style: context.texts.labelSmall?.copyWith(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.xl),
                FadeSlideIn(
                  index: 1,
                  child: Text(
                    'Creating your $toolName',
                    textAlign: TextAlign.center,
                    style: context.texts.titleLarge?.copyWith(
                      color: ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                FadeSlideIn(
                  index: 2,
                  child: Obx(
                    () => AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: Text(
                        controller.caption.value.isEmpty
                            ? controller.statusLabel.value
                            : controller.caption.value,
                        key: ValueKey(
                          controller.caption.value.isEmpty
                              ? controller.statusLabel.value
                              : controller.caption.value,
                        ),
                        textAlign: TextAlign.center,
                        style: context.texts.bodyMedium?.copyWith(
                          color: muted,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                Text(
                  'Usually takes under a minute',
                  style: context.texts.labelSmall?.copyWith(
                    color: AppColors.textMuted(b),
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

class _ProcessingScanLine extends StatefulWidget {
  const _ProcessingScanLine();

  @override
  State<_ProcessingScanLine> createState() => _ProcessingScanLineState();
}

class _ProcessingScanLineState extends State<_ProcessingScanLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_ctrl.value);
        return Align(
          alignment: Alignment(0, -1 + (t * 2)),
          child: Container(
            height: 72,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0),
                  Colors.white.withValues(alpha: 0.18),
                  Colors.white.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ResultPane extends StatelessWidget {
  const _ResultPane({required this.controller});

  final ToolDetailController controller;

  @override
  Widget build(BuildContext context) {
    final g = controller.result.value!;
    final out = g.outputImageUrl;
    final localFiles = controller.photos
        .where((f) => f.existsSync())
        .toList();
    final remoteUrls = g.allInputImageUrls;
    final b = Theme.of(context).brightness;
    final accent = AppColors.accentOf(b);
    final creditCost = controller.tool.value?.creditCost ?? g.creditCost;
    const statusLabel = 'Ready';
    final personLabels = (controller.tool.value?.minInputImages ?? 1) >= 2;

    return AdaptiveContainer(
      child: ListView(
        padding: const EdgeInsets.only(
          top: AppSpace.pageTop,
          bottom: AppSpace.xxl,
        ),
        children: [
          // 1) Result photo — multi originals as a quiet strip under compare
          if (out != null && out.isNotEmpty)
            FadeSlideIn(
              child: AppCard(
                lite: true,
                elevated: true,
                padding: EdgeInsets.zero,
                child: ResultOriginalsCompare(
                  afterUrl: out,
                  beforeFiles: localFiles,
                  beforeUrls: remoteUrls,
                  aspectRatio: 1,
                  displayWidth: 1200,
                  personLabels: personLabels,
                  afterError: const Center(
                    child: Icon(AppIcons.photoBroken),
                  ),
                ),
              ),
            ),

          // 2) Status + Share/Save — tight under the photo
          const SizedBox(height: AppSpace.sm),
          FadeSlideIn(
            index: 1,
            child: Row(
              children: [
                Icon(
                  AppIcons.checkCircle,
                  size: 18,
                  color: accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    localFiles.length > 1 || remoteUrls.length > 1
                        ? '$statusLabel · ${localFiles.isNotEmpty ? localFiles.length : remoteUrls.length} originals · $creditCost credits'
                        : '$statusLabel · $creditCost credits used',
                    style: context.texts.titleSmall?.copyWith(
                      color: AppColors.text(b),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (out != null && out.isNotEmpty) ...[
            const SizedBox(height: AppSpace.sm),
            FadeSlideIn(
              index: 1,
              child: GenerationActionBar(generation: g),
            ),
          ],
        ],
      ),
    );
  }
}

class _FailedPane extends StatelessWidget {
  const _FailedPane({required this.controller});

  final ToolDetailController controller;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.error, size: 44, color: AppColors.error),
            const SizedBox(height: AppSpace.md),
            Text(
              'Something went wrong',
              style: context.texts.titleLarge?.copyWith(
                color: AppColors.text(b),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpace.xs),
            Obx(
              () => Text(
                controller.errorMessage.value,
                textAlign: TextAlign.center,
                style: context.texts.bodyMedium?.copyWith(
                  color: AppColors.textSecondary(b),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.xl),
            AppButton(label: 'Try again', onPressed: controller.retry),
            const SizedBox(height: AppSpace.sm),
            AppButton(
              label: 'Back',
              gradient: false,
              onPressed: () => popOrShell(),
            ),
          ],
        ),
      ),
    );
  }
}
