class BusinessProfile {
  const BusinessProfile({
    required this.ownerId,
    required this.storeName,
    required this.address,
    required this.phoneNumber,
  });

  final String ownerId;
  final String storeName;
  final String address;
  final String phoneNumber;

  factory BusinessProfile.fromMap(Map<String, dynamic> map, {String? ownerId}) {
    return BusinessProfile(
      ownerId: ownerId ?? (map['ownerId'] as String? ?? ''),
      storeName: map['storeName'] as String? ?? '',
      address: map['address'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'storeName': storeName,
      'address': address,
      'phoneNumber': phoneNumber,
    };
  }
}
