import 'package:get/get.dart';

import '../../core/middleware/auth_middleware.dart';
import '../../features/auth/auth_binding.dart';
import '../../features/categories/categories_binding.dart';
import '../../features/categories/categories_view.dart';
import '../../features/auth/views/login_view.dart';
import '../../features/auth/views/register_view.dart';
import '../../features/create/photo_preview_binding.dart';
import '../../features/create/photo_preview_view.dart';
import '../../features/generate/generation_result_view.dart';
import '../../features/generate/tool_detail_binding.dart';
import '../../features/generate/tool_detail_view.dart';
import '../../features/onboarding/onboarding_binding.dart';
import '../../features/onboarding/onboarding_view.dart';
import '../../features/settings/settings_view.dart';
import '../../features/shell/shell_binding.dart';
import '../../features/shell/shell_view.dart';
import '../../features/splash/splash_binding.dart';
import '../../features/splash/splash_view.dart';
import '../../features/support/support_view.dart';
import '../../features/tools/tools_binding.dart';
import '../../features/tools/tools_view.dart';
import '../../features/wallet/wallet_view.dart';
import 'app_routes.dart';

class AppPages {
  AppPages._();

  static final _auth = [AuthMiddleware()];

  static final pages = <GetPage>[
    GetPage(
      name: AppRoutes.splash,
      page: () => const SplashView(),
      binding: SplashBinding(),
    ),
    GetPage(
      name: AppRoutes.onboarding,
      page: () => const OnboardingView(),
      binding: OnboardingBinding(),
    ),
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginView(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.register,
      page: () => const RegisterView(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.shell,
      page: () => const ShellView(),
      binding: ShellBinding(),
      middlewares: _auth,
    ),
    GetPage(
      name: AppRoutes.tools,
      page: () => const ToolsView(),
      binding: ToolsBinding(),
      middlewares: _auth,
      preventDuplicates: true,
    ),
    GetPage(
      name: AppRoutes.categories,
      page: () => const CategoriesView(),
      binding: CategoriesBinding(),
      middlewares: _auth,
      preventDuplicates: true,
    ),
    GetPage(
      name: AppRoutes.generationResult,
      page: () => const GenerationResultView(),
      middlewares: _auth,
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 320),
    ),
    GetPage(
      name: AppRoutes.toolDetail,
      page: () => const ToolDetailView(),
      binding: ToolDetailBinding(),
      middlewares: _auth,
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 320),
      preventDuplicates: true,
    ),
    GetPage(
      name: AppRoutes.photoPreview,
      page: () => const PhotoPreviewView(),
      binding: PhotoPreviewBinding(),
      middlewares: _auth,
      transition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 320),
    ),
    GetPage(
      name: AppRoutes.wallet,
      page: () => const WalletView(),
      middlewares: _auth,
    ),
    GetPage(
      name: AppRoutes.settings,
      page: () => const SettingsView(),
      middlewares: _auth,
    ),
    GetPage(
      name: AppRoutes.support,
      page: () => const SupportView(),
      middlewares: _auth,
    ),
  ];
}
