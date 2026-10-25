import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/network/api_exception.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/sources/social_auth_source.dart';

class AuthController extends GetxController {
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final nameCtrl = TextEditingController();

  final loading = false.obs;
  final socialLoading = false.obs;
  final obscure = true.obs;
  final loginFormKey = GlobalKey<FormState>();
  final registerFormKey = GlobalKey<FormState>();

  AuthRepository get _repo => Get.find();
  SocialAuthSource get _social => Get.find();

  Future<void> login() async {
    if (!(loginFormKey.currentState?.validate() ?? false)) return;
    loading.value = true;
    try {
      await _repo.login(
        email: emailCtrl.text.trim(),
        password: passwordCtrl.text,
      );
      Get.offAllNamed(AppRoutes.shell);
    } on ApiException catch (e) {
      Get.snackbar('Login failed', e.message);
    } finally {
      loading.value = false;
    }
  }

  Future<void> register() async {
    if (!(registerFormKey.currentState?.validate() ?? false)) return;
    loading.value = true;
    try {
      await _repo.register(
        email: emailCtrl.text.trim(),
        password: passwordCtrl.text,
        displayName: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
      );
      Get.offAllNamed(AppRoutes.shell);
    } on ApiException catch (e) {
      Get.snackbar('Register failed', e.message);
    } finally {
      loading.value = false;
    }
  }

  Future<void> signInWithGoogle() async {
    if (socialLoading.value) return;
    socialLoading.value = true;
    try {
      final result = await _social.signInWithGoogle();
      await _repo.socialLogin(
        provider: result.provider,
        idToken: result.idToken,
        nonce: result.nonce,
      );
      Get.offAllNamed(AppRoutes.shell);
    } on SocialSignInCancelled {
      // User closed the picker — nothing to report.
    } on ApiException catch (e) {
      Get.snackbar('Google sign-in failed', e.message);
    } catch (_) {
      Get.snackbar('Google sign-in failed', 'Please try again.');
    } finally {
      socialLoading.value = false;
    }
  }

  Future<void> signInWithApple() async {
    if (socialLoading.value) return;
    socialLoading.value = true;
    try {
      final result = await _social.signInWithApple();
      await _repo.socialLogin(
        provider: result.provider,
        idToken: result.idToken,
        nonce: result.nonce,
      );
      Get.offAllNamed(AppRoutes.shell);
    } on SocialSignInCancelled {
      // User closed the sheet — nothing to report.
    } on ApiException catch (e) {
      Get.snackbar('Apple sign-in failed', e.message);
    } catch (_) {
      Get.snackbar('Apple sign-in failed', 'Please try again.');
    } finally {
      socialLoading.value = false;
    }
  }

  @override
  void onClose() {
    emailCtrl.dispose();
    passwordCtrl.dispose();
    nameCtrl.dispose();
    super.onClose();
  }
}
