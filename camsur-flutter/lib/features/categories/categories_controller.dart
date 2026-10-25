import 'package:get/get.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/tool_model.dart';
import '../../data/repositories/tool_repository.dart';

/// Dedicated "browse by category" screen — one deliberate destination for
/// people who want to shop tools category-first, distinct from Home's
/// quick filter chips.
class CategoriesController extends GetxController {
  final categories = <ToolCategoryModel>[].obs;
  final loading = true.obs;
  final error = RxnString();
  final loaded = false.obs;

  @override
  void onInit() {
    super.onInit();
    _hydrateCache();
    load();
  }

  void _hydrateCache() {
    final repo = Get.find<ToolRepository>();
    if (repo.hasCachedCatalog) {
      categories.assignAll(repo.cachedCatalog);
      loaded.value = true;
      loading.value = false;
    }
  }

  Future<void> load({bool force = false}) async {
    final first = categories.isEmpty && !loaded.value;
    if (first) loading.value = true;
    if (force) error.value = null;

    try {
      final list = await Get.find<ToolRepository>().catalog();
      categories.assignAll(list);
      error.value = null;
    } on ApiException catch (e) {
      if (categories.isEmpty) error.value = e.message;
    } catch (_) {
      if (categories.isEmpty) {
        error.value = 'Couldn’t load categories';
      }
    } finally {
      loaded.value = true;
      loading.value = false;
    }
  }
}
