import 'package:get/get.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/local_storage.dart';
import '../../core/theme/theme_controller.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/credit_repository.dart';
import '../../data/repositories/generation_repository.dart';
import '../../data/repositories/tool_repository.dart';
import '../../data/repositories/upload_repository.dart';
import '../../data/sources/social_auth_source.dart';

/// App-wide singletons — registered once at startup.
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(LocalStorage(), permanent: true);
    Get.put(ApiClient(Get.find()), permanent: true);
    Get.put(ThemeController(), permanent: true);

    Get.lazyPut(() => AuthRepository(Get.find(), Get.find()), fenix: true);
    Get.lazyPut(SocialAuthSource.new, fenix: true);
    Get.lazyPut(() => ToolRepository(Get.find()), fenix: true);
    Get.lazyPut(() => CreditRepository(Get.find()), fenix: true);
    Get.lazyPut(() => GenerationRepository(Get.find()), fenix: true);
    Get.lazyPut(() => UploadRepository(Get.find()), fenix: true);
  }
}
