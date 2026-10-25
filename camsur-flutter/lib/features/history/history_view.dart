import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/extensions/context_x.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/image_cache_size.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/tool_icons.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../core/widgets/generation_actions.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/studio_state_card.dart';
import '../../data/models/generation_model.dart';
import 'history_controller.dart';
import '../../core/theme/app_icons.dart';

class HistoryView extends GetView<HistoryController> {
  const HistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Obx(() {
        final loading = controller.loading.value;
        final items = controller.items.toList();
        final err = controller.error.value;

        return RefreshIndicator(
          onRefresh: () => controller.load(force: true),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: KeyedSubtree(
              key: ValueKey(
                loading && items.isEmpty
                    ? 'history-loading'
                    : items.isEmpty
                        ? 'history-empty'
                        : 'history-${items.length}',
              ),
              child: _buildBody(context, loading, items, err),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildBody(
    BuildContext context,
    bool loading,
    List<GenerationModel> items,
    String? err,
  ) {
    final r = context.responsive;

    if (loading && items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          r.pagePadding,
          r.contentTop,
          r.pagePadding,
          r.contentBottom,
        ),
        children: const [
          SectionHeader(title: 'Your creations'),
          SizedBox(height: AppSpace.listGap),
          StudioLoadingBlock(),
        ],
      );
    }

    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          r.pagePadding,
          r.contentTop,
          r.pagePadding,
          r.contentBottom,
        ),
        children: [
          const SectionHeader(title: 'Your creations'),
          const SizedBox(height: AppSpace.listGap),
          err != null
              ? StudioStateCard.error(
                  message: err,
                  onRetry: () => controller.load(force: true),
                )
              : StudioStateCard.empty(
                  title: 'No creations yet',
                  message: 'Your generated photos will show up here.',
                  icon: AppIcons.history,
                ),
        ],
      );
    }

    final cols = items.length == 1
        ? 1
        : r.gridColumns(mobile: 2, tablet: 3, desktop: 4);
    final cacheW = imageCachePx(context, items.length == 1 ? 420 : 220);
    final aspect = items.length == 1 ? 1.35 : 0.82;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: AdaptiveContainer(
            shell: true,
            child: const Padding(
              padding: EdgeInsets.only(bottom: AppSpace.listGap),
              child: SectionHeader(title: 'Your creations'),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            r.pagePadding,
            0,
            r.pagePadding,
            r.contentBottom,
          ),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: aspect,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                final generation = items[i];
                return FadeSlideIn(
                  index: i,
                  maxAnimated: 6,
                  child: _HistoryTile(
                    generation: generation,
                    cacheWidth: cacheW,
                    onTap: () => Get.toNamed(
                      AppRoutes.generationResult,
                      arguments: generation,
                    ),
                  ),
                );
              },
              childCount: items.length,
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.generation,
    required this.onTap,
    required this.cacheWidth,
  });

  final GenerationModel generation;
  final VoidCallback onTap;
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    final url = generation.outputImageUrl;
    final b = Theme.of(context).brightness;

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      lite: true,
      elevated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg - 1),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: AppNetworkImage(
                      url: url,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      optimize: false,
                      displayWidth: 600,
                      memCacheWidth: cacheWidth,
                      error: Center(
                        child: Icon(toolIconFor(generation.toolSlug)),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _StatusPill(status: generation.status),
                  ),
                  if (generation.isSuccess &&
                      generation.outputImageUrl != null)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: GestureDetector(
                        onTap: () {},
                        child: GenerationActionChips(generation: generation),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  toolTitleFor(generation.toolSlug),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.titleSmall?.copyWith(
                    color: AppColors.text(b),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${generation.creditCost} credits',
                  style: context.texts.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'completed' => AppColors.success,
      'failed' || 'refunded' || 'cancelled' => AppColors.error,
      _ => AppColors.warning,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
