import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../app/routes/nav.dart';
import '../../core/extensions/context_x.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/tool_icons.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../core/widgets/generation_actions.dart';
import '../../core/widgets/result_originals_compare.dart';
import '../../data/models/generation_model.dart';
import '../../data/repositories/generation_repository.dart';
import '../history/history_controller.dart';
import '../home/home_controller.dart';
import '../../core/theme/app_icons.dart';

/// History detail / deep-link into a single creation.
class GenerationResultView extends StatefulWidget {
  const GenerationResultView({super.key});

  @override
  State<GenerationResultView> createState() => _GenerationResultViewState();
}

class _GenerationResultViewState extends State<GenerationResultView> {
  late GenerationModel _gen;
  var _refreshing = false;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is GenerationModel) {
      _gen = args;
      _refreshSignedUrls();
    } else {
      _gen = const GenerationModel(
        id: '',
        toolSlug: '',
        status: 'failed',
        errorMessage: 'Creation not found',
      );
    }
  }

  Future<void> _refreshSignedUrls() async {
    if (_gen.id.isEmpty || _refreshing) return;
    setState(() => _refreshing = true);
    try {
      final fresh = await Get.find<GenerationRepository>().getById(_gen.id);
      if (!mounted) return;
      setState(() => _gen = fresh);
    } catch (_) {
      // Keep stale payload — share/save may still work briefly.
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = _gen;
    final out = g.outputImageUrl;
    final b = Theme.of(context).brightness;
    final accent = AppColors.accentOf(b);
    final when = g.createdAt != null
        ? DateFormat.yMMMd().add_jm().format(g.createdAt!.toLocal())
        : null;
    final doneAt = g.completedAt != null
        ? DateFormat.yMMMd().add_jm().format(g.completedAt!.toLocal())
        : null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(toolTitleFor(g.toolSlug)),
        actions: [
          if (g.id.isNotEmpty)
            IconButton(
              tooltip: 'Delete',
              onPressed: () => _confirmDelete(context, g.id),
              icon: const Icon(AppIcons.trash),
            ),
          TextButton(
            onPressed: () => popOrShell(),
            child: Text(
              'Done',
              style: context.texts.labelLarge?.copyWith(
                color: AppColors.accentOf(b),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: AdaptiveContainer(
        child: ListView(
          padding: const EdgeInsets.only(
            top: AppSpace.pageTop,
            bottom: AppSpace.xxl,
          ),
          children: [
            FadeSlideIn(
              child: AppCard(
                lite: true,
                elevated: true,
                padding: EdgeInsets.zero,
                child: out != null && out.isNotEmpty
                    ? Stack(
                        children: [
                          ResultOriginalsCompare(
                            afterUrl: out,
                            beforeUrls: g.allInputImageUrls,
                            aspectRatio: 1,
                            displayWidth: 1200,
                            afterError: Center(
                              child: Icon(
                                toolIconFor(g.toolSlug),
                                size: 40,
                                color: context.colors.outline,
                              ),
                            ),
                          ),
                          if (_refreshing)
                            const Positioned(
                              left: 0,
                              right: 0,
                              top: 0,
                              child: LinearProgressIndicator(minHeight: 2),
                            ),
                        ],
                      )
                    : SizedBox(
                        height: 220,
                        child: Center(
                          child: Text(
                            g.status.toUpperCase(),
                            style: context.texts.titleMedium,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            FadeSlideIn(
              index: 1,
              child: Row(
                children: [
                  Icon(
                    g.isSuccess
                        ? AppIcons.checkCircle
                        : AppIcons.info,
                    color: g.isSuccess ? AppColors.success : AppColors.warning,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      g.isSuccess
                          ? (g.allInputImageUrls.length > 1
                              ? 'Ready · ${g.allInputImageUrls.length} originals · ${g.creditCost} credits'
                              : 'Ready · ${g.creditCost} credits used')
                          : '${g.status} · ${g.creditCost} credits',
                      style: context.texts.titleSmall?.copyWith(
                        color: AppColors.text(b),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (g.isSuccess) ...[
              const SizedBox(height: AppSpace.sm),
              FadeSlideIn(
                index: 1,
                child: GenerationActionBar(generation: g),
              ),
            ],
            const SizedBox(height: AppSpace.section),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: false,
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: AppSpace.listGap),
                title: Text(
                  'Details',
                  style: context.texts.titleMedium?.copyWith(
                    color: AppColors.text(b),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                children: [
                  AppCard(
                    lite: true,
                    elevated: false,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.md,
                      vertical: AppSpace.sm,
                    ),
                    child: Column(
                      children: [
                        _InfoRow(
                          label: 'Tool',
                          value: toolTitleFor(g.toolSlug),
                          icon: toolIconFor(g.toolSlug),
                        ),
                        _InfoRow(
                          label: 'Status',
                          value: _prettyStatus(g.status),
                          icon: AppIcons.flag,
                          valueColor: g.isSuccess
                              ? AppColors.success
                              : (g.status == 'failed' ||
                                      g.status == 'refunded' ||
                                      g.status == 'cancelled')
                                  ? AppColors.error
                                  : AppColors.warning,
                        ),
                        _InfoRow(
                          label: 'Credits',
                          value: '${g.creditCost}',
                          icon: AppIcons.credits,
                        ),
                        if (g.source != null && g.source!.isNotEmpty)
                          _InfoRow(
                            label: 'Source',
                            value: _prettySource(g.source!),
                            icon: AppIcons.camera,
                          ),
                        if (when != null)
                          _InfoRow(
                            label: 'Created',
                            value: when,
                            icon: AppIcons.schedule,
                          ),
                        if (doneAt != null)
                          _InfoRow(
                            label: 'Completed',
                            value: doneAt,
                            icon: AppIcons.check,
                          ),
                        if (g.id.isNotEmpty)
                          _InfoRow(
                            label: 'ID',
                            value: g.id,
                            icon: AppIcons.tag,
                            mono: true,
                          ),
                      ],
                    ),
                  ),
                  if (g.settings.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.md),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Options used',
                        style: context.texts.titleSmall?.copyWith(
                          color: AppColors.text(b),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.listGap),
                    AppCard(
                      lite: true,
                      elevated: false,
                      padding: const EdgeInsets.all(AppSpace.md),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: g.settings.entries.map((e) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: AppRadius.smAll,
                              color: accent.withValues(
                                alpha: b == Brightness.dark ? 0.14 : 0.1,
                              ),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.28),
                              ),
                            ),
                            child: Text(
                              '${_labelize(e.key)} · ${_labelize('${e.value}')}',
                              style: context.texts.labelLarge?.copyWith(
                                color: AppColors.text(b),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  if (g.styleNotes != null &&
                      g.styleNotes!.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpace.md),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Style notes',
                        style: context.texts.titleSmall?.copyWith(
                          color: AppColors.text(b),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.listGap),
                    AppCard(
                      lite: true,
                      elevated: false,
                      child: Text(
                        g.styleNotes!,
                        style: context.texts.bodyMedium?.copyWith(
                          color: AppColors.textSecondary(b),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (g.errorMessage != null && g.errorMessage!.isNotEmpty) ...[
              const SizedBox(height: AppSpace.md),
              AppCard(
                lite: true,
                elevated: false,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(AppIcons.error, color: AppColors.error),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: Text(
                        g.errorMessage!,
                        style: context.texts.bodyMedium?.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _prettyStatus(String status) {
    if (status.isEmpty) return 'Unknown';
    return status[0].toUpperCase() + status.substring(1);
  }

  String _prettySource(String source) => switch (source) {
        'camera' => 'Camera',
        'upload' || 'gallery' => 'Gallery',
        _ => _labelize(source),
      };

  String _labelize(String raw) {
    final cleaned = raw.replaceAll('_', ' ').trim();
    if (cleaned.isEmpty) return raw;
    return cleaned
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  Future<void> _confirmDelete(BuildContext context, String id) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Delete creation?'),
        content: const Text(
          'This removes the saved image. Credits are not refunded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Get.find<GenerationRepository>().delete(id);
      if (Get.isRegistered<HistoryController>()) {
        await Get.find<HistoryController>().load(force: true);
      }
      if (Get.isRegistered<HomeController>()) {
        await Get.find<HomeController>().refreshRecentOnly();
      }
      Get.back();
      Get.snackbar('Deleted', 'Creation removed');
    } catch (e) {
      Get.snackbar('Delete failed', e.toString());
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
    this.mono = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted(b)),
          const SizedBox(width: 10),
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: context.texts.bodySmall?.copyWith(
                color: AppColors.textMuted(b),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: context.texts.bodyMedium?.copyWith(
                color: valueColor ?? AppColors.text(b),
                fontWeight: FontWeight.w600,
                fontFamily: mono ? 'monospace' : null,
                fontSize: mono ? 12 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
