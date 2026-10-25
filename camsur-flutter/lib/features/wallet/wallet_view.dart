import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../credits/credits_controller.dart';
import '../shell/shell_binding.dart';
import '../shell/shell_controller.dart';

/// Legacy `/wallet` route — opens the shell Wallet tab.
class WalletView extends StatelessWidget {
  const WalletView({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.isRegistered<ShellController>()) {
        ensureShellTab(2);
        Get.find<ShellController>().setIndex(2);
        if (Get.isRegistered<CreditsController>()) {
          Get.find<CreditsController>().setTab(1);
        }
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
