class Customer {
  const Customer({
    required this.id,
    required this.storeId,
    required this.name,
    this.phone,
    this.location,
    required this.totalBalance,
    this.notes,
    required this.isActive,
    this.creditLimit = 0,
    this.creditDays = 0,
    this.creditBlocked = false,
  });

  final String id;
  final String storeId;
  final String name;
  final String? phone;
  final String? location;
  final double totalBalance;
  final String? notes;
  final bool isActive;
  final double creditLimit;
  final int creditDays;
  final bool creditBlocked;

  bool get hasDebt => totalBalance > 0;
  bool get hasLimit => creditLimit > 0;
  double get remainingCredit => hasLimit ? (creditLimit - totalBalance).clamp(0, creditLimit) : double.infinity;

  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
        id: map['id'] as String,
        storeId: map['store_id'] as String,
        name: map['name'] as String,
        phone: map['phone'] as String?,
        location: map['location'] as String?,
        totalBalance: (map['total_balance'] as num).toDouble(),
        notes: map['notes'] as String?,
        isActive: map['is_active'] as bool? ?? true,
        creditLimit: (map['credit_limit'] as num?)?.toDouble() ?? 0,
        creditDays: (map['credit_days'] as num?)?.toInt() ?? 0,
        creditBlocked: map['credit_blocked'] as bool? ?? false,
      );
}
