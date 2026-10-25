import 'dart:async';

import 'package:get/get.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/credit_model.dart';
import '../../data/repositories/credit_repository.dart';
import '../home/home_controller.dart';

class CreditsController extends GetxController {
  final balance = 0.obs;
  final packages = <CreditPackage>[].obs;
  final transactions = <CreditTransaction>[].obs;
  final loading = true.obs;
  final txLoading = true.obs;
  final purchasingSlug = RxnString();
  final error = RxnString();
  final txError = RxnString();
  final tabIndex = 0.obs;
  final plansLoaded = false.obs;
  final activityLoaded = false.obs;

  CreditRepository get _repo => Get.find();
  Future<void>? _inflight;
  Future<void>? _txInflight;

  @override
  void onInit() {
    super.onInit();
    if (Get.isRegistered<HomeController>()) {
      balance.value = Get.find<HomeController>().balance.value;
    }
    // Warm from cache only — never throw into the zone.
    () async {
      try {
        final packs = await _repo.packages();
        if (packs.isNotEmpty && packages.isEmpty) {
          packages.assignAll(packs);
          loading.value = false;
          plansLoaded.value = true;
        }
      } catch (_) {}
    }();
  }

  @override
  void onReady() {
    super.onReady();
    load();
  }

  void setTab(int index) {
    if (tabIndex.value == index) return;
    tabIndex.value = index;
    if (index == 1 && !activityLoaded.value) {
      loadActivity();
    }
  }

  Future<void> load({bool force = false}) {
    if (_inflight != null && !force) return _inflight!;
    final run = _loadBody(force: force);
    _inflight = run.whenComplete(() => _inflight = null);
    return _inflight!;
  }

  Future<void> _loadBody({required bool force}) async {
    final firstPaint = packages.isEmpty && !plansLoaded.value;
    if (firstPaint) loading.value = true;
    if (force) error.value = null;

    final ok =
        await _loadPlansOnce(force: force) || await _loadPlansOnce(force: true);

    if (!ok && packages.isEmpty) {
      error.value ??= 'Couldn’t load top-up plans';
    } else if (packages.isNotEmpty) {
      error.value = null;
    }

    plansLoaded.value = true;
    loading.value = false;

    // Keep activity warm in the background.
    unawaited(loadActivity(force: force));
  }

  Future<bool> _loadPlansOnce({required bool force}) async {
    try {
      final balFuture = _repo.balance();
      final packsFuture = _repo.packages();

      CreditBalance? bal;
      List<CreditPackage>? packs;
      Object? packsErr;

      try {
        bal = await balFuture;
      } catch (_) {}
      try {
        packs = await packsFuture;
      } catch (e) {
        packsErr = e;
      }

      if (bal != null) {
        balance.value = bal.balance;
        _syncHomeBalance(bal.balance);
      }

      if (packs != null) {
        if (packs.isNotEmpty) {
          packages.assignAll(packs);
          error.value = null;
          return true;
        }
        // Genuine empty catalog from API (and no cache fallback).
        if (packages.isEmpty) {
          error.value = null;
        }
        return packages.isNotEmpty;
      }

      if (packages.isNotEmpty) {
        error.value = null;
        return true;
      }

      if (packsErr is ApiException) {
        error.value = packsErr.statusCode == 401
            ? 'Session expired. Please sign in again.'
            : packsErr.message;
      } else {
        error.value = 'Couldn’t load top-up plans';
      }
      return false;
    } catch (e) {
      if (packages.isNotEmpty) return true;
      if (e is ApiException) {
        error.value = e.statusCode == 401
            ? 'Session expired. Please sign in again.'
            : e.message;
      } else {
        error.value = 'Couldn’t load top-up plans';
      }
      return false;
    }
  }

  Future<void> loadActivity({bool force = false}) {
    if (_txInflight != null && !force) return _txInflight!;
    final run = _loadActivityBody(force: force);
    _txInflight = run.whenComplete(() => _txInflight = null);
    return _txInflight!;
  }

  Future<void> _loadActivityBody({required bool force}) async {
    final firstPaint = transactions.isEmpty && !activityLoaded.value;
    if (firstPaint) txLoading.value = true;
    if (force) txError.value = null;

    try {
      final list = await _repo.transactions(limit: 50);
      transactions.assignAll(list);
      txError.value = null;
    } on ApiException catch (e) {
      if (transactions.isEmpty) {
        txError.value = e.message;
      }
    } catch (_) {
      if (transactions.isEmpty) {
        txError.value = 'Couldn’t load wallet activity';
      }
    } finally {
      activityLoaded.value = true;
      txLoading.value = false;
    }
  }

  Future<void> purchase(CreditPackage package) async {
    if (purchasingSlug.value != null) return;
    purchasingSlug.value = package.slug;
    try {
      final result = await _repo.purchase(package.slug);
      balance.value = result.balanceAfter ?? balance.value + package.credits;
      _syncHomeBalance(balance.value);
      Get.snackbar(
        'Top-up complete',
        '+${package.credits} credits added',
        snackPosition: SnackPosition.BOTTOM,
      );
      await Future.wait([
        load(force: true),
        loadActivity(force: true),
      ]);
    } on ApiException catch (e) {
      Get.snackbar(
        'Top-up failed',
        e.message,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (_) {
      Get.snackbar(
        'Top-up failed',
        'Something went wrong. Try again.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      purchasingSlug.value = null;
    }
  }

  void _syncHomeBalance(int value) {
    if (Get.isRegistered<HomeController>()) {
      Get.find<HomeController>().balance.value = value;
    }
  }
}
