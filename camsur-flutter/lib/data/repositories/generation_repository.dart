import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/json_x.dart';
import '../models/generation_model.dart';

// TEMP DEBUG (remove once mobile/desktop identity-preservation parity is
// confirmed): logs exactly what bytes we're about to send to the backend for
// a generation, so it can be compared against what the admin panel's preview
// path sends for the same source photo. No PII beyond image dimensions/size.
Future<void> _logOutgoingPhotoDebugInfo(File f) async {
  if (!kDebugMode) return;
  try {
    final bytes = await f.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final ext = f.path.split('.').last.toLowerCase();
    debugPrint(
      '[upload-debug] path=${f.path.split(RegExp(r'[\\/]')).last} '
      'ext=$ext bytes=${bytes.length} '
      'dims=${frame.image.width}x${frame.image.height}',
    );
  } catch (e) {
    debugPrint('[upload-debug] failed to inspect $f: $e');
  }
}

class GenerationRepository {
  GenerationRepository(this._api);

  final ApiClient _api;

  static const _asyncHeaders = {'X-Async': 'true'};

  // Last-known-good snapshot — used only to paint Home/History instantly
  // while a fresh network call is in flight, or as a fallback if that fresh
  // call throws. `mine()` always hits the network; this is never used to
  // skip a request.
  List<GenerationModel>? _cachedMine;

  /// Instant hydrate for Home/History without a network round-trip.
  List<GenerationModel> get cachedMine =>
      List<GenerationModel>.unmodifiable(_cachedMine ?? const []);

  bool get hasCachedMine => _cachedMine != null && _cachedMine!.isNotEmpty;

  Future<List<GenerationModel>> mine({int limit = 20}) async {
    try {
      final list = await _api.get(
        ApiConstants.generationsMine,
        query: {'limit': limit},
        parser: _parseList,
      );

      // A *successful* response is ground truth even when empty (e.g. the
      // user deleted everything) — only a thrown failure below falls back
      // to the last good cache. Trusting a successful empty result here
      // used to get silently overridden by stale cached data.
      _cachedMine = list;
      return list;
    } catch (_) {
      if (_cachedMine != null && _cachedMine!.isNotEmpty) {
        return _cachedMine!.take(limit).toList();
      }
      rethrow;
    }
  }

  static List<GenerationModel> _parseList(dynamic data) {
    final out = <GenerationModel>[];
    for (final item in asJsonList(data)) {
      try {
        if (item is! Map) continue;
        final g = GenerationModel.fromJson(Map<String, dynamic>.from(item));
        if (g.id.isEmpty) continue;
        out.add(g);
      } catch (_) {
        // Skip corrupt rows — one bad item must not blank History.
      }
    }
    return out;
  }

  void invalidate() {
    _cachedMine = null;
  }

  /// Seed / merge after a successful generate so Home updates instantly.
  void upsertLocal(GenerationModel generation) {
    final current = List<GenerationModel>.from(_cachedMine ?? const []);
    current.removeWhere((g) => g.id == generation.id);
    current.insert(0, generation);
    _cachedMine = current;
  }

  Future<GenerationModel> getById(String id) async {
    return _api.get(
      '${ApiConstants.generations}/$id',
      parser: (d) => GenerationModel.fromJson(asJsonMap(d)),
    );
  }

  Future<void> delete(String id) async {
    await _api.delete('${ApiConstants.generations}/$id');
    if (_cachedMine != null) {
      _cachedMine = _cachedMine!.where((g) => g.id != id).toList();
    }
  }

  /// Async create from already-uploaded path/URL.
  Future<GenerationModel> create({
    required String toolSlug,
    required String inputImageUrl,
    required String source,
    Map<String, dynamic> settings = const {},
    String? styleNotes,
    String? idempotencyKey,
    bool async = true,
  }) async {
    final g = await _api.post(
      ApiConstants.generations,
      headers: async ? _asyncHeaders : null,
      body: {
        'tool_slug': toolSlug,
        'source': source,
        'input_image_url': inputImageUrl,
        'settings': settings,
        if (styleNotes != null && styleNotes.isNotEmpty)
          'style_notes': styleNotes,
        'idempotency_key': ?idempotencyKey,
      },
      parser: (d) => GenerationModel.fromJson(asJsonMap(d)),
    );
    invalidate();
    return g;
  }

  /// One-shot multipart generate (preferred for camera/gallery).
  /// Sends 1–5 photos as repeated `photos` form fields.
  Future<GenerationModel> fromPhoto({
    required File photo,
    List<File>? photos,
    required String toolSlug,
    String source = 'upload',
    Map<String, dynamic> settings = const {},
    String? styleNotes,
    String? idempotencyKey,
    bool async = true,
  }) async {
    final files = <File>[
      ...?photos,
      if (photos == null || photos.isEmpty) photo,
    ];
    // Deduplicate by path, cap at 5.
    final seen = <String>{};
    final unique = <File>[];
    for (final f in files) {
      if (seen.add(f.path)) unique.add(f);
      if (unique.length >= 5) break;
    }
    if (unique.isEmpty) unique.add(photo);

    if (kDebugMode) {
      for (final f in unique) {
        await _logOutgoingPhotoDebugInfo(f);
      }
    }

    final map = <String, dynamic>{
      'tool_slug': toolSlug,
      'source': source,
      if (settings.isNotEmpty) 'settings': jsonEncode(settings),
      if (styleNotes != null && styleNotes.isNotEmpty)
        'style_notes': styleNotes,
      'idempotency_key': ?idempotencyKey,
    };

    if (unique.length == 1) {
      final name = unique.first.path.split(RegExp(r'[\\/]')).last;
      map['photo'] = await MultipartFile.fromFile(
        unique.first.path,
        filename: name,
      );
    } else {
      map['photos'] = [
        for (final f in unique)
          await MultipartFile.fromFile(
            f.path,
            filename: f.path.split(RegExp(r'[\\/]')).last,
          ),
      ];
    }

    final form = FormData.fromMap(map);

    final g = await _api.postForm(
      ApiConstants.generationsFromPhoto,
      formData: form,
      headers: async ? _asyncHeaders : null,
      parser: (d) => GenerationModel.fromJson(asJsonMap(d)),
    );
    invalidate();
    return g;
  }

  /// Poll until terminal status or timeout.
  ///
  /// Starts faster (feels snappier when jobs finish early), then eases out
  /// so we do not hammer the API during long BFL runs.
  Future<GenerationModel> waitUntilDone(
    String id, {
    void Function(GenerationModel)? onTick,
    Duration initialInterval = const Duration(milliseconds: 700),
    Duration maxInterval = const Duration(milliseconds: 1600),
    // Generous on purpose: this is wall-clock, so time spent backgrounded
    // counts against it too. Returning early just means the caller loops
    // and calls this again (see ToolDetailController._pollUntilDone) — it
    // never causes a false "failed", but a short deadline here would mean
    // needlessly restarting the poll loop after every brief backgrounding.
    Duration timeout = const Duration(minutes: 6),
  }) async {
    final deadline = DateTime.now().add(timeout);
    var interval = initialInterval;
    var first = true;
    var consecutiveFailures = 0;
    // The job runs async on the server — backgrounding the app (which tears
    // down in-flight sockets, especially on iOS) or a plain network blip
    // must not surface as "generation failed" here; it only means this one
    // poll request didn't land. Only give up after several failures in a
    // row, or once the overall deadline has actually passed.
    const maxConsecutiveFailures = 6;
    while (true) {
      if (!first) {
        await Future<void>.delayed(interval);
        final nextMs = (interval.inMilliseconds * 1.25).round();
        interval = Duration(
          milliseconds: nextMs.clamp(
            initialInterval.inMilliseconds,
            maxInterval.inMilliseconds,
          ),
        );
      }
      first = false;

      GenerationModel g;
      try {
        g = await getById(id);
      } catch (_) {
        consecutiveFailures++;
        if (consecutiveFailures >= maxConsecutiveFailures ||
            DateTime.now().isAfter(deadline)) {
          rethrow;
        }
        continue;
      }
      consecutiveFailures = 0;

      onTick?.call(g);
      if (g.isTerminal) {
        upsertLocal(g);
        return g;
      }
      if (DateTime.now().isAfter(deadline)) {
        upsertLocal(g);
        return g;
      }
    }
  }
}
