import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/extensions/context_x.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/tool_icons.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/studio_state_card.dart';
import '../../core/widgets/tool_card.dart';
import '../../core/widgets/tool_category_chips.dart';
import '../../data/models/tool_model.dart';
import 'tools_controller.dart';

class ToolsView extends GetView<ToolsController> {
  const ToolsView({super.key});

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final b = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('All Tools'),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(r.pagePadding, 0, r.pagePadding, 12),
            child: AppCard(
              lite: true,
              elevated: false,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
              child: TextField(
                onChanged: controller.onQueryChanged,
                style: context.texts.bodyMedium?.copyWith(
                  color: AppColors.text(b),
                ),
                decoration: InputDecoration(
                  hintText: 'Search tools…',
                  hintStyle: context.texts.bodyMedium?.copyWith(
                    color: AppColors.textMuted(b),
                  ),
                  prefixIcon: Icon(
                    AppIcons.search,
                    color: AppColors.textMuted(b),
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ),
          Obx(() {
            final searching = controller.query.value.trim().isNotEmpty;
            final cats = controller.categories.toList();
            if (searching || cats.isEmpty) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ToolCategoryChips(
                categories: cats,
                selectedSlug: controller.selectedCategory.value,
                onSelect: controller.selectCategory,
                padding: EdgeInsets.symmetric(horizontal: r.pagePadding),
              ),
            );
          }),
          Expanded(
            child: Obx(() {
              final loading = controller.loading.value;
              final tools = controller.visibleTools;
              final err = controller.error.value;
              final searching = controller.query.value.trim().isNotEmpty;
              final title = controller.sectionTitle;

              return RefreshIndicator(
                onRefresh: () => controller.load(force: true),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: KeyedSubtree(
                    key: ValueKey(
                      loading && tools.isEmpty
                          ? 'tools-loading'
                          : tools.isEmpty
                              ? 'tools-empty-${controller.selectedCategory.value}'
                              : 'tools-${controller.selectedCategory.value}-${tools.length}',
                    ),
                    child: _buildBody(
                      context,
                      loading: loading,
                      tools: tools,
                      err: err,
                      searching: searching,
                      title: title,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool loading,
    required List<ToolModel> tools,
    required String? err,
    required bool searching,
    required String title,
  }) {
    final r = context.responsive;

    if (loading && tools.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          r.pagePadding,
          r.contentTop,
          r.pagePadding,
          r.contentBottom,
        ),
        children: [
          SectionHeader(title: title),
          const SizedBox(height: AppSpace.listGap),
          const StudioLoadingBlock(),
        ],
      );
    }

    if (tools.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          r.pagePadding,
          r.contentTop,
          r.pagePadding,
          r.contentBottom,
        ),
        children: [
          SectionHeader(title: title),
          const SizedBox(height: AppSpace.listGap),
          err != null
              ? StudioStateCard.error(
                  message: err,
                  onRetry: () => controller.load(force: true),
                )
              : StudioStateCard.empty(
                  title: searching ? 'No matches' : 'No tools here',
                  message: searching
                      ? 'Try a different search term.'
                      : 'Nothing in this category yet — try All.',
                  icon: searching ? AppIcons.searchOff : AppIcons.tools,
                  onRetry: searching
                      ? null
                      : () => controller.load(force: true),
                ),
        ],
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              r.pagePadding,
              r.contentTop,
              r.pagePadding,
              AppSpace.listGap,
            ),
            child: SectionHeader(title: title),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            r.pagePadding,
            0,
            r.pagePadding,
            r.contentBottom,
          ),
          sliver: SliverList.separated(
            itemCount: tools.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppSpace.listGap),
            itemBuilder: (_, i) {
              final t = tools[i];
              return ToolCard(
                index: i,
                title: t.name,
                subtitle: t.description,
                icon: toolIconFor(t.slug),
                imageUrl: t.imageUrl,
                creditCost: t.creditCost,
                onTap: () => controller.openTool(t),
              );
            },
          ),
        ),
      ],
    );
  }
}
