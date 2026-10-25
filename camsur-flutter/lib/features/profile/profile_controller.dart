import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/credit_repository.dart';
import '../../data/repositories/generation_repository.dart';
import '../../data/repositories/tool_repository.dart';

class ProfileController extends GetxController {
  final user = Rxn<UserModel>();
  final loading = false.obs;

  @override
  void onInit() {
    super.onInit();
    user.value = Get.find<AuthRepository>().cachedUser();
    refreshMe();
  }

  Future<void> refreshMe() async {
    loading.value = user.value == null;
    try {
      final me = await Get.find<AuthRepository>().me();
      if (me != null) user.value = me;
    } catch (_) {
    } finally {
      loading.value = false;
    }
  }

  void logout() {
    Get.find<AuthRepository>().logout();
    if (Get.isRegistered<CreditRepository>()) {
      Get.find<CreditRepository>().invalidate();
    }
    if (Get.isRegistered<ToolRepository>()) {
      Get.find<ToolRepository>().invalidate();
    }
    if (Get.isRegistered<GenerationRepository>()) {
      Get.find<GenerationRepository>().invalidate();
    }
    Get.offAllNamed(AppRoutes.login);
  }
}
