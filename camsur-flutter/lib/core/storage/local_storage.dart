import 'package:get_storage/get_storage.dart';

import '../constants/storage_keys.dart';

/// Thin wrapper over GetStorage for typed access.
class LocalStorage {
  LocalStorage() : _box = GetStorage();

  final GetStorage _box;

  String? get accessToken => _box.read<String>(StorageKeys.accessToken);
  set accessToken(String? v) => _write(StorageKeys.accessToken, v);

  String? get refreshToken => _box.read<String>(StorageKeys.refreshToken);
  set refreshToken(String? v) => _write(StorageKeys.refreshToken, v);

  String? get userJson => _box.read<String>(StorageKeys.userJson);
  set userJson(String? v) => _write(StorageKeys.userJson, v);

  bool get onboardingDone =>
      _box.read<bool>(StorageKeys.onboardingDone) ?? false;
  set onboardingDone(bool v) => _box.write(StorageKeys.onboardingDone, v);

  String? get onboardingSlidesJson =>
      _box.read<String>(StorageKeys.onboardingSlides);
  set onboardingSlidesJson(String? v) =>
      _write(StorageKeys.onboardingSlides, v);

  bool get isLoggedIn {
    final access = accessToken;
    return access != null && access.isNotEmpty;
  }

  /// True when we can attempt a silent refresh.
  bool get canRefreshSession {
    final refresh = refreshToken;
    return refresh != null && refresh.isNotEmpty;
  }

  void clearSession() {
    _box.remove(StorageKeys.accessToken);
    _box.remove(StorageKeys.refreshToken);
    _box.remove(StorageKeys.userJson);
  }

  /// Awaited token persistence for the two moments where losing a write
  /// actually breaks the session: right after login and right after a
  /// silent refresh. Supabase rotates refresh tokens on every use, so if the
  /// app process dies before this flushes to disk, the *old* (already
  /// consumed) refresh token would be all that's left — and the next silent
  /// refresh attempt would then legitimately fail even though the session
  /// was fine. The plain property setters below stay fire-and-forget for
  /// lower-stakes writes (flags, cached copies).
  Future<void> persistTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await _box.write(StorageKeys.accessToken, accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _box.write(StorageKeys.refreshToken, refreshToken);
    }
  }

  Future<void> persistUserJson(String json) =>
      _box.write(StorageKeys.userJson, json);

  void _write(String key, String? value) {
    if (value == null) {
      _box.remove(key);
    } else {
      _box.write(key, value);
    }
  }
}
