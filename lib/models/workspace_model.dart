import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/app_constants.dart';
import 'enums.dart';
import 'firestore_helpers.dart';

class WorkspaceSettings {
  final bool allowOverselling;
  final bool requireCustomerForSale;
  final double taxPercent;
  final bool preOrderEnabled;
  final bool preOrderRequireEstDate;
  final bool preOrderDeductOnConfirm;
  final String invoiceFooterNote;

  const WorkspaceSettings({
    this.allowOverselling = false,
    this.requireCustomerForSale = false,
    this.taxPercent = 0,
    this.preOrderEnabled = true,
    this.preOrderRequireEstDate = false,
    this.preOrderDeductOnConfirm = false,
    this.invoiceFooterNote = 'Terima kasih telah berbelanja',
  });

  factory WorkspaceSettings.fromMap(dynamic raw) {
    final m = mapOf(raw);
    return WorkspaceSettings(
      allowOverselling: boolOf(m['allowOverselling']),
      requireCustomerForSale: boolOf(m['requireCustomerForSale']),
      taxPercent: doubleOf(m['taxPercent']),
      preOrderEnabled: m['preOrder'] == null ? true : boolOf(m['preOrder']['enabled'], true),
      preOrderRequireEstDate: boolOf(mapOf(m['preOrder'])['requireEstimatedDate']),
      preOrderDeductOnConfirm: boolOf(mapOf(m['preOrder'])['deductStockOnConfirm']),
      invoiceFooterNote: str(mapOf(m['invoice'])['footerNote'],
          'Terima kasih telah berbelanja'),
    );
  }

  Map<String, dynamic> toMap() => {
        'allowOverselling': allowOverselling,
        'requireCustomerForSale': requireCustomerForSale,
        'taxPercent': taxPercent,
        'preOrder': {
          'enabled': preOrderEnabled,
          'requireEstimatedDate': preOrderRequireEstDate,
          'deductStockOnConfirm': preOrderDeductOnConfirm,
        },
        'invoice': {'footerNote': invoiceFooterNote},
      };
}

class Workspace {
  final String id;
  final String ownerId;
  final String name;
  final String businessType;
  final String businessCategory;
  final String description;
  final List<BusinessModel> businessModels;
  final String whatsappNumber;
  final String address;
  final String? logoUrl;
  final String currency;
  final String timezone;
  final WorkspaceStatus status;
  final bool isPersonalWorkspace;
  final WorkspaceSettings settings;
  final DateTime? createdAt;

  const Workspace({
    required this.id,
    required this.ownerId,
    required this.name,
    this.businessType = '',
    this.businessCategory = '',
    this.description = '',
    this.businessModels = const [BusinessModel.physicalProduct],
    this.whatsappNumber = '',
    this.address = '',
    this.logoUrl,
    this.currency = AppConstants.defaultCurrency,
    this.timezone = AppConstants.defaultTimezone,
    this.status = WorkspaceStatus.ACTIVE,
    this.isPersonalWorkspace = false,
    this.settings = const WorkspaceSettings(),
    this.createdAt,
  });

  factory Workspace.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Workspace(
      id: doc.id,
      ownerId: str(d['ownerId']),
      name: str(d['name']),
      businessType: str(d['businessType']),
      businessCategory: str(d['businessCategory']),
      description: str(d['description']),
      businessModels: strList(d['businessModels'])
          .map((s) => enumFromName(BusinessModel.values, s, BusinessModel.physicalProduct))
          .toList(),
      whatsappNumber: str(d['whatsappNumber']),
      address: str(d['address']),
      logoUrl: strOrNull(d['logoUrl']),
      currency: str(d['currency'], AppConstants.defaultCurrency),
      timezone: str(d['timezone'], AppConstants.defaultTimezone),
      status: enumFromName(WorkspaceStatus.values, d['status'], WorkspaceStatus.ACTIVE),
      isPersonalWorkspace: boolOf(d['personalWorkspace']),
      settings: WorkspaceSettings.fromMap(d['settings']),
      createdAt: dtFromTs(d['createdAt']),
    );
  }

  bool hasModel(BusinessModel model) =>
      businessModels.contains(model) ||
      (model != BusinessModel.preOrder &&
          businessModels.contains(BusinessModel.preOrder));

  bool get supportsPhysicalProducts =>
      hasModel(BusinessModel.physicalProduct);

  bool get supportsPreOrder => hasModel(BusinessModel.preOrder);

  Map<String, dynamic> toCreateMap() {
    return {
      'ownerId': ownerId,
      'name': name.trim(),
      'businessType': businessType,
      'businessCategory': businessCategory,
      'description': description,
      'businessModels': businessModels.map((m) => m.name).toList(),
      'whatsappNumber': whatsappNumber,
      'address': address,
      'logoUrl': logoUrl,
      'currency': currency,
      'timezone': timezone,
      'status': status.name,
      'personalWorkspace': isPersonalWorkspace,
      'settings': settings.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
