class Customer {
  const Customer({required this.id, required this.storeId, required this.name, this.phone, this.location, required this.totalBalance});
  final String id;
  final String storeId;
  final String name;
  final String? phone;
  final String? location;
  final double totalBalance;

  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
        id: map['id'] as String,
        storeId: map['store_id'] as String,
        name: map['name'] as String,
        phone: map['phone'] as String?,
        location: map['location'] as String?,
        totalBalance: (map['total_balance'] as num).toDouble(),
      );
}
