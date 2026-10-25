import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/extensions/context_x.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/tool_icons.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/app_shimmer.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/studio_state_card.dart';
import '../../core/widgets/tool_card.dart';
import '../../core/widgets/tool_category_chips.dart';
import '../../data/models/generation_model.dart';
import '../../data/models/tool_model.dart';
import '../shell/shell_binding.dart';
import '../shell/shell_controller.dart';
import 'home_controller.dart';
import '../../core/theme/app_icons.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () => controller.refreshAll(force: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: AdaptiveContainer(
                shell: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Obx(() => _trendingSection(context)),
                    Obx(() => _bannersSection(context)),
                    const SizedBox(height: AppSpace.xl),
                    Obx(() {
                      final cats = controller.categories.toList();
                      if (cats.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeader(
                            title: 'Categories',
                            actionLabel: 'See all',
                            onAction: () => Get.toNamed(AppRoutes.categories),
                          ),
                          const SizedBox(height: AppSpace.sm),
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpace.md),
                            child: ToolCategoryChips(
                              categories: cats,
                              selectedSlug: controller.selectedCategory.value,
                              onSelect: controller.selectCategory,
                            ),
                          ),
                        ],
                      );
                    }),
                    Obx(
                      () => SectionHeader(
                        title: controller.toolsSectionTitle,
                        actionLabel: 'See all',
                        onAction: controller.openAllTools,
                      ),
                    ),
                    const SizedBox(height: AppSpace.sm),
                  ],
                ),
              ),
            ),
            Obx(() => _toolsSliver(context, r)),
            Obx(() => _recentSliver(context, controller.recent.toList())),
          ],
        ),
      ),
    );
  }

  Widget _trendingSection(BuildContext context) {
    if (controller.isInitialLoading) {
      return const Padding(
        padding: EdgeInsets.only(bottom: AppSpace.xl),
        child: _TrendingSkeleton(),
      );
    }
    final trending = controller.trendingTools;
    if (trending.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: '🔥 Trending'),
        const SizedBox(height: AppSpace.sm),
        _TrendingRail(tools: trending),
        const SizedBox(height: AppSpace.xl),
      ],
    );
  }

  Widget _bannersSection(BuildContext context) {
    if (controller.isInitialLoading) {
      return const _BannerSkeleton();
    }
    if (controller.banners.isEmpty) {
      return const SizedBox.shrink();
    }
    return _BannerCarousel(banners: controller.banners.toList());
  }

  Widget _toolsSliver(BuildContext context, Responsive r) {
    final loading = controller.isInitialLoading;
    final items = controller.previewTools;

    if (loading) {
      return SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: r.pagePadding),
        sliver: SliverList.separated(
          itemCount: 4,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpace.listGap),
          itemBuilder: (_, _) => const _ToolCardSkeleton(),
        ),
      );
    }

    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: r.pagePadding),
          child: _SectionEmpty(
            message:
                controller.toolsError.value ??
                (controller.selectedCategory.value != null
                    ? 'No tools in this category'
                    : 'No tools available yet'),
            onRetry: () => controller.refreshAll(force: true),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: r.pagePadding),
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpace.listGap),
        itemBuilder: (_, i) {
          final t = items[i];
          return ToolCard(
            index: i,
            title: t.name,
            subtitle: t.description,
            icon: toolIconFor(t.slug),
            imageUrl: t.imageUrl,
            creditCost: t.creditCost,
            onTap: () => Get.toNamed(AppRoutes.tool(t.slug)),
          );
        },
      ),
    );
  }

  Widget _recentSliver(BuildContext context, List<GenerationModel> recent) {
    final r = context.responsive;
    final pending =
        controller.isRecentPending || controller.recentLoading.value;
    final err = controller.recentError.value;

    return SliverToBoxAdapter(
      child: AdaptiveContainer(
        child: Column(
          children: [
            const SizedBox(height: 28),
            SectionHeader(
              title: 'Recent Creations',
              actionLabel: 'View all',
              onAction: () {
                ensureShellTab(1);
                Get.find<ShellController>().setIndex(1);
              },
            ),
            const SizedBox(height: 14),
            if (pending && recent.isEmpty)
              const _RecentSkeleton()
            else if (err != null && recent.isEmpty)
              StudioStateCard.error(
                title: controller.recentErrorIsSession.value
                    ? 'Session expired'
                    : 'Couldn’t load creations',
                message: err,
                onRetry: controller.retryRecent,
              )
            else if (recent.isEmpty)
              const FadeSlideIn(index: 4, child: _EmptyRecent())
            else
              _RecentCreationsGrid(recent: recent),
            SizedBox(height: r.contentBottom),
          ],
        ),
      ),
    );
  }
}

class _SectionEmpty extends StatelessWidget {
  const _SectionEmpty({required this.message, this.onRetry});

  final String message;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      lite: true,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Column(
        children: [
          Icon(AppIcons.tools, size: 36, color: context.colors.outline),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.texts.bodyMedium,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }
}

class _TrendingRail extends StatefulWidget {
  const _TrendingRail({required this.tools});

  final List<ToolModel> tools;

  // "Flexible" sizing target — the actual card width is derived per-build
  // from the viewport so a whole number of cards always fits exactly, never
  // a partial card cropped at the trailing edge.
  static const double _targetCardWidth = 128;
  static const double _cardHeight = 168;
  static const double _gap = AppSpace.sm;

  @override
  State<_TrendingRail> createState() => _TrendingRailState();
}

class _TrendingRailState extends State<_TrendingRail> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.tools.length;
    const gap = _TrendingRail._gap;

    return SizedBox(
      height: _TrendingRail._cardHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewport = constraints.maxWidth;

          // How many cards fit per screen near the target width.
          final rawFit =
              ((viewport + gap) / (_TrendingRail._targetCardWidth + gap))
                  .round();
          final targetCount = rawFit.clamp(2, 4);
          // Fewer items than that? Size cards to fill the row exactly —
          // never a left-aligned row with dead space on the right.
          final effectiveCount = count < targetCount ? count : targetCount;
          final cardWidth = effectiveCount > 0
              ? (viewport - (effectiveCount - 1) * gap) / effectiveCount
              : _TrendingRail._targetCardWidth;
          final itemExtent = cardWidth + gap;

          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final offset = _controller.hasClients ? _controller.offset : 0.0;
              final focus = offset + viewport / 2;

              return ListView.separated(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                itemCount: count,
                separatorBuilder: (_, _) => const SizedBox(width: gap),
                itemBuilder: (_, i) {
                  final t = widget.tools[i];
                  final itemCenter = i * itemExtent + cardWidth / 2;
                  final distance = (itemCenter - focus).abs();
                  // Full size/opacity near the viewport center; eases down
                  // toward the edges as the rail scrolls.
                  final ease =
                      1 - (distance / (viewport * 0.7)).clamp(0.0, 1.0);
                  final scale = 0.88 + 0.12 * ease;
                  final opacity = 0.55 + 0.45 * ease;

                  return FadeSlideIn(
                    index: i,
                    maxAnimated: 8,
                    child: Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: scale,
                        child: SizedBox(
                          width: cardWidth,
                          child: _TrendingCard(tool: t),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _TrendingCard extends StatelessWidget {
  const _TrendingCard({required this.tool});

  final ToolModel tool;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final accent = AppColors.accentOf(b);
    final hasImage = (tool.imageUrl ?? '').isNotEmpty;

    return AppCard(
      onTap: () => Get.toNamed(AppRoutes.tool(tool.slug)),
      lite: true,
      elevated: true,
      padding: EdgeInsets.zero,
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
                    child: hasImage
                        ? AppNetworkImage(
                            url: tool.imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            displayWidth: 320,
                            logicalWidth: 128,
                            error: Center(child: Icon(toolIconFor(tool.slug))),
                          )
                        : Center(child: Icon(toolIconFor(tool.slug))),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('🔥', style: TextStyle(fontSize: 11)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tool.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.texts.labelLarge?.copyWith(
                    color: AppColors.text(b),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${tool.creditCost} credits',
                  style: context.texts.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w600,
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

class _TrendingSkeleton extends StatelessWidget {
  const _TrendingSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _TrendingRail._cardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpace.sm),
        // Same AppCard shell + layout as the real _TrendingCard (image area
        // + caption strip) so loading never looks like a different, plainer
        // card than the one that replaces it.
        itemBuilder: (_, _) => SizedBox(
          width: _TrendingRail._targetCardWidth,
          child: AppCard(
            lite: true,
            elevated: true,
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Expanded(
                  child: AppShimmerBlock(height: double.infinity, radius: 0),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      AppShimmerBlock(height: 12, width: 64),
                      SizedBox(height: 4),
                      AppShimmerBlock(height: 10, width: 40),
                    ],
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

class _BannerSkeleton extends StatelessWidget {
  const _BannerSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        // Same AppCard shell as the real _BannerSlide, so the border/rim
        // doesn't just appear once the banner finishes loading.
        SizedBox(
          height: 132,
          child: AppCard(
            lite: true,
            padding: EdgeInsets.zero,
            child: AppShimmerBlock(height: double.infinity, radius: 0),
          ),
        ),
        SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppShimmer(width: 16, height: 6, radius: 4),
            SizedBox(width: 6),
            AppShimmer(width: 6, height: 6, radius: 4),
          ],
        ),
      ],
    );
  }
}

class _ToolCardSkeleton extends StatelessWidget {
  const _ToolCardSkeleton();

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
                  AppShimmerBlock(height: 14, width: 140),
                  SizedBox(height: 8),
                  AppShimmerBlock(height: 12, width: double.infinity),
                  SizedBox(height: 6),
                  AppShimmerBlock(height: 12, width: 72),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentSkeleton extends StatelessWidget {
  const _RecentSkeleton();

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final extent = r.value(mobile: 168.0, tablet: 184.0, desktop: 200.0);
    const gap = 10.0;
    const cols = 3;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardW = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: List.generate(
            6,
            (_) => SizedBox(
              width: cardW,
              height: extent,
              child: const AppCard(
                lite: true,
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: AppShimmerBlock(
                        height: double.infinity,
                        radius: 0,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(8, 8, 8, 8),
                      child: AppShimmerBlock(height: 12, width: 70),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 3-up grid (like the Trending rail's cards, laid out as a grid instead of
/// a horizontal scroller); a lone creation spans the full row.
class _RecentCreationsGrid extends StatelessWidget {
  const _RecentCreationsGrid({required this.recent});

  final List<GenerationModel> recent;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    const gap = 10.0;
    final single = recent.length == 1;
    final cols = single ? 1 : 3;
    final extent = single
        ? r.value(mobile: 210.0, tablet: 230.0, desktop: 250.0)
        : r.value(mobile: 168.0, tablet: 184.0, desktop: 200.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardW = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: List.generate(recent.length, (i) {
            return SizedBox(
              width: cardW,
              height: extent,
              child: _RecentThumb(
                index: i,
                compact: !single,
                generation: recent[i],
                onTap: () => Get.toNamed(
                  AppRoutes.generationResult,
                  arguments: recent[i],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel({required this.banners});

  final List<BannerModel> banners;

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final _page = PageController();
  int _index = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _open(BannerModel b) {
    switch (b.linkType) {
      case 'tool' when b.linkValue != null:
        Get.toNamed(AppRoutes.tool(b.linkValue!));
      case 'route' when b.linkValue != null:
        Get.toNamed(b.linkValue!);
      case 'credits':
        ensureShellTab(2);
        Get.find<ShellController>().setIndex(2);
      case 'category':
        Get.toNamed(AppRoutes.tools);
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 132,
          width: double.infinity,
          child: AnimatedBuilder(
            animation: _page,
            builder: (context, child) {
              return PageView.builder(
                controller: _page,
                itemCount: widget.banners.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) {
                  double scale = 1;
                  if (_page.hasClients && _page.position.haveDimensions) {
                    final page = _page.page ?? _index.toDouble();
                    scale = 1 - (page - i).abs().clamp(0.0, 1.0) * 0.08;
                  }
                  return Transform.scale(
                    scale: scale,
                    child: _BannerSlide(
                      banner: widget.banners[i],
                      onTap: () => _open(widget.banners[i]),
                    ),
                  );
                },
              );
            },
          ),
        ),
        if (widget.banners.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.banners.length, (i) {
              final on = i == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: on ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: on
                      ? AppColors.ink(Theme.of(context).brightness)
                      : context.colors.outline.withValues(alpha: 0.5),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _BannerSlide extends StatelessWidget {
  const _BannerSlide({required this.banner, required this.onTap});

  final BannerModel banner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = banner;
    return AppCard(
      onTap: onTap,
      lite: true,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AppNetworkImage(
              url: b.imageUrl,
              fit: BoxFit.cover,
              displayWidth: 900,
              logicalWidth: 420,
              logicalHeight: 160,
              error: const DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.primaryGradient),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.72),
                    Colors.black.withValues(alpha: 0.2),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    b.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (b.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      b.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentThumb extends StatelessWidget {
  const _RecentThumb({
    required this.generation,
    required this.onTap,
    this.index = 0,
    this.compact = false,
  });

  final GenerationModel generation;
  final VoidCallback onTap;
  final int index;

  /// Tighter caption for the 3-up grid — title only, like the Trending
  /// cards, so it doesn't get cramped at a third of the row width.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final accent = AppColors.accentOf(b);
    final url = generation.outputImageUrl;
    final title = toolTitleFor(generation.toolSlug);
    final when = _relativeTime(generation.completedAt ?? generation.createdAt);
    final subtitle = _recentSubtitle(generation, when);
    final icon = toolIconFor(generation.toolSlug);

    return FadeSlideIn(
      index: index,
      maxAnimated: 6,
      child: AppCard(
        onTap: onTap,
        lite: true,
        elevated: true,
        padding: EdgeInsets.zero,
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
                        logicalWidth: compact ? 160 : 220,
                        error: Center(child: Icon(icon)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 8 : 12,
                compact ? 6 : 10,
                compact ? 8 : 12,
                compact ? 8 : 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        (compact ? context.texts.labelLarge : context.texts.titleSmall)
                            ?.copyWith(
                      color: AppColors.text(b),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (subtitle.isNotEmpty) subtitle,
                        if (generation.creditCost > 0)
                          '${generation.creditCost} credits',
                      ].where((s) => s.isNotEmpty).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.labelSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _recentSubtitle(GenerationModel generation, String when) {
  final parts = <String>[];
  if (!generation.isSuccess) {
    parts.add(generation.status);
  }
  if (when.isNotEmpty) parts.add(when);
  return parts.join(' · ');
}

String _relativeTime(DateTime? dt) {
  if (dt == null) return '';
  final local = dt.toLocal();
  final diff = DateTime.now().difference(local);
  if (diff.isNegative || diff.inSeconds < 45) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  final m = local.month;
  final d = local.day;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[m - 1]} $d';
}

class _EmptyRecent extends StatelessWidget {
  const _EmptyRecent();

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final accent = AppColors.accentOf(b);

    return SizedBox(
      width: double.infinity,
      child: AppCard(
        lite: true,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: AppSpace.xl,
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: AppRadius.mdAll,
                color: accent.withValues(
                  alpha: b == Brightness.dark ? 0.14 : 0.12,
                ),
                border: Border.all(color: accent.withValues(alpha: 0.28)),
              ),
              child: Icon(AppIcons.sparkle, size: 26, color: accent),
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              'No creations yet',
              textAlign: TextAlign.center,
              style: context.texts.titleMedium?.copyWith(
                color: AppColors.text(b),
              ),
            ),
            const SizedBox(height: AppSpace.xxs),
            Text(
              'Pick a tool and turn your first photo into a studio shot.',
              textAlign: TextAlign.center,
              style: context.texts.bodyMedium?.copyWith(
                color: AppColors.textSecondary(b),
              ),
            ),
            const SizedBox(height: AppSpace.md),
            AppButton(
              label: 'Browse tools',
              expand: false,
              icon: AppIcons.tools,
              onPressed: () => Get.toNamed(AppRoutes.tools),
            ),
          ],
        ),
      ),
    );
  }
}
