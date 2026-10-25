import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/context_x.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/root_pop_scope.dart';
import '../../../core/widgets/social_sign_in_buttons.dart';
import '../auth_controller.dart';
import '../../../core/theme/app_icons.dart';

class LoginView extends GetView<AuthController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return RootPopScope(
      child: Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: context.responsive.pagePadding,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: controller.loginFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: AppLogo(size: 96),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Welcome back',
                      textAlign: TextAlign.center,
                      style: context.texts.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sign in to ${AppConstants.shortName}',
                      textAlign: TextAlign.center,
                      style: context.texts.bodyMedium,
                    ),
                    const SizedBox(height: 32),
                    AppTextField(
                      controller: controller.emailCtrl,
                      label: 'Email',
                      hint: 'you@email.com',
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: AppIcons.mail,
                      validator: Validators.email,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    Obx(
                      () => AppTextField(
                        controller: controller.passwordCtrl,
                        label: 'Password',
                        hint: '••••••••',
                        obscure: controller.obscure.value,
                        prefixIcon: AppIcons.lock,
                        validator: Validators.password,
                        suffix: IconButton(
                          onPressed: () => controller.obscure.toggle(),
                          icon: Icon(
                            controller.obscure.value
                                ? AppIcons.eye
                                : AppIcons.eyeOff,
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        child: const Text('Forgot password?'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Obx(
                      () => AppButton(
                        label: 'Sign In',
                        loading: controller.loading.value,
                        onPressed: controller.login,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Obx(
                      () => SocialSignInButtons(
                        loading: controller.socialLoading.value,
                        onGoogle: controller.signInWithGoogle,
                        onApple: controller.signInWithApple,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: context.texts.bodyMedium,
                        ),
                        GestureDetector(
                          onTap: () => Get.toNamed(AppRoutes.register),
                          child: Text(
                            'Register',
                            style: context.texts.bodyMedium?.copyWith(
                              color: context.colors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }
}
