import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../storage/local_storage.dart';

/// Blocks protected routes when there is no session. Guests are not allowed.
class AuthMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final storage = Get.isRegistered<LocalStorage>()
        ? Get.find<LocalStorage>()
        : LocalStorage();
    if (!storage.isLoggedIn) {
      return const RouteSettings(name: AppRoutes.login);
    }
    return null;
  }
}
