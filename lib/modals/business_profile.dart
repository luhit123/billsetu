class BusinessProfile {
  const BusinessProfile({
    required this.ownerId,
    required this.storeName,
    required this.address,
    required this.phoneNumber,
    this.gstin = '',
    this.stateCode = '',
    this.logoUrl = '',
    this.bankAccountName = '',
    this.bankAccountNumber = '',
    this.bankIfsc = '',
    this.bankName = '',
    this.upiId = '',
    this.upiNumber = '',
    this.upiQrUrl = '',
    this.defaultPaymentTerms = '',
    this.defaultGstRate = '',
    this.invoicePrefix = 'INV-',
    this.showTaxOnPdf = true,
  });

  final String ownerId;
  final String storeName;
  final String address;
  final String phoneNumber;
  final String gstin;
  final String stateCode;

  // Business logo
  final String logoUrl;

  // Bank account details
  final String bankAccountName;
  final String bankAccountNumber;
  final String bankIfsc;
  final String bankName;

  // UPI
  final String upiId;
  final String upiNumber;
  final String upiQrUrl;

  // Invoice settings
  final String defaultPaymentTerms;
  final String defaultGstRate;
  final String invoicePrefix;
  final bool showTaxOnPdf;

  factory BusinessProfile.fromMap(Map<String, dynamic> map, {String? ownerId}) {
    return BusinessProfile(
      ownerId: ownerId ?? (map['ownerId'] as String? ?? ''),
      storeName: map['storeName'] as String? ?? '',
      address: map['address'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? '',
      gstin: map['gstin'] as String? ?? '',
      stateCode: map['stateCode'] as String? ?? '',
      logoUrl: map['logoUrl'] as String? ?? '',
      bankAccountName: map['bankAccountName'] as String? ?? '',
      bankAccountNumber: map['bankAccountNumber'] as String? ?? '',
      bankIfsc: map['bankIfsc'] as String? ?? '',
      bankName: map['bankName'] as String? ?? '',
      upiId: map['upiId'] as String? ?? '',
      upiNumber: map['upiNumber'] as String? ?? '',
      upiQrUrl: map['upiQrUrl'] as String? ?? '',
      defaultPaymentTerms: map['defaultPaymentTerms'] as String? ?? '',
      defaultGstRate: map['defaultGstRate'] as String? ?? '',
      invoicePrefix: map['invoicePrefix'] as String? ?? 'INV-',
      showTaxOnPdf: map['showTaxOnPdf'] as bool? ?? true,
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
      'logoUrl': logoUrl,
      'bankAccountName': bankAccountName,
      'bankAccountNumber': bankAccountNumber,
      'bankIfsc': bankIfsc,
      'bankName': bankName,
      'upiId': upiId,
      'upiNumber': upiNumber,
      'upiQrUrl': upiQrUrl,
      'defaultPaymentTerms': defaultPaymentTerms,
      'defaultGstRate': defaultGstRate,
      'invoicePrefix': invoicePrefix,
      'showTaxOnPdf': showTaxOnPdf,
    };
  }

  BusinessProfile copyWith({
    String? ownerId,
    String? storeName,
    String? address,
    String? phoneNumber,
    String? gstin,
    String? stateCode,
    String? logoUrl,
    String? bankAccountName,
    String? bankAccountNumber,
    String? bankIfsc,
    String? bankName,
    String? upiId,
    String? upiNumber,
    String? upiQrUrl,
    String? defaultPaymentTerms,
    String? defaultGstRate,
    String? invoicePrefix,
    bool? showTaxOnPdf,
  }) {
    return BusinessProfile(
      ownerId: ownerId ?? this.ownerId,
      storeName: storeName ?? this.storeName,
      address: address ?? this.address,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      gstin: gstin ?? this.gstin,
      stateCode: stateCode ?? this.stateCode,
      logoUrl: logoUrl ?? this.logoUrl,
      bankAccountName: bankAccountName ?? this.bankAccountName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankIfsc: bankIfsc ?? this.bankIfsc,
      bankName: bankName ?? this.bankName,
      upiId: upiId ?? this.upiId,
      upiNumber: upiNumber ?? this.upiNumber,
      upiQrUrl: upiQrUrl ?? this.upiQrUrl,
      defaultPaymentTerms: defaultPaymentTerms ?? this.defaultPaymentTerms,
      defaultGstRate: defaultGstRate ?? this.defaultGstRate,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      showTaxOnPdf: showTaxOnPdf ?? this.showTaxOnPdf,
    );
  }
}
