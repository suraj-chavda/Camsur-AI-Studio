class CreditBalance {
  const CreditBalance({required this.balance, this.userId});

  final int balance;
  final String? userId;

  factory CreditBalance.fromJson(Map<String, dynamic> json) => CreditBalance(
        balance: (json['balance'] as num?)?.toInt() ?? 0,
        userId: json['user_id']?.toString(),
      );
}

class CreditPackage {
  const CreditPackage({
    required this.slug,
    required this.name,
    required this.credits,
    required this.priceCents,
    this.currency = 'USD',
    this.platform = 'manual',
    this.metadata = const {},
    this.sortOrder = 100,
  });

  final String slug;
  final String name;
  final int credits;
  final int priceCents;
  final String currency;
  final String platform;
  final Map<String, dynamic> metadata;
  final int sortOrder;

  String get priceLabel {
    final amount = priceCents / 100;
    return '\$${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)}';
  }

  factory CreditPackage.fromJson(Map<String, dynamic> json) => CreditPackage(
        slug: json['slug']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        credits: (json['credits'] as num?)?.toInt() ?? 0,
        priceCents: (json['price_amount_cents'] as num?)?.toInt() ?? 0,
        currency: json['currency']?.toString() ?? 'USD',
        platform: json['platform']?.toString() ?? 'manual',
        metadata: Map<String, dynamic>.from((json['metadata'] as Map?) ?? {}),
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 100,
      );
}

class CreditTransaction {
  const CreditTransaction({
    required this.id,
    required this.amount,
    required this.type,
    this.userId,
    this.generationId,
    this.toolSlug,
    this.balanceAfter,
    this.reason,
    this.createdAt,
  });

  final String id;
  final int amount;
  final String type;
  final String? userId;
  final String? generationId;
  final String? toolSlug;
  final int? balanceAfter;
  final String? reason;
  final DateTime? createdAt;

  bool get isCredit => amount > 0;

  factory CreditTransaction.fromJson(Map<String, dynamic> json) =>
      CreditTransaction(
        id: json['id']?.toString() ?? '',
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        type: json['type']?.toString() ?? 'unknown',
        userId: json['user_id']?.toString(),
        generationId: json['generation_id']?.toString(),
        toolSlug: json['tool_slug']?.toString(),
        balanceAfter: (json['balance_after'] as num?)?.toInt(),
        reason: json['reason']?.toString(),
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString())
            : null,
      );
}

class CreditPurchaseResult {
  const CreditPurchaseResult({
    required this.id,
    required this.status,
    required this.credits,
    required this.packageSlug,
    required this.packageName,
    required this.priceCents,
    this.balanceAfter,
    this.currency = 'USD',
  });

  final String id;
  final String status;
  final int credits;
  final String packageSlug;
  final String packageName;
  final int priceCents;
  final int? balanceAfter;
  final String currency;

  factory CreditPurchaseResult.fromJson(Map<String, dynamic> json) =>
      CreditPurchaseResult(
        id: json['id'].toString(),
        status: (json['status'] as String?) ?? 'unknown',
        credits: (json['credits'] as num?)?.toInt() ?? 0,
        packageSlug: (json['package_slug'] as String?) ?? '',
        packageName: (json['package_name'] as String?) ?? '',
        priceCents: (json['price_amount_cents'] as num?)?.toInt() ?? 0,
        balanceAfter: (json['balance_after'] as num?)?.toInt(),
        currency: (json['currency'] as String?) ?? 'USD',
      );
}
