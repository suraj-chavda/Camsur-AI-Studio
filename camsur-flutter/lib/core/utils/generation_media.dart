import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'app_image_cache.dart';

/// Download / share / save generated studio images.
class GenerationMedia {
  GenerationMedia._();

  static bool hasImage(String? url) =>
      url != null && url.trim().isNotEmpty && url.startsWith('http');

  /// Resolve a network image to a local file (cache-first).
  static Future<File> resolveFile(String url, {String? preferredName}) async {
    final cached = await AppImageCache.instance.getSingleFile(url);
    if (preferredName == null || preferredName.trim().isEmpty) {
      return cached;
    }

    final dir = await getTemporaryDirectory();
    final ext = p.extension(cached.path).isNotEmpty
        ? p.extension(cached.path)
        : '.jpg';
    final safe = preferredName
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .clampLength(48);
    final out = File(p.join(dir.path, '$safe$ext'));
    if (out.path != cached.path) {
      await cached.copy(out.path);
      return out;
    }
    return cached;
  }

  static Future<void> share(
    String url, {
    String? fileName,
    String? text,
  }) async {
    final file = await resolveFile(url, preferredName: fileName ?? 'camsur');
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: _mimeFor(file.path))],
        text: text,
        title: 'Camsur Pro',
      ),
    );
  }

  static Future<void> saveToGallery(String url, {String? fileName}) async {
    final hasAccess = await Gal.hasAccess(toAlbum: true);
    if (!hasAccess) {
      final granted = await Gal.requestAccess(toAlbum: true);
      if (!granted) {
        throw StateError('Photo library permission is required to save.');
      }
    }

    final file = await resolveFile(url, preferredName: fileName ?? 'camsur');
    await Gal.putImage(file.path, album: 'Camsur Pro');
  }

  static String _mimeFor(String path) {
    final ext = p.extension(path).toLowerCase();
    return switch (ext) {
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      '.gif' => 'image/gif',
      _ => 'image/jpeg',
    };
  }

  /// Runs [action] with snackbars for success / failure.
  static Future<void> run({
    required Future<void> Function() action,
    required String busyLabel,
    String? doneLabel,
  }) async {
    if (kIsWeb) {
      Get.snackbar('Unavailable', 'This action isn’t supported on web yet.');
      return;
    }
    try {
      await action();
      if (doneLabel != null) {
        Get.snackbar('Done', doneLabel, snackPosition: SnackPosition.BOTTOM);
      }
    } on GalException catch (e) {
      Get.snackbar(
        'Couldn’t save',
        e.type.message,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Something went wrong',
        e.toString().clampLength(120),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}

extension on String {
  String clampLength(int max) =>
      length <= max ? this : substring(0, max);
}
