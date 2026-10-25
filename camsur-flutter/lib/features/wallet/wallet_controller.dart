import 'package:get/get.dart';

import '../../data/models/credit_model.dart';
import '../../data/repositories/credit_repository.dart';

class WalletController extends GetxController {
  final balance = 0.obs;
  final transactions = <CreditTransaction>[].obs;
  final loading = true.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    loading.value = true;
    try {
      final repo = Get.find<CreditRepository>();
      final results = await Future.wait([
        repo.balance(),
        repo.transactions(limit: 50),
      ]);
      balance.value = (results[0] as CreditBalance).balance;
      transactions.assignAll(results[1] as List<CreditTransaction>);
    } catch (_) {
      // Keep last known
    } finally {
      loading.value = false;
    }
  }
}
