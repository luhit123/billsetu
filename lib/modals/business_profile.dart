class BusinessProfile {
  const BusinessProfile({
    required this.ownerId,
    required this.storeName,
    required this.address,
    required this.phoneNumber,
    this.gstin = '',
    this.stateCode = '',
  });

  final String ownerId;
  final String storeName;
  final String address;
  final String phoneNumber;
  final String gstin;
  final String stateCode;

  factory BusinessProfile.fromMap(Map<String, dynamic> map, {String? ownerId}) {
    return BusinessProfile(
      ownerId: ownerId ?? (map['ownerId'] as String? ?? ''),
      storeName: map['storeName'] as String? ?? '',
      address: map['address'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? '',
      gstin: map['gstin'] as String? ?? '',
      stateCode: map['stateCode'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'storeName': storeName,
      'address': address,
      'phoneNumber': phoneNumber,
      'gstin': gstin,
      'stateCode': stateCode,
    };
  }
}
