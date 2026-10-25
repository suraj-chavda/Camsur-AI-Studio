import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/json_x.dart';
import '../models/tool_model.dart';

class ToolRepository {
  ToolRepository(this._api);

  final ApiClient _api;

  // Last-known-good snapshots — used only (a) to paint a screen instantly
  // while a fresh network call is in flight, and (b) as a fallback if that
  // fresh call throws. Every call below always hits the network first;
  // nothing here is a TTL/staleness cache that skips a request.
  List<ToolModel>? _cachedTools;
  List<ToolCategoryModel>? _cachedCatalog;
  List<BannerModel>? _cachedBanners;

  bool get hasCachedTools =>
      _cachedTools != null && _cachedTools!.isNotEmpty;

  List<ToolModel> get cachedTools =>
      List<ToolModel>.unmodifiable(_cachedTools ?? const []);

  bool get hasCachedCatalog =>
      _cachedCatalog != null && _cachedCatalog!.isNotEmpty;

  List<ToolCategoryModel> get cachedCatalog =>
      List<ToolCategoryModel>.unmodifiable(_cachedCatalog ?? const []);

  bool get hasCachedBanners =>
      _cachedBanners != null && _cachedBanners!.isNotEmpty;

  List<BannerModel> get cachedBanners =>
      List<BannerModel>.unmodifiable(_cachedBanners ?? const []);

  /// Flatten catalog tools once by slug (first category wins).
  static List<ToolModel> dedupeTools(Iterable<ToolModel> tools) {
    final seen = <String>{};
    final out = <ToolModel>[];
    for (final t in tools) {
      if (t.slug.isEmpty || !seen.add(t.slug)) continue;
      out.add(t);
    }
    out.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return out;
  }

  /// Tools for one category — catalog nest first, else filter flat list.
  static List<ToolModel> toolsForCategory({
    required List<ToolCategoryModel> catalog,
    required List<ToolModel> flat,
    required String categorySlug,
  }) {
    for (final c in catalog) {
      if (c.slug == categorySlug) {
        final nested = dedupeTools(c.tools);
        if (nested.isNotEmpty) return nested;
        break;
      }
    }
    return dedupeTools(flat.where((t) => t.category == categorySlug));
  }

  Future<List<ToolModel>> list({String? search}) async {
    final q = search?.trim();
    final isFlatList = q == null || q.isEmpty;

    try {
      final items = await _api.get(
        ApiConstants.tools,
        query: isFlatList ? null : {'search': q},
        parser: _parseTools,
      );

      if (isFlatList) {
        if (items.isNotEmpty) {
          _cachedTools = items;
          return items;
        }
        // A genuinely empty server response is ground truth, unless we have
        // a last-known-good snapshot to fall back on.
        if (hasCachedTools) return List<ToolModel>.from(_cachedTools!);
      }
      return items;
    } catch (_) {
      if (isFlatList && hasCachedTools) {
        return List<ToolModel>.from(_cachedTools!);
      }
      rethrow;
    }
  }

  static List<ToolModel> _parseTools(dynamic data) {
    final list = <ToolModel>[];
    for (final e in asJsonList(data)) {
      try {
        final t = ToolModel.fromJson(asJsonMap(e));
        if (t.slug.isNotEmpty) list.add(t);
      } catch (_) {}
    }
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  Future<List<ToolCategoryModel>> catalog({String? search}) async {
    final q = search?.trim();
    final isFlatList = q == null || q.isEmpty;

    try {
      final items = await _api.get(
        ApiConstants.toolsCatalog,
        query: isFlatList ? null : {'search': q},
        parser: (d) {
          final list = <ToolCategoryModel>[];
          for (final e in asJsonList(d)) {
            try {
              list.add(ToolCategoryModel.fromJson(asJsonMap(e)));
            } catch (_) {}
          }
          list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          return list;
        },
      );

      if (isFlatList) {
        if (items.isNotEmpty) {
          _cachedCatalog = items;
          // Warm flat cache from catalog when tools list is empty.
          if (_cachedTools == null || _cachedTools!.isEmpty) {
            final flat = dedupeTools(items.expand((c) => c.tools));
            if (flat.isNotEmpty) _cachedTools = flat;
          }
          return items;
        }
        if (hasCachedCatalog) return List<ToolCategoryModel>.from(_cachedCatalog!);
      }
      return items;
    } catch (_) {
      if (isFlatList && hasCachedCatalog) {
        return List<ToolCategoryModel>.from(_cachedCatalog!);
      }
      rethrow;
    }
  }

  Future<List<BannerModel>> banners() async {
    try {
      final items = await _api.get(
        ApiConstants.toolsBanners,
        parser: (d) {
          final list = <BannerModel>[];
          for (final e in asJsonList(d)) {
            try {
              list.add(BannerModel.fromJson(asJsonMap(e)));
            } catch (_) {}
          }
          list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          return list;
        },
      );
      if (items.isNotEmpty) {
        _cachedBanners = items;
        return items;
      }
      if (hasCachedBanners) return List<BannerModel>.from(_cachedBanners!);
      return items;
    } catch (_) {
      if (hasCachedBanners) return List<BannerModel>.from(_cachedBanners!);
      rethrow;
    }
  }

  Future<List<OnboardingSlideModel>> onboarding() async {
    return _api.get(
      ApiConstants.toolsOnboarding,
      parser: (d) {
        final items = <OnboardingSlideModel>[];
        for (final e in asJsonList(d)) {
          try {
            items.add(OnboardingSlideModel.fromJson(asJsonMap(e)));
          } catch (_) {}
        }
        items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        return items;
      },
    );
  }

  Future<ToolModel?> bySlug(String slug) async {
    final needle = slug.trim();
    if (needle.isEmpty) return null;

    final tools = await list();
    for (final t in tools) {
      if (t.slug == needle) return t;
    }
    return null;
  }

  void invalidate() {
    _cachedTools = null;
    _cachedCatalog = null;
    _cachedBanners = null;
  }
}
