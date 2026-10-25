import 'dart:io';

import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

/// Shared capture / gallery selection — hard product cap is 5 photos.
class PhotoPick {
  PhotoPick._();

  static const maxCount = 5;
  static const maxWidth = 2048.0;
  static const maxHeight = 2048.0;
  static const imageQuality = 92;

  static final ImagePicker _picker = ImagePicker();

  /// Returns newly picked files (does not include [alreadyHave] paths).
  /// Gallery uses multi-select when room for more than one; camera always one.
  static Future<List<File>> pick({
    required ImageSource source,
    int alreadyHave = 0,
    int limit = maxCount,
  }) async {
    final room = (limit.clamp(1, maxCount)) - alreadyHave;
    if (room <= 0) {
      Get.snackbar('Photos', 'You can add up to $maxCount photos.');
      return const [];
    }

    try {
      if (source == ImageSource.gallery && room > 1) {
        final picked = await _picker.pickMultiImage(
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          imageQuality: imageQuality,
          limit: room,
        );
        return [
          for (final x in picked) File(x.path),
        ];
      }

      final x = await _picker.pickImage(
        source: source,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
      );
      if (x == null) return const [];
      return [File(x.path)];
    } catch (_) {
      Get.snackbar(
        'Photo',
        source == ImageSource.camera
            ? 'Could not open camera. Check permissions.'
            : 'Could not open gallery. Check permissions.',
      );
      return const [];
    }
  }

  /// Merge [incoming] into [current], capped at [limit].
  /// When [allowDuplicates] is true (Together), the same file path may be added
  /// again as an identity reference for the same person.
  static List<File> merge(
    List<File> current,
    List<File> incoming, {
    int limit = maxCount,
    bool allowDuplicates = false,
  }) {
    final cap = limit.clamp(1, maxCount);
    final seen = <String>{for (final f in current) f.path};
    final out = List<File>.from(current);
    for (final f in incoming) {
      if (out.length >= cap) break;
      if (!allowDuplicates && !seen.add(f.path)) continue;
      if (allowDuplicates) seen.add(f.path);
      out.add(f);
    }
    return out;
  }
}
