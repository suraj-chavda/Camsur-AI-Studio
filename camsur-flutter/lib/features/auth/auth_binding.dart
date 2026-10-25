import 'package:get/get.dart';

import 'auth_controller.dart';

class AuthBinding extends Bindings {
  @override
  void dependencies() {
    // fenix: popping register must not leave login without a controller.
    Get.lazyPut(AuthController.new, fenix: true);
  }
}
