import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/extensions/context_x.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/social_sign_in_buttons.dart';
import '../auth_controller.dart';
import '../../../core/theme/app_icons.dart';

class RegisterView extends GetView<AuthController> {
  const RegisterView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: context.responsive.pagePadding,
              vertical: 16,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: controller.registerFormKey,
                child: Column(
                  children: [
                    const AppLogo(size: 88),
                    const SizedBox(height: 20),
                    AppTextField(
                      controller: controller.nameCtrl,
                      label: 'Display name',
                      hint: 'Optional',
                      prefixIcon: AppIcons.profile,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
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
                        hint: 'At least 8 characters',
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
                    const SizedBox(height: 28),
                    Obx(
                      () => AppButton(
                        label: 'Create Account',
                        loading: controller.loading.value,
                        onPressed: controller.register,
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
