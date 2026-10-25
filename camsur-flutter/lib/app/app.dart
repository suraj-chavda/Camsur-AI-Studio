import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_controller.dart';
import '../core/widgets/app_navigator_host.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';

class CamsurApp extends StatelessWidget {
  const CamsurApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Get.find<ThemeController>();

    return GetMaterialApp(
      title: AppConstants.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: theme.mode.value,
      initialRoute: AppRoutes.splash,
      getPages: AppPages.pages,
      defaultTransition: Transition.cupertino,
      // Avoid null navigator child during pops showing only the grid.
      builder: (context, child) => AppNavigatorHost(child: child),
    );
  }
}
