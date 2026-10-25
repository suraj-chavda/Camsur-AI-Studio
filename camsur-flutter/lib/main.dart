import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';

import 'app/app.dart';
import 'app/bindings/initial_binding.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Keep more decoded frames so banners / tools don't flash-empty on scroll.
  PaintingBinding.instance.imageCache.maximumSize = 180;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 120 << 20;
  await GetStorage.init();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  InitialBinding().dependencies();
  runApp(const CamsurApp());
}
