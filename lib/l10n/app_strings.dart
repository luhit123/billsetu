import 'package:billeasy/screens/language_selection_screen.dart';
import 'package:billeasy/l10n/translations/all_translations.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── AppStrings ─────────────────────────────────────────────────────────────
//
// Map-based localization: each language's translations live in a separate
// file under `lib/l10n/translations/`. The `_t()` method does a simple key
// lookup with automatic fallback to English.

class AppStrings {
  const AppStrings(this._lang);

  final AppLanguage _lang;
  AppLanguage get language => _lang;

  static AppStrings of(BuildContext context) => _AppStringsScope.of(context);

  /// Core lookup: find the string for [key] in the current language,
  /// falling back to English if missing.
  String _t(String key) {
    final langMap = allTranslations[_lang];
    return langMap?[key] ?? allTranslations[AppLanguage.english]?[key] ?? key;
  }

  // ── Login ──────────────────────────────────────────────────────────────────

  String get loginTagline => _t('loginTagline');
  String get loginBadgeLabel => _t('loginBadgeLabel');
  String get loginWelcome => _t('loginWelcome');
  String get loginSubtitle => _t('loginSubtitle');
  String get loginSigningIn => _t('loginSigningIn');
  String get loginContinueGoogle => _t('loginContinueGoogle');
  String get loginCancelled => _t('loginCancelled');

  // ── Home ───────────────────────────────────────────────────────────────────

  String get homeSearchHint => _t('homeSearchHint');
  String get homeCloseSearch => _t('homeCloseSearch');
  String get homeSearchTooltip => _t('homeSearchTooltip');
  String get homeFilterPeriodTooltip => _t('homeFilterPeriodTooltip');
  String get homePeriodLabel => _t('homePeriodLabel');
  String get homePeriodChange => _t('homePeriodChange');
  String get homeStatTotalBilled => _t('homeStatTotalBilled');
  String get homeStatCollected => _t('homeStatCollected');
  String get homeStatOutstanding => _t('homeStatOutstanding');
  String get homeStatDiscounts => _t('homeStatDiscounts');
  String get homeFilterAll => _t('homeFilterAll');
  String get homeFilterPaid => _t('homeFilterPaid');
  String get homeFilterPending => _t('homeFilterPending');
  String get homeFilterOverdue => _t('homeFilterOverdue');

  String homeNoInvoicesSearch(String query) =>
      _t('homeNoInvoicesSearch').replaceAll('\$query', query);
  String get homeNoInvoicesYet => _t('homeNoInvoicesYet');
  String get homeNoInvoicesFilter => _t('homeNoInvoicesFilter');
  String get homeLoadError => _t('homeLoadError');
  String get homePeriodAllInvoices => _t('homePeriodAllInvoices');
  String get homePeriodToday => _t('homePeriodToday');
  String get homePeriodThisWeek => _t('homePeriodThisWeek');
  String get homePeriodCustomRange => _t('homePeriodCustomRange');

  String homePeriodDateRange(String start, String end) => '$start - $end';
  String homePeriodCustomLabel(String start, String end) =>
      _t('homePeriodCustomLabel')
          .replaceAll('\$start', start)
          .replaceAll('\$end', end);

  String get homeRecentInvoices => _t('homeRecentInvoices');
  String get homeViewAll => _t('homeViewAll');
  String get homeMonthlyRevenue => _t('homeMonthlyRevenue');
  String get homeCreateInvoice => _t('homeCreateInvoice');
  String get homeDateApply => _t('homeDateApply');
  String get homeBottomInvoices => _t('homeBottomInvoices');
  String get homeBottomHome => _t('homeBottomHome');
  String get homeBottomClients => _t('homeBottomClients');
  String get homeBottomProducts => _t('homeBottomProducts');
  String get homeAddClient => _t('homeAddClient');
  String get homeQuickActions => _t('homeQuickActions');

  // ── Drawer ─────────────────────────────────────────────────────────────────

  String get drawerWorkspace => _t('drawerWorkspace');
  String get drawerMyProfile => _t('drawerMyProfile');
  String get drawerProducts => _t('drawerProducts');
  String get drawerCustomers => _t('drawerCustomers');
  String get drawerAnalytics => _t('drawerAnalytics');
  String get drawerReports => _t('drawerReports');
  String get drawerGst => _t('drawerGst');
  String get drawerSettings => _t('drawerSettings');
  String get drawerLogIn => _t('drawerLogIn');
  String get drawerLogOut => _t('drawerLogOut');
  String get drawerNotSignedIn => _t('drawerNotSignedIn');
  String get drawerProductsDesc => _t('drawerProductsDesc');
  String get drawerCustomersDesc => _t('drawerCustomersDesc');
  String get drawerAnalyticsDesc => _t('drawerAnalyticsDesc');
  String get drawerGstDesc => _t('drawerGstDesc');
  String get drawerSettingsDesc => _t('drawerSettingsDesc');
  String get drawerProfileLoadError => _t('drawerProfileLoadError');
  String get drawerMyProfileFallback => _t('drawerMyProfileFallback');
  String drawerFailedLogOut(String error) =>
      _t('drawerFailedLogOut').replaceAll('\$error', error);

  // ── Settings ───────────────────────────────────────────────────────────────

  String get settingsHubTitle => _t('settingsHubTitle');
  String get settingsHubSubtitle => _t('settingsHubSubtitle');
  String get settingsQuickActionsTitle => _t('settingsQuickActionsTitle');
  String get settingsQuickActionsSubtitle => _t('settingsQuickActionsSubtitle');
  String get settingsEditProfile => _t('settingsEditProfile');
  String get settingsHeroHint => _t('settingsHeroHint');
  String get settingsAboutTitle => _t('settingsAboutTitle');
  String get settingsAboutBody => _t('settingsAboutBody');
  String get settingsHelpTitle => _t('settingsHelpTitle');
  String get settingsHelpBody => _t('settingsHelpBody');
  String get settingsInvoicesSubtitle => _t('settingsInvoicesSubtitle');
  String get settingsSignOut => _t('settingsSignOut');
  String get settingsLanguageTitle => _t('settingsLanguageTitle');
  String get settingsLanguageSubtitle => _t('settingsLanguageSubtitle');
  String settingsCurrentLanguage(String language) =>
      _t('settingsCurrentLanguage').replaceAll('\$language', language);
  String settingsLanguageChanged(String language) =>
      _t('settingsLanguageChanged').replaceAll('\$language', language);

  // ── Create Invoice ─────────────────────────────────────────────────────────

  String get createTitle => _t('createTitle');
  String get createCustomerLabel => _t('createCustomerLabel');
  String get createSelectCustomer => _t('createSelectCustomer');
  String get createCustomerHint => _t('createCustomerHint');
  String get createPickCustomer => _t('createPickCustomer');
  String get createChangeCustomer => _t('createChangeCustomer');
  String get createAddNew => _t('createAddNew');
  String get createCustomerRequired => _t('createCustomerRequired');
  String get createInvoiceDate => _t('createInvoiceDate');
  String get createPickDate => _t('createPickDate');
  String get createDateHintEmpty => _t('createDateHintEmpty');
  String get createDateHintSelected => _t('createDateHintSelected');
  String get createDateRequired => _t('createDateRequired');
  String get createProductLabel => _t('createProductLabel');
  String get createQtyLabel => _t('createQtyLabel');
  String get createUnitLabel => _t('createUnitLabel');
  String get createUnitPriceLabel => _t('createUnitPriceLabel');
  String get createEnterProduct => _t('createEnterProduct');
  String get createDeleteItem => _t('createDeleteItem');
  String get createAddItem => _t('createAddItem');
  String get createInvoiceStatus => _t('createInvoiceStatus');
  String get createDiscountTitle => _t('createDiscountTitle');
  String get createDiscountPctLabel => _t('createDiscountPctLabel');
  String get createDiscountOverallLabel => _t('createDiscountOverallLabel');
  String get createDiscountPctField => _t('createDiscountPctField');
  String get createDiscountOverallField => _t('createDiscountOverallField');
  String get createDiscountPctHint => _t('createDiscountPctHint');
  String get createDiscountOverallHint => _t('createDiscountOverallHint');
  String get createSummarySubtotal => _t('createSummarySubtotal');
  String get createSummaryDiscount => _t('createSummaryDiscount');
  String get createSummaryGrandTotal => _t('createSummaryGrandTotal');
  String get createSavingInvoice => _t('createSavingInvoice');
  String get createSaveInvoice => _t('createSaveInvoice');
  String createItemNumber(int number) =>
      _t('createItemNumber').replaceAll('\$number', number.toString());
  String get createSaveHint => _t('createSaveHint');
  String get createDiscountEmptyHint => _t('createDiscountEmptyHint');
  String get createErrorPctMax => _t('createErrorPctMax');
  String get createErrorOverallMax => _t('createErrorOverallMax');
  String get createSignInRequired => _t('createSignInRequired');
  String createFailedSave(String error) =>
      _t('createFailedSave').replaceAll('\$error', error);
  String createDiscountPreviewPct(String pct, String subtotal, String discountAmount) =>
      _t('createDiscountPreviewPct')
          .replaceAll('\$pct', pct)
          .replaceAll('\$subtotal', subtotal)
          .replaceAll('\$discountAmount', discountAmount);
  String createDiscountPreviewOverall(String discAmt, String subtotal) =>
      _t('createDiscountPreviewOverall')
          .replaceAll('\$discAmt', discAmt)
          .replaceAll('\$subtotal', subtotal);
  String get createAddLineItem => _t('createAddLineItem');
  String get createGstTitle => _t('createGstTitle');
  String get createGstRate => _t('createGstRate');
  String get createGstType => _t('createGstType');
  String get createGstTypeCgstSgst => _t('createGstTypeCgstSgst');
  String get createGstTypeIgst => _t('createGstTypeIgst');
  String get createGstPlaceOfSupply => _t('createGstPlaceOfSupply');
  String get createGstPlaceOfSupplyHint => _t('createGstPlaceOfSupplyHint');
  String get createGstCustomerGstin => _t('createGstCustomerGstin');
  String get createGstCustomerGstinHint => _t('createGstCustomerGstinHint');
  String get createDueDateLabel => _t('createDueDateLabel');
  String get createDueDateHint => _t('createDueDateHint');
  String get createDueDateNone => _t('createDueDateNone');
  String get createHsnLabel => _t('createHsnLabel');
  String get createHsnHint => _t('createHsnHint');
  String get createPerItemGstLabel => _t('createPerItemGstLabel');
  String get hsnCodeLabel => _t('hsnCodeLabel');
  String get hsnCodeHint => _t('hsnCodeHint');

  // ── Home Tabs ──────────────────────────────────────────────────────────────

  String get homeTabHome => _t('homeTabHome');
  String get homeTabInvoices => _t('homeTabInvoices');
  String get homeTabCustomers => _t('homeTabCustomers');
  String get homeTabProducts => _t('homeTabProducts');
  String get drawerPurchases => _t('drawerPurchases');

  // ── GST Report ─────────────────────────────────────────────────────────────

  String get gstReportTitle => _t('gstReportTitle');
  String get gstReportPeriod => _t('gstReportPeriod');
  String get gstReportNoData => _t('gstReportNoData');
  String get gstReportSummaryTitle => _t('gstReportSummaryTitle');
  String get gstReportTaxableAmount => _t('gstReportTaxableAmount');
  String get gstReportCgst => _t('gstReportCgst');
  String get gstReportSgst => _t('gstReportSgst');
  String get gstReportIgst => _t('gstReportIgst');
  String get gstReportTotalTax => _t('gstReportTotalTax');
  String get gstReportGrandTotal => _t('gstReportGrandTotal');
  String gstReportInvoiceCount(int count) =>
      _t('gstReportInvoiceCount').replaceAll('\$count', count.toString());
  String get gstReportBreakdownTitle => _t('gstReportBreakdownTitle');
  String get gstReportNoGst => _t('gstReportNoGst');
  String get gstReportDetailsCgst => _t('gstReportDetailsCgst');
  String get gstReportDetailsSgst => _t('gstReportDetailsSgst');
  String get gstReportDetailsIgst => _t('gstReportDetailsIgst');
  String get gstReportMonthly => _t('gstReportMonthly');
  String get gstReportQuarterly => _t('gstReportQuarterly');
  String get gstReportYearly => _t('gstReportYearly');
  String get gstReportInvoiceBreakdown => _t('gstReportInvoiceBreakdown');
  String get gstReportNoInvoices => _t('gstReportNoInvoices');
  String get gstReportShareReport => _t('gstReportShareReport');

  // ── Status ─────────────────────────────────────────────────────────────────

  String get statusPaid => _t('statusPaid');
  String get statusPending => _t('statusPending');
  String get statusOverdue => _t('statusOverdue');

  // ── Invoice Details ────────────────────────────────────────────────────────

  String get detailsTitle => _t('detailsTitle');
  String get detailsPreviewPrint => _t('detailsPreviewPrint');
  String get detailsSeller => _t('detailsSeller');
  String get detailsStore => _t('detailsStore');
  String get detailsAddress => _t('detailsAddress');
  String get detailsNotAddedYet => _t('detailsNotAddedYet');
  String get detailsPhone => _t('detailsPhone');
  String get detailsEmail => _t('detailsEmail');
  String get detailsCustomer => _t('detailsCustomer');
  String get detailsName => _t('detailsName');
  String get detailsReference => _t('detailsReference');
  String get detailsOpenProfile => _t('detailsOpenProfile');
  String get detailsItems => _t('detailsItems');
  String get detailsItemQty => _t('detailsItemQty');
  String get detailsItemUnitPrice => _t('detailsItemUnitPrice');
  String get detailsDiscount => _t('detailsDiscount');
  String get detailsItemsCount => _t('detailsItemsCount');
  String get detailsStatus => _t('detailsStatus');
  String get detailsNoDiscount => _t('detailsNoDiscount');
  String get detailsOverallDiscount => _t('detailsOverallDiscount');
  String get detailsYourStore => _t('detailsYourStore');
  String get detailsAmountSummary => _t('detailsAmountSummary');
  String get detailsInvoiceLabel => _t('detailsInvoiceLabel');
  String get detailsDateLabel => _t('detailsDateLabel');
  String get detailsStatusLabel => _t('detailsStatusLabel');
  String get detailsDueLabel => _t('detailsDueLabel');
  String get detailsDueDateNone => _t('detailsDueDateNone');
  String get detailsItemsTitle => _t('detailsItemsTitle');
  String get detailsItem => _t('detailsItem');
  String get detailsQty => _t('detailsQty');
  String get detailsUnit => _t('detailsUnit');
  String get detailsPrice => _t('detailsPrice');
  String get detailsSubtotal => _t('detailsSubtotal');
  String get detailsTotal => _t('detailsTotal');
  String get detailsGstTitle => _t('detailsGstTitle');
  String get detailsGstEnabled => _t('detailsGstEnabled');
  String get detailsGstRate => _t('detailsGstRate');
  String get detailsGstType => _t('detailsGstType');
  String get detailsGstTypeCgstSgst => _t('detailsGstTypeCgstSgst');
  String get detailsGstTypeIgst => _t('detailsGstTypeIgst');
  String get detailsGstPlaceOfSupply => _t('detailsGstPlaceOfSupply');
  String get detailsGstCustomerGstin => _t('detailsGstCustomerGstin');
  String get detailsGstTaxable => _t('detailsGstTaxable');
  String get detailsGstCgst => _t('detailsGstCgst');
  String get detailsGstSgst => _t('detailsGstSgst');
  String get detailsGstIgst => _t('detailsGstIgst');
  String get detailsGstTotalTax => _t('detailsGstTotalTax');
  String get detailsDiscountLabel => _t('detailsDiscountLabel');
  String get detailsGrandTotal => _t('detailsGrandTotal');
  String get detailsActionsTitle => _t('detailsActionsTitle');
  String get detailsSharePdf => _t('detailsSharePdf');
  String get detailsDownloadPdf => _t('detailsDownloadPdf');
  String get detailsMarkPaid => _t('detailsMarkPaid');
  String get detailsMarkPending => _t('detailsMarkPending');
  String get detailsMarkOverdue => _t('detailsMarkOverdue');
  String get detailsDeleteInvoice => _t('detailsDeleteInvoice');
  String get detailsDeleteConfirmTitle => _t('detailsDeleteConfirmTitle');
  String get detailsDeleteConfirmBody => _t('detailsDeleteConfirmBody');
  String get detailsDeleteConfirmAction => _t('detailsDeleteConfirmAction');
  String get detailsDeleteCancelAction => _t('detailsDeleteCancelAction');
  String get detailsDeleteSuccess => _t('detailsDeleteSuccess');
  String detailsIssuedBy(String name) =>
      _t('detailsIssuedBy').replaceAll('\$name', name);
  String detailsPctOff(String value) =>
      _t('detailsPctOff').replaceAll('\$value', value);
  String detailsPdfError(String error) =>
      _t('detailsPdfError').replaceAll('\$error', error);
  String get detailsSummaryTitle => _t('detailsSummaryTitle');
  String get detailsYes => _t('detailsYes');
  String get detailsNo => _t('detailsNo');
  String get detailsHsnCode => _t('detailsHsnCode');
  String get detailsItemGstRate => _t('detailsItemGstRate');
  String get detailsItemAmount => _t('detailsItemAmount');
  String get detailsTaxBreakdown => _t('detailsTaxBreakdown');
  String get detailsHsnSac => _t('detailsHsnSac');
  String get detailsRate => _t('detailsRate');

  // ── Invoice Card Actions ───────────────────────────────────────────────────

  String get cardMarkPaid => _t('cardMarkPaid');
  String get cardMarkOverdue => _t('cardMarkOverdue');
  String get cardDelete => _t('cardDelete');

  // ── Profile ────────────────────────────────────────────────────────────────

  String get profileAppBarSetup => _t('profileAppBarSetup');
  String get profileAppBarEdit => _t('profileAppBarEdit');
  String get profileSignOutTooltip => _t('profileSignOutTooltip');
  String get profilePromptTitleSetup => _t('profilePromptTitleSetup');
  String get profilePromptTitleEdit => _t('profilePromptTitleEdit');
  String get profilePromptBodySetup => _t('profilePromptBodySetup');
  String get profilePromptBodyEdit => _t('profilePromptBodyEdit');
  String get profileBadgeFallback => _t('profileBadgeFallback');
  String get profileStoreLabel => _t('profileStoreLabel');
  String get profileAddressLabel => _t('profileAddressLabel');
  String get profilePhoneLabel => _t('profilePhoneLabel');
  String get profileOptionalHint => _t('profileOptionalHint');
  String get profileSaving => _t('profileSaving');
  String get profileSaveAndContinue => _t('profileSaveAndContinue');
  String get profileGstinLabel => _t('profileGstinLabel');
  String get profileTitle => _t('profileTitle');
  String get profileBusinessName => _t('profileBusinessName');
  String get profileBusinessNameHint => _t('profileBusinessNameHint');
  String get profilePhone => _t('profilePhone');
  String get profilePhoneHint => _t('profilePhoneHint');
  String get profileEmail => _t('profileEmail');
  String get profileEmailHint => _t('profileEmailHint');
  String get profileAddress => _t('profileAddress');
  String get profileAddressHint => _t('profileAddressHint');
  String get profileGstin => _t('profileGstin');
  String get profileGstinHint => _t('profileGstinHint');
  String get profileSave => _t('profileSave');
  String get profileSaveUpdates => _t('profileSaveUpdates');
  String get profileSetupTitle => _t('profileSetupTitle');
  String get profileSetupSubtitle => _t('profileSetupSubtitle');
  String get profileSavingProfile => _t('profileSavingProfile');
  String get profileSignInRequired => _t('profileSignInRequired');
  String get profileSavedSuccess => _t('profileSavedSuccess');
  String profileFailedSave(String error) =>
      _t('profileFailedSave').replaceAll('\$error', error);
  String profileFailedSignOut(String error) =>
      _t('profileFailedSignOut').replaceAll('\$error', error);

  // ── Placeholder ────────────────────────────────────────────────────────────

  String placeholderComingSoon(String title) =>
      _t('placeholderComingSoon').replaceAll('\$title', title);
  String get placeholderBody => _t('placeholderBody');
  String get placeholderStayTuned => _t('placeholderStayTuned');

  // ── Customers ──────────────────────────────────────────────────────────────

  String get customersTitle => _t('customersTitle');
  String get customersSelectTitle => _t('customersSelectTitle');
  String get customersSearchHint => _t('customersSearchHint');
  String get customersCloseSearch => _t('customersCloseSearch');
  String get customersSearchTooltip => _t('customersSearchTooltip');
  String get customersManageGroupsTooltip => _t('customersManageGroupsTooltip');
  String get customersIntroTitle => _t('customersIntroTitle');
  String get customersIntroBody => _t('customersIntroBody');
  String get customersSelectIntroTitle => _t('customersSelectIntroTitle');
  String get customersSelectIntroBody => _t('customersSelectIntroBody');
  String get customersEmptyTitle => _t('customersEmptyTitle');
  String get customersEmptySelectTitle => _t('customersEmptySelectTitle');
  String get customersEmptyBody => _t('customersEmptyBody');
  String get customersEmptySelectBody => _t('customersEmptySelectBody');
  String get customersAddButton => _t('customersAddButton');
  String get customersAll => _t('customersAll');
  String get customersUngrouped => _t('customersUngrouped');
  String get customersMoveToGroup => _t('customersMoveToGroup');
  String get customersChangeGroup => _t('customersChangeGroup');
  String get customersDeleteTitle => _t('customersDeleteTitle');
  String get customersDeleteSubtitle => _t('customersDeleteSubtitle');
  String get customersCancel => _t('customersCancel');
  String get customersDelete => _t('customersDelete');
  String get customersNoGroupSubtitle => _t('customersNoGroupSubtitle');
  String get customersGroupsError => _t('customersGroupsError');
  String get customersEmptyGroupTitle => _t('customersEmptyGroupTitle');
  String get customersEmptyGroupBody => _t('customersEmptyGroupBody');
  String get customersNoCustomersTitle => _t('customersNoCustomersTitle');
  String get customersNoCustomersBody => _t('customersNoCustomersBody');
  String get customersAddFirst => _t('customersAddFirst');
  String customersEmptySearchTitle(String query) =>
      _t('customersEmptySearchTitle').replaceAll('\$query', query);
  String get customersEmptySearchBody => _t('customersEmptySearchBody');
  String customersReadyForBilling(String name) =>
      _t('customersReadyForBilling').replaceAll('\$name', name);
  String get customersAddCustomer => _t('customersAddCustomer');
  String get customersSelected => _t('customersSelected');

  // ── Customer Form ──────────────────────────────────────────────────────────

  String get customerFormTitleAdd => _t('customerFormTitleAdd');
  String get customerFormSubtitleAdd => _t('customerFormSubtitleAdd');
  String get customerFormSubtitleEdit => _t('customerFormSubtitleEdit');
  String get customerFormNameError => _t('customerFormNameError');
  String get customerFormOptionalHint => _t('customerFormOptionalHint');
  String get customerGstinLabel => _t('customerGstinLabel');
  String get customerGstinHint => _t('customerGstinHint');
  String get customerFormSaveChanges => _t('customerFormSaveChanges');
  String get customerFormCreate => _t('customerFormCreate');
  String get customerFormTitleNew => _t('customerFormTitleNew');
  String get customerFormTitleEdit => _t('customerFormTitleEdit');
  String get customerFormNameLabel => _t('customerFormNameLabel');
  String get customerFormNameHint => _t('customerFormNameHint');
  String get customerFormPhoneLabel => _t('customerFormPhoneLabel');
  String get customerFormPhoneHint => _t('customerFormPhoneHint');
  String get customerFormEmailLabel => _t('customerFormEmailLabel');
  String get customerFormEmailHint => _t('customerFormEmailHint');
  String get customerFormAddressLabel => _t('customerFormAddressLabel');
  String get customerFormAddressHint => _t('customerFormAddressHint');
  String get customerFormGstinLabel => _t('customerFormGstinLabel');
  String get customerFormGstinHint => _t('customerFormGstinHint');
  String get customerFormNotesLabel => _t('customerFormNotesLabel');
  String get customerFormNotesHint => _t('customerFormNotesHint');
  String get customerFormSave => _t('customerFormSave');
  String get customerFormSaveUpdates => _t('customerFormSaveUpdates');
  String get customerFormSaving => _t('customerFormSaving');
  String get customerFormNameRequired => _t('customerFormNameRequired');
  String customerFormFailedSave(String error) =>
      _t('customerFormFailedSave').replaceAll('\$error', error);

  // ── Customer Details ───────────────────────────────────────────────────────

  String get customerDetailsTitle => _t('customerDetailsTitle');
  String get customerDetailsStatInvoices => _t('customerDetailsStatInvoices');
  String get customerDetailsStatTotalBilled => _t('customerDetailsStatTotalBilled');
  String get customerDetailsStatOutstanding => _t('customerDetailsStatOutstanding');
  String get customerDetailsContact => _t('customerDetailsContact');
  String get customerDetailsGroup => _t('customerDetailsGroup');
  String get customerDetailsPhone => _t('customerDetailsPhone');
  String get customerDetailsEmail => _t('customerDetailsEmail');
  String get customerDetailsAddress => _t('customerDetailsAddress');
  String get customerDetailsNotes => _t('customerDetailsNotes');
  String get customerDetailsNotAdded => _t('customerDetailsNotAdded');
  String get customerDetailsHistory => _t('customerDetailsHistory');
  String get customerDetailsHistoryEmpty => _t('customerDetailsHistoryEmpty');
  String get customerDetailsHistoryError => _t('customerDetailsHistoryError');
  String get customerDetailsCreateInvoice => _t('customerDetailsCreateInvoice');
  String get customerDetailsEditTooltip => _t('customerDetailsEditTooltip');
  String get customerDetailsMoveGroup => _t('customerDetailsMoveGroup');
  String get customerDetailsChangeGroup => _t('customerDetailsChangeGroup');
  String customerDetailsLastUpdated(String date) =>
      _t('customerDetailsLastUpdated').replaceAll('\$date', date);
  String customersCurrentGroup(String name) =>
      _t('customersCurrentGroup').replaceAll('\$name', name);
  String get customersGroupAll => _t('customersGroupAll');
  String get customersGroupUngrouped => _t('customersGroupUngrouped');
  String customersDeleteConfirm(String name) =>
      _t('customersDeleteConfirm').replaceAll('\$name', name);
  String customersNowUngrouped(String name) =>
      _t('customersNowUngrouped').replaceAll('\$name', name);
  String customersMovedToGroup(String name, String group) =>
      _t('customersMovedToGroup')
          .replaceAll('\$name', name)
          .replaceAll('\$group', group);
  String customersFailedUpdateGroup(String error) =>
      _t('customersFailedUpdateGroup').replaceAll('\$error', error);
  String customersDeletedCustomer(String name) =>
      _t('customersDeletedCustomer').replaceAll('\$name', name);
  String customersFailedDelete(String error) =>
      _t('customersFailedDelete').replaceAll('\$error', error);
  String customerDetailsNowUngrouped(String name) =>
      _t('customerDetailsNowUngrouped').replaceAll('\$name', name);
  String customerDetailsMovedToGroup(String name, String group) =>
      _t('customerDetailsMovedToGroup')
          .replaceAll('\$name', name)
          .replaceAll('\$group', group);
  String customerDetailsFailedUpdateGroup(String error) =>
      _t('customerDetailsFailedUpdateGroup').replaceAll('\$error', error);

  // ── Customer Groups ────────────────────────────────────────────────────────

  String get groupsTitle => _t('groupsTitle');
  String get groupsSubtitle => _t('groupsSubtitle');
  String get groupsAdd => _t('groupsAdd');
  String get groupsLoadError => _t('groupsLoadError');
  String get groupsEmpty => _t('groupsEmpty');
  String get groupsRenameHint => _t('groupsRenameHint');
  String get groupsRenameTooltip => _t('groupsRenameTooltip');
  String get groupsAddTitle => _t('groupsAddTitle');
  String get groupsRenameTitle => _t('groupsRenameTitle');
  String get groupsCancel => _t('groupsCancel');
  String get groupsPickerTitle => _t('groupsPickerTitle');
  String get groupsPickerSubtitle => _t('groupsPickerSubtitle');
  String get groupsManage => _t('groupsManage');
  String get groupsUngrouped => _t('groupsUngrouped');
  String get groupsUngroupedSubtitle => _t('groupsUngroupedSubtitle');
  String get groupsPickerEmpty => _t('groupsPickerEmpty');
  String get groupsSearchHint => _t('groupsSearchHint');
  String get groupsNoGroupsTitle => _t('groupsNoGroupsTitle');
  String get groupsNoGroupsBody => _t('groupsNoGroupsBody');
  String get groupsAddFirst => _t('groupsAddFirst');
  String get groupsNewTitle => _t('groupsNewTitle');
  String get groupsEditTitle => _t('groupsEditTitle');
  String get groupsNameLabel => _t('groupsNameLabel');
  String get groupsNameHint => _t('groupsNameHint');
  String get groupsSave => _t('groupsSave');
  String get groupsSaving => _t('groupsSaving');
  String get groupsNameRequired => _t('groupsNameRequired');
  String groupsFailedSave(String error) =>
      _t('groupsFailedSave').replaceAll('\$error', error);
  String get groupsDeleteConfirm => _t('groupsDeleteConfirm');
  String get groupsDeleteSuccess => _t('groupsDeleteSuccess');
  String groupsMoveInto(String name) =>
      _t('groupsMoveInto').replaceAll('\$name', name);

  // ── Products ───────────────────────────────────────────────────────────────

  String get productsTitle => _t('productsTitle');
  String get productsSearchHint => _t('productsSearchHint');
  String get productsNoProductsTitle => _t('productsNoProductsTitle');
  String get productsNoProductsBody => _t('productsNoProductsBody');
  String get productsAddFirst => _t('productsAddFirst');
  String get productsAddProduct => _t('productsAddProduct');
  String get productsEditProduct => _t('productsEditProduct');
  String get productsFormNameLabel => _t('productsFormNameLabel');
  String get productsFormNameHint => _t('productsFormNameHint');
  String get productsFormPriceLabel => _t('productsFormPriceLabel');
  String get productsFormPriceHint => _t('productsFormPriceHint');
  String get productsFormUnitLabel => _t('productsFormUnitLabel');
  String get productsFormUnitHint => _t('productsFormUnitHint');
  String get productsFormHsnLabel => _t('productsFormHsnLabel');
  String get productsFormHsnHint => _t('productsFormHsnHint');
  String get productsFormGstLabel => _t('productsFormGstLabel');
  String get productsFormGstHint => _t('productsFormGstHint');
  String get productsFormSave => _t('productsFormSave');
  String get productsFormSaveChanges => _t('productsFormSaveChanges');
  String get productsFormSaving => _t('productsFormSaving');
  String get productsFormNameRequired => _t('productsFormNameRequired');
  String get productsFormFailedSave => _t('productsFormFailedSave');
  String get productsFormDeleteConfirm => _t('productsFormDeleteConfirm');
  String get productsFormDeleteSuccess => _t('productsFormDeleteSuccess');
  String get productsFormFailedDelete => _t('productsFormFailedDelete');
  String get productsFilterAll => _t('productsFilterAll');
  String get productsFilterLowStock => _t('productsFilterLowStock');
  String get productsFilterOutOfStock => _t('productsFilterOutOfStock');
  String get productsStockLabel => _t('productsStockLabel');
  String get productsLowStock => _t('productsLowStock');
  String get productsOutOfStock => _t('productsOutOfStock');
  String get productsInStock => _t('productsInStock');
  String get productsStockIn => _t('productsStockIn');
  String get productsStockOut => _t('productsStockOut');
  String get productsStockAdjust => _t('productsStockAdjust');
  String get productsMovements => _t('productsMovements');
  String get productsMovementIn => _t('productsMovementIn');
  String get productsMovementOut => _t('productsMovementOut');
  String get productsMovementAdjust => _t('productsMovementAdjust');
  String get productsNoMovements => _t('productsNoMovements');
  String get productsCurrentStock => _t('productsCurrentStock');
  String get productsMovementNote => _t('productsMovementNote');
  String get productsMovementQty => _t('productsMovementQty');
  String get productsMovementSave => _t('productsMovementSave');
  String get productsMovementSaving => _t('productsMovementSaving');
  String get productsDeleteConfirm => _t('productsDeleteConfirm');
  String get productsDeleteSuccess => _t('productsDeleteSuccess');

  // ── PDF ────────────────────────────────────────────────────────────────────

  String get pdfInvoiceNo => _t('pdfInvoiceNo');
  String get pdfInvoiceDate => _t('pdfInvoiceDate');
  String get pdfInvoice => _t('pdfInvoice');
  String get pdfFrom => _t('pdfFrom');
  String get pdfBillTo => _t('pdfBillTo');
  String get pdfItem => _t('pdfItem');
  String get pdfAmount => _t('pdfAmount');
  String get pdfAddressNotAdded => _t('pdfAddressNotAdded');
  String get pdfPhoneNotAdded => _t('pdfPhoneNotAdded');
  String get pdfGeneratedBy => _t('pdfGeneratedBy');
  String get pdfPage => _t('pdfPage');
  String get pdfOf => _t('pdfOf');
  String pdfItemsCount(int n) =>
      _t('pdfItemsCount').replaceAll('\$n', n.toString());

  // ── Login (Phone/OTP) ──────────────────────────────────────────────────────

  String get loginPhoneLabel => _t('loginPhoneLabel');
  String get loginPhoneHint => _t('loginPhoneHint');
  String get loginSendOtp => _t('loginSendOtp');
  String get loginVerifyOtp => _t('loginVerifyOtp');
  String get loginOtpSent => _t('loginOtpSent');
  String get loginOtpHint => _t('loginOtpHint');
  String get loginOtpError => _t('loginOtpError');
  String get loginOrDivider => _t('loginOrDivider');
  String get loginPhoneError => _t('loginPhoneError');
  String get loginOtpSending => _t('loginOtpSending');
  String get loginOtpVerifying => _t('loginOtpVerifying');

  // ── Subscription ───────────────────────────────────────────────────────────

  String get subscriptionTitle => _t('subscriptionTitle');
  String get subscriptionCurrentPlan => _t('subscriptionCurrentPlan');
  String get subscriptionExpiresOn => _t('subscriptionExpiresOn');
  String get subscriptionUpgrade => _t('subscriptionUpgrade');
  String get subscriptionManage => _t('subscriptionManage');
  String get subscriptionFreePlan => _t('subscriptionFreePlan');
  String get subscriptionTrialDaysLeft => _t('subscriptionTrialDaysLeft');
  String get subscriptionProPlan => _t('subscriptionProPlan');
  String get subscriptionCancelledInfo => _t('subscriptionCancelledInfo');
  String get subscriptionRenewsOn => _t('subscriptionRenewsOn');

  // ── Purchase Orders ────────────────────────────────────────────────────────

  String get poTitle => _t('poTitle');
  String get poSearchHint => _t('poSearchHint');
  String get poNoOrdersTitle => _t('poNoOrdersTitle');
  String get poNoOrdersBody => _t('poNoOrdersBody');
  String get poCreateFirst => _t('poCreateFirst');
  String get poCreateOrder => _t('poCreateOrder');
  String get poEditOrder => _t('poEditOrder');
  String get poOrderNumber => _t('poOrderNumber');
  String get poSupplier => _t('poSupplier');
  String get poDate => _t('poDate');
  String get poStatus => _t('poStatus');
  String get poTotal => _t('poTotal');
  String get poItems => _t('poItems');
  String get poNotes => _t('poNotes');
  String get poSave => _t('poSave');
  String get poSaving => _t('poSaving');
  String get poSaveChanges => _t('poSaveChanges');
  String get poDeleteConfirm => _t('poDeleteConfirm');
  String get poDeleteSuccess => _t('poDeleteSuccess');
  String get poStatusDraft => _t('poStatusDraft');
  String get poStatusSent => _t('poStatusSent');
  String get poStatusReceived => _t('poStatusReceived');
  String get poMarkSent => _t('poMarkSent');
  String get poMarkReceived => _t('poMarkReceived');
  String get supplierName => _t('supplierName');
  String get purchasePrice => _t('purchasePrice');
}

// ─── InheritedWidget scope ───────────────────────────────────────────────────

class _AppStringsScope extends InheritedWidget {
  const _AppStringsScope({required this.strings, required super.child});

  final AppStrings strings;

  static AppStrings of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_AppStringsScope>();
    assert(
      scope != null,
      'AppStrings.of() called outside of a LanguageProvider tree.',
    );
    return scope?.strings ?? const AppStrings(AppLanguage.english);
  }

  @override
  bool updateShouldNotify(_AppStringsScope old) =>
      strings.language != old.strings.language;
}

// ─── LanguageProvider ────────────────────────────────────────────────────────

class LanguageProvider extends StatefulWidget {
  const LanguageProvider({super.key, required this.child});

  final Widget child;

  /// Read the current strings from the nearest [LanguageProvider].
  static AppStrings stringsOf(BuildContext context) =>
      _AppStringsScope.of(context);

  /// Persist and broadcast a new language choice.
  static Future<void> setLanguage(
    BuildContext context,
    AppLanguage lang,
  ) async {
    final state = context.findAncestorStateOfType<_LanguageProviderState>();
    await state?._setLanguage(lang);
  }

  @override
  State<LanguageProvider> createState() => _LanguageProviderState();
}

class _LanguageProviderState extends State<LanguageProvider> {
  AppStrings _strings = const AppStrings(AppLanguage.english);

  static const _prefKey = 'app_language';

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final langName = prefs.getString(_prefKey);
    final lang = AppLanguage.values.firstWhere(
      (l) => l.name == langName,
      orElse: () => AppLanguage.english,
    );
    if (mounted) {
      setState(() => _strings = AppStrings(lang));
    }
  }

  Future<void> _setLanguage(AppLanguage lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, lang.name);
    if (mounted) {
      setState(() => _strings = AppStrings(lang));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AppStringsScope(strings: _strings, child: widget.child);
  }
}
