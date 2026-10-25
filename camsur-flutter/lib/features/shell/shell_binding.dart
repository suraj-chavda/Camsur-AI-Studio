import 'package:get/get.dart';

import '../credits/credits_controller.dart';
import '../history/history_controller.dart';
import '../home/home_controller.dart';
import '../profile/profile_controller.dart';
import 'shell_controller.dart';

class ShellBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(ShellController.new, fenix: true);
    // Home loads with the shell; other tabs register on first open.
    Get.lazyPut(HomeController.new, fenix: true);
  }
}

/// Lazily register tab controllers the first time a tab is opened.
void ensureShellTab(int index) {
  switch (index) {
    case 1:
      if (!Get.isRegistered<HistoryController>()) {
        Get.lazyPut(HistoryController.new, fenix: true);
      }
    case 2:
      if (!Get.isRegistered<CreditsController>()) {
        Get.lazyPut(CreditsController.new, fenix: true);
      }
    case 3:
      if (!Get.isRegistered<ProfileController>()) {
        Get.lazyPut(ProfileController.new, fenix: true);
      }
  }
}
