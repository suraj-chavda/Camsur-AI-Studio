import 'package:get/get.dart';

import 'app_routes.dart';

/// Safe pop — never leave an empty navigator (blank grid).
void popOrShell() {
  final nav = Get.key.currentState;
  if (nav != null && nav.canPop()) {
    Get.back();
    return;
  }
  Get.offAllNamed(AppRoutes.shell);
}
