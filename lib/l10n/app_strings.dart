import 'package:billeasy/screens/language_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── AppStrings ─────────────────────────────────────────────────────────────

class AppStrings {
  const AppStrings(this._lang);

  final AppLanguage _lang;
  AppLanguage get language => _lang;

  static AppStrings of(BuildContext context) => _AppStringsScope.of(context);

  String _t({required String en, required String hi, required String as_}) {
    switch (_lang) {
      case AppLanguage.english:
        return en;
      case AppLanguage.hindi:
        return hi;
      case AppLanguage.assamese:
        return as_;
    }
  }

  // ── Login ──────────────────────────────────────────────────────────────────

  String get loginTagline => _t(
    en: 'A calmer way to create, track, and manage invoices.',
    hi: 'बिल बनाएं, ट्रैक करें और मैनेज करें – एकदम आसान तरीके से।',
    as_: 'বিল বনাওক, ট্ৰেক কৰক আৰু পৰিচালনা কৰক – একেবাৰে সহজভাৱে।',
  );

  String get loginBadgeLabel => _t(
    en: 'Minimal billing workspace',
    hi: 'सरल बिलिंग कार्यक्षेत्र',
    as_: 'সৰল বিলিং কাৰ্যক্ষেত্ৰ',
  );

  String get loginWelcome =>
      _t(en: 'Welcome back', hi: 'वापस आने का स्वागत है', as_: 'পুনৰ স্বাগতম');

  String get loginSubtitle => _t(
    en: 'Sign in with Google to continue to your invoices, customers, and billing dashboard.',
    hi: 'अपने इनवॉइस, कस्टमर और बिलिंग डैशबोर्ड तक पहुंचने के लिए Google से साइन इन करें।',
    as_: 'আপোনাৰ বিল, গ্ৰাহক আৰু ডেছবোৰ্ড চাবলৈ Google-এৰে চাইন ইন কৰক।',
  );

  String get loginSigningIn => _t(
    en: 'Signing in...',
    hi: 'साइन इन हो रहा है...',
    as_: 'চাইন ইন হৈ আছে...',
  );

  String get loginContinueGoogle => _t(
    en: 'Continue with Google',
    hi: 'Google से जारी रखें',
    as_: 'Google-এৰে আগবাঢ়ক',
  );

  String get loginCancelled => _t(
    en: 'Google sign-in was cancelled.',
    hi: 'Google साइन-इन रद्द किया गया।',
    as_: 'Google চাইন-ইন বাতিল কৰা হ\'ল।',
  );

  // ── Home ───────────────────────────────────────────────────────────────────

  String get homeTitle => _t(en: 'BillEasy', hi: 'BillEasy', as_: 'BillEasy');

  String get homeSearchHint => _t(
    en: 'Search customer name',
    hi: 'ग्राहक का नाम खोजें',
    as_: 'গ্ৰাহকৰ নাম বিচাৰক',
  );

  String get homeCloseSearch =>
      _t(en: 'Close search', hi: 'खोज बंद करें', as_: 'সন্ধান বন্ধ কৰক');

  String get homeSearchTooltip =>
      _t(en: 'Search customers', hi: 'ग्राहक खोजें', as_: 'গ্ৰাহক বিচাৰক');

  String get homeFilterPeriodTooltip => _t(
    en: 'Filter by period',
    hi: 'अवधि के अनुसार फ़िल्टर करें',
    as_: 'সময়কাল অনুসাৰে ফিল্টাৰ কৰক',
  );

  String get homePeriodLabel => _t(en: 'Period', hi: 'अवधि', as_: 'সময়কাল');

  String get homePeriodChange => _t(en: 'Change', hi: 'बदलें', as_: 'সলনি কৰক');

  String get homeStatTotalBilled =>
      _t(en: 'Total Billed', hi: 'कुल बिल', as_: 'মুঠ বিল');

  String get homeStatCollected =>
      _t(en: 'Collected', hi: 'वसूल किया', as_: 'সংগ্ৰহ কৰা');

  String get homeStatOutstanding =>
      _t(en: 'Outstanding', hi: 'बकाया', as_: 'বাকী');

  String get homeStatDiscounts =>
      _t(en: 'Discounts', hi: 'छूट', as_: 'ৰেহাইসমূহ');

  String get homeFilterAll => _t(en: 'All', hi: 'सभी', as_: 'সকলো');
  String get homeFilterPaid =>
      _t(en: 'Paid', hi: 'भुगतान हुआ', as_: 'পৰিশোধ হৈছে');
  String get homeFilterPending =>
      _t(en: 'Pending', hi: 'लंबित', as_: 'বাকী আছে');
  String get homeFilterOverdue =>
      _t(en: 'Overdue', hi: 'अतिदेय', as_: 'মিয়াদ পাৰ');

  String homeNoInvoicesSearch(String query) => _t(
    en: 'No invoices found for "$query".',
    hi: '"$query" के लिए कोई इनवॉइस नहीं मिला।',
    as_: '"$query"-এৰ কোনো বিল পোৱা নগ\'ল।',
  );

  String get homeNoInvoicesYet => _t(
    en: 'No invoices available yet.',
    hi: 'अभी तक कोई इनवॉइस नहीं है।',
    as_: 'এতিয়াও কোনো বিল নাই।',
  );

  String get homeNoInvoicesFilter => _t(
    en: 'No invoices match this filter.',
    hi: 'इस फ़िल्टर से कोई इनवॉइस मेल नहीं खाता।',
    as_: 'এই ফিল্টাৰত কোনো বিল নাই।',
  );

  String get homeLoadError => _t(
    en: 'Unable to load invoices right now.',
    hi: 'अभी इनवॉइस लोड नहीं हो सके।',
    as_: 'এতিয়া বিলসমূহ লোড হোৱা নাই।',
  );

  String get homePeriodAllInvoices =>
      _t(en: 'All Invoices', hi: 'सभी इनवॉइस', as_: 'সকলো বিল');
  String get homePeriodToday => _t(en: 'Today', hi: 'आज', as_: 'আজি');
  String get homePeriodThisWeek =>
      _t(en: 'This Week', hi: 'इस सप्ताह', as_: 'এই সপ্তাহ');
  String get homePeriodCustomRange =>
      _t(en: 'Custom Range', hi: 'कस्टम अवधि', as_: 'কাষ্টম সময়');

  String homePeriodDateRange(String start, String end) =>
      '$start - $end'; // date format is language-independent

  String homePeriodCustomLabel(String start, String end) => _t(
    en: 'Custom: $start - $end',
    hi: 'कस्टम: $start - $end',
    as_: 'কাষ্টম: $start - $end',
  );

  // ── Drawer ─────────────────────────────────────────────────────────────────

  String get drawerWorkspace =>
      _t(en: 'Workspace', hi: 'कार्यक्षेत्र', as_: 'কাৰ্যক্ষেত্ৰ');
  String get drawerMyProfile =>
      _t(en: 'My Profile', hi: 'मेरी प्रोफ़ाइल', as_: 'মোৰ প্ৰফাইল');
  String get drawerProducts => _t(en: 'Products', hi: 'उत्पाद', as_: 'সামগ্ৰী');
  String get drawerCustomers =>
      _t(en: 'Customers', hi: 'ग्राहक', as_: 'গ্ৰাহকসমূহ');
  String get drawerSubscriptions =>
      _t(en: 'Subscriptions', hi: 'सदस्यता', as_: 'চাবস্ক্ৰিপচন');
  String get drawerAnalytics =>
      _t(en: 'Analytics', hi: 'विश्लेषण', as_: 'বিশ্লেষণ');
  String get drawerGst => _t(en: 'GST', hi: 'जीएसटी', as_: 'জিএছটি');
  String get drawerSettings => _t(en: 'Settings', hi: 'सेटिंग', as_: 'ছেটিংছ');
  String get drawerLogIn => _t(en: 'Log In', hi: 'लॉग इन', as_: 'লগ ইন');
  String get drawerLogOut => _t(en: 'Log Out', hi: 'लॉग आउट', as_: 'লগ আউট');
  String get drawerNotSignedIn =>
      _t(en: 'Not signed in', hi: 'साइन इन नहीं है', as_: 'চাইন ইন কৰা নাই');

  String get drawerProductsDesc => _t(
    en: 'Create and organize your product catalog, pricing, and reusable invoice items from one place.',
    hi: 'अपना उत्पाद कैटलॉग, मूल्य निर्धारण और पुन: उपयोगी इनवॉइस आइटम एक ही जगह से बनाएं और व्यवस्थित करें।',
    as_:
        'আপোনাৰ সামগ্ৰীৰ তালিকা, মূল্য আৰু পুনৰ ব্যৱহাৰযোগ্য বিলৰ আইটেমসমূহ এঠাইৰ পৰা বনাওক।',
  );

  String get drawerSubscriptionsDesc => _t(
    en: 'Track active plans, recurring billing, renewals, and premium access features for your business.',
    hi: 'अपने व्यवसाय के लिए सक्रिय प्लान, आवर्ती बिलिंग, नवीकरण और प्रीमियम सुविधाएं ट्रैक करें।',
    as_:
        'আপোনাৰ ব্যৱসায়ৰ সক্ৰিয় পৰিকল্পনা, নিয়মীয়া বিলিং আৰু প্ৰিমিয়াম সুবিধাসমূহ ট্ৰেক কৰক।',
  );

  String get drawerAnalyticsDesc => _t(
    en: 'See billing trends, collections, overdue patterns, and business performance insights at a glance.',
    hi: 'बिलिंग रुझान, संग्रह, अतिदेय पैटर्न और व्यवसाय प्रदर्शन की जानकारी एक नज़र में देखें।',
    as_:
        'বিলিং ধাৰা, সংগ্ৰহ, মিয়াদ পাৰ আৰ্হি আৰু ব্যৱসায়িক কাৰ্যক্ষমতা এক নজৰত চাওক।',
  );

  String get drawerGstDesc => _t(
    en: 'Prepare GST-ready records, tax summaries, and compliance-friendly invoice data for filing.',
    hi: 'दाखिल करने के लिए GST-तैयार रिकॉर्ड, कर सारांश और अनुपालन-अनुकूल इनवॉइस डेटा तैयार करें।',
    as_:
        'দাখিল কৰাৰ বাবে GST-সাজু তথ্য, কৰ সাৰাংশ আৰু অনুপালন-অনুকূল বিলৰ ডেটা প্ৰস্তুত কৰক।',
  );

  String get drawerSettingsDesc => _t(
    en: 'Control preferences, app behavior, business defaults, and account-level configuration settings.',
    hi: 'प्राथमिकताएं, ऐप व्यवहार, व्यवसाय डिफ़ॉल्ट और खाता-स्तर कॉन्फ़िगरेशन सेटिंग नियंत्रित करें।',
    as_:
        'পছন্দ, এপ আচৰণ, ব্যৱসায়িক ডিফল্ট আৰু একাউণ্ট-স্তৰৰ বিন্যাস নিয়ন্ত্ৰণ কৰক।',
  );

  String get settingsLanguageTitle =>
      _t(en: 'App Language', hi: 'ऐप भाषा', as_: 'এপ ভাষা');

  String get settingsLanguageSubtitle => _t(
    en: 'Change the language any time. Updates apply instantly across the app.',
    hi: 'कभी भी भाषा बदलें। बदलाव पूरे ऐप में तुरंत दिखेगा।',
    as_: 'যিকোনো সময় ভাষা সলনি কৰক। পৰিবর্তন গোটেই এপত তৎক্ষণাত দেখা যাব।',
  );

  String settingsCurrentLanguage(String language) => _t(
    en: 'Current language: $language',
    hi: 'वर्तमान भाषा: $language',
    as_: 'বৰ্তমান ভাষা: $language',
  );

  String settingsLanguageChanged(String language) => _t(
    en: 'Language changed to $language.',
    hi: 'भाषा $language में बदल दी गई।',
    as_: 'ভাষা $language-লৈ সলনি কৰা হ\'ল।',
  );

  String get drawerProfileLoadError => _t(
    en: 'Unable to load your profile right now. Please try again.',
    hi: 'अभी आपकी प्रोफ़ाइल लोड नहीं हो सकी। कृपया पुनः प्रयास करें।',
    as_: 'এতিয়া আপোনাৰ প্ৰফাইল লোড হোৱা নাই। পুনৰ চেষ্টা কৰক।',
  );

  String drawerFailedLogOut(String error) => _t(
    en: 'Failed to log out: $error',
    hi: 'लॉग आउट विफल: $error',
    as_: 'লগ আউট বিফল: $error',
  );

  // ── Create Invoice ─────────────────────────────────────────────────────────

  String get createTitle =>
      _t(en: 'Create Invoice', hi: 'इनवॉइस बनाएं', as_: 'বিল বনাওক');

  String get createCustomerLabel =>
      _t(en: 'Customer', hi: 'ग्राहक', as_: 'গ্ৰাহক');

  String get createSelectCustomer => _t(
    en: 'Select a saved customer',
    hi: 'सहेजा हुआ ग्राहक चुनें',
    as_: 'সংৰক্ষিত গ্ৰাহক বাছক',
  );

  String get createCustomerHint => _t(
    en: 'Choose an existing customer or add a new one before saving the invoice.',
    hi: 'इनवॉइस सहेजने से पहले कोई मौजूदा ग्राहक चुनें या नया जोड़ें।',
    as_: 'বিল সংৰক্ষণ কৰাৰ আগতে এজন গ্ৰাহক বাছক বা নতুন যোগ কৰক।',
  );

  String get createPickCustomer =>
      _t(en: 'Select Customer', hi: 'ग्राहक चुनें', as_: 'গ্ৰাহক বাছক');

  String get createChangeCustomer =>
      _t(en: 'Change Customer', hi: 'ग्राहक बदलें', as_: 'গ্ৰাহক সলনি কৰক');

  String get createAddNew =>
      _t(en: 'Add New', hi: 'नया जोड़ें', as_: 'নতুন যোগ কৰক');

  String get createCustomerRequired => _t(
    en: 'Select a customer before saving the invoice',
    hi: 'इनवॉइस सहेजने से पहले ग्राहक चुनें',
    as_: 'বিল সংৰক্ষণৰ আগতে গ্ৰাহক বাছক',
  );

  String get createInvoiceDate =>
      _t(en: 'Invoice Date', hi: 'इनवॉइस तिथि', as_: 'বিলৰ তাৰিখ');

  String get createPickDate => _t(
    en: 'Pick Invoice Date',
    hi: 'इनवॉइस तिथि चुनें',
    as_: 'বিলৰ তাৰিখ বাছক',
  );

  String get createDateHintEmpty => _t(
    en: 'Tap here to choose the billing date before saving.',
    hi: 'सहेजने से पहले बिलिंग तारीख चुनने के लिए यहाँ टैप करें।',
    as_: 'সংৰক্ষণৰ আগতে তাৰিখ বাছিবলৈ ইয়াত টেপ কৰক।',
  );

  String get createDateHintSelected => _t(
    en: 'Tap to change the selected billing date.',
    hi: 'चुनी हुई बिलिंग तारीख बदलने के लिए टैप करें।',
    as_: 'বাছি লোৱা তাৰিখ সলনি কৰিবলৈ টেপ কৰক।',
  );

  String get createDateRequired => _t(
    en: 'Select an invoice date',
    hi: 'इनवॉइस तिथि चुनें',
    as_: 'বিলৰ তাৰিখ বাছক',
  );

  String get createProductLabel => _t(
    en: 'Product / Description',
    hi: 'उत्पाद / विवरण',
    as_: 'সামগ্ৰী / বিৱৰণ',
  );

  String get createQtyLabel => _t(en: 'Qty', hi: 'मात्रा', as_: 'পৰিমাণ');

  String get createUnitLabel => _t(en: 'Unit', hi: 'इकाई', as_: 'একক');

  String get createUnitPriceLabel =>
      _t(en: 'Unit Price', hi: 'इकाई मूल्य', as_: 'একক মূল্য');

  String get createEnterProduct =>
      _t(en: 'Enter product', hi: 'उत्पाद दर्ज करें', as_: 'সামগ্ৰী দিয়ক');

  String get createDeleteItem =>
      _t(en: 'Delete item', hi: 'आइटम हटाएं', as_: 'আইটেম মচক');

  String get createAddItem =>
      _t(en: '+ Add Item', hi: '+ आइटम जोड़ें', as_: '+ আইটেম যোগ কৰক');

  String get createInvoiceStatus =>
      _t(en: 'Invoice Status', hi: 'इनवॉइस स्थिति', as_: 'বিলৰ স্থিতি');

  String get createDiscountTitle => _t(en: 'Discount', hi: 'छूट', as_: 'ৰেহাই');

  String get createDiscountPctLabel =>
      _t(en: 'Percentage', hi: 'प्रतिशत', as_: 'শতাংশ');

  String get createDiscountOverallLabel =>
      _t(en: 'Overall', hi: 'कुल', as_: 'সামগ্ৰিক');

  String get createDiscountPctField =>
      _t(en: 'Discount Percentage', hi: 'छूट प्रतिशत', as_: 'ৰেহাইৰ শতাংশ');

  String get createDiscountOverallField =>
      _t(en: 'Overall Discount', hi: 'कुल छूट', as_: 'সামগ্ৰিক ৰেহাই');

  String get createDiscountPctHint => _t(
    en: 'Optional, e.g. 10',
    hi: 'वैकल्पिक, जैसे 10',
    as_: 'ঐচ্ছিক, যেনে 10',
  );

  String get createDiscountOverallHint => _t(
    en: 'Optional, e.g. 500',
    hi: 'वैकल्पिक, जैसे 500',
    as_: 'ঐচ্ছিক, যেনে 500',
  );

  String get createSummarySubtotal =>
      _t(en: 'Subtotal', hi: 'उप-कुल', as_: 'উপ-মুঠ');

  String get createSummaryDiscount =>
      _t(en: 'Discount', hi: 'छूट', as_: 'ৰেহাই');

  String get createSummaryGrandTotal =>
      _t(en: 'Grand Total', hi: 'कुल योग', as_: 'মুঠ যোগফল');

  String get createSavingInvoice => _t(
    en: 'Saving Invoice...',
    hi: 'इनवॉइस सहेजा जा रहा है...',
    as_: 'বিল সংৰক্ষণ হৈ আছে...',
  );

  String get createSaveInvoice =>
      _t(en: 'Save Invoice', hi: 'इनवॉइस सहेजें', as_: 'বিল সংৰক্ষণ কৰক');

  String createItemNumber(int number) =>
      _t(en: 'Item $number', hi: 'आइटम $number', as_: 'সামগ্ৰী $number');

  String get createSaveHint => _t(
    en: 'Review the invoice date and total, then save to generate the final bill.',
    hi: 'इनवॉइस तिथि और कुल जांचें, फिर अंतिम बिल बनाने के लिए सहेजें।',
    as_:
        'বিলৰ তাৰিখ আৰু মুঠ পৰীক্ষা কৰক, তাৰপিছত চূড়ান্ত বিল বনাবলৈ সংৰক্ষণ কৰক।',
  );

  String get createAddLineItem => _t(
    en: 'Add at least one line item.',
    hi: 'कम से कम एक आइटम जोड़ें।',
    as_: 'কমপক্ষে এটা আইটেম যোগ কৰক।',
  );

  String get createErrorPctMax => _t(
    en: 'Percentage discount cannot be more than 100.',
    hi: 'प्रतिशत छूट 100 से अधिक नहीं हो सकती।',
    as_: 'শতাংশ ৰেহাই ১০০-ৰ বেছি হ\'ব নোৱাৰে।',
  );

  String get createErrorOverallMax => _t(
    en: 'Overall discount cannot be more than the subtotal.',
    hi: 'कुल छूट उप-कुल से अधिक नहीं हो सकती।',
    as_: 'সামগ্ৰিক ৰেহাই উপ-মুঠতকৈ বেছি হ\'ব নোৱাৰে।',
  );

  String get createSignInRequired => _t(
    en: 'Please sign in before saving invoices.',
    hi: 'इनवॉइस सहेजने से पहले साइन इन करें।',
    as_: 'বিল সংৰক্ষণৰ আগতে চাইন ইন কৰক।',
  );

  String createFailedSave(String error) => _t(
    en: 'Failed to save invoice: $error',
    hi: 'इनवॉइस सहेजना विफल: $error',
    as_: 'বিল সংৰক্ষণ বিফল: $error',
  );

  String get createDiscountEmptyHint => _t(
    en: 'Leave discount empty to keep the invoice at full subtotal.',
    hi: 'पूरे उप-कुल पर इनवॉइस रखने के लिए छूट खाली छोड़ें।',
    as_: 'পূৰ্ণ উপ-মুঠত বিল ৰাখিবলৈ ৰেহাই খালি ৰাখক।',
  );

  String createDiscountPreviewPct(
    String pct,
    String subtotal,
    String discAmt,
  ) => _t(
    en: '$pct% discount will reduce $subtotal by $discAmt.',
    hi: '$pct% छूट $subtotal को $discAmt से कम करेगी।',
    as_: '$pct% ৰেহাইয়ে $subtotal-ৰ পৰা $discAmt কমাব।',
  );

  String createDiscountPreviewOverall(String discAmt, String subtotal) => _t(
    en: 'Overall discount of $discAmt will be applied to $subtotal.',
    hi: '$discAmt का कुल छूट $subtotal पर लागू होगा।',
    as_: '$discAmt-ৰ সামগ্ৰিক ৰেহাই $subtotal-ত প্ৰযোজ্য হ\'ব।',
  );

  // ── PDF labels ────────────────────────────────────────────────────────────

  String get pdfInvoice => 'INVOICE';

  String get pdfInvoiceNo =>
      _t(en: 'Invoice No.', hi: 'चालान नं.', as_: 'বিল নং.');

  String get pdfInvoiceDate =>
      _t(en: 'Invoice Date', hi: 'इनवॉइस तिथि', as_: 'বিলৰ তাৰিখ');

  String get pdfFrom => _t(en: 'FROM', hi: 'विक्रेता', as_: 'বিক্ৰেতা');

  String get pdfBillTo => _t(en: 'BILL TO', hi: 'खरीदार', as_: 'ক্ৰেতা');

  String get pdfItem => _t(en: 'Item', hi: 'वस्तु', as_: 'সামগ্ৰী');

  String get pdfAmount => _t(en: 'Amount', hi: 'राशि', as_: 'মূল্য');

  String get pdfAddressNotAdded => _t(
    en: 'Address not added',
    hi: 'पता नहीं जोड़ा',
    as_: 'ঠিকনা যোগ কৰা নাই',
  );

  String get pdfPhoneNotAdded =>
      _t(en: 'Phone not added', hi: 'फोन नहीं जोड़ा', as_: 'ফোন যোগ কৰা নাই');

  String get pdfGeneratedBy => _t(
    en: 'Generated by BillEasy',
    hi: 'BillEasy द्वारा जारी',
    as_: 'BillEasy-এ তৈয়াৰ কৰিছে',
  );

  String get pdfPage => _t(en: 'Page', hi: 'पृष्ठ', as_: 'পৃষ্ঠা');

  String get pdfOf => _t(en: 'of', hi: 'का', as_: 'ৰ');

  String pdfItemsCount(int n) => _t(
    en: '$n item${n == 1 ? '' : 's'}',
    hi: '$n वस्तु',
    as_: '$n সামগ্ৰী',
  );

  // ── Invoice Details ────────────────────────────────────────────────────────

  String get detailsTitle =>
      _t(en: 'Invoice Details', hi: 'इनवॉइस विवरण', as_: 'বিলৰ বিৱৰণ');

  String get detailsPreviewPrint => _t(
    en: 'Preview / Print',
    hi: 'पूर्वावलोकन / प्रिंट',
    as_: 'পূৰ্বদৰ্শন / প্ৰিণ্ট',
  );

  String get detailsSharePdf =>
      _t(en: 'Share PDF', hi: 'PDF साझा करें', as_: 'PDF শ্বেয়াৰ কৰক');

  String detailsIssuedBy(String name) => _t(
    en: 'Issued by $name',
    hi: '$name द्वारा जारी',
    as_: '$name-এ জাৰি কৰিছে',
  );

  String get detailsSeller => _t(en: 'Seller', hi: 'विक्रेता', as_: 'বিক্ৰেতা');

  String get detailsCustomer => _t(en: 'Customer', hi: 'ग्राहक', as_: 'গ্ৰাহক');

  String get detailsItems =>
      _t(en: 'Items', hi: 'वस्तुएं', as_: 'সামগ্ৰীসমূহ');

  String get detailsAmountSummary =>
      _t(en: 'Amount Summary', hi: 'राशि सारांश', as_: 'বিলৰ সাৰাংশ');

  String get detailsStore => _t(en: 'Store', hi: 'दुकान', as_: 'দোকান');

  String get detailsAddress => _t(en: 'Address', hi: 'पता', as_: 'ঠিকনা');

  String get detailsPhone => _t(en: 'Phone', hi: 'फोन', as_: 'ফোন');

  String get detailsEmail => _t(en: 'Email', hi: 'ईमेल', as_: 'ইমেইল');

  String get detailsNotAddedYet =>
      _t(en: 'Not added yet', hi: 'अभी नहीं जोड़ा', as_: 'এতিয়াও যোগ কৰা নাই');

  String get detailsName => _t(en: 'Name', hi: 'नाम', as_: 'নাম');

  String get detailsReference =>
      _t(en: 'Reference', hi: 'संदर्भ', as_: 'প্ৰসঙ্গ');

  String get detailsOpenProfile => _t(
    en: 'Open Customer Profile',
    hi: 'ग्राहक प्रोफ़ाइल खोलें',
    as_: 'গ্ৰাহকৰ প্ৰফাইল খোলক',
  );

  String get detailsItemQty => _t(en: 'Qty', hi: 'मात्रा', as_: 'পৰিমাণ');

  String get detailsItemUnitPrice =>
      _t(en: 'Unit Price', hi: 'इकाई मूल्य', as_: 'একক মূল্য');

  String get detailsItemTotal => _t(en: 'Total', hi: 'कुल', as_: 'মুঠ');

  String get detailsSubtotal =>
      _t(en: 'Subtotal', hi: 'उप-योग', as_: 'উপ-মুঠ');

  String get detailsDiscount => _t(en: 'Discount', hi: 'छूट', as_: 'ৰেহাই');

  String get detailsItemsCount =>
      _t(en: 'Items Count', hi: 'आइटम गिनती', as_: 'সামগ্ৰীৰ সংখ্যা');

  String get detailsStatus => _t(en: 'Status', hi: 'स्थिति', as_: 'স্থিতি');

  String get detailsGrandTotal =>
      _t(en: 'Grand Total', hi: 'कुल योग', as_: 'মুঠ যোগফল');

  String get detailsNoDiscount =>
      _t(en: 'No discount', hi: 'कोई छूट नहीं', as_: 'কোনো ৰেহাই নাই');

  String detailsPctOff(String value) =>
      _t(en: '$value% off', hi: '$value% की छूट', as_: '$value% ৰেহাই');

  String get detailsOverallDiscount =>
      _t(en: 'Overall discount', hi: 'कुल छूट', as_: 'সামগ্ৰিক ৰেহাই');

  String detailsPdfError(String error) => _t(
    en: 'Unable to generate invoice PDF: $error',
    hi: 'इनवॉइस PDF बनाना विफल: $error',
    as_: 'বিলৰ PDF বনাব পৰা নগ\'ল: $error',
  );

  // ── Status labels (shared) ─────────────────────────────────────────────────

  String get statusPaid => _t(en: 'Paid', hi: 'भुगतान', as_: 'পৰিশোধ');

  String get statusPending => _t(en: 'Pending', hi: 'लंबित', as_: 'বাকী');

  String get statusOverdue =>
      _t(en: 'Overdue', hi: 'अतिदेय', as_: 'মিয়াদোত্তীৰ্ণ');

  // ── Profile Setup ──────────────────────────────────────────────────────────

  String get profileAppBarSetup => _t(
    en: 'Complete Profile',
    hi: 'प्रोफ़ाइल पूरी करें',
    as_: 'প্ৰফাইল সম্পূৰ্ণ কৰক',
  );

  String get profileAppBarEdit =>
      _t(en: 'My Profile', hi: 'मेरी प्रोफ़ाइल', as_: 'মোৰ প্ৰফাইল');

  String get profileSignOutTooltip =>
      _t(en: 'Sign out', hi: 'साइन आउट', as_: 'চাইন আউট');

  String get profilePromptTitleSetup => _t(
    en: 'Set up your billing profile',
    hi: 'अपनी बिलिंग प्रोफ़ाइल सेट करें',
    as_: 'আপোনাৰ বিলিং প্ৰফাইল ছেট আপ কৰক',
  );

  String get profilePromptTitleEdit =>
      _t(en: 'My Profile', hi: 'मेरी प्रोफ़ाइल', as_: 'মোৰ প্ৰফাইল');

  String get profilePromptBodySetup => _t(
    en: 'Add your shop details once so they can appear on your invoices. Every field is optional, but saving this profile unlocks your workspace.',
    hi: 'अपनी दुकान की जानकारी एक बार जोड़ें ताकि यह आपके इनवॉइस पर दिखे। सभी फ़ील्ड वैकल्पिक हैं, लेकिन प्रोफ़ाइल सहेजने से आपका कार्यक्षेत्र खुल जाता है।',
    as_:
        'আপোনাৰ দোকানৰ তথ্য এবাৰ যোগ কৰক যাতে বিলত দেখা যায়। সকলো ক্ষেত্ৰ ঐচ্ছিক, কিন্তু প্ৰফাইল সংৰক্ষণে আপোনাৰ কাৰ্যক্ষেত্ৰ খোলে।',
  );

  String get profilePromptBodyEdit => _t(
    en: 'Update the business details that appear on your invoices. All fields stay optional, so you can keep it light and edit later.',
    hi: 'अपने इनवॉइस पर दिखने वाले व्यावसायिक विवरण अपडेट करें। सभी फ़ील्ड वैकल्पिक रहते हैं।',
    as_:
        'আপোনাৰ বিলত দেখা যোৱা ব্যৱসায়িক তথ্য আপডেট কৰক। সকলো ক্ষেত্ৰ ঐচ্ছিক থাকে।',
  );

  String get profileBadgeFallback => _t(
    en: 'Business profile',
    hi: 'व्यावसायिक प्रोफ़ाइल',
    as_: 'ব্যৱসায়িক প্ৰফাইল',
  );

  String get profileStoreLabel => _t(
    en: 'Store / Shop Name',
    hi: 'दुकान / स्टोर का नाम',
    as_: 'দোকানৰ নাম',
  );

  String get profileAddressLabel => _t(en: 'Address', hi: 'पता', as_: 'ঠিকনা');

  String get profilePhoneLabel =>
      _t(en: 'Phone Number', hi: 'फोन नंबर', as_: 'ফোন নম্বৰ');

  String get profileOptionalHint =>
      _t(en: 'Optional', hi: 'वैकल्पिक', as_: 'ঐচ্ছিক');

  String get profileSaving =>
      _t(en: 'Saving...', hi: 'सहेजा जा रहा है...', as_: 'সংৰক্ষণ হৈ আছে...');

  String get profileSaveAndContinue => _t(
    en: 'Save and Continue',
    hi: 'सहेजें और जारी रखें',
    as_: 'সংৰক্ষণ কৰক আৰু আগবাঢ়ক',
  );

  String get profileSave => _t(
    en: 'Save Profile',
    hi: 'प्रोफ़ाइल सहेजें',
    as_: 'প্ৰফাইল সংৰক্ষণ কৰক',
  );

  String get profileSignInRequired => _t(
    en: 'Please sign in again to save profile.',
    hi: 'प्रोफ़ाइल सहेजने के लिए फिर से साइन इन करें।',
    as_: 'প্ৰফাইল সংৰক্ষণৰ বাবে পুনৰ চাইন ইন কৰক।',
  );

  String get profileSavedSuccess => _t(
    en: 'Profile saved successfully.',
    hi: 'प्रोफ़ाइल सफलतापूर्वक सहेजी गई।',
    as_: 'প্ৰফাইল সফলভাৱে সংৰক্ষণ হ\'ল।',
  );

  String profileFailedSave(String error) => _t(
    en: 'Failed to save profile: $error',
    hi: 'प्रोफ़ाइल सहेजना विफल: $error',
    as_: 'প্ৰফাইল সংৰক্ষণ বিফল: $error',
  );

  String profileFailedSignOut(String error) => _t(
    en: 'Failed to sign out: $error',
    hi: 'साइन आउट विफल: $error',
    as_: 'চাইন আউট বিফল: $error',
  );

  // ── Feature Placeholder ────────────────────────────────────────────────────

  String placeholderComingSoon(String title) => _t(
    en: '$title module is coming soon. This placeholder is ready for the real feature to be plugged in next.',
    hi: '$title मॉड्यूल जल्द आ रहा है। यह प्लेसहोल्डर अगली बार असली फीचर के लिए तैयार है।',
    as_:
        '$title মডিউল সোনকালে আহিব। এই প্লেচহোল্ডাৰ পৰৱৰ্তী ৰিয়েল ফিচাৰৰ বাবে সাজু।',
  );

  // ── Customers ──────────────────────────────────────────────────────────────

  String get customersTitle =>
      _t(en: 'Customers', hi: 'ग्राहक', as_: 'গ্ৰাহকসমূহ');

  String get customersSelectTitle =>
      _t(en: 'Select Customer', hi: 'ग्राहक चुनें', as_: 'গ্ৰাহক বাছক');

  String get customersSearchHint =>
      _t(en: 'Search customers', hi: 'ग्राहक खोजें', as_: 'গ্ৰাহক বিচাৰক');

  String get customersCloseSearch =>
      _t(en: 'Close search', hi: 'खोज बंद करें', as_: 'সন্ধান বন্ধ কৰক');

  String get customersLoadError => _t(
    en: 'Unable to load customers right now.',
    hi: 'अभी ग्राहक लोड नहीं हो सके।',
    as_: 'এতিয়া গ্ৰাহকসমূহ লোড হোৱা নাই।',
  );

  String get customersIntroTitle => _t(
    en: 'Your saved customer profiles live here.',
    hi: 'आपके सहेजे हुए ग्राहक यहाँ हैं।',
    as_: 'আপোনাৰ সংৰক্ষিত গ্ৰাহক প্ৰফাইলসমূহ ইয়াত আছে।',
  );

  String get customersIntroBody => _t(
    en: 'Use this space for repeat customers, quick contact lookup, and a clean invoice history for each relationship.',
    hi: 'दोबारा आने वाले ग्राहकों के लिए यहाँ प्रोफ़ाइल बनाएं।',
    as_:
        'নিয়মীয়া গ্ৰাহকৰ বাবে দ্ৰুত যোগাযোগ আৰু পৰিষ্কাৰ বিলৰ ইতিহাসৰ বাবে এই ঠাই ব্যৱহাৰ কৰক।',
  );

  String get customersSelectIntroTitle => _t(
    en: 'Choose who this invoice belongs to.',
    hi: 'यह इनवॉइस किसके लिए है, चुनें।',
    as_: 'এই বিলটো কাৰ বাবে, সেইটো বাছক।',
  );

  String get customersSelectIntroBody => _t(
    en: 'Pick an existing customer or create a new one without leaving the billing flow.',
    hi: 'कोई मौजूदा ग्राहक चुनें या बिलिंग छोड़े बिना नया बनाएं।',
    as_: 'এজন বিদ্যমান গ্ৰাহক বাছক বা বিলিং প্ৰবাহ নেৰাকৈ নতুন বনাওক।',
  );

  String get customersEmptyTitle => _t(
    en: 'Start your customer book here.',
    hi: 'अपनी ग्राहक सूची यहाँ शुरू करें।',
    as_: 'আপোনাৰ গ্ৰাহক তালিকা ইয়াৰ পৰা আৰম্ভ কৰক।',
  );

  String get customersEmptySelectTitle => _t(
    en: 'No saved customers yet.',
    hi: 'अभी कोई ग्राहक नहीं जोड़ा।',
    as_: 'এতিয়াও কোনো গ্ৰাহক যোগ কৰা নাই।',
  );

  String customersEmptySearchTitle(String query) => _t(
    en: 'No customer matched "$query".',
    hi: '"$query" से कोई ग्राहक नहीं मिला।',
    as_: '"$query"-এৰ কোনো গ্ৰাহক পোৱা নগ\'ল।',
  );

  String get customersEmptyBody => _t(
    en: 'Saved customers make repeat invoicing faster and keep all their bills together in one place.',
    hi: 'सहेजे हुए ग्राहक बार-बार बिलिंग को तेज़ बनाते हैं।',
    as_: 'সংৰক্ষিত গ্ৰাহকে বাৰে বাৰে বিলিং দ্ৰুত কৰে আৰু সকলো বিল এঠাইত ৰাখে।',
  );

  String get customersEmptySelectBody => _t(
    en: 'Create a customer profile first, then come back to attach invoices to it.',
    hi: 'पहले ग्राहक प्रोफ़ाइल बनाएं, फिर इनवॉइस जोड़ें।',
    as_: 'প্ৰথমে গ্ৰাহক প্ৰফাইল বনাওক, তাৰপিছত বিল সংযুক্ত কৰিবলৈ উভতি আহক।',
  );

  String get customersEmptySearchBody => _t(
    en: 'Try another name, or add this customer as a new profile.',
    hi: 'कोई और नाम आज़माएं, या इस ग्राहक को नई प्रोफ़ाइल के रूप में जोड़ें।',
    as_: 'আন এটা নাম চেষ্টা কৰক, বা এই গ্ৰাহকক নতুন প্ৰফাইল হিচাপে যোগ কৰক।',
  );

  String get customersAddButton =>
      _t(en: 'Add Customer', hi: 'ग्राहक जोड़ें', as_: 'গ্ৰাহক যোগ কৰক');

  String customersReadyForBilling(String name) => _t(
    en: '$name is ready for billing.',
    hi: '$name बिलिंग के लिए तैयार है।',
    as_: '$name বিলিঙৰ বাবে সাজু।',
  );

  // ── Customer Form ──────────────────────────────────────────────────────────

  String get customerFormTitleAdd =>
      _t(en: 'Add Customer', hi: 'ग्राहक जोड़ें', as_: 'গ্ৰাহক যোগ কৰক');

  String get customerFormTitleEdit => _t(
    en: 'Edit Customer',
    hi: 'ग्राहक संपादित करें',
    as_: 'গ্ৰাহক সম্পাদনা কৰক',
  );

  String get customerFormBadge => _t(
    en: 'Customer profile',
    hi: 'ग्राहक प्रोफ़ाइल',
    as_: 'গ্ৰাহকৰ প্ৰফাইল',
  );

  String get customerFormSubtitleAdd => _t(
    en: 'Create a crisp customer profile for repeat billing, quick selection, and a calmer workflow.',
    hi: 'दोबारा बिलिंग, त्वरित चयन और बेहतर वर्कफ़्लो के लिए ग्राहक प्रोफ़ाइल बनाएं।',
    as_:
        'পুনৰাবৃত্তি বিলিং, দ্ৰুত বাছনি আৰু সহজ কাৰ্যপ্ৰণালীৰ বাবে গ্ৰাহক প্ৰফাইল বনাওক।',
  );

  String get customerFormSubtitleEdit => _t(
    en: 'Refresh the essentials for this customer so repeat billing stays quick and clean.',
    hi: 'इस ग्राहक की जानकारी अपडेट करें ताकि बार-बार बिलिंग तेज़ और आसान रहे।',
    as_: 'এই গ্ৰাহকৰ তথ্য আপডেট কৰক যাতে বিলিং দ্ৰুত থাকে।',
  );

  String get customerFormNameLabel =>
      _t(en: 'Customer Name', hi: 'ग्राहक का नाम', as_: 'গ্ৰাহকৰ নাম');

  String get customerFormNameRequired =>
      _t(en: 'Required', hi: 'आवश्यक', as_: 'আৱশ্যকীয়');

  String get customerFormNameError => _t(
    en: 'Enter customer name',
    hi: 'ग्राहक का नाम दर्ज करें',
    as_: 'গ্ৰাহকৰ নাম দিয়ক',
  );

  String get customerFormPhoneLabel =>
      _t(en: 'Phone Number', hi: 'फोन नंबर', as_: 'ফোন নম্বৰ');

  String get customerFormAddressLabel =>
      _t(en: 'Address', hi: 'पता', as_: 'ঠিকনা');

  String get customerFormOptionalHint =>
      _t(en: 'Optional', hi: 'वैकल्पिक', as_: 'ঐচ্ছিক');

  String get customerFormSaving => _t(
    en: 'Saving Customer...',
    hi: 'ग्राहक सहेजा जा रहा है...',
    as_: 'গ্ৰাহক সংৰক্ষণ হৈ আছে...',
  );

  String get customerFormSaveChanges =>
      _t(en: 'Save Changes', hi: 'बदलाव सहेजें', as_: 'পৰিৱৰ্তন সংৰক্ষণ কৰক');

  String get customerFormCreate =>
      _t(en: 'Create Customer', hi: 'ग्राहक बनाएं', as_: 'গ্ৰাহক বনাওক');

  String customerFormFailedSave(String error) => _t(
    en: 'Failed to save customer: $error',
    hi: 'ग्राहक सहेजना विफल: $error',
    as_: 'গ্ৰাহক সংৰক্ষণ বিফল: $error',
  );

  // ── Customer Details ───────────────────────────────────────────────────────

  String get customerDetailsTitle => _t(
    en: 'Customer Profile',
    hi: 'ग्राहक प्रोफ़ाइल',
    as_: 'গ্ৰাহকৰ প্ৰফাইল',
  );

  String get customerDetailsEditTooltip => _t(
    en: 'Edit customer',
    hi: 'ग्राहक संपादित करें',
    as_: 'গ্ৰাহক সম্পাদনা কৰক',
  );

  String get customerDetailsCreateInvoice => _t(
    en: 'Create Invoice for This Customer',
    hi: 'इस ग्राहक के लिए इनवॉइस बनाएं',
    as_: 'এই গ্ৰাহকৰ বাবে বিল বনাওক',
  );

  String get customerDetailsStatInvoices =>
      _t(en: 'Invoices', hi: 'इनवॉइस', as_: 'বিলসমূহ');

  String get customerDetailsStatTotalBilled =>
      _t(en: 'Total Billed', hi: 'कुल बिल', as_: 'মুঠ বিল');

  String get customerDetailsStatOutstanding =>
      _t(en: 'Outstanding', hi: 'बकाया', as_: 'বাকী');

  String get customerDetailsContact =>
      _t(en: 'Contact Details', hi: 'संपर्क विवरण', as_: 'যোগাযোগৰ বিৱৰণ');

  String get customerDetailsPhone => _t(en: 'Phone', hi: 'फोन', as_: 'ফোন');

  String get customerDetailsEmail => _t(en: 'Email', hi: 'ईमेल', as_: 'ইমেইল');

  String get customerDetailsAddress =>
      _t(en: 'Address', hi: 'पता', as_: 'ঠিকনা');

  String get customerDetailsNotAdded =>
      _t(en: 'Not added yet', hi: 'अभी नहीं जोड़ा', as_: 'এতিয়াও যোগ কৰা নাই');

  String get customerDetailsNotes =>
      _t(en: 'Notes', hi: 'नोट्स', as_: 'টোকাসমূহ');

  String get customerDetailsHistory =>
      _t(en: 'Invoice History', hi: 'इनवॉइस इतिहास', as_: 'বিলৰ ইতিহাস');

  String get customerDetailsHistoryError => _t(
    en: 'Unable to load this customer\'s invoices right now.',
    hi: 'इस ग्राहक के इनवॉइस अभी लोड नहीं हो सके।',
    as_: 'এই গ্ৰাহকৰ বিলসমূহ এতিয়া লোড হোৱা নাই।',
  );

  String get customerDetailsHistoryEmpty => _t(
    en: 'No invoices linked to this customer yet. Create the first one to start their billing history.',
    hi: 'अभी इस ग्राहक से कोई इनवॉइस नहीं जुड़ा। पहला इनवॉइस बनाएं।',
    as_: 'এই গ্ৰাহকৰ লগত এতিয়াও কোনো বিল নাই। প্ৰথমটো বনাওক।',
  );

  String customerDetailsLastUpdated(String date) => _t(
    en: 'Last updated $date',
    hi: '$date को अंतिम अपडेट',
    as_: '$date-ত শেষবাৰ আপডেট কৰা হ\'ল',
  );

  // ── Invoice Card actions ───────────────────────────────────────────────────

  String get cardMarkPaid => _t(
    en: 'Mark as Paid',
    hi: 'भुगतान किया गया',
    as_: 'পৰিশোধ হিচাপে চিহ্নিত কৰক',
  );

  String get cardMarkOverdue => _t(
    en: 'Mark as Overdue',
    hi: 'अतिदेय चिह्नित करें',
    as_: 'মিয়াদ পাৰ হিচাপে চিহ্নিত কৰক',
  );

  String get cardDelete => _t(en: 'Delete', hi: 'हटाएं', as_: 'মচক');

  // ── Customers extra ────────────────────────────────────────────────────────

  String get customersManageGroupsTooltip => _t(
    en: 'Manage groups',
    hi: 'ग्रुप प्रबंधित करें',
    as_: 'গ্ৰুপ পৰিচালনা কৰক',
  );

  String get customersSearchTooltip =>
      _t(en: 'Search customers', hi: 'ग्राहक खोजें', as_: 'গ্ৰাহক বিচাৰক');

  String get customersGroupsLabel =>
      _t(en: 'Customer Groups', hi: 'ग्राहक ग्रुप', as_: 'গ্ৰাহকৰ গ্ৰুপ');

  String get customersManage =>
      _t(en: 'Manage', hi: 'प्रबंधित करें', as_: 'পৰিচালনা কৰক');

  String get customersAll => _t(en: 'All', hi: 'सभी', as_: 'সকলো');

  String get customersUngrouped =>
      _t(en: 'Ungrouped', hi: 'बिना ग्रुप', as_: 'গ্ৰুপবিহীন');

  String get customersSelected =>
      _t(en: 'Selected', hi: 'चुना गया', as_: 'বাছি লোৱা হ\'ল');

  String get customersMoveToGroup =>
      _t(en: 'Move to Group', hi: 'ग्रुप में ले जाएं', as_: 'গ্ৰুপলৈ লৈ যাওক');

  String get customersChangeGroup =>
      _t(en: 'Change Group', hi: 'ग्रुप बदलें', as_: 'গ্ৰুপ সলনি কৰক');

  String customersCurrentGroup(String name) => _t(
    en: 'Current group: $name',
    hi: 'वर्तमान ग्रुप: $name',
    as_: 'বৰ্তমান গ্ৰুপ: $name',
  );

  String get customersNoGroupSubtitle => _t(
    en: 'Assign this customer to a group after creation.',
    hi: 'बनाने के बाद इस ग्राहक को ग्रुप में रखें।',
    as_: 'বনোৱাৰ পিছত এই গ্ৰাহকক এটা গ্ৰুপত ৰাখক।',
  );

  String get customersDeleteTitle =>
      _t(en: 'Delete Customer', hi: 'ग्राहक हटाएं', as_: 'গ্ৰাহক মচক');

  String customersDeleteConfirm(String name) => _t(
    en: 'Delete $name from your customer list? Invoices already created for this customer will stay saved.',
    hi: '$name को हटाएं? इस ग्राहक के इनवॉइस सुरक्षित रहेंगे।',
    as_: '$name মচিব? এই গ্ৰাহকৰ বিলসমূহ সংৰক্ষিত থাকিব।',
  );

  String get customersCancel =>
      _t(en: 'Cancel', hi: 'रद्द करें', as_: 'বাতিল কৰক');

  String get customersDelete => _t(en: 'Delete', hi: 'हटाएं', as_: 'মচক');

  String get customersDeleteSubtitle => _t(
    en: 'Invoices stay saved, but this customer profile will be removed.',
    hi: 'इनवॉइस सुरक्षित रहेंगे, लेकिन ग्राहक प्रोफ़ाइल हटा दी जाएगी।',
    as_: 'বিলসমূহ সংৰক্ষিত থাকিব, কিন্তু গ্ৰাহক প্ৰফাইল আঁতৰোৱা হ\'ব।',
  );

  String customersNowUngrouped(String name) => _t(
    en: '$name is now ungrouped.',
    hi: '$name अब किसी ग्रुप में नहीं है।',
    as_: '$name এতিয়া গ্ৰুপবিহীন।',
  );

  String customersMovedToGroup(String name, String group) => _t(
    en: '$name moved to $group.',
    hi: '$name को $group में ले जाया गया।',
    as_: '$name $group-লৈ স্থানান্তৰিত হ\'ল।',
  );

  String customersFailedUpdateGroup(String error) => _t(
    en: 'Failed to update customer group: $error',
    hi: 'ग्राहक ग्रुप अपडेट विफल: $error',
    as_: 'গ্ৰাহক গ্ৰুপ আপডেট বিফল: $error',
  );

  String customersDeletedCustomer(String name) => _t(
    en: '$name was deleted.',
    hi: '$name हटा दिया गया।',
    as_: '$name মচা হ\'ল।',
  );

  String customersFailedDelete(String error) => _t(
    en: 'Failed to delete customer: $error',
    hi: 'ग्राहक हटाना विफल: $error',
    as_: 'গ্ৰাহক মচা বিফল: $error',
  );

  String get customersGroupsError => _t(
    en: 'Groups are unavailable right now, but customers are still accessible.',
    hi: 'ग्रुप अभी उपलब्ध नहीं, लेकिन ग्राहक दिख रहे हैं।',
    as_: 'গ্ৰুপসমূহ এতিয়া উপলব্ধ নহয়, কিন্তু গ্ৰাহকসমূহ চাব পাৰিব।',
  );

  String get customersEmptyGroupTitle => _t(
    en: 'No customers in this group yet.',
    hi: 'इस ग्रुप में अभी कोई ग्राहक नहीं।',
    as_: 'এই গ্ৰুপত এতিয়াও কোনো গ্ৰাহক নাই।',
  );

  String get customersEmptyGroupBody => _t(
    en: 'Pick another group, or move a customer into this one after creating them.',
    hi: 'कोई और ग्रुप चुनें, या नया ग्राहक बनाने के बाद यहाँ रखें।',
    as_:
        'আন এটা গ্ৰুপ বাছক, বা নতুন গ্ৰাহক বনোৱাৰ পিছত এই গ্ৰুপলৈ স্থানান্তৰিত কৰক।',
  );

  // ── Customer Details extra ─────────────────────────────────────────────────

  String get customerDetailsGroup => _t(en: 'Group', hi: 'ग्रुप', as_: 'গ্ৰুপ');

  String get customerDetailsMoveGroup =>
      _t(en: 'Move to group', hi: 'ग्रुप में ले जाएं', as_: 'গ্ৰুপলৈ লৈ যাওক');

  String get customerDetailsChangeGroup =>
      _t(en: 'Change group', hi: 'ग्रुप बदलें', as_: 'গ্ৰুপ সলনি কৰক');

  String customerDetailsNowUngrouped(String name) => _t(
    en: '$name is now ungrouped.',
    hi: '$name अब किसी ग्रुप में नहीं है।',
    as_: '$name এতিয়া গ্ৰুপবিহীন।',
  );

  String customerDetailsMovedToGroup(String name, String group) => _t(
    en: '$name moved to $group.',
    hi: '$name को $group में ले जाया गया।',
    as_: '$name $group-লৈ স্থানান্তৰিত হ\'ল।',
  );

  String customerDetailsFailedUpdateGroup(String error) => _t(
    en: 'Failed to update customer group: $error',
    hi: 'ग्राहक ग्रुप अपडेट विफल: $error',
    as_: 'গ্ৰাহক গ্ৰুপ আপডেট বিফল: $error',
  );

  // ── Customer Groups Sheet ──────────────────────────────────────────────────

  String get groupsTitle =>
      _t(en: 'Customer Groups', hi: 'ग्राहक ग्रुप', as_: 'গ্ৰাহকৰ গ্ৰুপ');

  String get groupsSubtitle => _t(
    en: 'Create simple groups like Group A, VIP, or Batch B, and rename them any time.',
    hi: 'Group A, VIP या Batch B जैसे ग्रुप बनाएं, जिन्हें कभी भी नाम बदला जा सकता है।',
    as_:
        'Group A, VIP বা Batch B-ৰ দৰে গ্ৰুপ বনাওক, যিকোনো সময়তে নাম সলনি কৰক।',
  );

  String get groupsAdd => _t(en: 'Add', hi: 'जोड़ें', as_: 'যোগ কৰক');

  String get groupsLoadError => _t(
    en: 'Unable to load groups right now.',
    hi: 'अभी ग्रुप लोड नहीं हो सके।',
    as_: 'এতিয়া গ্ৰুপসমূহ লোড হোৱা নাই।',
  );

  String get groupsEmpty => _t(
    en: 'No groups yet. Create one to organize customers faster.',
    hi: 'अभी कोई ग्रुप नहीं। तेज़ बिलिंग के लिए एक ग्रुप बनाएं।',
    as_: 'এতিয়াও কোনো গ্ৰুপ নাই। দ্ৰুত বিলিঙৰ বাবে এটা বনাওক।',
  );

  String get groupsRenameHint => _t(
    en: 'Tap edit to rename this group.',
    hi: 'नाम बदलने के लिए संपादन दबाएं।',
    as_: 'নাম সলনি কৰিবলৈ সম্পাদনা টিপক।',
  );

  String get groupsRenameTooltip => _t(
    en: 'Rename group',
    hi: 'ग्रुप का नाम बदलें',
    as_: 'গ্ৰুপৰ নাম সলনি কৰক',
  );

  String get groupsAddTitle =>
      _t(en: 'Add Group', hi: 'ग्रुप जोड़ें', as_: 'গ্ৰুপ যোগ কৰক');

  String get groupsRenameTitle =>
      _t(en: 'Rename Group', hi: 'ग्रुप नाम बदलें', as_: 'গ্ৰুপৰ নাম সলনি কৰক');

  String get groupsNameLabel =>
      _t(en: 'Group Name', hi: 'ग्रुप का नाम', as_: 'গ্ৰুপৰ নাম');

  String get groupsNameHint =>
      _t(en: 'For example: Group A', hi: 'जैसे: Group A', as_: 'যেনে: Group A');

  String get groupsCancel =>
      _t(en: 'Cancel', hi: 'रद्द करें', as_: 'বাতিল কৰক');

  String get groupsSaving =>
      _t(en: 'Saving...', hi: 'सहेजा जा रहा है...', as_: 'সংৰক্ষণ হৈ আছে...');

  String get groupsSave => _t(en: 'Save', hi: 'सहेजें', as_: 'সংৰক্ষণ কৰক');

  String groupsFailedSave(String error) => _t(
    en: 'Failed to save group: $error',
    hi: 'ग्रुप सहेजना विफल: $error',
    as_: 'গ্ৰুপ সংৰক্ষণ বিফল: $error',
  );

  String get groupsPickerTitle => _t(
    en: 'Move Customer to Group',
    hi: 'ग्राहक को ग्रुप में ले जाएं',
    as_: 'গ্ৰাহকক গ্ৰুপলৈ লৈ যাওক',
  );

  String get groupsPickerSubtitle => _t(
    en: 'Pick a group for this customer, or leave them ungrouped.',
    hi: 'इस ग्राहक के लिए एक ग्रुप चुनें, या बिना ग्रुप के छोड़ें।',
    as_: 'এই গ্ৰাহকৰ বাবে এটা গ্ৰুপ বাছক, বা গ্ৰুপবিহীন ৰাখক।',
  );

  String get groupsManage =>
      _t(en: 'Manage', hi: 'प्रबंधित करें', as_: 'পৰিচালনা কৰক');

  String get groupsUngrouped =>
      _t(en: 'Ungrouped', hi: 'बिना ग्रुप', as_: 'গ্ৰুপবিহীন');

  String get groupsUngroupedSubtitle => _t(
    en: 'Keep this customer outside any group for now.',
    hi: 'इस ग्राहक को अभी किसी ग्रुप में न रखें।',
    as_: 'এই গ্ৰাহকক এতিয়া কোনো গ্ৰুপত নাৰাখক।',
  );

  String get groupsPickerEmpty => _t(
    en: 'No groups yet. Use Manage to create your first one.',
    hi: 'अभी कोई ग्रुप नहीं। पहला ग्रुप बनाने के लिए Manage दबाएं।',
    as_: 'এতিয়াও কোনো গ্ৰুপ নাই। প্ৰথমটো বনাবলৈ পৰিচালনা কৰক।',
  );

  String groupsMoveInto(String name) => _t(
    en: 'Move this customer into $name.',
    hi: 'इस ग्राहक को $name में ले जाएं।',
    as_: 'এই গ্ৰাহকক $name-লৈ লৈ যাওক।',
  );

  // ── Misc ──────────────────────────────────────────────────────────────────

  String get homeDateApply =>
      _t(en: 'Apply', hi: 'लागू करें', as_: 'প্ৰয়োগ কৰক');

  String get detailsYourStore =>
      _t(en: 'Your Store', hi: 'आपकी दुकान', as_: 'আপোনাৰ দোকান');

  String get drawerMyProfileFallback =>
      _t(en: 'My Profile', hi: 'मेरी प्रोफ़ाइल', as_: 'মোৰ প্ৰফাইল');
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
