import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../core/storage/local_storage.dart';
import '../../core/utils/app_image_cache.dart';
import '../../core/utils/catalog_images.dart';
import '../../data/models/tool_model.dart';
import '../../data/repositories/tool_repository.dart';

/// Loads `/tools/onboarding` and warms images during splash.
class OnboardingWarmup {
  OnboardingWarmup._();

  /// Public base URL of your onboarding images. Set with
  /// `--dart-define=ONBOARDING_ASSETS_BASE_URL=...`. The backend's
  /// `/tools/onboarding` endpoint overrides these when it responds.
  static const _assetsBase = String.fromEnvironment(
    'ONBOARDING_ASSETS_BASE_URL',
    defaultValue:
        'https://your-project.supabase.co/storage/v1/object/public/your-bucket/assets/onboarding',
  );

  static const catalog = [
    OnboardingSlideModel(
      slug: 'welcome',
      title: 'Stunning AI photos\nin seconds',
      subtitle:
          'Turn everyday selfies into studio-quality portraits with Camsur.',
      imageUrl:
          '$_assetsBase/welcome.png',
      icon: 'auto_awesome',
      sortOrder: 10,
    ),
    OnboardingSlideModel(
      slug: 'headshots',
      title: 'Multiple styles,\none tap',
      subtitle:
          'Headshots, LinkedIn, passport photos, and background tools — ready for you.',
      imageUrl:
          '$_assetsBase/headshots.png',
      icon: 'palette',
      sortOrder: 20,
    ),
    OnboardingSlideModel(
      slug: 'documents',
      title: 'Passport & profile\nready',
      subtitle:
          'Clean crops and compliant backgrounds for documents and professional profiles.',
      imageUrl:
          '$_assetsBase/documents.png',
      icon: 'badge',
      sortOrder: 30,
    ),
    OnboardingSlideModel(
      slug: 'private',
      title: 'Secure, private\n& reliable',
      subtitle:
          'Your photos stay protected. Credits are transparent. Results you can trust.',
      imageUrl:
          '$_assetsBase/edit.png',
      icon: 'shield',
      sortOrder: 40,
    ),
  ];

  static List<OnboardingSlideModel> slides = List.of(catalog);

  static Future<void> run(
    BuildContext context, {
    void Function(double progress, String label)? onProgress,
  }) async {
    void mark(double p, String label) => onProgress?.call(p.clamp(0, 1), label);

    mark(0.12, 'Loading studio…');
    slides = _cached() ?? List.of(catalog);

    mark(0.28, 'Fetching slides…');
    await _fetchRemote();
    if (!context.mounted) return;

    mark(0.42, 'Preparing photos…');
    await _precache(context, onProgress: mark);
    mark(1.0, 'Ready');
  }

  static Future<void> _fetchRemote() async {
    try {
      final remote = await Get.find<ToolRepository>()
          .onboarding()
          .timeout(const Duration(seconds: 4));
      if (remote.isEmpty) return;
      slides = remote;
      Get.find<LocalStorage>().onboardingSlidesJson = jsonEncode(
        remote.map((s) => s.toJson()).toList(),
      );
    } catch (_) {}
  }

  static List<OnboardingSlideModel>? _cached() {
    final raw = Get.find<LocalStorage>().onboardingSlidesJson;
    if (raw == null || raw.isEmpty) return null;
    try {
      final list = jsonDecode(raw) as List;
      final parsed = list
          .map((e) => OnboardingSlideModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return parsed.isEmpty ? null : parsed;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _precache(
    BuildContext context, {
    void Function(double progress, String label)? onProgress,
  }) async {
    final urls = slides
        .map((s) => CatalogImages.displayUrl(s.imageUrl))
        .whereType<String>()
        .toList();
    if (urls.isEmpty) return;

    Future<void> warm(String url) {
      return precacheImage(
        CachedNetworkImageProvider(url, cacheManager: AppImageCache.instance),
        context,
      ).timeout(const Duration(seconds: 8), onTimeout: () {});
    }

    for (var i = 0; i < urls.length; i++) {
      if (!context.mounted) return;
      onProgress?.call(
        0.42 + (0.56 * (i / urls.length)),
        'Preparing photos…',
      );
      await warm(urls[i]);
      // If render URL fails, still warm the original object.
      final original = CatalogImages.originalUrl(urls[i]);
      if (original != null && original != urls[i]) {
        await warm(original);
      }
    }
  }
}
