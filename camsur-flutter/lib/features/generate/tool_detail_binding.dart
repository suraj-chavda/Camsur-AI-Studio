import 'package:get/get.dart';

import 'tool_detail_controller.dart';

class ToolDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(ToolDetailController.new, fenix: true);
  }
}
