import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Shared disk cache for network images — longer timeouts, light retries.
class AppImageCache {
  AppImageCache._();

  static const key = 'camsurImageCache';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 240,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );
}
