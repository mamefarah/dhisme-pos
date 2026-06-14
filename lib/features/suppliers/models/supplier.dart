class Supplier {
  const Supplier({
    required this.id,
    required this.storeId,
    required this.name,
    this.phone,
    this.address,
    this.contactPerson,
    this.notes,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String storeId;
  final String name;
  final String? phone;
  final String? address;
  final String? contactPerson;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;

  factory Supplier.fromMap(Map<String, dynamic> m) => Supplier(
        id: m['id'] as String,
        storeId: m['store_id'] as String,
        name: m['name'] as String,
        phone: m['phone'] as String?,
        address: m['address'] as String?,
        contactPerson: m['contact_person'] as String?,
        notes: m['notes'] as String?,
        isActive: m['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
