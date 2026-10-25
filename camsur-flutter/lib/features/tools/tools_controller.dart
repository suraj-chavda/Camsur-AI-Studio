import 'dart:async';

import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/network/api_exception.dart';
import '../../data/models/tool_model.dart';
import '../../data/repositories/tool_repository.dart';

class ToolsController extends GetxController {
  final tools = <ToolModel>[].obs;
  final categories = <ToolCategoryModel>[].obs;

  /// null = All categories.
  final selectedCategory = RxnString();

  final loading = true.obs;
  final error = RxnString();
  final query = ''.obs;
  final loaded = false.obs;
  Timer? _debounce;
  int _requestId = 0;

  /// Visible tools for the current chip + search (always deduped).
  List<ToolModel> get visibleTools {
    final searching = query.value.trim().isNotEmpty;
    final slug = selectedCategory.value;
    if (searching || slug == null) {
      return ToolRepository.dedupeTools(tools);
    }
    return ToolRepository.toolsForCategory(
      catalog: categories,
      flat: tools,
      categorySlug: slug,
    );
  }

  String get sectionTitle {
    if (query.value.trim().isNotEmpty) return 'Results';
    final slug = selectedCategory.value;
    if (slug == null) return 'Browse';
    for (final c in categories) {
      if (c.slug == slug) return c.name;
    }
    return 'Browse';
  }

  @override
  void onInit() {
    super.onInit();
    _applyRouteCategory();
    _hydrateCache();
    load();
  }

  void _applyRouteCategory() {
    final args = Get.arguments;
    if (args is Map && args['category'] != null) {
      final s = args['category']?.toString().trim();
      if (s != null && s.isNotEmpty) selectedCategory.value = s;
    }
  }

  void _hydrateCache() {
    final repo = Get.find<ToolRepository>();
    if (repo.hasCachedTools) {
      tools.assignAll(repo.cachedTools);
      loaded.value = true;
      loading.value = false;
      error.value = null;
    }
    if (repo.hasCachedCatalog) {
      categories.assignAll(repo.cachedCatalog);
    }
  }

  void selectCategory(String? slug) {
    selectedCategory.value = slug;
  }

  void onQueryChanged(String v) {
    query.value = v;
    // Search spans all tools — clear category filter to avoid empty+confused UX.
    if (v.trim().isNotEmpty) selectedCategory.value = null;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), load);
  }

  Future<void> load({bool force = false}) async {
    final req = ++_requestId;
    final first = tools.isEmpty && !loaded.value;
    if (first) loading.value = true;
    if (force) error.value = null;

    final searching = query.value.trim().isNotEmpty;
    final repo = Get.find<ToolRepository>();

    try {
      final catalogFuture = searching
          ? Future<List<ToolCategoryModel>>.value(categories.toList())
          : repo.catalog();

      final toolsFuture = repo.list(
        search: searching ? query.value.trim() : null,
      );

      final results = await Future.wait([catalogFuture, toolsFuture]);
      if (req != _requestId) return;

      if (!searching) {
        categories.assignAll(results[0] as List<ToolCategoryModel>);
      }
      tools.assignAll(results[1] as List<ToolModel>);
      error.value = null;
    } on ApiException catch (e) {
      if (req != _requestId) return;
      if (tools.isEmpty || searching) {
        if (searching) tools.clear();
        error.value = e.message;
      }
    } catch (_) {
      if (req != _requestId) return;
      if (tools.isEmpty || searching) {
        if (searching) tools.clear();
        error.value = 'Couldn’t load tools';
      }
    } finally {
      if (req == _requestId) {
        loaded.value = true;
        loading.value = false;
      }
    }
  }

  void openTool(ToolModel t) => Get.toNamed(AppRoutes.tool(t.slug));

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }
}
