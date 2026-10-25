import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../shell/shell_binding.dart';
import '../shell/shell_controller.dart';

/// Legacy `/settings` route — settings live on Profile now.
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.isRegistered<ShellController>()) {
        ensureShellTab(3);
        Get.find<ShellController>().setIndex(3);
        if (Get.key.currentState?.canPop() ?? false) {
          Get.back();
        }
      } else {
        Get.offAllNamed(AppRoutes.shell);
      }
    });
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: SizedBox.shrink(),
    );
  }
}
