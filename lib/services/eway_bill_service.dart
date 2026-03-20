import 'dart:convert';

import 'package:billeasy/modals/business_profile.dart';
import 'package:billeasy/modals/invoice.dart';
import 'package:intl/intl.dart';

class EWayBillService {
  /// Validates invoice eligibility for E-Way Bill.
  /// Returns list of validation errors (empty list = valid).
  List<String> validate(Invoice invoice, BusinessProfile profile) {
    final errors = <String>[];

    if (invoice.grandTotal <= 50000) {
      errors.add(
        'Invoice value must exceed ₹50,000 (current: ₹${invoice.grandTotal.toStringAsFixed(2)})',
      );
    }

    if (!invoice.gstEnabled) {
      errors.add('GST must be enabled on the invoice for E-Way Bill');
    }

    if (profile.gstin.trim().isEmpty) {
      errors.add('Your business GSTIN is missing — update it in Settings');
    }

    if (invoice.customerGstin.trim().isEmpty) {
      errors.add(
        'Customer GSTIN is missing (required for B2B). Add it on the invoice.',
      );
    }

    final itemsMissingHsn = invoice.items
        .where((item) => item.hsnCode.trim().isEmpty)
        .map((item) => item.description)
        .toList();
    if (itemsMissingHsn.isNotEmpty) {
      errors.add(
        'HSN code missing for: ${itemsMissingHsn.join(', ')}',
      );
    }

    if (invoice.placeOfSupply.trim().isEmpty) {
      errors.add('Place of supply is not set on the invoice');
    }

    return errors;
  }

  /// Builds NIC-compliant E-Way Bill JSON structure.
  Map<String, dynamic> buildJson({
    required Invoice invoice,
    required BusinessProfile profile,
    String vehicleNo = '',
    String transporterGstin = '',
    String transportMode = '1', // 1=Road, 2=Rail, 3=Air, 4=Ship
  }) {
    return {
      'supplyType': 'O', // O=Outward, I=Inward
      'subSupplyType': '1', // 1=Supply
      'docType': 'INV',
      'docNo': invoice.invoiceNumber,
      'docDate': DateFormat('dd/MM/yyyy').format(invoice.createdAt),
      'fromGstin': profile.gstin,
      'fromTrdName': profile.storeName,
      'fromAddr1': profile.address,
      'fromPlace': profile.address.split(',').last.trim(),
      'fromPincode': '000000',
      'fromStateCode': _stateCode(profile.gstin),
      'toGstin':
          invoice.customerGstin.isEmpty ? 'URP' : invoice.customerGstin,
      'toTrdName': invoice.clientName,
      'toAddr1': '',
      'toPlace': invoice.placeOfSupply,
      'toPincode': '000000',
      'toStateCode': _stateCodeFromName(invoice.placeOfSupply),
      'totInvVal': invoice.grandTotal,
      'transDistance': '0',
      'transporterId': transporterGstin,
      'transporterName': '',
      'transDocNo': '',
      'transMode': transportMode,
      'vehicleNo': vehicleNo,
      'vehicleType': 'R', // R=Regular
      'itemList': invoice.items
          .map(
            (item) => {
              'productName': item.description,
              'hsnCode': item.hsnCode,
              'quantity': item.quantity,
              'qtyUnit': 'NOS',
              'taxableAmount': item.total,
              'sgstRate':
                  invoice.gstType == 'cgst_sgst' ? invoice.gstRate / 2 : 0,
              'cgstRate':
                  invoice.gstType == 'cgst_sgst' ? invoice.gstRate / 2 : 0,
              'igstRate':
                  invoice.gstType == 'igst' ? invoice.gstRate : 0,
              'cessRate': 0,
            },
          )
          .toList(),
    };
  }

  int _stateCode(String gstin) {
    if (gstin.length < 2) return 0;
    return int.tryParse(gstin.substring(0, 2)) ?? 0;
  }

  int _stateCodeFromName(String stateName) {
    const codes = {
      'Andhra Pradesh': 37,
      'Arunachal Pradesh': 12,
      'Assam': 18,
      'Bihar': 10,
      'Chhattisgarh': 22,
      'Goa': 30,
      'Gujarat': 24,
      'Haryana': 6,
      'Himachal Pradesh': 2,
      'Jharkhand': 20,
      'Karnataka': 29,
      'Kerala': 32,
      'Madhya Pradesh': 23,
      'Maharashtra': 27,
      'Manipur': 14,
      'Meghalaya': 17,
      'Mizoram': 15,
      'Nagaland': 13,
      'Odisha': 21,
      'Punjab': 3,
      'Rajasthan': 8,
      'Sikkim': 11,
      'Tamil Nadu': 33,
      'Telangana': 36,
      'Tripura': 16,
      'Uttar Pradesh': 9,
      'Uttarakhand': 5,
      'West Bengal': 19,
      'Delhi': 7,
      'Jammu and Kashmir': 1,
      'Ladakh': 38,
    };
    return codes[stateName] ?? 0;
  }

  String toJsonString(Map<String, dynamic> json) {
    return const JsonEncoder.withIndent('  ').convert(json);
  }
}
