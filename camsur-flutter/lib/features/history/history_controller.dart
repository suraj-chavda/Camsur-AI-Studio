import 'package:get/get.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/generation_model.dart';
import '../../data/repositories/generation_repository.dart';

class HistoryController extends GetxController {
  /// Flat feed from API / cache, newest first.
  final items = <GenerationModel>[].obs;

  final loading = true.obs;
  final error = RxnString();
  final loaded = false.obs;

  @override
  void onInit() {
    super.onInit();
    final repo = Get.find<GenerationRepository>();
    if (repo.hasCachedMine) {
      seedFrom(repo.cachedMine);
    }
    load();
  }

  /// Called by Home right after it loads its own (smaller) recent-creations
  /// preview, before History has necessarily loaded anything itself.
  void seedFrom(List<GenerationModel> list) {
    if (list.isEmpty && items.isNotEmpty) return;
    if (items.isNotEmpty && list.length < items.length) return;
    _apply(list);
    error.value = null;
    loaded.value = true;
    loading.value = false;
  }

  /// Called by Home every time it (re)loads recent creations, even if
  /// History already has its own (larger) list loaded — merges by id so a
  /// generation that just finished on Home shows up in History without
  /// waiting for the user to separately pull-to-refresh that tab too.
  void mergeFresh(List<GenerationModel> list) {
    if (list.isEmpty) return;
    if (items.isEmpty) {
      seedFrom(list);
      return;
    }
    final byId = {for (final g in items) g.id: g};
    for (final g in list) {
      byId[g.id] = g;
    }
    final merged = byId.values.toList()
      ..sort((a, b) {
        final ad = a.createdAt;
        final bd = b.createdAt;
        if (ad == null || bd == null) return 0;
        return bd.compareTo(ad);
      });
    _apply(merged);
    error.value = null;
  }

  Future<void> load({bool force = false}) async {
    final first = items.isEmpty && !loaded.value;
    if (first) loading.value = true;
    if (force) error.value = null;

    try {
      final list = await Get.find<GenerationRepository>().mine(limit: 40);
      _apply(list);
      error.value = null;
    } on ApiException catch (e) {
      if (items.isEmpty) error.value = e.message;
    } catch (_) {
      if (items.isEmpty) {
        error.value = 'Couldn’t load your history';
      }
    } finally {
      loaded.value = true;
      loading.value = false;
    }
  }

  void _apply(List<GenerationModel> list) {
    items.assignAll(list);
  }
}
