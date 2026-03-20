import 'package:billeasy/screens/language_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── AppStrings ─────────────────────────────────────────────────────────────

class AppStrings {
  const AppStrings(this._lang);

  final AppLanguage _lang;
  AppLanguage get language => _lang;

  static AppStrings of(BuildContext context) => _AppStringsScope.of(context);

  String _t({
    required String en,
    required String hi,
    required String as_,
    required String gu,
    required String ta,
  }) {
    switch (_lang) {
      case AppLanguage.english:
        return en;
      case AppLanguage.hindi:
        return hi;
      case AppLanguage.assamese:
        return as_;
      case AppLanguage.gujarati:
        return gu;
      case AppLanguage.tamil:
        return ta;
    }
  }

  // ── Login ──────────────────────────────────────────────────────────────────

  String get loginTagline => _t(
    en: 'A calmer way to create, track, and manage invoices.',
    hi: 'बिल बनाएं, ट्रैक करें और मैनेज करें – एकदम आसान तरीके से।',
    as_: 'বিল বনাওক, ট্ৰেক কৰক আৰু পৰিচালনা কৰক – একেবাৰে সহজভাৱে।',
    gu: 'ઇન્વૉઇસ બનાવો, ટ્રૅક કરો અને મૅનેજ કરો – એકદમ સરળ રીતે.',
    ta: 'விலைப்பட்டியல்களை உருவாக்க, கண்காணிக்க மற்றும் நிர்வகிக்க ஒரு எளிய வழி.',
  );

  String get loginBadgeLabel => _t(
    en: 'Minimal billing workspace',
    hi: 'सरल बिलिंग कार्यक्षेत्र',
    as_: 'সৰল বিলিং কাৰ্যক্ষেত্ৰ',
    gu: 'સરળ બિલિંગ કાર્યક્ષેત્ર',
    ta: 'எளிய பில்லிங் பணியிடம்',
  );

  String get loginWelcome => _t(
    en: 'Welcome back',
    hi: 'वापस आने का स्वागत है',
    as_: 'পুনৰ স্বাগতম',
    gu: 'પાછા આવ્યા, સ્વાગત છે',
    ta: 'மீண்டும் வரவேற்கிறோம்',
  );

  String get loginSubtitle => _t(
    en: 'Sign in with Google to continue to your invoices, customers, and billing dashboard.',
    hi: 'अपने इनवॉइस, कस्टमर और बिलिंग डैशबोर्ड तक पहुंचने के लिए Google से साइन इन करें।',
    as_: 'আপোনাৰ বিল, গ্ৰাহক আৰু ডেছবোৰ্ড চাবলৈ Google-এৰে চাইন ইন কৰক।',
    gu: 'તમારા ઇન્વૉઇસ, ગ્રાહક અને ડૅશબોર્ડ ઍક્સેસ કરવા Google થી સાઇન ઇન કરો.',
    ta: 'உங்கள் விலைப்பட்டியல்கள், வாடிக்கையாளர்கள் மற்றும் டாஷ்போர்டை அணுக Google மூலம் உள்நுழையுங்கள்.',
  );

  String get loginSigningIn => _t(
    en: 'Signing in...',
    hi: 'साइन इन हो रहा है...',
    as_: 'চাইন ইন হৈ আছে...',
    gu: 'સાઇન ઇન થઈ રહ્યું છે...',
    ta: 'உள்நுழைகிறது...',
  );

  String get loginContinueGoogle => _t(
    en: 'Continue with Google',
    hi: 'Google से जारी रखें',
    as_: 'Google-এৰে আগবাঢ়ক',
    gu: 'Google સાથે ચાલુ રાખો',
    ta: 'Google மூலம் தொடரவும்',
  );

  String get loginCancelled => _t(
    en: 'Google sign-in was cancelled.',
    hi: 'Google साइन-इन रद्द किया गया।',
    as_: 'Google চাইন-ইন বাতিল কৰা হ\'ল।',
    gu: 'Google સાઇન-ઇન રદ કરવામાં આવ્યું.',
    ta: 'Google உள்நுழைவு ரத்து செய்யப்பட்டது.',
  );

  // ── Home ───────────────────────────────────────────────────────────────────

  String get homeSearchHint => _t(
    en: 'Search customer name',
    hi: 'ग्राहक का नाम खोजें',
    as_: 'গ্ৰাহকৰ নাম বিচাৰক',
    gu: 'ગ્રાહકનું નામ શોધો',
    ta: 'வாடிக்கையாளர் பெயரைத் தேடுங்கள்',
  );

  String get homeCloseSearch => _t(
    en: 'Close search',
    hi: 'खोज बंद करें',
    as_: 'সন্ধান বন্ধ কৰক',
    gu: 'શોધ બંધ કરો',
    ta: 'தேடலை மூடு',
  );

  String get homeSearchTooltip => _t(
    en: 'Search customers',
    hi: 'ग्राहक खोजें',
    as_: 'গ্ৰাহক বিচাৰক',
    gu: 'ગ્રાહકો શોધો',
    ta: 'வாடிக்கையாளர்களைத் தேடு',
  );

  String get homeFilterPeriodTooltip => _t(
    en: 'Filter by period',
    hi: 'अवधि के अनुसार फ़िल्टर करें',
    as_: 'সময়কাল অনুসাৰে ফিল্টাৰ কৰক',
    gu: 'સમયગાળા પ્રમાણે ફિલ્ટર કરો',
    ta: 'காலத்தின்படி வடிகட்டு',
  );

  String get homePeriodLabel => _t(
    en: 'Period',
    hi: 'अवधि',
    as_: 'সময়কাল',
    gu: 'સમયગાળો',
    ta: 'காலம்',
  );

  String get homePeriodChange => _t(
    en: 'Change',
    hi: 'बदलें',
    as_: 'সলনি কৰক',
    gu: 'બદલો',
    ta: 'மாற்று',
  );

  String get homeStatTotalBilled => _t(
    en: 'Total Billed',
    hi: 'कुल बिल',
    as_: 'মুঠ বিল',
    gu: 'કુલ બિલ',
    ta: 'மொத்த கட்டணம்',
  );

  String get homeStatCollected => _t(
    en: 'Collected',
    hi: 'वसूल किया',
    as_: 'সংগ্ৰহ কৰা',
    gu: 'વસૂલ',
    ta: 'வசூல்',
  );

  String get homeStatOutstanding => _t(
    en: 'Outstanding',
    hi: 'बकाया',
    as_: 'বাকী',
    gu: 'બાકી',
    ta: 'நிலுவையில்',
  );

  String get homeStatDiscounts => _t(
    en: 'Discounts',
    hi: 'छूट',
    as_: 'ৰেহাইসমূহ',
    gu: 'છૂટ',
    ta: 'தள்ளுபடிகள்',
  );

  String get homeFilterAll => _t(
    en: 'All',
    hi: 'सभी',
    as_: 'সকলো',
    gu: 'બધા',
    ta: 'அனைத்தும்',
  );
  String get homeFilterPaid => _t(
    en: 'Paid',
    hi: 'भुगतान हुआ',
    as_: 'পৰিশোধ হৈছে',
    gu: 'ચૂકવેલ',
    ta: 'பணம் செலுத்தப்பட்டது',
  );
  String get homeFilterPending => _t(
    en: 'Pending',
    hi: 'लंबित',
    as_: 'বাকী আছে',
    gu: 'બાકી',
    ta: 'நிலுவையில்',
  );
  String get homeFilterOverdue => _t(
    en: 'Overdue',
    hi: 'अतिदेय',
    as_: 'মিয়াদ পাৰ',
    gu: 'મુદ્દત વીતી',
    ta: 'தாமதமானது',
  );

  String homeNoInvoicesSearch(String query) => _t(
    en: 'No invoices found for "$query".',
    hi: '"$query" के लिए कोई इनवॉइस नहीं मिला।',
    as_: '"$query"-এৰ কোনো বিল পোৱা নগ\'ল।',
    gu: '"$query" માટે કોઈ ઇન્વૉઇસ મળ્યો નથી.',
    ta: '"$query" க்கு விலைப்பட்டியல் எதுவும் கிடைக்கவில்லை.',
  );

  String get homeNoInvoicesYet => _t(
    en: 'No invoices available yet.',
    hi: 'अभी तक कोई इनवॉइस नहीं है।',
    as_: 'এতিয়াও কোনো বিল নাই।',
    gu: 'હજુ સુધી કોઈ ઇન્વૉઇસ નથી.',
    ta: 'இன்னும் விலைப்பட்டியல் எதுவும் இல்லை.',
  );

  String get homeNoInvoicesFilter => _t(
    en: 'No invoices match this filter.',
    hi: 'इस फ़िल्टर से कोई इनवॉइस मेल नहीं खाता।',
    as_: 'এই ফিল্টাৰত কোনো বিল নাই।',
    gu: 'આ ફિલ્ટર સાથે કોઈ ઇન્વૉઇસ મળ્યો નથી.',
    ta: 'இந்த வடிகட்டிக்கு பொருந்தும் விலைப்பட்டியல் இல்லை.',
  );

  String get homeLoadError => _t(
    en: 'Unable to load invoices right now.',
    hi: 'अभी इनवॉइस लोड नहीं हो सके।',
    as_: 'এতিয়া বিলসমূহ লোড হোৱা নাই।',
    gu: 'હમણાં ઇન્વૉઇસ લોડ કરી શકાતા નથી.',
    ta: 'இப்போது விலைப்பட்டியல்களை ஏற்ற முடியவில்லை.',
  );

  String get homePeriodAllInvoices => _t(
    en: 'All Invoices',
    hi: 'सभी इनवॉइस',
    as_: 'সকলো বিল',
    gu: 'બધા ઇન્વૉઇસ',
    ta: 'அனைத்து விலைப்பட்டியல்கள்',
  );
  String get homePeriodToday => _t(
    en: 'Today',
    hi: 'आज',
    as_: 'আজি',
    gu: 'આજે',
    ta: 'இன்று',
  );
  String get homePeriodThisWeek => _t(
    en: 'This Week',
    hi: 'इस सप्ताह',
    as_: 'এই সপ্তাহ',
    gu: 'આ સપ્તાહ',
    ta: 'இந்த வாரம்',
  );
  String get homePeriodCustomRange => _t(
    en: 'Custom Range',
    hi: 'कस्टम अवधि',
    as_: 'কাষ্টম সময়',
    gu: 'કસ્ટમ સમયગાળો',
    ta: 'தனிப்பயன் வரம்பு',
  );

  String homePeriodDateRange(String start, String end) =>
      '$start - $end'; // date format is language-independent

  String homePeriodCustomLabel(String start, String end) => _t(
    en: 'Custom: $start - $end',
    hi: 'कस्टम: $start - $end',
    as_: 'কাষ্টম: $start - $end',
    gu: 'કસ્ટમ: $start - $end',
    ta: 'தனிப்பயன்: $start - $end',
  );

  // ── Drawer ─────────────────────────────────────────────────────────────────

  String get drawerWorkspace => _t(
    en: 'Workspace',
    hi: 'कार्यक्षेत्र',
    as_: 'কাৰ্যক্ষেত্ৰ',
    gu: 'કાર્યક્ષેત્ર',
    ta: 'பணியிடம்',
  );
  String get drawerMyProfile => _t(
    en: 'My Profile',
    hi: 'मेरी प्रोफ़ाइल',
    as_: 'মোৰ প্ৰফাইল',
    gu: 'મારી પ્રોફાઇલ',
    ta: 'என் சுயவிவரம்',
  );
  String get drawerProducts => _t(
    en: 'Products',
    hi: 'उत्पाद',
    as_: 'সামগ্ৰী',
    gu: 'ઉત્પાદનો',
    ta: 'தயாரிப்புகள்',
  );
  String get drawerCustomers => _t(
    en: 'Customers',
    hi: 'ग्राहक',
    as_: 'গ্ৰাহকসমূহ',
    gu: 'ગ્રાહકો',
    ta: 'வாடிக்கையாளர்கள்',
  );
  String get drawerAnalytics => _t(
    en: 'Analytics',
    hi: 'विश्लेषण',
    as_: 'বিশ্লেষণ',
    gu: 'વિશ્લેષણ',
    ta: 'பகுப்பாய்வு',
  );
  String get drawerGst => _t(
    en: 'GST',
    hi: 'जीएसटी',
    as_: 'জিএছটি',
    gu: 'જીએસટી',
    ta: 'ஜிஎஸ்டி',
  );
  String get drawerSettings => _t(
    en: 'Settings',
    hi: 'सेटिंग',
    as_: 'ছেটিংছ',
    gu: 'સેટિંગ્સ',
    ta: 'அமைப்புகள்',
  );
  String get drawerLogIn => _t(
    en: 'Log In',
    hi: 'लॉग इन',
    as_: 'লগ ইন',
    gu: 'લૉગ ઇન',
    ta: 'உள்நுழை',
  );
  String get drawerLogOut => _t(
    en: 'Log Out',
    hi: 'लॉग आउट',
    as_: 'লগ আউট',
    gu: 'લૉગ આઉટ',
    ta: 'வெளியேறு',
  );
  String get drawerNotSignedIn => _t(
    en: 'Not signed in',
    hi: 'साइन इन नहीं है',
    as_: 'চাইন ইন কৰা নাই',
    gu: 'સાઇન ઇન નથી',
    ta: 'உள்நுழையவில்லை',
  );

  String get drawerProductsDesc => _t(
    en: 'Create and organize your product catalog, pricing, and reusable invoice items from one place.',
    hi: 'अपना उत्पाद कैटलॉग, मूल्य निर्धारण और पुन: उपयोगी इनवॉइस आइटम एक ही जगह से बनाएं और व्यवस्थित करें।',
    as_: 'আপোনাৰ সামগ্ৰীৰ তালিকা, মূল্য আৰু পুনৰ ব্যৱহাৰযোগ্য বিলৰ আইটেমসমূহ এঠাইৰ পৰা বনাওক।',
    gu: 'એક જ જગ્યાએથી ઉત્પાદન કૅટેલૉગ, ભાવ અને ઇન્વૉઇસ આઇટમ બનાવો.',
    ta: 'ஒரே இடத்திலிருந்து உங்கள் தயாரிப்பு பட்டியல், விலை மற்றும் விலைப்பட்டியல் பொருட்களை உருவாக்குங்கள்.',
  );

  String get drawerCustomersDesc => _t(
    en: 'Store customer names, phone numbers, GSTINs, and notes so invoices stay quick to create.',
    hi: 'ग्राहक के नाम, फोन नंबर, GSTIN और नोट्स सहेजें ताकि इनवॉइस जल्दी बनें।',
    as_: 'গ্ৰাহকৰ নাম, ফোন নম্বৰ, GSTIN আৰু টোকা সংৰক্ষণ কৰক যাতে বিল দ্ৰুতকৈ বনাব পাৰি।',
    gu: 'ઇન્વૉઇસ ઝડપથી બનાવવા ગ્રાહક નામ, ફોન, GSTIN અને નોંધ સાચવો.',
    ta: 'விலைப்பட்டியல்களை விரைவாக உருவாக்க வாடிக்கையாளர் பெயர்கள், தொலைபேசி, GSTIN சேமிக்கவும்.',
  );

  String get drawerAnalyticsDesc => _t(
    en: 'See billing trends, collections, overdue patterns, and business performance insights at a glance.',
    hi: 'बिलिंग रुझान, संग्रह, अतिदेय पैटर्न और व्यवसाय प्रदर्शन की जानकारी एक नज़र में देखें।',
    as_: 'বিলিং ধাৰা, সংগ্ৰহ, মিয়াদ পাৰ আৰ্হি আৰু ব্যৱসায়িক কাৰ্যক্ষমতা এক নজৰত চাওক।',
    gu: 'બિલિંગ ટ્રેન્ડ, સংગ્રહ, ઓવરડ્યૂ પૅટર્ન અને વ્યવસાય કામગીરી એક નજরમાં જુઓ.',
    ta: 'பில்லிங் போக்குகள், வசூல்கள், தாமத வடிவங்கள் மற்றும் வணிக செயல்திறனை ஒரு பார்வையில் பாருங்கள்.',
  );

  String get drawerGstDesc => _t(
    en: 'Prepare GST-ready records, tax summaries, and compliance-friendly invoice data for filing.',
    hi: 'दाखिल करने के लिए GST-तैयार रिकॉर्ड, कर सारांश और अनुपालन-अनुकूल इनवॉइस डेटा तैयार करें।',
    as_: 'দাখিল কৰাৰ বাবে GST-সাজু তথ্য, কৰ সাৰাংশ আৰু অনুপালন-অনুকূল বিলৰ ডেটা প্ৰস্তুত কৰক।',
    gu: 'ફાઇલ કરવા GST-તૈયાર રેકૉર્ડ, ટૅક્સ સારાંશ અને ઇન્વૉઇસ ડેટા તૈયાર કરો.',
    ta: 'தாக்கல் செய்ய GST-தயார் பதிவுகள், வரி சுருக்கங்கள் மற்றும் இணக்கமான விலைப்பட்டியல் தரவு தயாரிக்கவும்.',
  );

  String get drawerSettingsDesc => _t(
    en: 'Control preferences, app behavior, business defaults, and account-level configuration settings.',
    hi: 'प्राथमिकताएं, ऐप व्यवहार, व्यवसाय डिफ़ॉल्ट और खाता-स्तर कॉन्फ़िगरेशन सेटिंग नियंत्रित करें।',
    as_: 'পছন্দ, এপ আচৰণ, ব্যৱসায়িক ডিফল্ট আৰু একাউণ্ট-স্তৰৰ বিন্যাস নিয়ন্ত্ৰণ কৰক।',
    gu: 'પ્રાધાન્ય, એપ વર્તણૂક, વ્યવસાય ડિફૉલ્ટ અને ખાતા-સ્તર સેટિંગ નિયંત્રિત કરો.',
    ta: 'விருப்பங்கள், பயன்பாட்டு நடத்தை, வணிக இயல்புநிலைகள் மற்றும் கணக்கு நிலை அமைப்புகளை கட்டுப்படுத்துங்கள்.',
  );

  String get settingsHubTitle => _t(
    en: 'BillRaja control center',
    hi: 'BillRaja नियंत्रण केंद्र',
    as_: 'BillRaja নিয়ন্ত্ৰণ কেন্দ্ৰ',
    gu: 'BillRaja નિયંત્રણ કેન્દ્ર',
    ta: 'BillRaja கட்டுப்பாட்டு மையம்',
  );

  String get settingsHubSubtitle => _t(
    en: 'Manage your business profile, billing tools, language, and support from one place.',
    hi: 'अपनी व्यवसाय प्रोफ़ाइल, बिलिंग टूल, भाषा और सहायता एक ही जगह से संभालें।',
    as_: 'এজন ঠাইৰ পৰাই আপোনাৰ ব্যৱসায়িক প্ৰফাইল, বিলিং টুল, ভাষা আৰু সহায় পৰিচালনা কৰক।',
    gu: 'એક જ જગ્યાએથી વ્યવસાય પ્રોફાઇલ, બિલિંગ ટૂલ, ભાષા અને સહાય સંભાળો.',
    ta: 'ஒரே இடத்திலிருந்து உங்கள் வணிக சுயவிவரம், பில்லிங் கருவிகள், மொழி மற்றும் ஆதரவை நிர்வகிக்கவும்.',
  );

  String get settingsQuickActionsTitle => _t(
    en: 'Quick actions',
    hi: 'त्वरित विकल्प',
    as_: 'দ্ৰুত বিকল্প',
    gu: 'ઝડપી વિકલ્પો',
    ta: 'விரைவு செயல்கள்',
  );

  String get settingsQuickActionsSubtitle => _t(
    en: 'Jump straight to the parts of the app you use every day.',
    hi: 'ऐप के उन हिस्सों पर जाएं जिनका आप हर दिन इस्तेमाल करते हैं।',
    as_: 'প্ৰতিদিন ব্যৱহাৰ কৰা এপৰ অংশবোৰলৈ সোজাকৈ যাওক।',
    gu: 'રોજ ઉપયોગ કરો તે એપ ભાગ સીધા ખોલો.',
    ta: 'நீங்கள் தினமும் பயன்படுத்தும் பயன்பாட்டின் பகுதிகளுக்கு நேரடியாக செல்லுங்கள்.',
  );

  String get settingsEditProfile => _t(
    en: 'Edit profile',
    hi: 'प्रोफ़ाइल संपादित करें',
    as_: 'প্ৰফাইল সম্পাদনা কৰক',
    gu: 'પ્રોફાઇલ સંપાદિત કરો',
    ta: 'சுயவிவரத்தை திருத்து',
  );

  String get settingsHeroHint => _t(
    en: 'Your billing workspace, shortcuts, and support live here.',
    hi: 'आपका बिलिंग कार्यक्षेत्र, शॉर्टकट और सहायता यहीं मिलते हैं।',
    as_: 'আপোনাৰ বিলিং কাৰ্যক্ষেত্ৰ, চৰ্টকাট আৰু সহায় এতিয়াই ইয়াত আছে।',
    gu: 'તમારું બિલિંગ કાર્યક્ષેત્ર, શૉર્ટકટ અને સহાય અહીં છે.',
    ta: 'உங்கள் பில்லிங் பணியிடம், குறுக்குவழிகள் மற்றும் ஆதரவு இங்கே உள்ளது.',
  );

  String get settingsAboutTitle => _t(
    en: 'About BillRaja',
    hi: 'BillRaja के बारे में',
    as_: 'BillRaja বিষয়ে',
    gu: 'BillRaja વિશે',
    ta: 'BillRaja பற்றி',
  );

  String get settingsAboutBody => _t(
    en: 'Built for fast invoicing, GST-ready records, and a calmer daily workflow.',
    hi: 'तेज़ बिलिंग, GST-तैयार रिकॉर्ड और आसान दैनिक काम के लिए बनाया गया।',
    as_: 'দ্ৰুত বিলিং, GST-সাজু তথ্য আৰু সৰল দৈনন্দিন কামৰ বাবে তৈয়াৰ কৰা হৈছে।',
    gu: 'ઝડપી ઇન્વૉઇસ, GST-તૈયાર રેકૉર્ડ અને સરળ દૈનિક કાર્ય માટે બનાવ્યું.',
    ta: 'விரைவான விலைப்பட்டியல், GST-தயார் பதிவுகள் மற்றும் அமைதியான அன்றாட பணிப்பாய்வுக்காக உருவாக்கப்பட்டது.',
  );

  String get settingsHelpTitle => _t(
    en: 'Need help?',
    hi: 'मदद चाहिए?',
    as_: 'সহায় লাগিব নেকি?',
    gu: 'મદદ જોઈએ છે?',
    ta: 'உதவி வேண்டுமா?',
  );

  String get settingsHelpBody => _t(
    en: 'Use the shortcuts above to open profile, billing, GST, and catalog screens in one tap.',
    hi: 'ऊपर दिए गए विकल्पों से प्रोफ़ाइल, बिलिंग, GST और कैटलॉग स्क्रीन एक टैप में खोलें।',
    as_: 'ওপৰৰ চৰ্টকাট ব্যৱহাৰ কৰি এটা টেপত প্ৰফাইল, বিলিং, GST আৰু কেটালগ স্ক্ৰীণ খোলক।',
    gu: 'ઉપરના શૉર્ટકટ વापрી પ્રોફાઇલ, બિલિંગ, GST અને કૅટેલૉગ સ્ક્રીન એક ટૅپ में ખોલો.',
    ta: 'மேலே உள்ள குறுக்குவழிகளைப் பயன்படுத்தி சுயவிவரம், பில்லிங், GST மற்றும் பட்டியல் திரைகளை ஒரு தட்டலில் திறக்கவும்.',
  );

  String get settingsInvoicesSubtitle => _t(
    en: 'Review every invoice, status, and recent change from one place.',
    hi: 'सभी इनवॉइस, उनकी स्थिति और हाल के बदलाव एक जगह देखें।',
    as_: 'সমস্ত বিল, অৱস্থা আৰু শেহতীয়া পৰিবর্তন এঠাইত পৰ্যালোচনা কৰক।',
    gu: 'દરેક ઇન્વૉઇસ, સ્ટેટસ અને તાજેતરના ફેરફારો એક જ જગ્યાએ જુઓ.',
    ta: 'ஒரே இடத்திலிருந்து ஒவ்வொரு விலைப்பட்டியல், நிலை மற்றும் சமீபத்திய மாற்றங்களை மதிப்பாய்வு செய்யுங்கள்.',
  );

  String get settingsSignOut => _t(
    en: 'Sign out',
    hi: 'साइन आउट',
    as_: 'চাইন আউট',
    gu: 'સાઇન આઉટ',
    ta: 'வெளியேறு',
  );

  String get settingsLanguageTitle => _t(
    en: 'App Language',
    hi: 'ऐप भाषा',
    as_: 'এপ ভাষা',
    gu: 'એપ ભાષા',
    ta: 'பயன்பாட்டு மொழி',
  );

  String get settingsLanguageSubtitle => _t(
    en: 'Change the language any time. Updates apply instantly across the app.',
    hi: 'कभी भी भाषा बदलें। बदलाव पूरे ऐप में तुरंत दिखेगा।',
    as_: 'যিকোনো সময় ভাষা সলনি কৰক। পৰিবর্তন গোটেই এপত তৎক্ষণাত দেখা যাব।',
    gu: 'ગમે ત્યારે ભાષા બદલો. ફેરફારો તરત જ એપ પર લાગુ થશે.',
    ta: 'எந்த நேரத்திலும் மொழியை மாற்றுங்கள். மாற்றங்கள் உடனடியாக பயன்பாட்டில் பொருந்தும்.',
  );

  String settingsCurrentLanguage(String language) => _t(
    en: 'Current language: $language',
    hi: 'वर्तमान भाषा: $language',
    as_: 'বৰ্তমান ভাষা: $language',
    gu: 'વર્તમાન ભાષા: $language',
    ta: 'தற்போதைய மொழி: $language',
  );

  String settingsLanguageChanged(String language) => _t(
    en: 'Language changed to $language.',
    hi: 'भाषा $language में बदल दी गई।',
    as_: 'ভাষা $language-লৈ সলনি কৰা হ\'ল।',
    gu: 'ભાષા $language માં બદલવામાં આવ્યો.',
    ta: 'மொழி $language ஆக மாற்றப்பட்டது.',
  );

  String get drawerProfileLoadError => _t(
    en: 'Unable to load your profile right now. Please try again.',
    hi: 'अभी आपकी प्रोफ़ाइल लोड नहीं हो सकी। कृपया पुनः प्रयास करें।',
    as_: 'এতিয়া আপোনাৰ প্ৰফাইল লোড হোৱা নাই। পুনৰ চেষ্টা কৰক।',
    gu: 'હમણાં પ્રોફાઇલ લોડ કરી શકાઈ નહીં. ફરી પ્રયાસ કરો.',
    ta: 'இப்போது உங்கள் சுயவிவரத்தை ஏற்ற முடியவில்லை. மீண்டும் முயற்சிக்கவும்.',
  );

  String drawerFailedLogOut(String error) => _t(
    en: 'Failed to log out: $error',
    hi: 'लॉग आउट विफल: $error',
    as_: 'লগ আউট বিফল: $error',
    gu: 'લૉગ આઉટ નિષ્ફળ: $error',
    ta: 'வெளியேறுவதில் தோல்வி: $error',
  );

  // ── Create Invoice ─────────────────────────────────────────────────────────

  String get createTitle => _t(
    en: 'Create Invoice',
    hi: 'इनवॉइस बनाएं',
    as_: 'বিল বনাওক',
    gu: 'ઇન્વૉઇસ બનાવો',
    ta: 'விலைப்பட்டியல் உருவாக்கு',
  );

  String get createCustomerLabel => _t(
    en: 'Customer',
    hi: 'ग्राहक',
    as_: 'গ্ৰাহক',
    gu: 'ગ્રાહક',
    ta: 'வாடிக்கையாளர்',
  );

  String get createSelectCustomer => _t(
    en: 'Select a saved customer',
    hi: 'सहेजा हुआ ग्राहक चुनें',
    as_: 'সংৰক্ষিত গ্ৰাহক বাছক',
    gu: 'સાચવેલ ગ્રાહક પસંદ કરો',
    ta: 'சேமித்த வாடிக்கையாளரை தேர்ந்தெடுக்கவும்',
  );

  String get createCustomerHint => _t(
    en: 'Choose an existing customer or add a new one before saving the invoice.',
    hi: 'इनवॉइस सहेजने से पहले कोई मौजूदा ग्राहक चुनें या नया जोड़ें।',
    as_: 'বিল সংৰক্ষণ কৰাৰ আগতে এজন গ্ৰাহক বাছক বা নতুন যোগ কৰক।',
    gu: 'ઇন્વૉઇસ સાચવતા પહેલાં ગ્રાહક પસંદ કરો અથવા નવો ઉમેરો.',
    ta: 'விலைப்பட்டியலை சேமிப்பதற்கு முன் ஒரு வாடிக்கையாளரை தேர்ந்தெடுக்கவும் அல்லது புதியதை சேர்க்கவும்.',
  );

  String get createPickCustomer => _t(
    en: 'Select Customer',
    hi: 'ग्राहक चुनें',
    as_: 'গ্ৰাহক বাছক',
    gu: 'ગ્રાહક પસંદ કરો',
    ta: 'வாடிக்கையாளரை தேர்ந்தெடு',
  );

  String get createChangeCustomer => _t(
    en: 'Change Customer',
    hi: 'ग्राहक बदलें',
    as_: 'গ্ৰাহক সলনি কৰক',
    gu: 'ગ્રાહક બદલો',
    ta: 'வாடிக்கையாளரை மாற்று',
  );

  String get createAddNew => _t(
    en: 'Add New',
    hi: 'नया जोड़ें',
    as_: 'নতুন যোগ কৰক',
    gu: 'નવો ઉમેરો',
    ta: 'புதியதை சேர்',
  );

  String get createCustomerRequired => _t(
    en: 'Select a customer before saving the invoice',
    hi: 'इनवॉइस सहेजने से पहले ग्राहक चुनें',
    as_: 'বিল সংৰক্ষণৰ আগতে গ্ৰাহক বাছক',
    gu: 'ઇન્વૉઇસ સાચવતા પહેલાં ગ્રાહક પસંદ કરો',
    ta: 'விலைப்பட்டியலை சேமிப்பதற்கு முன் வாடிக்கையாளரை தேர்ந்தெடுக்கவும்',
  );

  String get createInvoiceDate => _t(
    en: 'Invoice Date',
    hi: 'इनवॉइस तिथि',
    as_: 'বিলৰ তাৰিখ',
    gu: 'ઇન્વૉઇસ તારીખ',
    ta: 'விலைப்பட்டியல் தேதி',
  );

  String get createPickDate => _t(
    en: 'Pick Invoice Date',
    hi: 'इनवॉइस तिथि चुनें',
    as_: 'বিলৰ তাৰিখ বাছক',
    gu: 'ઇન્વૉઇસ તારીખ પસંદ કરો',
    ta: 'விலைப்பட்டியல் தேதியை தேர்ந்தெடு',
  );

  String get createDateHintEmpty => _t(
    en: 'Tap here to choose the billing date before saving.',
    hi: 'सहेजने से पहले बिलिंग तारीख चुनने के लिए यहाँ टैप करें।',
    as_: 'সংৰক্ষণৰ আগতে তাৰিখ বাছিবলৈ ইয়াত টেপ কৰক।',
    gu: 'સાચવતા પહેલાં બિલ તારીખ પસંદ કરવા અહીં ટૅপ કરો.',
    ta: 'சேமிப்பதற்கு முன் பில்லிங் தேதியை தேர்ந்தெடுக்க இங்கே தட்டவும்.',
  );

  String get createDateHintSelected => _t(
    en: 'Tap to change the selected billing date.',
    hi: 'चुनी हुई बिलिंग तारीख बदलने के लिए टैप करें।',
    as_: 'বাছি লোৱা তাৰিখ সলনি কৰিবলৈ টেপ কৰক।',
    gu: 'પસંદ કરેલ બિલ તારીખ બદલવા ટૅπ કরো.',
    ta: 'தேர்ந்தெடுத்த பில்லிங் தேதியை மாற்ற தட்டவும்.',
  );

  String get createDateRequired => _t(
    en: 'Select an invoice date',
    hi: 'इनवॉइस तिथि चुनें',
    as_: 'বিলৰ তাৰিখ বাছক',
    gu: 'ઇન્વૉઇસ તારીખ પસંદ કરો',
    ta: 'விலைப்பட்டியல் தேதியை தேர்ந்தெடுக்கவும்',
  );

  String get createProductLabel => _t(
    en: 'Product / Description',
    hi: 'उत्पाद / विवरण',
    as_: 'সামগ্ৰী / বিৱৰণ',
    gu: 'ઉત્પાદન / વિવરણ',
    ta: 'தயாரிப்பு / விளக்கம்',
  );

  String get createQtyLabel => _t(
    en: 'Qty',
    hi: 'मात्रा',
    as_: 'পৰিমাণ',
    gu: 'જથ્થો',
    ta: 'அளவு',
  );

  String get createUnitLabel => _t(
    en: 'Unit',
    hi: 'इकाई',
    as_: 'একক',
    gu: 'એકમ',
    ta: 'அலகு',
  );

  String get createUnitPriceLabel => _t(
    en: 'Unit Price',
    hi: 'इकाई मूल्य',
    as_: 'একক মূল্য',
    gu: 'એકમ ભાવ',
    ta: 'அலகு விலை',
  );

  String get createEnterProduct => _t(
    en: 'Enter product',
    hi: 'उत्पाद दर्ज करें',
    as_: 'সামগ্ৰী দিয়ক',
    gu: 'ઉત્પાદન દાખલ કરો',
    ta: 'தயாரிப்பை உள்ளிடவும்',
  );

  String get createDeleteItem => _t(
    en: 'Delete item',
    hi: 'आइटम हटाएं',
    as_: 'আইটেম মচক',
    gu: 'આઇટમ ડिলीট કરો',
    ta: 'பொருளை நீக்கு',
  );

  String get createAddItem => _t(
    en: '+ Add Item',
    hi: '+ आइटम जोड़ें',
    as_: '+ আইটেম যোগ কৰক',
    gu: '+ આઇટમ ઉમેરો',
    ta: '+ பொருளை சேர்',
  );

  String get createInvoiceStatus => _t(
    en: 'Invoice Status',
    hi: 'इनवॉइस स्थिति',
    as_: 'বিলৰ স্থিতি',
    gu: 'ઇન્વૉઇસ સ્ટેટસ',
    ta: 'விலைப்பட்டியல் நிலை',
  );

  String get createDiscountTitle => _t(
    en: 'Discount',
    hi: 'छूट',
    as_: 'ৰেহাই',
    gu: 'છૂટ',
    ta: 'தள்ளுபடி',
  );

  String get createDiscountPctLabel => _t(
    en: 'Percentage',
    hi: 'प्रतिशत',
    as_: 'শতাংশ',
    gu: 'ટકાવારી',
    ta: 'சதவீதம்',
  );

  String get createDiscountOverallLabel => _t(
    en: 'Overall',
    hi: 'कुल',
    as_: 'সামগ্ৰিক',
    gu: 'એકંદર',
    ta: 'மொத்தம்',
  );

  String get createDiscountPctField => _t(
    en: 'Discount Percentage',
    hi: 'छूट प्रतिशत',
    as_: 'ৰেহাইৰ শতাংশ',
    gu: 'છૂટ ટકાવારી',
    ta: 'தள்ளுபடி சதவீதம்',
  );

  String get createDiscountOverallField => _t(
    en: 'Overall Discount',
    hi: 'कुल छूट',
    as_: 'সামগ্ৰিক ৰেহাই',
    gu: 'એકંદર છૂટ',
    ta: 'ஒட்டுமொத்த தள்ளுபடி',
  );

  String get createDiscountPctHint => _t(
    en: 'Optional, e.g. 10',
    hi: 'वैकल्पिक, जैसे 10',
    as_: 'ঐচ্ছিক, যেনে 10',
    gu: 'વૈકલ્પિક, જેમ કે 10',
    ta: 'விருப்பமான, எ.கா. 10',
  );

  String get createDiscountOverallHint => _t(
    en: 'Optional, e.g. 500',
    hi: 'वैकल्पिक, जैसे 500',
    as_: 'ঐচ্ছিক, যেনে 500',
    gu: 'વૈકલ્પિક, જેમ કે 500',
    ta: 'விருப்பமான, எ.கா. 500',
  );

  String get createSummarySubtotal => _t(
    en: 'Subtotal',
    hi: 'उप-कुल',
    as_: 'উপ-মুঠ',
    gu: 'પેટા-કુલ',
    ta: 'உப மொத்தம்',
  );

  String get createSummaryDiscount => _t(
    en: 'Discount',
    hi: 'छूट',
    as_: 'ৰেহাই',
    gu: 'છૂટ',
    ta: 'தள்ளுபடி',
  );

  String get createSummaryGrandTotal => _t(
    en: 'Grand Total',
    hi: 'कुल योग',
    as_: 'মুঠ যোগফল',
    gu: 'ગ્રૅન્ડ ટોટલ',
    ta: 'மொத்த தொகை',
  );

  String get createSavingInvoice => _t(
    en: 'Saving Invoice...',
    hi: 'इनवॉइस सहेजा जा रहा है...',
    as_: 'বিল সংৰক্ষণ হৈ আছে...',
    gu: 'ઇन्वॉइस સાચવাઈ રહ્યો છે...',
    ta: 'விலைப்பட்டியல் சேமிக்கப்படுகிறது...',
  );

  String get createSaveInvoice => _t(
    en: 'Save Invoice',
    hi: 'इनवॉइस सहेजें',
    as_: 'বিল সংৰক্ষণ কৰক',
    gu: 'ઇน्वॉइस સાચવો',
    ta: 'விலைப்பட்டியலை சேமி',
  );

  String createItemNumber(int number) => _t(
    en: 'Item $number',
    hi: 'आइटम $number',
    as_: 'সামগ্ৰী $number',
    gu: 'આઇટમ $number',
    ta: 'பொருள் $number',
  );

  String get createSaveHint => _t(
    en: 'Review the invoice date and total, then save to generate the final bill.',
    hi: 'इनवॉइस तिथि और कुल जांचें, फिर अंतिम बिल बनाने के लिए सहेजें।',
    as_: 'বিলৰ তাৰিখ আৰু মুঠ পৰীক্ষা কৰক, তাৰপিছত চূড়ান্ত বিল বনাবলৈ সংৰক্ষণ কৰক।',
    gu: 'ઇন્વૉઇસ તારીખ અને કુલ ચકાસો, પછી અંતિم बिल बनाने के लिए सहेजें.',
    ta: 'விலைப்பட்டியல் தேதி மற்றும் மொத்தத்தை மதிப்பாய்வு செய்து, இறுதி பட்டியலை உருவாக்க சேமிக்கவும்.',
  );

  String get createAddLineItem => _t(
    en: 'Add at least one line item.',
    hi: 'कम से कम एक आइटम जोड़ें।',
    as_: 'কমপক্ষে এটা আইটেম যোগ কৰক।',
    gu: 'ઓછામાં ઓછો એક આઇટમ ઉમેરો.',
    ta: 'குறைந்தது ஒரு வரி பொருளை சேர்க்கவும்.',
  );

  String get createErrorPctMax => _t(
    en: 'Percentage discount cannot be more than 100.',
    hi: 'प्रतिशत छूट 100 से अधिक नहीं हो सकती।',
    as_: 'শতাংশ ৰেহাই ১০০-ৰ বেছি হ\'ব নোৱাৰে।',
    gu: 'ટકાવારી છૂટ 100 થી વધુ ન હોઈ શકે.',
    ta: 'சதவீத தள்ளுபடி 100 ஐ விட அதிகமாக இருக்க முடியாது.',
  );

  String get createErrorOverallMax => _t(
    en: 'Overall discount cannot be more than the subtotal.',
    hi: 'कुल छूट उप-कुल से अधिक नहीं हो सकती।',
    as_: 'সামগ্ৰিক ৰেহাই উপ-মুঠতকৈ বেছি হ\'ব নোৱাৰে।',
    gu: 'એકंदर छूट पेटा-कुल थी वधु न होई शके.',
    ta: 'ஒட்டுமொத்த தள்ளுபடி உப மொத்தத்தை விட அதிகமாக இருக்க முடியாது.',
  );

  String get createSignInRequired => _t(
    en: 'Please sign in before saving invoices.',
    hi: 'इनवॉइस सहेजने से पहले साइन इन करें।',
    as_: 'বিল সংৰক্ষণৰ আগতে চাইন ইন কৰক।',
    gu: 'ઇन्वॉइस सहेजने से पहले साइन इन करें.',
    ta: 'விலைப்பட்டியல்களை சேமிப்பதற்கு முன் உள்நுழையவும்.',
  );

  String createFailedSave(String error) => _t(
    en: 'Failed to save invoice: $error',
    hi: 'इनवॉइस सहेजना विफल: $error',
    as_: 'বিল সংৰক্ষণ বিফল: $error',
    gu: 'ઇн्वॉइस सहेजना विफल: $error',
    ta: 'விலைப்பட்டியலை சேமிப்பதில் தோல்வி: $error',
  );

  String get createDiscountEmptyHint => _t(
    en: 'Leave discount empty to keep the invoice at full subtotal.',
    hi: 'पूरे उप-कुल पर इनवॉइस रखने के लिए छूट खाली छोड़ें।',
    as_: 'পূৰ্ণ উপ-মুঠত বিল ৰাখিবলৈ ৰেহাই খালি ৰাখক।',
    gu: 'ઇن्वॉइस पूरे पेटा-कुल पर रखने के लिए छूट खाली छोड़ें.',
    ta: 'விலைப்பட்டியலை முழு உப மொத்தத்தில் வைக்க தள்ளுபடியை காலியாக விடுங்கள்.',
  );

  String createDiscountPreviewPct(
    String pct,
    String subtotal,
    String discAmt,
  ) => _t(
    en: '$pct% discount will reduce $subtotal by $discAmt.',
    hi: '$pct% छूट $subtotal को $discAmt से कम करेगी।',
    as_: '$pct% ৰেহাইয়ে $subtotal-ৰ পৰা $discAmt কমাব।',
    gu: '$pct% छूट $subtotal मांथी $discAmt ओछी करशे.',
    ta: '$pct% தள்ளுபடி $subtotal ஐ $discAmt குறைக்கும்.',
  );

  String createDiscountPreviewOverall(String discAmt, String subtotal) => _t(
    en: 'Overall discount of $discAmt will be applied to $subtotal.',
    hi: '$discAmt का कुल छूट $subtotal पर लागू होगा।',
    as_: '$discAmt-ৰ সামগ্ৰিক ৰেহাই $subtotal-ত প্ৰযোজ্য হ\'ব।',
    gu: '$discAmt ની એकंदर छूट $subtotal पर लागू थशे.',
    ta: '$discAmt இன் ஒட்டுமொத்த தள்ளுபடி $subtotal க்கு பயன்படுத்தப்படும்.',
  );

  // ── PDF labels ────────────────────────────────────────────────────────────

  String get pdfInvoice => 'INVOICE';

  String get pdfInvoiceNo => _t(
    en: 'Invoice No.',
    hi: 'चालान नं.',
    as_: 'বিল নং.',
    gu: 'ઇন્વૉઇસ નં.',
    ta: 'விலைப்பட்டியல் எண்.',
  );

  String get pdfInvoiceDate => _t(
    en: 'Invoice Date',
    hi: 'इनवॉइस तिथि',
    as_: 'বিলৰ তাৰিখ',
    gu: 'ઇن्वॉइस तारीख',
    ta: 'விலைப்பட்டியல் தேதி',
  );

  String get pdfFrom => _t(
    en: 'FROM',
    hi: 'विक्रेता',
    as_: 'বিক্ৰেতা',
    gu: 'પ્રેષક',
    ta: 'இருந்து',
  );

  String get pdfBillTo => _t(
    en: 'BILL TO',
    hi: 'खरीदार',
    as_: 'ক্ৰেতা',
    gu: 'બિલ ટૂ',
    ta: 'பட்டியல் செலுத்துபவர்',
  );

  String get pdfItem => _t(
    en: 'Item',
    hi: 'वस्तु',
    as_: 'সামগ্ৰী',
    gu: 'આઇटम',
    ta: 'பொருள்',
  );

  String get pdfAmount => _t(
    en: 'Amount',
    hi: 'राशि',
    as_: 'মূল্য',
    gu: 'રકम',
    ta: 'தொகை',
  );

  String get pdfAddressNotAdded => _t(
    en: 'Address not added',
    hi: 'पता नहीं जोड़ा',
    as_: 'ঠিকনা যোগ কৰা নাই',
    gu: 'સরนामुं ઉমेरायुं नथी',
    ta: 'முகவரி சேர்க்கப்படவில்லை',
  );

  String get pdfPhoneNotAdded => _t(
    en: 'Phone not added',
    hi: 'फोन नहीं जोड़ा',
    as_: 'ফোন যোগ কৰা নাই',
    gu: 'ফোন ઉमेरायुं नथी',
    ta: 'தொலைபேசி சேர்க்கப்படவில்லை',
  );

  String get pdfGeneratedBy => _t(
    en: 'Generated by BillRaja',
    hi: 'BillRaja द्वारा जारी',
    as_: 'BillRaja-এ তৈয়াৰ কৰিছে',
    gu: 'BillRaja દ્வारा बनाया',
    ta: 'BillRaja மூலம் உருவாக்கப்பட்டது',
  );

  String get pdfPage => _t(
    en: 'Page',
    hi: 'पृष्ठ',
    as_: 'পৃষ্ঠা',
    gu: 'पेज',
    ta: 'பக்கம்',
  );

  String get pdfOf => _t(
    en: 'of',
    hi: 'का',
    as_: 'ৰ',
    gu: 'ਦਾ',
    ta: 'இல்',
  );

  String pdfItemsCount(int n) => _t(
    en: '$n item${n == 1 ? '' : 's'}',
    hi: '$n वस्तु',
    as_: '$n সামগ্ৰী',
    gu: '$n આइटम',
    ta: '$n பொருள்',
  );

  // ── Invoice Details ────────────────────────────────────────────────────────

  String get detailsTitle => _t(
    en: 'Invoice Details',
    hi: 'इनवॉइस विवरण',
    as_: 'বিলৰ বিৱৰণ',
    gu: 'ઇन्वॉइस विवरण',
    ta: 'விலைப்பட்டியல் விவரங்கள்',
  );

  String get detailsPreviewPrint => _t(
    en: 'Preview / Print',
    hi: 'पूर्वावलोकन / प्रिंट',
    as_: 'পূৰ্বদৰ্শন / প্ৰিণ্ট',
    gu: 'પ્રિвью / प्रिंट',
    ta: 'முன்னோட்டம் / அச்சிடு',
  );

  String get detailsSharePdf => _t(
    en: 'Share PDF',
    hi: 'PDF साझा करें',
    as_: 'PDF শ্বেয়াৰ কৰক',
    gu: 'PDF শेर करो',
    ta: 'PDF பகிர்',
  );

  String detailsIssuedBy(String name) => _t(
    en: 'Issued by $name',
    hi: '$name द्वारा जारी',
    as_: '$name-এ জাৰি কৰিছে',
    gu: '$name দ্বারা जारी',
    ta: '$name மூலம் வழங்கப்பட்டது',
  );

  String get detailsSeller => _t(
    en: 'Seller',
    hi: 'विक्रेता',
    as_: 'বিক্ৰেতা',
    gu: 'विक्रेता',
    ta: 'விற்பனையாளர்',
  );

  String get detailsCustomer => _t(
    en: 'Customer',
    hi: 'ग्राहक',
    as_: 'গ্ৰাহক',
    gu: 'ग्राहक',
    ta: 'வாடிக்கையாளர்',
  );

  String get detailsItems => _t(
    en: 'Items',
    hi: 'वस्तुएं',
    as_: 'সামগ্ৰীসমূহ',
    gu: 'आइटम',
    ta: 'பொருட்கள்',
  );

  String get detailsAmountSummary => _t(
    en: 'Amount Summary',
    hi: 'राशि सारांश',
    as_: 'বিলৰ সাৰাংশ',
    gu: 'रकम सारांश',
    ta: 'தொகை சுருக்கம்',
  );

  String get detailsStore => _t(
    en: 'Store',
    hi: 'दुकान',
    as_: 'দোকান',
    gu: 'दुकान',
    ta: 'கடை',
  );

  String get detailsAddress => _t(
    en: 'Address',
    hi: 'पता',
    as_: 'ঠিকনা',
    gu: 'સरनामुं',
    ta: 'முகவரி',
  );

  String get detailsPhone => _t(
    en: 'Phone',
    hi: 'फोन',
    as_: 'ফোন',
    gu: 'ফোন',
    ta: 'தொலைபேசி',
  );

  String get detailsEmail => _t(
    en: 'Email',
    hi: 'ईमेल',
    as_: 'ইমেইল',
    gu: 'ઈ-मेइल',
    ta: 'மின்னஞ்சல்',
  );

  String get detailsNotAddedYet => _t(
    en: 'Not added yet',
    hi: 'अभी नहीं जोड़ा',
    as_: 'এতিয়াও যোগ কৰা নাই',
    gu: 'हजु ઉमेरायुं नथी',
    ta: 'இன்னும் சேர்க்கப்படவில்லை',
  );

  String get detailsName => _t(
    en: 'Name',
    hi: 'नाम',
    as_: 'নাম',
    gu: 'નામ',
    ta: 'பெயர்',
  );

  String get detailsReference => _t(
    en: 'Reference',
    hi: 'संदर्भ',
    as_: 'প্ৰসঙ্গ',
    gu: 'संदर्भ',
    ta: 'குறிப்பு',
  );

  String get detailsOpenProfile => _t(
    en: 'Open Customer Profile',
    hi: 'ग्राहक प्रोफ़ाइल खोलें',
    as_: 'গ্ৰাহকৰ প্ৰফাইল খোলক',
    gu: 'ग्राहक प्रोफाइल खोलो',
    ta: 'வாடிக்கையாளர் சுயவிவரத்தை திற',
  );

  String get detailsItemQty => _t(
    en: 'Qty',
    hi: 'मात्रा',
    as_: 'পৰিমাণ',
    gu: 'जथ्थो',
    ta: 'அளவு',
  );

  String get detailsItemUnitPrice => _t(
    en: 'Unit Price',
    hi: 'इकाई मूल्य',
    as_: 'একক মূল্য',
    gu: 'एकम भाव',
    ta: 'அலகு விலை',
  );

  String get detailsItemTotal => _t(
    en: 'Total',
    hi: 'कुल',
    as_: 'মুঠ',
    gu: 'કुल',
    ta: 'மொத்தம்',
  );

  String get detailsSubtotal => _t(
    en: 'Subtotal',
    hi: 'उप-योग',
    as_: 'উপ-মুঠ',
    gu: 'पेटा-कुल',
    ta: 'உப மொத்தம்',
  );

  String get detailsDiscount => _t(
    en: 'Discount',
    hi: 'छूट',
    as_: 'ৰেহাই',
    gu: 'छूट',
    ta: 'தள்ளுபடி',
  );

  String get detailsItemsCount => _t(
    en: 'Items Count',
    hi: 'आइटम गिनती',
    as_: 'সামগ্ৰীৰ সংখ্যা',
    gu: 'आइटम गणना',
    ta: 'பொருட்கள் எண்ணிக்கை',
  );

  String get detailsStatus => _t(
    en: 'Status',
    hi: 'स्थिति',
    as_: 'স্থিতি',
    gu: 'સ્ţitus',
    ta: 'நிலை',
  );

  String get detailsGrandTotal => _t(
    en: 'Grand Total',
    hi: 'कुल योग',
    as_: 'মুঠ যোগফল',
    gu: 'ग्रैंड टोटल',
    ta: 'மொத்த தொகை',
  );

  String get detailsNoDiscount => _t(
    en: 'No discount',
    hi: 'कोई छूट नहीं',
    as_: 'কোনো ৰেহাই নাই',
    gu: 'कोई छूट नही',
    ta: 'தள்ளுபடி இல்லை',
  );

  String detailsPctOff(String value) => _t(
    en: '$value% off',
    hi: '$value% की छूट',
    as_: '$value% ৰেহাই',
    gu: '$value% छूट',
    ta: '$value% தள்ளுபடி',
  );

  String get detailsOverallDiscount => _t(
    en: 'Overall discount',
    hi: 'कुल छूट',
    as_: 'সামগ্ৰিক ৰেহাই',
    gu: 'एकंदर छूट',
    ta: 'ஒட்டுமொத்த தள்ளுபடி',
  );

  String detailsPdfError(String error) => _t(
    en: 'Unable to generate invoice PDF: $error',
    hi: 'इनवॉइस PDF बनाना विफल: $error',
    as_: 'বিলৰ PDF বনাব পৰা নগ\'ল: $error',
    gu: 'ইn्वॉइस PDF बनाना विफल: $error',
    ta: 'விலைப்பட்டியல் PDF உருவாக்குவதில் தோல்வி: $error',
  );

  // ── Status labels (shared) ─────────────────────────────────────────────────

  String get statusPaid => _t(
    en: 'Paid',
    hi: 'भुगतान',
    as_: 'পৰিশোধ',
    gu: 'ચૂકવેલ',
    ta: 'பணம் செலுத்தப்பட்டது',
  );

  String get statusPending => _t(
    en: 'Pending',
    hi: 'लंबित',
    as_: 'বাকী',
    gu: 'બાકી',
    ta: 'நிலுவையில்',
  );

  String get statusOverdue => _t(
    en: 'Overdue',
    hi: 'अतिदेय',
    as_: 'মিয়াদোত্তীৰ্ণ',
    gu: 'મुদत वीती',
    ta: 'தாமதமானது',
  );

  // ── Profile Setup ──────────────────────────────────────────────────────────

  String get profileAppBarSetup => _t(
    en: 'Complete Profile',
    hi: 'प्रोफ़ाइल पूरी करें',
    as_: 'প্ৰফাইল সম্পূৰ্ণ কৰক',
    gu: 'પ્રોफाइल पूरी करो',
    ta: 'சுயவிவரத்தை நிறைவு செய்',
  );

  String get profileAppBarEdit => _t(
    en: 'My Profile',
    hi: 'मेरी प्रोफ़ाइल',
    as_: 'মোৰ প্ৰফাইল',
    gu: 'मारी प्रोफाइल',
    ta: 'என் சுயவிவரம்',
  );

  String get profileSignOutTooltip => _t(
    en: 'Sign out',
    hi: 'साइन आउट',
    as_: 'চাইন আউট',
    gu: 'साइन आउट',
    ta: 'வெளியேறு',
  );

  String get profilePromptTitleSetup => _t(
    en: 'Set up your billing profile',
    hi: 'अपनी बिलिंग प्रोफ़ाइल सेट करें',
    as_: 'আপোনাৰ বিলিং প্ৰফাইল ছেট আপ কৰক',
    gu: 'તमारी बिलिंग प्रोफाइल सेट करो',
    ta: 'உங்கள் பில்லிங் சுயவிவரத்தை அமைக்கவும்',
  );

  String get profilePromptTitleEdit => _t(
    en: 'My Profile',
    hi: 'मेरी प्रोफ़ाइल',
    as_: 'মোৰ প্ৰফাইল',
    gu: 'मारी प्रोफाइल',
    ta: 'என் சுயவிவரம்',
  );

  String get profilePromptBodySetup => _t(
    en: 'Add your shop details once so they can appear on your invoices. Every field is optional, but saving this profile unlocks your workspace.',
    hi: 'अपनी दुकान की जानकारी एक बार जोड़ें ताकि यह आपके इनवॉइस पर दिखे। सभी फ़ील्ड वैकल्पिक हैं, लेकिन प्रोफ़ाइल सहेजने से आपका कार्यक्षेत्र खुल जाता है।',
    as_: 'আপোনাৰ দোকানৰ তথ্য এবাৰ যোগ কৰক যাতে বিলত দেখা যায়। সকলো ক্ষেত্ৰ ঐচ্ছিক, কিন্তু প্ৰফাইল সংৰক্ষণে আপোনাৰ কাৰ্যক্ষেত্ৰ খোলে।',
    gu: 'তमारी दुकानना विगत एकवार ઉмेरो जेथी ते invoice पर दखाय. बधा fields optional छे.',
    ta: 'உங்கள் கடை விவரங்களை ஒருமுறை சேர்க்கவும். அனைத்து புலங்களும் விருப்பமானவை.',
  );

  String get profilePromptBodyEdit => _t(
    en: 'Update the business details that appear on your invoices. All fields stay optional, so you can keep it light and edit later.',
    hi: 'अपने इनवॉइस पर दिखने वाले व्यावसायिक विवरण अपडेट करें। सभी फ़ील्ड वैकल्पिक रहते हैं।',
    as_: 'আপোনাৰ বিলত দেখা যোৱা ব্যৱসায়িক তথ্য আপডেট কৰক। সকলো ক্ষেত্ৰ ঐচ্ছিক থাকে।',
    gu: 'Invoice पर दखाता व्यापारिक विगत अपडेट करो. बधा fields optional रहे छे.',
    ta: 'உங்கள் விலைப்பட்டியல்களில் தோன்றும் வணிக விவரங்களை புதுப்பிக்கவும்.',
  );

  String get profileBadgeFallback => _t(
    en: 'Business profile',
    hi: 'व्यावसायिक प्रोफ़ाइल',
    as_: 'ব্যৱসায়িক প্ৰফাইল',
    gu: 'व्यापारिक प्रोफाइल',
    ta: 'வணிக சுயவிவரம்',
  );

  String get profileStoreLabel => _t(
    en: 'Store / Shop Name',
    hi: 'दुकान / स्टोर का नाम',
    as_: 'দোকানৰ নাম',
    gu: 'दुकान / स्टोर नाम',
    ta: 'கடை / வியாபார பெயர்',
  );

  String get profileAddressLabel => _t(
    en: 'Address',
    hi: 'पता',
    as_: 'ঠিকনা',
    gu: 'સरنामुं',
    ta: 'முகவரி',
  );

  String get profilePhoneLabel => _t(
    en: 'Phone Number',
    hi: 'फोन नंबर',
    as_: 'ফোন নম্বৰ',
    gu: 'ফোन नंबर',
    ta: 'தொலைபேசி எண்',
  );

  String get profileOptionalHint => _t(
    en: 'Optional',
    hi: 'वैकल्पिक',
    as_: 'ঐচ্ছিক',
    gu: 'वैकल्पिक',
    ta: 'விருப்பமான',
  );

  String get profileSaving => _t(
    en: 'Saving...',
    hi: 'सहेजा जा रहा है...',
    as_: 'সংৰক্ষণ হৈ আছে...',
    gu: 'सहेजाई रह्युं छे...',
    ta: 'சேமிக்கப்படுகிறது...',
  );

  String get profileSaveAndContinue => _t(
    en: 'Save and Continue',
    hi: 'सहेजें और जारी रखें',
    as_: 'সংৰক্ষণ কৰক আৰু আগবাঢ়ক',
    gu: 'सहेजो और आगे वधो',
    ta: 'சேமித்து தொடரவும்',
  );

  String get profileSave => _t(
    en: 'Save Profile',
    hi: 'प्रोफ़ाइल सहेजें',
    as_: 'প্ৰফাইল সংৰক্ষণ কৰক',
    gu: 'प्रोफाइल सहेजो',
    ta: 'சுயவிவரத்தை சேமி',
  );

  String get profileSignInRequired => _t(
    en: 'Please sign in again to save profile.',
    hi: 'प्रोफ़ाइल सहेजने के लिए फिर से साइन इन करें।',
    as_: 'প্ৰফাইল সংৰক্ষণৰ বাবে পুনৰ চাইন ইন কৰক।',
    gu: 'प्रोफाइल सहेजवा फरी साइन इन करो.',
    ta: 'சுயவிவரத்தை சேமிக்க மீண்டும் உள்நுழையவும்.',
  );

  String get profileSavedSuccess => _t(
    en: 'Profile saved successfully.',
    hi: 'प्रोफ़ाइल सफलतापूर्वक सहेजी गई।',
    as_: 'প্ৰফাইল সফলভাৱে সংৰক্ষণ হ\'ল।',
    gu: 'प्रोफाइल सफळतापूर्वक सहेजाई.',
    ta: 'சுயவிவரம் வெற்றிகரமாக சேமிக்கப்பட்டது.',
  );

  String profileFailedSave(String error) => _t(
    en: 'Failed to save profile: $error',
    hi: 'प्रोफ़ाइल सहेजना विफल: $error',
    as_: 'প্ৰফাইল সংৰক্ষণ বিফল: $error',
    gu: 'प्रोफाइल सहेजवामां निष्फळ: $error',
    ta: 'சுயவிவரத்தை சேமிப்பதில் தோல்வி: $error',
  );

  String profileFailedSignOut(String error) => _t(
    en: 'Failed to sign out: $error',
    hi: 'साइन आउट विफल: $error',
    as_: 'চাইন আউট বিফল: $error',
    gu: 'साइन आउट निष्फळ: $error',
    ta: 'வெளியேறுவதில் தோல்வி: $error',
  );

  // ── Feature Placeholder ────────────────────────────────────────────────────

  String placeholderComingSoon(String title) => _t(
    en: '$title module is coming soon. This placeholder is ready for the real feature to be plugged in next.',
    hi: '$title मॉड्यूल जल्द आ रहा है। यह प्लेसहोल्डर अगली बार असली फीचर के लिए तैयार है।',
    as_: '$title মডিউল সোনকালে আহিব। এই প্লেচহোল্ডাৰ পৰৱৰ্তী ৰিয়েল ফিচাৰৰ বাবে সাজু।',
    gu: '$title मॉड्यूल जल्दी आवशे. आ placeholder आगलु real feature माटे तैयार छे.',
    ta: '$title தொகுதி விரைவில் வரும். இந்த இடம்பிடி அடுத்த உண்மையான அம்சத்திற்கு தயாராக உள்ளது.',
  );

  // ── Customers ──────────────────────────────────────────────────────────────

  String get customersTitle => _t(
    en: 'Customers',
    hi: 'ग्राहक',
    as_: 'গ্ৰাহকসমূহ',
    gu: 'ग्राहको',
    ta: 'வாடிக்கையாளர்கள்',
  );

  String get customersSelectTitle => _t(
    en: 'Select Customer',
    hi: 'ग्राहक चुनें',
    as_: 'গ্ৰাহক বাছক',
    gu: 'ग्राहक पसंद करो',
    ta: 'வாடிக்கையாளரை தேர்ந்தெடு',
  );

  String get customersSearchHint => _t(
    en: 'Search customers',
    hi: 'ग्राहक खोजें',
    as_: 'গ্ৰাহক বিচাৰক',
    gu: 'ग्राहको शोधो',
    ta: 'வாடிக்கையாளர்களை தேடு',
  );

  String get customersCloseSearch => _t(
    en: 'Close search',
    hi: 'खोज बंद करें',
    as_: 'সন্ধান বন্ধ কৰক',
    gu: 'शोध बंध करो',
    ta: 'தேடலை மூடு',
  );

  String get customersLoadError => _t(
    en: 'Unable to load customers right now.',
    hi: 'अभी ग्राहक लोड नहीं हो सके।',
    as_: 'এতিয়া গ্ৰাহকসমূহ লোড হোৱা নাই।',
    gu: 'अत्यारे ग्राहको लोड नथी थता.',
    ta: 'இப்போது வாடிக்கையாளர்களை ஏற்ற முடியவில்லை.',
  );

  String get customersIntroTitle => _t(
    en: 'Your saved customer profiles live here.',
    hi: 'आपके सहेजे हुए ग्राहक यहाँ हैं।',
    as_: 'আপোনাৰ সংৰক্ষিত গ্ৰাহক প্ৰফাইলসমূহ ইয়াত আছে।',
    gu: 'तमारा सहेजेला ग्राहको अहीं छे.',
    ta: 'உங்கள் சேமித்த வாடிக்கையாளர் சுயவிவரங்கள் இங்கே உள்ளன.',
  );

  String get customersIntroBody => _t(
    en: 'Use this space for repeat customers, quick contact lookup, and a clean invoice history for each relationship.',
    hi: 'दोबारा आने वाले ग्राहकों के लिए यहाँ प्रोफ़ाइल बनाएं।',
    as_: 'নিয়মীয়া গ্ৰাহকৰ বাবে দ্ৰুত যোগাযোগ আৰু পৰিষ্কাৰ বিলৰ ইতিহাসৰ বাবে এই ঠাই ব্যৱহাৰ কৰক।',
    gu: 'वारंवार आवता ग्राहको माटे आ जगहनो उपयोग करो.',
    ta: 'மீண்டும் வரும் வாடிக்கையாளர்களுக்கு இந்த இடத்தை பயன்படுத்துங்கள்.',
  );

  String get customersSelectIntroTitle => _t(
    en: 'Choose who this invoice belongs to.',
    hi: 'यह इनवॉइस किसके लिए है, चुनें।',
    as_: 'এই বিলটো কাৰ বাবে, সেইটো বাছক।',
    gu: 'आ invoice कोना माटे छे ते पसंद करो.',
    ta: 'இந்த விலைப்பட்டியல் யாருக்கு என்று தேர்ந்தெடுக்கவும்.',
  );

  String get customersSelectIntroBody => _t(
    en: 'Pick an existing customer or create a new one without leaving the billing flow.',
    hi: 'कोई मौजूदा ग्राहक चुनें या बिलिंग छोड़े बिना नया बनाएं।',
    as_: 'এজন বিদ্যমান গ্ৰাহক বাছক বা বিলিং প্ৰবাহ নেৰাকৈ নতুন বনাওক।',
    gu: 'हयातो ग्राहक पसंद करो या बिलिंग छोड्या विना नवो बनावो.',
    ta: 'ஏற்கனவே உள்ள வாடிக்கையாளரை தேர்ந்தெடுக்கவும் அல்லது புதியவரை உருவாக்கவும்.',
  );

  String get customersEmptyTitle => _t(
    en: 'Start your customer book here.',
    hi: 'अपनी ग्राहक सूची यहाँ शुरू करें।',
    as_: 'আপোনাৰ গ্ৰাহক তালিকা ইয়াৰ পৰা আৰম্ভ কৰক।',
    gu: 'तमारी ग्राहक यादी अहींथी शरू करो.',
    ta: 'உங்கள் வாடிக்கையாளர் புத்தகத்தை இங்கே தொடங்குங்கள்.',
  );

  String get customersEmptySelectTitle => _t(
    en: 'No saved customers yet.',
    hi: 'अभी कोई ग्राहक नहीं जोड़ा।',
    as_: 'এতিয়াও কোনো গ্ৰাহক যোগ কৰা নাই।',
    gu: 'हजु कोई ग्राहक सहेजायो नथी.',
    ta: 'இன்னும் சேமித்த வாடிக்கையாளர்கள் இல்லை.',
  );

  String customersEmptySearchTitle(String query) => _t(
    en: 'No customer matched "$query".',
    hi: '"$query" से कोई ग्राहक नहीं मिला।',
    as_: '"$query"-এৰ কোনো গ্ৰাহক পোৱা নগ\'ল।',
    gu: '"$query" थी कोई ग्राहक मळ्यो नहीं.',
    ta: '"$query" க்கு பொருந்தும் வாடிக்கையாளர் இல்லை.',
  );

  String get customersEmptyBody => _t(
    en: 'Saved customers make repeat invoicing faster and keep all their bills together in one place.',
    hi: 'सहेजे हुए ग्राहक बार-बार बिलिंग को तेज़ बनाते हैं।',
    as_: 'সংৰক্ষিত গ্ৰাহকে বাৰে বাৰে বিলিং দ্ৰুত কৰে আৰু সকলো বিল এঠাইত ৰাখে।',
    gu: 'सहेजेला ग्राहको वारंवार बिलिंग ने झडपी बनावे छे.',
    ta: 'சேமித்த வாடிக்கையாளர்கள் மீண்டும் மீண்டும் பில்லிங்கை விரைவுபடுத்துகிறார்கள்.',
  );

  String get customersEmptySelectBody => _t(
    en: 'Create a customer profile first, then come back to attach invoices to it.',
    hi: 'पहले ग्राहक प्रोफ़ाइल बनाएं, फिर इनवॉइस जोड़ें।',
    as_: 'প্ৰথমে গ্ৰাহক প্ৰফাইল বনাওক, তাৰপিছত বিল সংযুক্ত কৰিবলৈ উভতি আহক।',
    gu: 'पहेला ग्राहक प्रोफाइल बनावो, पछी invoice जोडवा पाछा आवो.',
    ta: 'முதலில் ஒரு வாடிக்கையாளர் சுயவிவரத்தை உருவாக்கவும்.',
  );

  String get customersEmptySearchBody => _t(
    en: 'Try another name, or add this customer as a new profile.',
    hi: 'कोई और नाम आज़माएं, या इस ग्राहक को नई प्रोफ़ाइल के रूप में जोड़ें।',
    as_: 'আন এটা নাম চেষ্টা কৰক, বা এই গ্ৰাহকক নতুন প্ৰফাইল হিচাপে যোগ কৰক।',
    gu: 'बीजु नाम अजमावो, या आ ग्राहकने नवी profile तरीके उमेरो.',
    ta: 'மற்றொரு பெயரை முயற்சிக்கவும், அல்லது இந்த வாடிக்கையாளரை புதிய சுயவிவரமாக சேர்க்கவும்.',
  );

  String get customersAddButton => _t(
    en: 'Add Customer',
    hi: 'ग्राहक जोड़ें',
    as_: 'গ্ৰাহক যোগ কৰক',
    gu: 'ग्राहक ऊमेरो',
    ta: 'வாடிக்கையாளரை சேர்',
  );

  String customersReadyForBilling(String name) => _t(
    en: '$name is ready for billing.',
    hi: '$name बिलिंग के लिए तैयार है।',
    as_: '$name বিলিঙৰ বাবে সাজু।',
    gu: '$name बिलिंग माटे तैयार छे.',
    ta: '$name பில்லிங்கிற்கு தயாராக உள்ளது.',
  );

  // ── Customer Form ──────────────────────────────────────────────────────────

  String get customerFormTitleAdd => _t(
    en: 'Add Customer',
    hi: 'ग्राहक जोड़ें',
    as_: 'গ্ৰাহক যোগ কৰক',
    gu: 'ग्राहक ऊमेरो',
    ta: 'வாடிக்கையாளரை சேர்',
  );

  String get customerFormTitleEdit => _t(
    en: 'Edit Customer',
    hi: 'ग्राहक संपादित करें',
    as_: 'গ্ৰাহক সম্পাদনা কৰক',
    gu: 'ग्राहक संपादित करो',
    ta: 'வாடிக்கையாளரை திருத்து',
  );

  String get customerFormBadge => _t(
    en: 'Customer profile',
    hi: 'ग्राहक प्रोफ़ाइल',
    as_: 'গ্ৰাহকৰ প্ৰফাইল',
    gu: 'ग्राहक प्रोफाइल',
    ta: 'வாடிக்கையாளர் சுயவிவரம்',
  );

  String get customerFormSubtitleAdd => _t(
    en: 'Create a crisp customer profile for repeat billing, quick selection, and a calmer workflow.',
    hi: 'दोबारा बिलिंग, त्वरित चयन और बेहतर वर्कफ़्लो के लिए ग्राहक प्रोफ़ाइल बनाएं।',
    as_: 'পুনৰাবৃত্তি বিলিং, দ্ৰুত বাছনি আৰু সহজ কাৰ্যপ্ৰণালীৰ বাবে গ্ৰাহক প্ৰফাইল বনাওক।',
    gu: 'वारंवार बिलिंग माटे ग्राहक प्रोफाइल बनावो.',
    ta: 'மீண்டும் மீண்டும் பில்லிங், விரைவான தேர்வுக்கு வாடிக்கையாளர் சுயவிவரத்தை உருவாக்கவும்.',
  );

  String get customerFormSubtitleEdit => _t(
    en: 'Refresh the essentials for this customer so repeat billing stays quick and clean.',
    hi: 'इस ग्राहक की जानकारी अपडेट करें ताकि बार-बार बिलिंग तेज़ और आसान रहे।',
    as_: 'এই গ্ৰাহকৰ তথ্য আপডেট কৰক যাতে বিলিং দ্ৰুত থাকে।',
    gu: 'आ ग्राहक माटे जरूरी माहिती अपडेट करो.',
    ta: 'இந்த வாடிக்கையாளருக்கான அத்தியாவசியமானவற்றை புதுப்பிக்கவும்.',
  );

  String get customerFormNameLabel => _t(
    en: 'Customer Name',
    hi: 'ग्राहक का नाम',
    as_: 'গ্ৰাহকৰ নাম',
    gu: 'ग्राहकनुं नाम',
    ta: 'வாடிக்கையாளர் பெயர்',
  );

  String get customerFormNameRequired => _t(
    en: 'Required',
    hi: 'आवश्यक',
    as_: 'আৱশ্যকীয়',
    gu: 'जरूरी',
    ta: 'தேவையான',
  );

  String get customerFormNameError => _t(
    en: 'Enter customer name',
    hi: 'ग्राहक का नाम दर्ज करें',
    as_: 'গ্ৰাহকৰ নাম দিয়ক',
    gu: 'ग्राहकनुं नाम दाखल करो',
    ta: 'வாடிக்கையாளர் பெயரை உள்ளிடவும்',
  );

  String get customerFormPhoneLabel => _t(
    en: 'Phone Number',
    hi: 'फोन नंबर',
    as_: 'ফোন নম্বৰ',
    gu: 'ফोन नंबर',
    ta: 'தொலைபேசி எண்',
  );

  String get customerFormAddressLabel => _t(
    en: 'Address',
    hi: 'पता',
    as_: 'ঠিকনা',
    gu: 'સरनामुं',
    ta: 'முகவரி',
  );

  String get customerFormOptionalHint => _t(
    en: 'Optional',
    hi: 'वैकल्पिक',
    as_: 'ঐচ্ছিক',
    gu: 'वैकल्पिक',
    ta: 'விருப்பமான',
  );

  String get customerFormSaving => _t(
    en: 'Saving Customer...',
    hi: 'ग्राहक सहेजा जा रहा है...',
    as_: 'গ্ৰাহক সংৰক্ষণ হৈ আছে...',
    gu: 'ग्राहक सहेजाई रह्युं छे...',
    ta: 'வாடிக்கையாளர் சேமிக்கப்படுகிறார்...',
  );

  String get customerFormSaveChanges => _t(
    en: 'Save Changes',
    hi: 'बदलाव सहेजें',
    as_: 'পৰিৱৰ্তন সংৰক্ষণ কৰক',
    gu: 'ফेरफार सहेजो',
    ta: 'மாற்றங்களை சேமி',
  );

  String get customerFormCreate => _t(
    en: 'Create Customer',
    hi: 'ग्राहक बनाएं',
    as_: 'গ্ৰাহক বনাওক',
    gu: 'ग्राहक बनावो',
    ta: 'வாடிக்கையாளரை உருவாக்கு',
  );

  String customerFormFailedSave(String error) => _t(
    en: 'Failed to save customer: $error',
    hi: 'ग्राहक सहेजना विफल: $error',
    as_: 'গ্ৰাহক সংৰক্ষণ বিফল: $error',
    gu: 'ग्राहक सहेजवामां निष्फळ: $error',
    ta: 'வாடிக்கையாளரை சேமிப்பதில் தோல்வி: $error',
  );

  // ── Customer Details ───────────────────────────────────────────────────────

  String get customerDetailsTitle => _t(
    en: 'Customer Profile',
    hi: 'ग्राहक प्रोफ़ाइल',
    as_: 'গ্ৰাহকৰ প্ৰফাইল',
    gu: 'ग्राहक प्रोफाइल',
    ta: 'வாடிக்கையாளர் சுயவிவரம்',
  );

  String get customerDetailsEditTooltip => _t(
    en: 'Edit customer',
    hi: 'ग्राहक संपादित करें',
    as_: 'গ্ৰাহক সম্পাদনা কৰক',
    gu: 'ग्राहक संपादित करो',
    ta: 'வாடிக்கையாளரை திருத்து',
  );

  String get customerDetailsCreateInvoice => _t(
    en: 'Create Invoice for This Customer',
    hi: 'इस ग्राहक के लिए इनवॉइस बनाएं',
    as_: 'এই গ্ৰাহকৰ বাবে বিল বনাওক',
    gu: 'आ ग्राहक माटे invoice बनावो',
    ta: 'இந்த வாடிக்கையாளருக்கு விலைப்பட்டியல் உருவாக்கு',
  );

  String get customerDetailsStatInvoices => _t(
    en: 'Invoices',
    hi: 'इनवॉइस',
    as_: 'বিলসমূহ',
    gu: 'ઇन्वॉइस',
    ta: 'விலைப்பட்டியல்கள்',
  );

  String get customerDetailsStatTotalBilled => _t(
    en: 'Total Billed',
    hi: 'कुल बिल',
    as_: 'মুঠ বিল',
    gu: 'कुल बिल',
    ta: 'மொத்த கட்டணம்',
  );

  String get customerDetailsStatOutstanding => _t(
    en: 'Outstanding',
    hi: 'बकाया',
    as_: 'বাকী',
    gu: 'बाकी',
    ta: 'நிலுவையில்',
  );

  String get customerDetailsContact => _t(
    en: 'Contact Details',
    hi: 'संपर्क विवरण',
    as_: 'যোগাযোগৰ বিৱৰণ',
    gu: 'संपर्क विगत',
    ta: 'தொடர்பு விவரங்கள்',
  );

  String get customerDetailsPhone => _t(
    en: 'Phone',
    hi: 'फोन',
    as_: 'ফোন',
    gu: 'ফोन',
    ta: 'தொலைபேசி',
  );

  String get customerDetailsEmail => _t(
    en: 'Email',
    hi: 'ईमेल',
    as_: 'ইমেইল',
    gu: 'ઈ-مेइल',
    ta: 'மின்னஞ்சல்',
  );

  String get customerDetailsAddress => _t(
    en: 'Address',
    hi: 'पता',
    as_: 'ঠিকনা',
    gu: 'સरनामुं',
    ta: 'முகவரி',
  );

  String get customerDetailsNotAdded => _t(
    en: 'Not added yet',
    hi: 'अभी नहीं जोड़ा',
    as_: 'এতিয়াও যোগ কৰা নাই',
    gu: 'हजु ऊमेरायुं नथी',
    ta: 'இன்னும் சேர்க்கப்படவில்லை',
  );

  String get customerDetailsNotes => _t(
    en: 'Notes',
    hi: 'नोट्स',
    as_: 'টোকাসমূহ',
    gu: 'नोंध',
    ta: 'குறிப்புகள்',
  );

  String get customerDetailsHistory => _t(
    en: 'Invoice History',
    hi: 'इनवॉइस इतिहास',
    as_: 'বিলৰ ইতিহাস',
    gu: 'ઇन्वॉइस इतिहास',
    ta: 'விலைப்பட்டியல் வரலாறு',
  );

  String get customerDetailsHistoryError => _t(
    en: 'Unable to load this customer\'s invoices right now.',
    hi: 'इस ग्राहक के इनवॉइस अभी लोड नहीं हो सके।',
    as_: 'এই গ্ৰাহকৰ বিলসমূহ এতিয়া লোড হোৱা নাই।',
    gu: 'अत्यारे आ ग्राहकना invoice लोड नथी थता.',
    ta: 'இப்போது இந்த வாடிக்கையாளரின் விலைப்பட்டியல்களை ஏற்ற முடியவில்லை.',
  );

  String get customerDetailsHistoryEmpty => _t(
    en: 'No invoices linked to this customer yet. Create the first one to start their billing history.',
    hi: 'अभी इस ग्राहक से कोई इनवॉइस नहीं जुड़ा। पहला इनवॉइस बनाएं।',
    as_: 'এই গ্ৰাহকৰ লগত এতিয়াও কোনো বিল নাই। প্ৰথমটো বনাওক।',
    gu: 'हजु आ ग्राहक साथे कोई invoice जोडायुं नथी. पहेलुं बनावो.',
    ta: 'இன்னும் இந்த வாடிக்கையாளருடன் எந்த விலைப்பட்டியலும் இணைக்கப்படவில்லை.',
  );

  String customerDetailsLastUpdated(String date) => _t(
    en: 'Last updated $date',
    hi: '$date को अंतिम अपडेट',
    as_: '$date-ত শেষবাৰ আপডেট কৰা হ\'ল',
    gu: '$date ना रोज छेल्लुं अपडेट',
    ta: 'கடைசியாக $date புதுப்பிக்கப்பட்டது',
  );

  // ── Invoice Card actions ───────────────────────────────────────────────────

  String get cardMarkPaid => _t(
    en: 'Mark as Paid',
    hi: 'भुगतान किया गया',
    as_: 'পৰিশোধ হিচাপে চিহ্নিত কৰক',
    gu: 'ચૂকवेल तरीके मार्क करो',
    ta: 'பணம் செலுத்தப்பட்டதாக குறி',
  );

  String get cardMarkOverdue => _t(
    en: 'Mark as Overdue',
    hi: 'अतिदेय चिह्नित करें',
    as_: 'মিয়াদ পাৰ হিচাপে চিহ্নিত কৰক',
    gu: 'मुदत वीती तरीके मार्क करो',
    ta: 'தாமதமானதாக குறி',
  );

  String get cardDelete => _t(
    en: 'Delete',
    hi: 'हटाएं',
    as_: 'মচক',
    gu: 'ডिلीट करो',
    ta: 'நீக்கு',
  );

  // ── Customers extra ────────────────────────────────────────────────────────

  String get customersManageGroupsTooltip => _t(
    en: 'Manage groups',
    hi: 'ग्रुप प्रबंधित करें',
    as_: 'গ্ৰুপ পৰিচালনা কৰক',
    gu: 'ग्रुप मैनेज करो',
    ta: 'குழுக்களை நிர்வகி',
  );

  String get customersSearchTooltip => _t(
    en: 'Search customers',
    hi: 'ग्राहक खोजें',
    as_: 'গ্ৰাহক বিচাৰক',
    gu: 'ग्राहको शोधो',
    ta: 'வாடிக்கையாளர்களை தேடு',
  );

  String get customersGroupsLabel => _t(
    en: 'Customer Groups',
    hi: 'ग्राहक ग्रुप',
    as_: 'গ্ৰাহকৰ গ্ৰুপ',
    gu: 'ग्राहक ग्रुप',
    ta: 'வாடிக்கையாளர் குழுக்கள்',
  );

  String get customersManage => _t(
    en: 'Manage',
    hi: 'प्रबंधित करें',
    as_: 'পৰিচালনা কৰক',
    gu: 'मैनेज करो',
    ta: 'நிர்வகி',
  );

  String get customersAll => _t(
    en: 'All',
    hi: 'सभी',
    as_: 'সকলো',
    gu: 'बधा',
    ta: 'அனைத்தும்',
  );

  String get customersUngrouped => _t(
    en: 'Ungrouped',
    hi: 'बिना ग्रुप',
    as_: 'গ্ৰুপবিহীন',
    gu: 'ग्रुप विना',
    ta: 'குழு இல்லாதவர்',
  );

  String get customersSelected => _t(
    en: 'Selected',
    hi: 'चुना गया',
    as_: 'বাছি লোৱা হ\'ল',
    gu: 'पसंद करायुं',
    ta: 'தேர்ந்தெடுக்கப்பட்டது',
  );

  String get customersMoveToGroup => _t(
    en: 'Move to Group',
    hi: 'ग्रुप में ले जाएं',
    as_: 'গ্ৰুপলৈ লৈ যাওক',
    gu: 'ग्रुपमां ले जावो',
    ta: 'குழுவிற்கு நகர்த்து',
  );

  String get customersChangeGroup => _t(
    en: 'Change Group',
    hi: 'ग्रुप बदलें',
    as_: 'গ্ৰুপ সলনি কৰক',
    gu: 'ग्रुप बदलो',
    ta: 'குழுவை மாற்று',
  );

  String customersCurrentGroup(String name) => _t(
    en: 'Current group: $name',
    hi: 'वर्तमान ग्रुप: $name',
    as_: 'বৰ্তমান গ্ৰুপ: $name',
    gu: 'वर्तमान ग्रुप: $name',
    ta: 'தற்போதைய குழு: $name',
  );

  String get customersNoGroupSubtitle => _t(
    en: 'Assign this customer to a group after creation.',
    hi: 'बनाने के बाद इस ग्राहक को ग्रुप में रखें।',
    as_: 'বনোৱাৰ পিছত এই গ্ৰাহকক এটা গ্ৰুপত ৰাখক।',
    gu: 'बनाव्या बाद आ ग्राहकने ग्रुपमां मुको.',
    ta: 'உருவாக்கிய பிறகு இந்த வாடிக்கையாளரை ஒரு குழுவில் சேர்க்கவும்.',
  );

  String get customersDeleteTitle => _t(
    en: 'Delete Customer',
    hi: 'ग्राहक हटाएं',
    as_: 'গ্ৰাহক মচক',
    gu: 'ग्राहक डिलीट करो',
    ta: 'வாடிக்கையாளரை நீக்கு',
  );

  String customersDeleteConfirm(String name) => _t(
    en: 'Delete $name from your customer list? Invoices already created for this customer will stay saved.',
    hi: '$name को हटाएं? इस ग्राहक के इनवॉइस सुरक्षित रहेंगे।',
    as_: '$name মচিব? এই গ্ৰাহকৰ বিলসমূহ সংৰক্ষিত থাকিব।',
    gu: '$name ने ग्राहक यादीमांथी डिलीट करो? आ ग्राहकना invoice सुरक्षित रहेशे.',
    ta: '$name ஐ வாடிக்கையாளர் பட்டியலிலிருந்து நீக்கவா? ஏற்கனவே உருவாக்கிய விலைப்பட்டியல்கள் சேமிக்கப்படும்.',
  );

  String get customersCancel => _t(
    en: 'Cancel',
    hi: 'रद्द करें',
    as_: 'বাতিল কৰক',
    gu: 'ரद्द करो',
    ta: 'ரத்து செய்',
  );

  String get customersDelete => _t(
    en: 'Delete',
    hi: 'हटाएं',
    as_: 'মচক',
    gu: 'डिलीट करो',
    ta: 'நீக்கு',
  );

  String get customersDeleteSubtitle => _t(
    en: 'Invoices stay saved, but this customer profile will be removed.',
    hi: 'इनवॉइस सुरक्षित रहेंगे, लेकिन ग्राहक प्रोफ़ाइल हटा दी जाएगी।',
    as_: 'বিলসমূহ সংৰক্ষিত থাকিব, কিন্তু গ্ৰাহক প্ৰফাইল আঁতৰোৱা হ\'ব।',
    gu: 'Invoice सुरक्षित रहेशे, पण ग्राहक profile दूर थशे.',
    ta: 'விலைப்பட்டியல்கள் சேமிக்கப்படும், ஆனால் இந்த வாடிக்கையாளர் சுயவிவரம் அகற்றப்படும்.',
  );

  String customersNowUngrouped(String name) => _t(
    en: '$name is now ungrouped.',
    hi: '$name अब किसी ग्रुप में नहीं है।',
    as_: '$name এতিয়া গ্ৰুপবিহীন।',
    gu: '$name हवे ग्रुप विना छे.',
    ta: '$name இப்போது குழு இல்லாமல் உள்ளது.',
  );

  String customersMovedToGroup(String name, String group) => _t(
    en: '$name moved to $group.',
    hi: '$name को $group में ले जाया गया।',
    as_: '$name $group-লৈ স্থানান্তৰিত হ\'ল।',
    gu: '$name ने $group मां ले जवायो.',
    ta: '$name $group க்கு நகர்த்தப்பட்டது.',
  );

  String customersFailedUpdateGroup(String error) => _t(
    en: 'Failed to update customer group: $error',
    hi: 'ग्राहक ग्रुप अपडेट विफल: $error',
    as_: 'গ্ৰাহক গ্ৰুপ আপডেট বিফল: $error',
    gu: 'ग्राहक ग्रुप अपडेट निष्फळ: $error',
    ta: 'வாடிக்கையாளர் குழுவை புதுப்பிப்பதில் தோல்வி: $error',
  );

  String customersDeletedCustomer(String name) => _t(
    en: '$name was deleted.',
    hi: '$name हटा दिया गया।',
    as_: '$name মচা হ\'ল।',
    gu: '$name ने डिलीट करायो.',
    ta: '$name நீக்கப்பட்டது.',
  );

  String customersFailedDelete(String error) => _t(
    en: 'Failed to delete customer: $error',
    hi: 'ग्राहक हटाना विफल: $error',
    as_: 'গ্ৰাহক মচা বিফল: $error',
    gu: 'ग्राहक डिलीट निष्फळ: $error',
    ta: 'வாடிக்கையாளரை நீக்குவதில் தோல்வி: $error',
  );

  String get customersGroupsError => _t(
    en: 'Groups are unavailable right now, but customers are still accessible.',
    hi: 'ग्रुप अभी उपलब्ध नहीं, लेकिन ग्राहक दिख रहे हैं।',
    as_: 'গ্ৰুপসমূহ এতিয়া উপলব্ধ নহয়, কিন্তু গ্ৰাহকসমূহ চাব পাৰিব।',
    gu: 'ग्रुप अत्यारे उपलब्ध नथी, पण ग्राहको जोई शकाशे.',
    ta: 'குழுக்கள் இப்போது கிடைக்கவில்லை, ஆனால் வாடிக்கையாளர்கள் இன்னும் அணுகலாம்.',
  );

  String get customersEmptyGroupTitle => _t(
    en: 'No customers in this group yet.',
    hi: 'इस ग्रुप में अभी कोई ग्राहक नहीं।',
    as_: 'এই গ্ৰুপত এতিয়াও কোনো গ্ৰাহক নাই।',
    gu: 'आ ग्रुपमां हजु कोई ग्राहक नथी.',
    ta: 'இந்த குழுவில் இன்னும் வாடிக்கையாளர்கள் இல்லை.',
  );

  String get customersEmptyGroupBody => _t(
    en: 'Pick another group, or move a customer into this one after creating them.',
    hi: 'कोई और ग्रुप चुनें, या नया ग्राहक बनाने के बाद यहाँ रखें।',
    as_: 'আন এটা গ্ৰুপ বাছক, বা নতুন গ্ৰাহক বনোৱাৰ পিছত এই গ্ৰুপলৈ স্থানান্তৰিত কৰক।',
    gu: 'बीजो ग्रुप पसंद करो, या नवो ग्राहक बनाव्या बाद आ ग्रुपमां मुको.',
    ta: 'மற்றொரு குழுவை தேர்ந்தெடுக்கவும், அல்லது ஒரு வாடிக்கையாளரை உருவாக்கிய பிறகு இதில் நகர்த்தவும்.',
  );

  // ── Customer Details extra ─────────────────────────────────────────────────

  String get customerDetailsGroup => _t(
    en: 'Group',
    hi: 'ग्रुप',
    as_: 'গ্ৰুপ',
    gu: 'ग्रुप',
    ta: 'குழு',
  );

  String get customerDetailsMoveGroup => _t(
    en: 'Move to group',
    hi: 'ग्रुप में ले जाएं',
    as_: 'গ্ৰুপলৈ লৈ যাওক',
    gu: 'ग्रुपमां ले जावो',
    ta: 'குழுவிற்கு நகர்த்து',
  );

  String get customerDetailsChangeGroup => _t(
    en: 'Change group',
    hi: 'ग्रुप बदलें',
    as_: 'গ্ৰুপ সলনি কৰক',
    gu: 'ग्रुप बदलो',
    ta: 'குழுவை மாற்று',
  );

  String customerDetailsNowUngrouped(String name) => _t(
    en: '$name is now ungrouped.',
    hi: '$name अब किसी ग्रुप में नहीं है।',
    as_: '$name এতিয়া গ্ৰুপবিহীন।',
    gu: '$name हवे ग्रुप विना छे.',
    ta: '$name இப்போது குழு இல்லாமல் உள்ளது.',
  );

  String customerDetailsMovedToGroup(String name, String group) => _t(
    en: '$name moved to $group.',
    hi: '$name को $group में ले जाया गया।',
    as_: '$name $group-লৈ স্থানান্তৰিত হ\'ল।',
    gu: '$name ने $group मां ले जवायो.',
    ta: '$name $group க்கு நகர்த்தப்பட்டது.',
  );

  String customerDetailsFailedUpdateGroup(String error) => _t(
    en: 'Failed to update customer group: $error',
    hi: 'ग्राहक ग्रुप अपडेट विफल: $error',
    as_: 'গ্ৰাহক গ্ৰুপ আপডেট বিফল: $error',
    gu: 'ग्राहक ग्रुप अपडेट निष्फळ: $error',
    ta: 'வாடிக்கையாளர் குழுவை புதுப்பிப்பதில் தோல்வி: $error',
  );

  // ── Customer Groups Sheet ──────────────────────────────────────────────────

  String get groupsTitle => _t(
    en: 'Customer Groups',
    hi: 'ग्राहक ग्रुप',
    as_: 'গ্ৰাহকৰ গ্ৰুপ',
    gu: 'ग्राहक ग्रुप',
    ta: 'வாடிக்கையாளர் குழுக்கள்',
  );

  String get groupsSubtitle => _t(
    en: 'Create simple groups like Group A, VIP, or Batch B, and rename them any time.',
    hi: 'Group A, VIP या Batch B जैसे ग्रुप बनाएं, जिन्हें कभी भी नाम बदला जा सकता है।',
    as_: 'Group A, VIP বা Batch B-ৰ দৰে গ্ৰুপ বনাওক, যিকোনো সময়তে নাম সলনি কৰক।',
    gu: 'Group A, VIP या Batch B जेवा ग्रुप बनावो, ज्यारे पण नाम बदली शकाय.',
    ta: 'Group A, VIP, அல்லது Batch B போன்ற எளிய குழுக்களை உருவாக்கவும்.',
  );

  String get groupsAdd => _t(
    en: 'Add',
    hi: 'जोड़ें',
    as_: 'যোগ কৰক',
    gu: 'ऊमेरो',
    ta: 'சேர்',
  );

  String get groupsLoadError => _t(
    en: 'Unable to load groups right now.',
    hi: 'अभी ग्रुप लोड नहीं हो सके।',
    as_: 'এতিয়া গ্ৰুপসমূহ লোড হোৱা নাই।',
    gu: 'अत्यारे ग्रुप लोड नथी थता.',
    ta: 'இப்போது குழுக்களை ஏற்ற முடியவில்லை.',
  );

  String get groupsEmpty => _t(
    en: 'No groups yet. Create one to organize customers faster.',
    hi: 'अभी कोई ग्रुप नहीं। तेज़ बिलिंग के लिए एक ग्रुप बनाएं।',
    as_: 'এতিয়াও কোনো গ্ৰুপ নাই। দ্ৰুত বিলিঙৰ বাবে এটা বনাওক।',
    gu: 'हजु कोई ग्रुप नथी. ग्राहको व्यवस्थित करवा एक बनावो.',
    ta: 'இன்னும் குழுக்கள் இல்லை. வாடிக்கையாளர்களை வேகமாக ஒழுங்கமைக்க ஒன்றை உருவாக்குங்கள்.',
  );

  String get groupsRenameHint => _t(
    en: 'Tap edit to rename this group.',
    hi: 'नाम बदलने के लिए संपादन दबाएं।',
    as_: 'নাম সলনি কৰিবলৈ সম্পাদনা টিপক।',
    gu: 'नाम बदलवा edit दबावो.',
    ta: 'இந்த குழுவை மறுபெயரிட திருத்தவும் தட்டவும்.',
  );

  String get groupsRenameTooltip => _t(
    en: 'Rename group',
    hi: 'ग्रुप का नाम बदलें',
    as_: 'গ্ৰুপৰ নাম সলনি কৰক',
    gu: 'ग्रुप नाम बदलो',
    ta: 'குழுவை மறுபெயரிடு',
  );

  String get groupsAddTitle => _t(
    en: 'Add Group',
    hi: 'ग्रुप जोड़ें',
    as_: 'গ্ৰুপ যোগ কৰক',
    gu: 'ग्रुप ऊमेरो',
    ta: 'குழுவை சேர்',
  );

  String get groupsRenameTitle => _t(
    en: 'Rename Group',
    hi: 'ग्रुप नाम बदलें',
    as_: 'গ্ৰুপৰ নাম সলনি কৰক',
    gu: 'ग्रुप नाम बदलो',
    ta: 'குழுவை மறுபெயரிடு',
  );

  String get groupsNameLabel => _t(
    en: 'Group Name',
    hi: 'ग्रुप का नाम',
    as_: 'গ্ৰুপৰ নাম',
    gu: 'ग्रुप नाम',
    ta: 'குழு பெயர்',
  );

  String get groupsNameHint => _t(
    en: 'For example: Group A',
    hi: 'जैसे: Group A',
    as_: 'যেনে: Group A',
    gu: 'जेम के: Group A',
    ta: 'எடுத்துக்காட்டு: Group A',
  );

  String get groupsCancel => _t(
    en: 'Cancel',
    hi: 'रद्द करें',
    as_: 'বাতিল কৰক',
    gu: 'ரद्द करो',
    ta: 'ரத்து செய்',
  );

  String get groupsSaving => _t(
    en: 'Saving...',
    hi: 'सहेजा जा रहा है...',
    as_: 'সংৰক্ষণ হৈ আছে...',
    gu: 'सहेजाई रह्युं छे...',
    ta: 'சேமிக்கப்படுகிறது...',
  );

  String get groupsSave => _t(
    en: 'Save',
    hi: 'सहेजें',
    as_: 'সংৰক্ষণ কৰক',
    gu: 'सहेजो',
    ta: 'சேமி',
  );

  String groupsFailedSave(String error) => _t(
    en: 'Failed to save group: $error',
    hi: 'ग्रुप सहेजना विफल: $error',
    as_: 'গ্ৰুপ সংৰক্ষণ বিফল: $error',
    gu: 'ग्रुप सहेजवामां निष्फळ: $error',
    ta: 'குழுவை சேமிப்பதில் தோல்வி: $error',
  );

  String get groupsPickerTitle => _t(
    en: 'Move Customer to Group',
    hi: 'ग्राहक को ग्रुप में ले जाएं',
    as_: 'গ্ৰাহকক গ্ৰুপলৈ লৈ যাওক',
    gu: 'ग्राहकने ग्रुपमां ले जावो',
    ta: 'வாடிக்கையாளரை குழுவிற்கு நகர்த்து',
  );

  String get groupsPickerSubtitle => _t(
    en: 'Pick a group for this customer, or leave them ungrouped.',
    hi: 'इस ग्राहक के लिए एक ग्रुप चुनें, या बिना ग्रुप के छोड़ें।',
    as_: 'এই গ্ৰাহকৰ বাবে এটা গ্ৰুপ বাছক, বা গ্ৰুপবিহীন ৰাখক।',
    gu: 'आ ग्राहक माटे ग्रुप पसंद करो, या ग्रुप विना छोडो.',
    ta: 'இந்த வாடிக்கையாளருக்கு ஒரு குழுவை தேர்ந்தெடுக்கவும்.',
  );

  String get groupsManage => _t(
    en: 'Manage',
    hi: 'प्रबंधित करें',
    as_: 'পৰিচালনা কৰক',
    gu: 'मैनेज करो',
    ta: 'நிர்வகி',
  );

  String get groupsUngrouped => _t(
    en: 'Ungrouped',
    hi: 'बिना ग्रुप',
    as_: 'গ্ৰুপবিহীন',
    gu: 'ग्रुप विना',
    ta: 'குழு இல்லாதவர்',
  );

  String get groupsUngroupedSubtitle => _t(
    en: 'Keep this customer outside any group for now.',
    hi: 'इस ग्राहक को अभी किसी ग्रुप में न रखें।',
    as_: 'এই গ্ৰাহকক এতিয়া কোনো গ্ৰুপত নাৰাখক।',
    gu: 'आ ग्राहकने अत्यारे कोई ग्रुपमां ना मुको.',
    ta: 'இந்த வாடிக்கையாளரை இப்போது எந்த குழுவிலும் சேர்க்காதீர்கள்.',
  );

  String get groupsPickerEmpty => _t(
    en: 'No groups yet. Use Manage to create your first one.',
    hi: 'अभी कोई ग्रुप नहीं। पहला ग्रुप बनाने के लिए Manage दबाएं।',
    as_: 'এতিয়াও কোনো গ্ৰুপ নাই। প্ৰথমটো বনাবলৈ পৰিচালনা কৰক।',
    gu: 'हजु कोई ग्रुप नथी. पहेलुं बनाववा Manage दबावो.',
    ta: 'இன்னும் குழுக்கள் இல்லை. முதல் குழுவை உருவாக்க Manage ஐ பயன்படுத்துங்கள்.',
  );

  String groupsMoveInto(String name) => _t(
    en: 'Move this customer into $name.',
    hi: 'इस ग्राहक को $name में ले जाएं।',
    as_: 'এই গ্ৰাহকক $name-লৈ লৈ যাওক।',
    gu: 'आ ग्राहकने $name मां ले जावो.',
    ta: 'இந்த வாடிக்கையாளரை $name க்கு நகர்த்துங்கள்.',
  );

  // ── Misc ──────────────────────────────────────────────────────────────────

  String get homeDateApply => _t(
    en: 'Apply',
    hi: 'लागू करें',
    as_: 'প্ৰয়োগ কৰক',
    gu: 'लागु करो',
    ta: 'பொருந்து',
  );

  String get detailsYourStore => _t(
    en: 'Your Store',
    hi: 'आपकी दुकान',
    as_: 'আপোনাৰ দোকান',
    gu: 'तमारी दुकान',
    ta: 'உங்கள் கடை',
  );

  String get drawerMyProfileFallback => _t(
    en: 'My Profile',
    hi: 'मेरी प्रोफ़ाइल',
    as_: 'মোৰ প্ৰফাইল',
    gu: 'मारी प्रोफाइल',
    ta: 'என் சுயவிவரம்',
  );

  // ── Dashboard (Stitch redesign) ───────────────────────────────────────────

  String get homeTitle => _t(
    en: 'Dashboard',
    hi: 'डैशबोर्ड',
    as_: 'ডেশব\'ৰ্ড',
    gu: 'ડेशबोर्ड',
    ta: 'டாஷ்போர்டு',
  );

  String get homeMonthlyRevenue => _t(
    en: 'Monthly Revenue',
    hi: 'मासिक आय',
    as_: 'মাহেকীয়া আয়',
    gu: 'मासिक आवक',
    ta: 'மாதாந்திர வருவாய்',
  );

  String get homeQuickActions => _t(
    en: 'Quick Actions',
    hi: 'त्वरित कार्य',
    as_: 'দ্ৰুত কাৰ্য',
    gu: 'ઝडपी कार्य',
    ta: 'விரைவு செயல்கள்',
  );

  String get homeCreateInvoice => _t(
    en: 'Create Invoice',
    hi: 'चालान बनाएं',
    as_: 'বিল তৈয়াৰ কৰক',
    gu: 'ઇन्वॉइस बनावो',
    ta: 'விலைப்பட்டியல் உருவாக்கு',
  );

  String get homeAddClient => _t(
    en: 'Add Client',
    hi: 'ग्राहक जोड़ें',
    as_: 'গ্ৰাহক যোগ কৰক',
    gu: 'ग्राहक ऊमेरो',
    ta: 'வாடிக்கையாளரை சேர்',
  );

  String get homeRecentInvoices => _t(
    en: 'Recent Invoices',
    hi: 'हाल के चालान',
    as_: 'শেহতীয়া বিলসমূহ',
    gu: 'हालना ઇन्वॉइस',
    ta: 'சமீபத்திய விலைப்பட்டியல்கள்',
  );

  String get homeBottomHome => _t(
    en: 'Home',
    hi: 'होम',
    as_: 'হোম',
    gu: 'होम',
    ta: 'முகப்பு',
  );
  String get homeBottomInvoices => _t(
    en: 'Invoices',
    hi: 'चालान',
    as_: 'বিলসমূহ',
    gu: 'ઇन्वॉइस',
    ta: 'விலைப்பட்டியல்கள்',
  );
  String get homeBottomClients => _t(
    en: 'Customers',
    hi: 'ग्राहक',
    as_: 'গ্ৰাহক',
    gu: 'ग्राहको',
    ta: 'வாடிக்கையாளர்கள்',
  );
  String get homeBottomProducts => _t(
    en: 'Products',
    hi: 'उत्पाद',
    as_: 'সামগ্ৰী',
    gu: 'ઉत्पादनो',
    ta: 'தயாரிப்புகள்',
  );
  String get homeBottomSettings => _t(
    en: 'Settings',
    hi: 'सेटिंग',
    as_: 'ছেটিং',
    gu: 'સेटिंग्स',
    ta: 'அமைப்புகள்',
  );

  String get homeViewAll => _t(
    en: 'View All',
    hi: 'सभी देखें',
    as_: 'সকলো চাওক',
    gu: 'बधा जुवो',
    ta: 'அனைத்தையும் பார்',
  );

  String get invoicesScreenTitle => _t(
    en: 'Invoices',
    hi: 'चालान',
    as_: 'বিলসমূহ',
    gu: 'ઇन्वॉइस',
    ta: 'விலைப்பட்டியல்கள்',
  );

  // ── GST Report ─────────────────────────────────────────────────────────────

  String get gstReportTitle => _t(
    en: 'GST Report',
    hi: 'GST रिपोर्ट',
    as_: 'GST প্ৰতিবেদন',
    gu: 'GST રিपोर्ट',
    ta: 'GST அறிக்கை',
  );

  String get gstReportSubtitle => _t(
    en: 'Tax collection summary for your business',
    hi: 'आपके व्यवसाय की कर संग्रह सारांश',
    as_: 'আপোনাৰ ব্যৱসায়ৰ কৰ সংগ্ৰহৰ সাৰাংশ',
    gu: 'तमारा व्यापारना कर संग्रहनो सारांश',
    ta: 'உங்கள் வணிகத்திற்கான வரி சேகரிப்பு சுருக்கம்',
  );

  String get gstReportPeriodLabel => _t(
    en: 'Period',
    hi: 'अवधि',
    as_: 'সময়কাল',
    gu: 'समयगाळो',
    ta: 'காலம்',
  );

  String get gstReportMonthly => _t(
    en: 'Monthly',
    hi: 'मासिक',
    as_: 'মাহেকীয়া',
    gu: 'मासिक',
    ta: 'மாதாந்திர',
  );

  String get gstReportQuarterly => _t(
    en: 'Quarterly',
    hi: 'त्रैमासिक',
    as_: 'ত্ৰৈমাসিক',
    gu: 'ત्रैमासिक',
    ta: 'காலாண்டு',
  );

  String get gstReportYearly => _t(
    en: 'Yearly',
    hi: 'वार्षिक',
    as_: 'বাৰ্ষিক',
    gu: 'वार्षिक',
    ta: 'வருடாந்திர',
  );

  String get gstReportTaxableAmount => _t(
    en: 'Taxable Amount',
    hi: 'कर योग्य राशि',
    as_: 'করযোগ্য পৰিমাণ',
    gu: 'करपात्र रकम',
    ta: 'வரிக்குட்பட்ட தொகை',
  );

  String get gstReportTotalCgst => _t(
    en: 'Total CGST',
    hi: 'कुल CGST',
    as_: 'মুঠ CGST',
    gu: 'कुल CGST',
    ta: 'மொத்த CGST',
  );

  String get gstReportTotalSgst => _t(
    en: 'Total SGST',
    hi: 'कुल SGST',
    as_: 'মুঠ SGST',
    gu: 'कुल SGST',
    ta: 'மொத்த SGST',
  );

  String get gstReportTotalIgst => _t(
    en: 'Total IGST',
    hi: 'कुल IGST',
    as_: 'মুঠ IGST',
    gu: 'कुल IGST',
    ta: 'மொத்த IGST',
  );

  String get gstReportTotalTax => _t(
    en: 'Total Tax Collected',
    hi: 'कुल कर संग्रहित',
    as_: 'মুঠ কৰ সংগ্ৰহ',
    gu: 'कुल कर संग्रह',
    ta: 'மொத்த வரி வசூல்',
  );

  String get gstReportInvoiceBreakdown => _t(
    en: 'Invoice-wise Breakdown',
    hi: 'इनवॉइस-वार विवरण',
    as_: 'বিল অনুযায়ী বিৱৰণ',
    gu: 'invoice मुजब विगत',
    ta: 'விலைப்பட்டியல் வாரியான விரிவாக்கம்',
  );

  String get gstReportNoInvoices => _t(
    en: 'No GST invoices found for this period',
    hi: 'इस अवधि में कोई GST इनवॉइस नहीं मिला',
    as_: 'এই সময়কালত কোনো GST বিল পোৱা নগ\'ল',
    gu: 'आ समयगाळामां कोई GST invoice मळ्यो नहीं',
    ta: 'இந்த காலகட்டத்தில் GST விலைப்பட்டியல்கள் எதுவும் இல்லை',
  );

  String get gstReportShareReport => _t(
    en: 'Share Report',
    hi: 'रिपोर्ट साझा करें',
    as_: 'প্ৰতিবেদন শ্বেয়াৰ কৰক',
    gu: 'रिपोर्ट शेर करो',
    ta: 'அறிக்கையை பகிர்',
  );

  String get gstReportCgstSgst => _t(
    en: 'CGST + SGST',
    hi: 'CGST + SGST',
    as_: 'CGST + SGST',
    gu: 'CGST + SGST',
    ta: 'CGST + SGST',
  );

  String get gstReportIgst => _t(
    en: 'IGST',
    hi: 'IGST',
    as_: 'IGST',
    gu: 'IGST',
    ta: 'IGST',
  );

  String get gstReportIntrastate => _t(
    en: 'Intrastate (Same State)',
    hi: 'राज्य के भीतर',
    as_: 'ৰাজ্যৰ ভিতৰত',
    gu: 'राज्यमां (एज राज्य)',
    ta: 'மாநிலத்திற்குள் (அதே மாநிலம்)',
  );

  String get gstReportInterstate => _t(
    en: 'Interstate',
    hi: 'अंतरराज्यीय',
    as_: 'আন্তঃৰাজ্যিক',
    gu: 'आंतरराज्यीय',
    ta: 'மாநிலங்களுக்கு இடையே',
  );

  String gstReportInvoiceCount(int count) => _t(
    en: '$count invoice${count == 1 ? '' : 's'} with GST',
    hi: '$count GST इनवॉइस',
    as_: '$count GST বিল',
    gu: '$count GST ઇन्वॉइस',
    ta: '$count GST விலைப்பட்டியல்கள்',
  );

  String get gstReportSelectMonth => _t(
    en: 'Select Month',
    hi: 'महीना चुनें',
    as_: 'মাহ বাছক',
    gu: 'महिनो पसंद करो',
    ta: 'மாதத்தை தேர்ந்தெடு',
  );

  String get gstReportSelectQuarter => _t(
    en: 'Select Quarter',
    hi: 'तिमाही चुनें',
    as_: 'ত্ৰৈমাস বাছক',
    gu: 'ત्रिमास पसंद करो',
    ta: 'காலாண்டை தேர்ந்தெடு',
  );

  // ── Profile GSTIN ────────────────────────────────────────────────────────────

  String get profileGstinLabel => _t(
    en: 'GSTIN (optional)',
    hi: 'GSTIN (वैकल्पिक)',
    as_: 'GSTIN (ঐচ্ছিক)',
    gu: 'GSTIN (वैकल्पिक)',
    ta: 'GSTIN (விருப்பமான)',
  );

  String get profileGstinHint => _t(
    en: 'e.g. 22AAAAA0000A1Z5',
    hi: 'जैसे 22AAAAA0000A1Z5',
    as_: 'যেনে 22AAAAA0000A1Z5',
    gu: 'जेम के 22AAAAA0000A1Z5',
    ta: 'எ.கா. 22AAAAA0000A1Z5',
  );

  String get profileStateLabel => _t(
    en: 'State / UT',
    hi: 'राज्य / केंद्र शासित प्रदेश',
    as_: 'ৰাজ্য / কেন্দ্ৰশাসিত অঞ্চল',
    gu: 'राज्य / केन्द्र शासित प्रदेश',
    ta: 'மாநிலம் / யூ.டி.',
  );

  // ── Customer GSTIN ───────────────────────────────────────────────────────────

  String get customerGstinLabel => _t(
    en: 'Customer GSTIN (optional)',
    hi: 'ग्राहक GSTIN (वैकल्पिक)',
    as_: 'গ্ৰাহকৰ GSTIN (ঐচ্ছিক)',
    gu: 'ग्राहक GSTIN (वैकल्पिक)',
    ta: 'வாடிக்கையாளர் GSTIN (விருப்பமான)',
  );

  String get customerGstinHint => _t(
    en: 'For B2B invoices — helps customer claim ITC',
    hi: 'B2B इनवॉइस के लिए — ग्राहक ITC क्लेम कर सकेंगे',
    as_: 'B2B বিলৰ বাবে — গ্ৰাহকে ITC দাবী কৰিব পাৰিব',
    gu: 'B2B invoice माटे — ग्राहक ITC claim करी शकशे',
    ta: 'B2B விலைப்பட்டியல்களுக்கு — வாடிக்கையாளர் ITC கோர உதவுகிறது',
  );

  // ── HSN / SAC ───────────────────────────────────────────────────────────────

  String get hsnCodeLabel => _t(
    en: 'HSN / SAC Code (optional)',
    hi: 'HSN / SAC कोड (वैकल्पिक)',
    as_: 'HSN / SAC ক\'ড (ঐচ্ছিক)',
    gu: 'HSN / SAC कोड (वैकल्पिक)',
    ta: 'HSN / SAC குறியீடு (விருப்பமான)',
  );

  String get hsnCodeHint => _t(
    en: 'e.g. 6211 for goods, 998313 for services',
    hi: 'जैसे 6211 (वस्तु) या 998313 (सेवा)',
    as_: 'যেনে 6211 (সামগ্ৰী) বা 998313 (সেৱা)',
    gu: 'जेम के 6211 (वस्तु) या 998313 (सेवा)',
    ta: 'எ.கா. 6211 (பொருட்கள்), 998313 (சேவைகள்)',
  );

  // ── Purchase Orders ─────────────────────────────────────────────────────────

  String get drawerPurchases => _t(
    en: 'Purchases',
    hi: 'खरीद',
    as_: 'ক্ৰয়',
    gu: 'ખरीदी',
    ta: 'கொள்முதல்கள்',
  );

  String get purchasesTitle => _t(
    en: 'Purchase Orders',
    hi: 'खरीद आदेश',
    as_: 'ক্ৰয় আদেশ',
    gu: 'ખरीद आदेश',
    ta: 'கொள்முதல் ஆர்டர்கள்',
  );

  String get purchasesEmpty => _t(
    en: 'No purchase orders yet',
    hi: 'अभी कोई खरीद आदेश नहीं',
    as_: 'কোনো ক্ৰয় আদেশ নাই',
    gu: 'हजु कोई ખरीद आदेश नथी',
    ta: 'இன்னும் கொள்முதல் ஆர்டர்கள் இல்லை',
  );

  String get purchasesCreateFirst => _t(
    en: 'Create your first PO to track purchases',
    hi: 'खरीद ट्रैक करने के लिए पहला PO बनाएं',
    as_: 'প্ৰথম PO তৈয়াৰ কৰক',
    gu: 'ખरीदी ट्रैक करवा पहेलो PO बनावो',
    ta: 'கொள்முதல்களை கண்காணிக்க உங்கள் முதல் PO உருவாக்குங்கள்',
  );

  String get newPurchaseOrder => _t(
    en: 'New Purchase Order',
    hi: 'नया खरीद आदेश',
    as_: 'নতুন ক্ৰয় আদেশ',
    gu: 'नवो ખरीद आदेश',
    ta: 'புதிய கொள்முதல் ஆர்டர்',
  );

  String get markAsReceived => _t(
    en: 'Mark as Received',
    hi: 'प्राप्त के रूप में चिह्नित करें',
    as_: 'প্ৰাপ্ত হিচাপে চিহ্নিত কৰক',
    gu: 'प्राप्त तरीके मार्क करो',
    ta: 'பெறப்பட்டதாக குறி',
  );

  String get supplierName => _t(
    en: 'Supplier Name',
    hi: 'आपूर्तिकर्ता का नाम',
    as_: 'যোগানকাৰীৰ নাম',
    gu: 'पुरवठाकारनुं नाम',
    ta: 'சப்ளையர் பெயர்',
  );

  String get purchasePrice => _t(
    en: 'Purchase Price',
    hi: 'खरीद मूल्य',
    as_: 'ক্ৰয় মূল্য',
    gu: 'ખरीद मूल्य',
    ta: 'கொள்முதல் விலை',
  );
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
