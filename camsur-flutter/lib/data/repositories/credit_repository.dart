import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/json_x.dart';
import '../models/credit_model.dart';

class CreditRepository {
  CreditRepository(this._api);

  final ApiClient _api;

  // Last-known-good snapshot — used only as a fallback if a fresh
  // `packages()` call throws. Every call below always hits the network
  // first.
  List<CreditPackage>? _cachedPackages;

  Future<CreditBalance> balance() async {
    return _api.get(
      ApiConstants.creditBalance,
      parser: (d) => CreditBalance.fromJson(asJsonMap(d)),
    );
  }

  Future<List<CreditPackage>> packages() async {
    try {
      final list = await _api.get(
        ApiConstants.creditPackages,
        parser: _parsePackages,
      );

      // Never cache an empty catalog over a known-good one — avoids
      // "No plans available" flashes from blips / partial responses.
      if (list.isNotEmpty) {
        _cachedPackages = list;
        return list;
      }

      if (_cachedPackages != null && _cachedPackages!.isNotEmpty) {
        return _cachedPackages!;
      }

      return list;
    } catch (e) {
      if (_cachedPackages != null && _cachedPackages!.isNotEmpty) {
        return _cachedPackages!;
      }
      rethrow;
    }
  }

  static List<CreditPackage> _parsePackages(dynamic data) {
    final raw = asJsonList(data);
    final out = <CreditPackage>[];
    for (final item in raw) {
      try {
        if (item is! Map) continue;
        final pack = CreditPackage.fromJson(Map<String, dynamic>.from(item));
        if (pack.slug.isEmpty || pack.credits <= 0) continue;
        out.add(pack);
      } catch (_) {
        // Skip bad rows — one corrupt pack shouldn't blank the wallet.
      }
    }
    out.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return out;
  }

  void invalidate() {
    _cachedPackages = null;
  }

  Future<List<CreditTransaction>> transactions({int limit = 50}) async {
    return _api.get(
      ApiConstants.creditTransactions,
      query: {'limit': limit},
      parser: (d) {
        final out = <CreditTransaction>[];
        for (final item in asJsonList(d)) {
          try {
            if (item is! Map) continue;
            out.add(
              CreditTransaction.fromJson(Map<String, dynamic>.from(item)),
            );
          } catch (_) {}
        }
        return out;
      },
    );
  }

  Future<Map<String, dynamic>> settings() async {
    return _api.get(
      ApiConstants.creditSettings,
      parser: (d) => asJsonMap(d),
    );
  }

  Future<CreditPurchaseResult> purchase(
    String packageSlug, {
    String? idempotencyKey,
  }) async {
    final result = await _api.post(
      ApiConstants.creditPurchases,
      body: {
        'package_slug': packageSlug,
        'idempotency_key': ?idempotencyKey,
      },
      parser: (d) =>
          CreditPurchaseResult.fromJson(asJsonMap(d)),
    );
    invalidate();
    return result;
  }
}
