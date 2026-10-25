import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/storage/local_storage.dart';
import '../../core/utils/catalog_images.dart';
import '../../data/models/tool_model.dart';
import 'onboarding_warmup.dart';

class OnboardingController extends GetxController {
  final page = 0.obs;
  final pageOffset = 0.0.obs;
  final pageController = PageController();
  final slides = <OnboardingSlideModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    slides.assignAll(OnboardingWarmup.slides);
    pageController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!pageController.hasClients) return;
    final p = pageController.page;
    if (p != null) pageOffset.value = p;
  }

  String? imageUrlFor(OnboardingSlideModel slide) =>
      CatalogImages.displayUrl(slide.imageUrl);

  void next() {
    if (page.value < slides.length - 1) {
      pageController.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    } else {
      finish();
    }
  }

  void onPageChanged(int i) => page.value = i;

  void finish() {
    Get.find<LocalStorage>().onboardingDone = true;
    Get.offAllNamed(AppRoutes.login);
  }

  @override
  void onClose() {
    pageController.removeListener(_onScroll);
    pageController.dispose();
    super.onClose();
  }
}
