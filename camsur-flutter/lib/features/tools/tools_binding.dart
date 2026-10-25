import 'package:get/get.dart';

import 'tools_controller.dart';

class ToolsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(ToolsController.new, fenix: true);
  }
}
