import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../constants/storage_keys.dart';

/// Persists and toggles light / dark / system theme.
class ThemeController extends GetxController {
  final _box = GetStorage();
  final mode = ThemeMode.dark.obs;

  @override
  void onInit() {
    super.onInit();
    final raw = _box.read<String>(StorageKeys.themeMode);
    mode.value = switch (raw) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
  }

  void setMode(ThemeMode value) {
    mode.value = value;
    final key = switch (value) {
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
      ThemeMode.dark => 'dark',
    };
    _box.write(StorageKeys.themeMode, key);
    Get.changeThemeMode(value);
  }

  void toggleDarkLight() {
    // From Auto → opposite of current effective theme; else flip dark/light.
    if (mode.value == ThemeMode.system) {
      setMode(isDark ? ThemeMode.light : ThemeMode.dark);
      return;
    }
    setMode(mode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  bool get isDark {
    if (mode.value == ThemeMode.system) {
      return Get.isPlatformDarkMode;
    }
    return mode.value == ThemeMode.dark;
  }
}
