import 'package:get/get.dart';

import 'splash_controller.dart';

class SplashBinding extends Bindings {
  @override
  void dependencies() {
    // Must put (not lazyPut) — view never touches controller, so lazy never boots.
    Get.put(SplashController());
  }
}
