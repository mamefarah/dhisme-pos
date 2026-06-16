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
  });

  final String id;
  final String storeId;
  final String name;
  final String? phone;
  final String? location;
  final double totalBalance;
  final String? notes;
  final bool isActive;

  bool get hasDebt => totalBalance > 0;

  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
        id: map['id'] as String,
        storeId: map['store_id'] as String,
        name: map['name'] as String,
        phone: map['phone'] as String?,
        location: map['location'] as String?,
        totalBalance: (map['total_balance'] as num).toDouble(),
        notes: map['notes'] as String?,
        isActive: map['is_active'] as bool? ?? true,
      );
}
