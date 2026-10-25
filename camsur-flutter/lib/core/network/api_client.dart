import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;

import '../../app/routes/app_routes.dart';
import '../constants/api_constants.dart';
import '../storage/local_storage.dart';
import 'api_exception.dart';

enum _RefreshOutcome { success, invalid, transient }

class ApiClient {
  ApiClient(this._storage) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        sendTimeout: ApiConstants.connectTimeout,
        headers: const {'Accept': 'application/json'},
      ),
    );

    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient()
          ..idleTimeout = const Duration(seconds: 15)
          ..connectionTimeout = ApiConstants.connectTimeout
          ..autoUncompress = true
          ..maxConnectionsPerHost = 4;
        return client;
      },
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _storage.accessToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          if (options.data is! FormData &&
              options.headers['Content-Type'] == null) {
            options.headers['Content-Type'] = 'application/json';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final status = error.response?.statusCode;
          final path = error.requestOptions.path;
          final isAuthCall =
              path.contains('/auth/login') ||
              path.contains('/auth/register') ||
              path.contains('/auth/social') ||
              path.contains('/auth/refresh');

          if (_isTransientTransport(error)) {
            final attempt = _retryCount(error.requestOptions);
            if (attempt < 2) {
              try {
                final req = error.requestOptions;
                req.extra = {...req.extra, _retryFlag: attempt + 1};
                await Future<void>.delayed(
                  Duration(milliseconds: 220 * (attempt + 1)),
                );
                final response = await _dio.fetch(req);
                return handler.resolve(response);
              } catch (_) {}
            }
          }

          if (status == 401 && !isAuthCall) {
            final failedBearer = error.requestOptions.headers['Authorization']
                ?.toString();
            final sessionAtFail = _sessionEpoch;

            final outcome = await _tryRefresh();
            if (outcome == _RefreshOutcome.success) {
              try {
                final req = error.requestOptions;
                req.headers['Authorization'] = 'Bearer ${_storage.accessToken}';
                final response = await _dio.fetch(req);
                return handler.resolve(response);
              } on DioException catch (e) {
                if (e.response?.statusCode == 401 &&
                    sessionAtFail != _sessionEpoch &&
                    !_inLoginGrace) {
                  _forceLogout();
                }
                return handler.next(e);
              } catch (_) {
                return handler.next(error);
              }
            }

            if (outcome == _RefreshOutcome.transient) {
              // The refresh attempt itself failed to even reach the server
              // (network blip) — we genuinely don't know if the session is
              // still valid. Surface a plain connectivity error instead of
              // forwarding the original 401's "Invalid or expired token"
              // body, which would wrongly tell the user to re-log in.
              return handler.next(
                DioException(
                  requestOptions: error.requestOptions,
                  type: DioExceptionType.connectionError,
                  error: 'Could not verify session (connection issue)',
                  message: 'Could not verify session (connection issue)',
                ),
              );
            }

            if (sessionAtFail == _sessionEpoch &&
                _isCurrentSession(failedBearer) &&
                !_inLoginGrace) {
              _forceLogout();
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  static const _retryFlag = '_camsur_retry';

  final LocalStorage _storage;
  late final Dio _dio;
  Future<_RefreshOutcome>? _refreshing;

  int _sessionEpoch = 0;
  DateTime? _loginGraceUntil;

  bool get _inLoginGrace =>
      _loginGraceUntil != null && DateTime.now().isBefore(_loginGraceUntil!);

  void markFreshSession() {
    _sessionEpoch++;
    _loginGraceUntil = DateTime.now().add(const Duration(seconds: 12));
  }

  int _retryCount(RequestOptions options) {
    final v = options.extra[_retryFlag];
    if (v is int) return v;
    return 0;
  }

  bool _isTransientTransport(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.unknown) {
      final msg = '${e.message} ${e.error}'.toLowerCase();
      if (e.type != DioExceptionType.unknown) return true;
      return msg.contains('connection') ||
          msg.contains('socket') ||
          msg.contains('stream');
    }
    final msg = '${e.message} ${e.error}'.toLowerCase();
    return msg.contains('connection terminated') ||
        msg.contains('connection closed') ||
        msg.contains('connection reset') ||
        msg.contains('stream id') ||
        msg.contains('broken pipe') ||
        msg.contains('software caused connection abort');
  }

  bool _isCurrentSession(String? failedBearer) {
    final current = _storage.accessToken;
    if (current == null || current.isEmpty) return false;
    if (failedBearer == null || failedBearer.isEmpty) return true;
    return failedBearer == 'Bearer $current';
  }

  Future<_RefreshOutcome> _tryRefresh() {
    return _refreshing ??= _refreshSession().whenComplete(() {
      _refreshing = null;
    });
  }

  Future<_RefreshOutcome> _refreshSession() async {
    final refresh = _storage.refreshToken;
    if (refresh == null || refresh.isEmpty) {
      return _RefreshOutcome.invalid;
    }
    try {
      final refreshDio = Dio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          connectTimeout: ApiConstants.connectTimeout,
          receiveTimeout: const Duration(seconds: 20),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      );
      refreshDio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient()
            ..idleTimeout = const Duration(seconds: 15)
            ..connectionTimeout = ApiConstants.connectTimeout;
          return client;
        },
      );
      final res = await refreshDio.post(
        ApiConstants.refresh,
        data: {'refresh_token': refresh},
      );
      final body = res.data;
      if (body is! Map || body['success'] == false) {
        return _RefreshOutcome.invalid;
      }
      final data = body['data'];
      if (data is! Map) return _RefreshOutcome.invalid;
      final access = data['access_token']?.toString();
      final nextRefresh = data['refresh_token']?.toString();
      if (access == null || access.isEmpty) return _RefreshOutcome.invalid;
      // Await the disk write — Supabase rotates refresh tokens on every use,
      // so an unflushed write here would strand the app on a refresh token
      // that's already been consumed if the process dies right after this.
      await _storage.persistTokens(
        accessToken: access,
        refreshToken: nextRefresh,
      );
      _sessionEpoch++;
      _loginGraceUntil = DateTime.now().add(const Duration(seconds: 8));
      return _RefreshOutcome.success;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      // Any response at all means the server evaluated the refresh token and
      // rejected it — 401/403 (expired/revoked) as well as 422/400 (the
      // token was missing or malformed). None of those are fixable by
      // retrying, so they must end the session, not be reported as a
      // "connection" problem. Only a request that never reached the server
      // (timeout, no network) is genuinely transient; a 5xx is the server's
      // fault and also transient.
      if (status != null && status >= 400 && status < 500) {
        return _RefreshOutcome.invalid;
      }
      return _RefreshOutcome.transient;
    } catch (_) {
      return _RefreshOutcome.transient;
    }
  }

  void _forceLogout() {
    _sessionEpoch++;
    _loginGraceUntil = null;
    _storage.clearSession();
    if (Get.currentRoute != AppRoutes.login) {
      Get.offAllNamed(AppRoutes.login);
    }
  }

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(dynamic data)? parser,
  }) {
    return _request(() => _dio.get(path, queryParameters: query), parser);
  }

  Future<T> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? headers,
    T Function(dynamic data)? parser,
  }) {
    return _request(
      () => _dio.post(
        path,
        data: body,
        options: Options(headers: headers),
      ),
      parser,
    );
  }

  Future<T> postForm<T>(
    String path, {
    required FormData formData,
    Map<String, dynamic>? headers,
    T Function(dynamic data)? parser,
  }) {
    // Multi-photo uploads can exceed the default 20s send timeout on LAN/mobile.
    return _request(
      () => _dio.post(
        path,
        data: formData,
        options: Options(
          headers: headers,
          sendTimeout: ApiConstants.receiveTimeout,
          receiveTimeout: ApiConstants.receiveTimeout,
        ),
      ),
      parser,
    );
  }

  Future<T> delete<T>(String path, {T Function(dynamic data)? parser}) {
    return _request(() => _dio.delete(path), parser);
  }

  Future<T> _request<T>(
    Future<Response> Function() call,
    T Function(dynamic data)? parser,
  ) async {
    try {
      final res = await call();
      final parsed = _parse(res, parser);
      return parsed;
    } on DioException catch (e) {
      final res = e.response;
      if (res != null && res.data is Map) {
        final body = res.data as Map;
        throw ApiException(
          _cleanMessage(body['message']?.toString()) ?? _messageFromDio(e),
          statusCode: res.statusCode,
          data: body['data'],
        );
      }
      throw ApiException(
        _messageFromDio(e),
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Something went wrong');
    }
  }

  T _parse<T>(Response res, T Function(dynamic data)? parser) {
    final body = res.data;
    if (body is Map && body['success'] == false) {
      throw ApiException(
        _cleanMessage(body['message']?.toString()) ?? 'Request failed',
        statusCode: res.statusCode,
        data: body['data'],
      );
    }
    final data = body is Map ? body['data'] : body;
    if (parser != null) {
      try {
        return parser(data);
      } catch (_) {
        throw ApiException(
          'Couldn’t read server response',
          statusCode: res.statusCode,
        );
      }
    }
    return data as T;
  }

  String _messageFromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return _cleanMessage(data['message']?.toString()) ??
          'Something went wrong';
    }
    if (e.response?.statusCode == 401) {
      return 'Session expired. Please sign in again.';
    }
    if (_isTransientTransport(e)) {
      return 'Connection dropped. Pull to refresh and try again.';
    }
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout =>
        'Connection timed out. Check the backend is running.',
      DioExceptionType.connectionError =>
        'Can’t reach the server. Check Wi‑Fi and API address.',
      _ => _cleanMessage(e.message) ?? 'Something went wrong',
    };
  }

  String? _cleanMessage(String? raw) {
    if (raw == null) return null;
    final lower = raw.toLowerCase();
    if (lower.contains('connection terminated') ||
        lower.contains('stream id') ||
        lower.contains('connection closed') ||
        lower.contains('connection reset')) {
      return 'Connection dropped. Pull to refresh and try again.';
    }
    final cleaned = raw.replaceAll(RegExp(r'[^\x20-\x7E]'), ' ').trim();
    if (cleaned.isEmpty || cleaned.length > 160) return null;
    if (cleaned.contains(r'\x')) return null;
    return cleaned;
  }
}

ApiClient get apiClient => Get.find<ApiClient>();
