class AppProfile {
  const AppProfile({
    required this.id,
    required this.storeId,
    required this.fullName,
    required this.role,
    this.phone,
  });

  final String id;
  final String storeId;
  final String fullName;
  final String role;
  final String? phone;

  bool get isOwner => role == 'owner';
  bool get isSeller => role == 'seller';

  factory AppProfile.fromMap(Map<String, dynamic> map) {
    return AppProfile(
      id: map['id'] as String,
      storeId: map['store_id'] as String,
      fullName: map['full_name'] as String,
      role: map['role'] as String,
      phone: map['phone'] as String?,
    );
  }
}
