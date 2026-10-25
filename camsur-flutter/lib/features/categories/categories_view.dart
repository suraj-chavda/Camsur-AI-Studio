import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/extensions/context_x.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/tool_icons.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../core/widgets/studio_state_card.dart';
import '../../data/models/tool_model.dart';
import 'categories_controller.dart';

/// One deliberate destination for browsing tools category-first — every
/// category as a full card (image, name, tool count), tap straight through
/// to that category's tools.
class CategoriesView extends GetView<CategoriesController> {
  const CategoriesView({super.key});

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Categories'),
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.load(force: true),
        child: Obx(() {
          final loading = controller.loading.value;
          final cats = controller.categories.toList();
          final err = controller.error.value;

          if (loading && cats.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                r.pagePadding,
                r.contentTop,
                r.pagePadding,
                r.contentBottom,
              ),
              children: const [StudioLoadingBlock()],
            );
          }

          if (cats.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                r.pagePadding,
                r.contentTop,
                r.pagePadding,
                r.contentBottom,
              ),
              children: [
                err != null
                    ? StudioStateCard.error(
                        message: err,
                        onRetry: () => controller.load(force: true),
                      )
                    : StudioStateCard.empty(
                        title: 'No categories yet',
                        message: 'Check back soon.',
                        icon: AppIcons.tag,
                      ),
              ],
            );
          }

          final columns = r.gridColumns(mobile: 2, tablet: 3, desktop: 4);
          return GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              r.pagePadding,
              r.contentTop,
              r.pagePadding,
              r.contentBottom,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: AppSpace.sm,
              mainAxisSpacing: AppSpace.sm,
              childAspectRatio: 0.86,
            ),
            itemCount: cats.length,
            itemBuilder: (_, i) =>
                _CategoryGridCard(index: i, category: cats[i]),
          );
        }),
      ),
    );
  }
}

class _CategoryGridCard extends StatelessWidget {
  const _CategoryGridCard({required this.category, this.index = 0});

  final ToolCategoryModel category;
  final int index;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final accent = AppColors.accentOf(b);
    final hasImage = (category.imageUrl ?? '').isNotEmpty;
    final icon = categoryIconFor(icon: category.icon, slug: category.slug);
    final count = category.tools.length;

    return FadeSlideIn(
      index: index,
      maxAnimated: 10,
      child: AppCard(
        onTap: () => Get.toNamed(
          AppRoutes.tools,
          arguments: {'category': category.slug},
        ),
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
                child: hasImage
                    ? AppNetworkImage(
                        url: category.imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        displayWidth: 400,
                        logicalWidth: 160,
                        error: _CategoryIconFallback(icon: icon, brightness: b),
                      )
                    : _CategoryIconFallback(icon: icon, brightness: b),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.titleSmall?.copyWith(
                      color: AppColors.text(b),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '$count tool${count == 1 ? '' : 's'}',
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

class _CategoryIconFallback extends StatelessWidget {
  const _CategoryIconFallback({required this.icon, required this.brightness});

  final IconData icon;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final isDark = brightness == Brightness.dark;
    final accent = AppColors.accentOf(brightness);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161616) : const Color(0xFFF0F0F4),
      ),
      child: Center(
        child: Icon(icon, color: accent, size: AppSize.iconLg),
      ),
    );
  }
}
