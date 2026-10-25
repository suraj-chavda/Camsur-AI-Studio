import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/api_exception.dart';
import '../../core/utils/photo_pick.dart';
import '../../data/models/generation_model.dart';
import '../../data/models/tool_model.dart';
import '../../data/repositories/credit_repository.dart';
import '../../data/repositories/generation_repository.dart';
import '../../data/repositories/tool_repository.dart';
import '../credits/credits_controller.dart';
import '../history/history_controller.dart';
import '../home/home_controller.dart';
import '../shell/capture_sheet.dart';

enum StudioPhase { loading, ready, processing, result, failed }

class ToolDetailController extends GetxController with WidgetsBindingObserver {
  final tool = Rxn<ToolModel>();
  final phase = StudioPhase.loading.obs;
  final photos = <File>[].obs;
  final source = 'upload'.obs;
  final selected = <String, String>{}.obs;
  final styleNotes = ''.obs;
  final balance = 0.obs;
  final submitting = false.obs;
  final statusLabel = 'Preparing…'.obs;
  final caption = ''.obs;
  final progress = 0.0.obs;
  final errorMessage = ''.obs;
  final result = Rxn<GenerationModel>();

  final notesCtrl = TextEditingController();

  Timer? _progressTimer;
  Timer? _captionTimer;
  DateTime? _processingStartedAt;
  int _captionIndex = 0;
  String _stage = 'upload';
  bool _disposed = false;

  static const _expectedSeconds = 42.0;

  static const _captionsByStage = <String, List<String>>{
    'upload': [
      'Sending your photos securely…',
      'Getting everything ready…',
    ],
    'queued': [
      'Lined up in the studio…',
      'Your turn is coming up…',
    ],
    'processing': [
      'Matching light and tone…',
      'Keeping your face natural…',
      'Refining background and framing…',
      'Polishing the final details…',
      'Almost ready to reveal…',
    ],
    'finishing': [
      'Saving your new photo…',
      'One last check…',
    ],
  };

  String get slug => Get.parameters['slug'] ?? '';

  File? get photo => photos.isEmpty ? null : photos.first;

  int get minPhotos => tool.value?.minInputImages.clamp(1, PhotoPick.maxCount) ?? 1;

  int get maxPhotos {
    final toolMax = tool.value?.maxInputImages ?? PhotoPick.maxCount;
    return toolMax.clamp(minPhotos, PhotoPick.maxCount);
  }

  bool get isTogetherTool => slug == 'together';

  bool get hasRequiredPhotos =>
      photos.length >= minPhotos && photos.length <= maxPhotos;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    notesCtrl.addListener(() => styleNotes.value = notesCtrl.text.trim());
    final session = PhotoSession.fromArguments(Get.arguments);
    if (session != null) {
      photos.assignAll(session.files.take(PhotoPick.maxCount));
      source.value = session.source;
    }
    _boot();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resumeProcessingTimers();
      // Coming back from the background: the generation kept running
      // server-side the whole time — check its real status immediately
      // instead of waiting out the poll backoff, so the UI catches up fast
      // rather than looking stuck (or wrongly reporting failure if the OS
      // had torn down the in-flight poll request while backgrounded).
      final g = result.value;
      if (phase.value == StudioPhase.processing && g != null && !g.isTerminal) {
        _recheckStatus(g.id);
      }
      return;
    }
    // paused / inactive / hidden / detached — the screen isn't visible
    // either way, so stop the cosmetic progress/caption timers rather than
    // let them keep firing pointlessly (and getting killed mid-tick) while
    // backgrounded. Polling for the real status continues regardless; only
    // these UI-only timers pause.
    _pauseProcessingTimers();
  }

  void _pauseProcessingTimers() {
    _progressTimer?.cancel();
    _progressTimer = null;
    _captionTimer?.cancel();
    _captionTimer = null;
  }

  void _resumeProcessingTimers() {
    if (phase.value != StudioPhase.processing) return;
    _progressTimer ??= Timer.periodic(
      const Duration(milliseconds: 220),
      (_) => _tickProgress(),
    );
    _captionTimer ??= Timer.periodic(
      const Duration(milliseconds: 2600),
      (_) => _rotateCaption(),
    );
  }

  Future<void> _recheckStatus(String id) async {
    try {
      final fresh = await Get.find<GenerationRepository>().getById(id);
      if (_disposed || phase.value != StudioPhase.processing) return;
      result.value = fresh;
      if (fresh.isTerminal) {
        _setStage('finishing', label: 'Finishing up…');
        _finish(fresh);
      }
    } catch (_) {
      // Ignore — the ongoing (now failure-tolerant) waitUntilDone loop keeps polling.
    }
  }

  Future<void> _boot() async {
    phase.value = StudioPhase.loading;
    errorMessage.value = '';

    try {
      final t = await Get.find<ToolRepository>().bySlug(slug);
      if (t == null) {
        errorMessage.value = 'Tool not found';
        phase.value = StudioPhase.failed;
        return;
      }
      tool.value = t;
      _initSettings(t);
      phase.value = StudioPhase.ready;
    } on ApiException catch (e) {
      errorMessage.value = e.message;
      phase.value = StudioPhase.failed;
      return;
    } catch (_) {
      errorMessage.value = 'Couldn’t load this tool';
      phase.value = StudioPhase.failed;
      return;
    }

    // Balance is nice-to-have — never block the customize screen.
    try {
      balance.value = (await Get.find<CreditRepository>().balance()).balance;
      if (Get.isRegistered<HomeController>()) {
        Get.find<HomeController>().balance.value = balance.value;
      }
    } catch (_) {}
  }

  /// Re-checks credit balance fresh from the server right before spending —
  /// `balance.value` is only a display hint and can go stale (e.g. after a
  /// prior generation on this same screen, or if the initial fetch in
  /// `_boot()` failed). If the fresh fetch itself fails, don't block: the
  /// server enforces the real balance atomically when the request lands.
  Future<bool> _hasEnoughCredits(int cost) async {
    try {
      final fresh = (await Get.find<CreditRepository>().balance()).balance;
      balance.value = fresh;
      if (Get.isRegistered<HomeController>()) {
        Get.find<HomeController>().balance.value = fresh;
      }
      return fresh >= cost;
    } catch (_) {
      return true;
    }
  }

  void _initSettings(ToolModel t) {
    selected.clear();
    for (final s in t.settings) {
      final def = s.defaultValue ??
          (s.options.isNotEmpty ? s.options.first.value : null);
      if (def != null) selected[s.key] = def;
    }
  }

  void selectOption(String key, String value) {
    if (tool.value?.settings.any((s) => s.key == key && s.locked) == true) {
      return;
    }
    selected[key] = value;
  }

  Future<void> pick(ImageSource src) async {
    final max = maxPhotos;
    if (photos.length >= max) {
      Get.snackbar(
        'Photos',
        max == 1
            ? 'This tool uses 1 photo.'
            : 'This tool uses up to $max photos.',
      );
      return;
    }
    final picked = await PhotoPick.pick(
      source: src,
      alreadyHave: photos.length,
      limit: max,
    );
    if (picked.isEmpty) return;
    photos.assignAll(
      PhotoPick.merge(
        photos.toList(),
        picked,
        limit: max,
        allowDuplicates: isTogetherTool,
      ),
    );
    source.value = src == ImageSource.camera ? 'camera' : 'upload';
  }

  void removePhotoAt(int index) {
    if (index < 0 || index >= photos.length) return;
    photos.removeAt(index);
  }

  void clearPhoto() {
    photos.clear();
  }

  Future<void> generate() async {
    final t = tool.value;
    if (t == null || submitting.value) return;
    if (!hasRequiredPhotos) {
      Get.snackbar(
        'Add photos',
        isTogetherTool
            ? 'Add at least $minPhotos photos. Extra slots can be more photos of the same people.'
            : maxPhotos <= 1
                ? 'Add a photo to continue.'
                : 'Add at least $minPhotos photo(s) (up to $maxPhotos).',
      );
      return;
    }
    final file = photos.first;

    if (!await _hasEnoughCredits(t.creditCost)) {
      Get.snackbar(
        'Not enough credits',
        'You need ${t.creditCost} credits for this tool.',
      );
      return;
    }

    submitting.value = true;
    phase.value = StudioPhase.processing;
    errorMessage.value = '';
    _beginProcessingUi(stage: 'upload', label: 'Uploading your photos…');

    try {
      final gen = await Get.find<GenerationRepository>().fromPhoto(
        photo: file,
        photos: List<File>.from(photos),
        toolSlug: t.slug,
        source: source.value,
        settings: Map<String, dynamic>.from(selected),
        styleNotes: styleNotes.value.isEmpty ? null : styleNotes.value,
        idempotencyKey: const Uuid().v4(),
        async: true,
      );

      result.value = gen;
      if (gen.isTerminal) {
        _finish(gen);
        return;
      }

      _setStage(
        gen.status == 'processing' ? 'processing' : 'queued',
        label: gen.status == 'processing'
            ? 'Creating your photo…'
            : 'Queued in studio…',
      );

      await _pollUntilDone(gen.id);
    } on ApiException catch (e) {
      if (e.data is Map) {
        try {
          final g = GenerationModel.fromJson(
            Map<String, dynamic>.from(e.data as Map),
          );
          result.value = g;
          _finish(g);
          return;
        } catch (_) {}
      }
      _stopProcessingUi();
      errorMessage.value = e.message;
      phase.value = StudioPhase.failed;
    } catch (_) {
      _stopProcessingUi();
      errorMessage.value = 'Generation failed. Please try again.';
      phase.value = StudioPhase.failed;
    } finally {
      submitting.value = false;
    }
  }

  /// Keeps checking until the job is actually terminal — never reports
  /// "failed" just because one wait cycle gave up. `waitUntilDone` bounds
  /// itself with a wall-clock deadline that keeps ticking while the app is
  /// backgrounded, so it can return a still-`processing` result long before
  /// the job is really done (this was showing users a false "failed" that
  /// flipped to a real success moments later once something re-synced).
  /// `didChangeAppLifecycleState` also re-checks immediately on resume;
  /// this loop is what keeps things converging even if the user just waits.
  Future<void> _pollUntilDone(String id) async {
    while (!_disposed) {
      final done = await Get.find<GenerationRepository>().waitUntilDone(
        id,
        onTick: (g) {
          if (_disposed) return;
          result.value = g;
          if (g.status == 'processing') {
            _setStage('processing', label: 'Creating your photo…');
          } else if (!g.isTerminal) {
            _setStage('queued', label: 'Queued in studio…');
          }
        },
      );
      if (_disposed) return;
      if (done.isTerminal) {
        _setStage('finishing', label: 'Finishing up…');
        _finish(done);
        return;
      }
      result.value = done;
      _setStage('processing', label: 'Still working — almost there…');
    }
  }

  void _beginProcessingUi({required String stage, required String label}) {
    _processingStartedAt = DateTime.now();
    progress.value = 0.04;
    _stage = ''; // force caption + timer refresh
    _setStage(stage, label: label);
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 220), (_) {
      _tickProgress();
    });
  }

  void _setStage(String stage, {required String label}) {
    final changed = _stage != stage;
    _stage = stage;
    statusLabel.value = label;
    if (changed) {
      _captionIndex = 0;
      _rotateCaption(force: true);
      _captionTimer?.cancel();
      _captionTimer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
        _rotateCaption();
      });
    }
  }

  void _rotateCaption({bool force = false}) {
    final list = _captionsByStage[_stage] ?? _captionsByStage['processing']!;
    if (list.isEmpty) return;
    if (!force) {
      _captionIndex = (_captionIndex + 1) % list.length;
    }
    caption.value = list[_captionIndex % list.length];
  }

  void _tickProgress() {
    final started = _processingStartedAt;
    if (started == null) return;
    final elapsed =
        DateTime.now().difference(started).inMilliseconds / 1000.0;
    // Ease toward ~92% over the expected window so the bar never stalls
    // or falsely claims completion before the job is done.
    final t = (elapsed / _expectedSeconds).clamp(0.0, 1.0);
    final eased = 1 - (1 - t) * (1 - t);
    var target = 0.04 + (eased * 0.88);
    if (_stage == 'finishing') {
      target = target.clamp(0.9, 0.96);
    } else if (_stage == 'upload') {
      target = target.clamp(0.0, 0.18);
    } else if (_stage == 'queued') {
      target = target.clamp(0.12, 0.28);
    }
    if (target > progress.value) {
      progress.value = target;
    }
  }

  void _stopProcessingUi({bool complete = false}) {
    _progressTimer?.cancel();
    _captionTimer?.cancel();
    _progressTimer = null;
    _captionTimer = null;
    if (complete) {
      progress.value = 1;
    }
  }

  void _finish(GenerationModel g) {
    result.value = g;
    if (g.isSuccess) {
      _stopProcessingUi(complete: true);
      phase.value = StudioPhase.result;
    } else {
      _stopProcessingUi();
      errorMessage.value =
          g.errorMessage ?? 'Generation ${g.status}. Credits may be refunded.';
      phase.value = StudioPhase.failed;
    }
    _refreshRelated();
  }

  void _refreshRelated() {
    // Targeted updates — avoid full home refreshAll after every generate.
    final repo = Get.find<GenerationRepository>();
    final done = result.value;
    if (done != null && done.isSuccess) {
      repo.upsertLocal(done);
    }

    unawaited(() async {
      try {
        final fresh = (await Get.find<CreditRepository>().balance()).balance;
        balance.value = fresh;
        if (Get.isRegistered<HomeController>()) {
          Get.find<HomeController>().balance.value = fresh;
        }
      } catch (_) {}
    }());
    if (Get.isRegistered<HomeController>()) {
      unawaited(Get.find<HomeController>().refreshRecentOnly().catchError((_) {}));
    }
    if (Get.isRegistered<HistoryController>()) {
      unawaited(Get.find<HistoryController>().load(force: true));
    }
    if (Get.isRegistered<CreditsController>()) {
      unawaited(Get.find<CreditsController>().load(force: true));
    }
  }

  void retry() {
    result.value = null;
    errorMessage.value = '';
    progress.value = 0;
    caption.value = '';
    if (tool.value != null) {
      phase.value = StudioPhase.ready;
    } else {
      _boot();
    }
  }

  void startOver() {
    photos.clear();
    result.value = null;
    errorMessage.value = '';
    progress.value = 0;
    caption.value = '';
    notesCtrl.clear();
    if (tool.value != null) {
      _initSettings(tool.value!);
      phase.value = StudioPhase.ready;
    }
  }

  @override
  void onClose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _stopProcessingUi();
    notesCtrl.dispose();
    super.onClose();
  }
}
