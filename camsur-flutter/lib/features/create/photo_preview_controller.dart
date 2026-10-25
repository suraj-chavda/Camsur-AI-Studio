import 'dart:io';

import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/routes/app_routes.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/photo_pick.dart';
import '../../data/models/tool_model.dart';
import '../../data/repositories/tool_repository.dart';
import '../shell/capture_sheet.dart';

class PhotoPreviewController extends GetxController {
  final photos = <File>[].obs;
  final source = 'upload'.obs;
  final tools = <ToolModel>[].obs;
  final loadingTools = true.obs;
  final toolsError = RxnString();

  File? get photo => photos.isEmpty ? null : photos.first;

  int get maxPhotos => PhotoPick.maxCount;

  bool get canAddMore => photos.length < maxPhotos;

  @override
  void onInit() {
    super.onInit();
    final session = PhotoSession.fromArguments(Get.arguments);
    if (session != null) {
      photos.assignAll(session.files.take(maxPhotos));
      source.value = session.source;
    }
    _hydrateCache();
    _loadTools();
  }

  void _hydrateCache() {
    final repo = Get.find<ToolRepository>();
    if (!repo.hasCachedTools) return;
    tools.assignAll(repo.cachedTools);
    loadingTools.value = false;
    toolsError.value = null;
  }

  Future<void> _loadTools({bool force = false}) async {
    final first = tools.isEmpty;
    if (first) loadingTools.value = true;
    if (force) toolsError.value = null;

    final repo = Get.find<ToolRepository>();
    try {
      final list = await repo.list();
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
    } finally {
      loadingTools.value = false;
    }
  }

  Future<void> addFromGallery() => _add(ImageSource.gallery);

  Future<void> addFromCamera() => _add(ImageSource.camera);

  /// Replaces the whole set (used by Retake toolbar).
  Future<void> replaceFromGallery() => _replaceAll(ImageSource.gallery);

  Future<void> replaceFromCamera() => _replaceAll(ImageSource.camera);

  Future<void> _add(ImageSource src) async {
    if (!canAddMore) {
      Get.snackbar('Photos', 'You can add up to $maxPhotos photos.');
      return;
    }
    final picked = await PhotoPick.pick(
      source: src,
      alreadyHave: photos.length,
      limit: maxPhotos,
    );
    if (picked.isEmpty) return;
    photos.assignAll(PhotoPick.merge(photos.toList(), picked, limit: maxPhotos));
    source.value = src == ImageSource.camera ? 'camera' : 'upload';
  }

  Future<void> _replaceAll(ImageSource src) async {
    final picked = await PhotoPick.pick(source: src, alreadyHave: 0);
    if (picked.isEmpty) return;
    photos.assignAll(picked.take(maxPhotos));
    source.value = src == ImageSource.camera ? 'camera' : 'upload';
  }

  void removeAt(int index) {
    if (index < 0 || index >= photos.length) return;
    photos.removeAt(index);
  }

  void continueWithTool(ToolModel tool) {
    if (photos.isEmpty) return;
    final need = tool.minInputImages.clamp(1, PhotoPick.maxCount);
    if (photos.isEmpty || photos.length < need) {
      Get.snackbar(
        'Add a photo',
        '${tool.name} needs at least $need photo${need == 1 ? '' : 's'} (up to ${tool.maxInputImages.clamp(1, PhotoPick.maxCount)}).',
      );
      return;
    }
    Get.toNamed(
      AppRoutes.tool(tool.slug),
      arguments: PhotoSession(
        files: List<File>.from(photos.take(tool.maxInputImages.clamp(1, 5))),
        source: source.value,
      ).toArguments(),
    );
  }

  Future<void> retryTools() => _loadTools(force: true);
}
