import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/network/api_exception.dart';
import '../../data/models/generation_model.dart';
import '../../data/models/tool_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/credit_repository.dart';
import '../../data/repositories/generation_repository.dart';
import '../../data/repositories/tool_repository.dart';
import '../history/history_controller.dart';

enum HomeLoadPhase { initial, refreshing, ready }

class HomeController extends GetxController {
  final user = Rxn<UserModel>();
  final balance = 0.obs;
  final tools = <ToolModel>[].obs;
  final categories = <ToolCategoryModel>[].obs;
  final selectedCategory = RxnString();
  final banners = <BannerModel>[].obs;
  final recent = <GenerationModel>[].obs;

  final phase = HomeLoadPhase.initial.obs;
  final toolsError = RxnString();
  final bannersError = RxnString();
  final recentError = RxnString();
  final recentErrorIsSession = false.obs;
  final recentLoading = true.obs;
  final recentLoaded = false.obs;

  bool get isInitialLoading =>
      phase.value == HomeLoadPhase.initial && tools.isEmpty;

  bool get isRefreshing => phase.value == HomeLoadPhase.refreshing;

  bool get isRecentPending => recentLoading.value && !recentLoaded.value;

  /// Admin-curated "Trending" rail — fully data-driven (tools.is_trending /
  /// trending_sort_order), so the lineup changes from the admin panel alone.
  List<ToolModel> get trendingTools {
    final list = tools.where((t) => t.isTrending).toList()
      ..sort((a, b) => a.trendingSortOrder.compareTo(b.trendingSortOrder));
    return list;
  }

  /// Home preview list — one filtered stream, never duplicated sections.
  List<ToolModel> get previewTools {
    final slug = selectedCategory.value;
    final list = slug == null
        ? ToolRepository.dedupeTools(tools)
        : ToolRepository.toolsForCategory(
            catalog: categories,
            flat: tools,
            categorySlug: slug,
          );
    return list.take(4).toList();
  }

  String get toolsSectionTitle {
    final slug = selectedCategory.value;
    if (slug == null) return 'Popular Tools';
    for (final c in categories) {
      if (c.slug == slug) return c.name;
    }
    return 'Popular Tools';
  }

  void selectCategory(String? slug) {
    selectedCategory.value = slug;
  }

  void openAllTools() {
    final args = selectedCategory.value == null
        ? null
        : {'category': selectedCategory.value};
    Get.toNamed(AppRoutes.tools, arguments: args);
  }

  @override
  void onReady() {
    super.onReady();
    _hydrateCaches();
    refreshAll();
  }

  void _hydrateCaches() {
    final toolsRepo = Get.find<ToolRepository>();
    if (toolsRepo.hasCachedTools) {
      tools.assignAll(toolsRepo.cachedTools);
      toolsError.value = null;
    }
    if (toolsRepo.hasCachedCatalog) {
      categories.assignAll(toolsRepo.cachedCatalog);
    }
    if (toolsRepo.hasCachedBanners) {
      banners.assignAll(toolsRepo.cachedBanners);
      bannersError.value = null;
    }

    final genRepo = Get.find<GenerationRepository>();
    if (genRepo.hasCachedMine) {
      recent.assignAll(genRepo.cachedMine.take(4));
      recentLoaded.value = true;
      recentLoading.value = false;
      recentError.value = null;
    }
  }

  Future<void> refreshAll({bool force = false}) async {
    final first = tools.isEmpty && banners.isEmpty;
    phase.value = first ? HomeLoadPhase.initial : HomeLoadPhase.refreshing;
    if (force) {
      toolsError.value = null;
      bannersError.value = null;
    }

    user.value = Get.find<AuthRepository>().cachedUser();

    // Sequential catalog fetch — parallel sockets flake on emulator ↔ host.
    await _loadCatalog();
    await _loadTools();
    await _loadBanners();

    // Session bits — still gentle; balance/me are small.
    await _loadRecent(force: force);
    await Future.wait([_loadMe(), _loadBalance()]);

    phase.value = HomeLoadPhase.ready;
  }

  Future<void> _loadMe() async {
    try {
      final me = await Get.find<AuthRepository>().me();
      if (me != null) user.value = me;
    } catch (_) {}
  }

  Future<void> _loadBalance() async {
    try {
      balance.value = (await Get.find<CreditRepository>().balance()).balance;
    } catch (_) {}
  }

  Future<void> _loadCatalog() async {
    try {
      final list = await Get.find<ToolRepository>().catalog();
      if (list.isNotEmpty) {
        categories.assignAll(list);
      }
    } catch (_) {
      // Categories are optional chrome — tools list still works.
    }
  }

  Future<void> _loadTools() async {
    try {
      final list = await Get.find<ToolRepository>().list();
      if (list.isNotEmpty) {
        tools.assignAll(list);
        toolsError.value = null;
      } else if (tools.isEmpty) {
        toolsError.value = 'No tools available yet';
      }
    } on ApiException catch (e) {
      if (tools.isEmpty) toolsError.value = e.message;
    } catch (_) {
      if (tools.isEmpty) {
        toolsError.value = 'Couldn’t load tools';
      }
    }
  }

  Future<void> _loadBanners() async {
    try {
      final list = await Get.find<ToolRepository>().banners();
      banners.assignAll(list);
      bannersError.value = null;
    } on ApiException catch (e) {
      if (banners.isEmpty) bannersError.value = e.message;
    } catch (_) {
      if (banners.isEmpty) {
        bannersError.value = 'Couldn’t load banners';
      }
    }
  }

  Future<void> _loadRecent({bool force = false}) async {
    final first = !recentLoaded.value && recent.isEmpty;
    if (first) recentLoading.value = true;
    if (force) recentError.value = null;

    try {
      final list = await Get.find<GenerationRepository>().mine(limit: 16);
      recent.assignAll(list.take(4));
      recentError.value = null;
      recentErrorIsSession.value = false;
      _syncHistory(list);
    } on ApiException catch (e) {
      if (recent.isEmpty) {
        final isSession = e.statusCode == 401;
        recentErrorIsSession.value = isSession;
        recentError.value = isSession
            ? 'Your session needs refreshing — pull down to try again.'
            : e.message;
      }
    } catch (_) {
      if (recent.isEmpty) {
        recentErrorIsSession.value = false;
        recentError.value = 'Couldn’t load recent creations';
      }
    } finally {
      recentLoaded.value = true;
      recentLoading.value = false;
    }
  }

  void _syncHistory(List<GenerationModel> list) {
    if (!Get.isRegistered<HistoryController>()) return;
    Get.find<HistoryController>().mergeFresh(list);
  }

  Future<void> refreshRecentOnly() => _loadRecent(force: true);

  Future<void> retryRecent() => _loadRecent(force: true);

  Future<void> retryTools() => _loadTools();
}
