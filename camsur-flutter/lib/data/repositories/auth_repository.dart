import 'dart:convert';

import 'package:get/get.dart';

import '../../core/network/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/storage/local_storage.dart';
import '../models/user_model.dart';

class AuthRepository {
  AuthRepository(this._api, this._storage);

  final ApiClient _api;
  final LocalStorage _storage;

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      ApiConstants.login,
      body: {'email': email, 'password': password},
      parser: (d) => Map<String, dynamic>.from(d as Map),
    );
    return _persist(data);
  }

  Future<UserModel> socialLogin({
    required String provider,
    required String idToken,
    String? accessToken,
    String? nonce,
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      ApiConstants.social,
      body: {
        'provider': provider,
        'id_token': idToken,
        'access_token': ?accessToken,
        'nonce': ?nonce,
      },
      parser: (d) => Map<String, dynamic>.from(d as Map),
    );
    return _persist(data);
  }

  Future<UserModel> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      ApiConstants.register,
      body: {
        'email': email,
        'password': password,
        'display_name': ?displayName,
      },
      parser: (d) => Map<String, dynamic>.from(d as Map),
    );
    return _persist(data);
  }

  Future<UserModel?> me() async {
    if (!_storage.isLoggedIn) return null;
    try {
      final data = await _api.get<Map<String, dynamic>>(
        ApiConstants.me,
        parser: (d) => Map<String, dynamic>.from(d as Map),
      );
      final user = UserModel.fromJson(data);
      _storage.userJson = jsonEncode(user.toJson());
      return user;
    } catch (_) {
      // Never clear the session here — ApiClient owns auth expiry.
      return cachedUser();
    }
  }

  UserModel? cachedUser() {
    final raw = _storage.userJson;
    if (raw == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  void logout() => _storage.clearSession();

  Future<UserModel> _persist(Map<String, dynamic> data) async {
    final access = data['access_token']?.toString();
    if (access == null || access.isEmpty) {
      throw StateError('Login response missing access token');
    }
    final rawUser = data['user'];
    if (rawUser is! Map) {
      throw StateError('Login response missing user');
    }
    final user = UserModel.fromJson(Map<String, dynamic>.from(rawUser));
    // Await both writes — see LocalStorage.persistTokens for why an
    // unflushed write here is dangerous (lost/rotated refresh token).
    await _storage.persistTokens(
      accessToken: access,
      refreshToken: data['refresh_token']?.toString(),
    );
    await _storage.persistUserJson(jsonEncode(user.toJson()));
    // Prevent stale 401 handlers from wiping this fresh session.
    if (Get.isRegistered<ApiClient>()) {
      Get.find<ApiClient>().markFreshSession();
    }
    return user;
  }
}
