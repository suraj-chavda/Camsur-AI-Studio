import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/theme_controller.dart';

class SettingsController extends GetxController {
  ThemeController get theme => Get.find();

  ThemeMode get mode => theme.mode.value;

  void setThemeMode(ThemeMode mode) => theme.setMode(mode);
}
