import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/storage/local_storage.dart';
import '../../data/repositories/auth_repository.dart';
import '../onboarding/onboarding_warmup.dart';

/// Splash only ever decides where to route (onboarding / login / shell) and
/// warms the (one-time, disk-cached) onboarding slides when needed. It must
/// NOT prefetch account data (tools, creations, wallet) — each screen loads
/// its own data the moment it actually needs it, so startup time doesn't
/// grow with every feature we add.
class SplashController extends GetxController {
  final progress = 0.08.obs;
  final label = 'Starting…'.obs;

  void _mark(double value, String text) {
    progress.value = value.clamp(0, 1);
    label.value = text;
  }

  @override
  void onReady() {
    super.onReady();
    _boot();
  }

  Future<void> _boot() async {
    final storage = Get.find<LocalStorage>();
    final ctx = Get.context;

    if (!storage.onboardingDone && ctx != null && ctx.mounted) {
      await OnboardingWarmup.run(ctx, onProgress: _mark);
      _mark(1, 'Ready');
      await Future<void>.delayed(const Duration(milliseconds: 180));
      Get.offAllNamed(AppRoutes.onboarding);
      return;
    }

    if (storage.isLoggedIn) {
      _mark(0.6, 'Checking your session…');
      // Validate the token server-side before committing to Shell. Without
      // this, an expired/revoked session would flash the Home screen first
      // and only bounce to Login once some later screen's API call 401s —
      // AuthRepository.me() round-trips through ApiClient's existing silent
      // refresh + force-logout handling, which clears the session here if
      // it's truly dead, so the check below sees the up-to-date state.
      await Get.find<AuthRepository>().me();
    }

    _mark(1, 'Ready');
    Get.offAllNamed(storage.isLoggedIn ? AppRoutes.shell : AppRoutes.login);
  }
}
