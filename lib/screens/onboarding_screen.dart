import 'package:flutter/material.dart';
import 'package:billeasy/screens/language_selection_screen.dart';
import 'package:billeasy/theme/app_colors.dart';

// ── Localized strings ─────────────────────────────────────────────────────────

class _Strings {
  final String step1Badge;
  final String screen1Title;
  final String screen1Subtitle;
  final String feat1a;
  final String feat1b;
  final String feat1c;
  final String step2Badge;
  final String screen2Title;
  final String screen2Subtitle;
  final String feat2a;
  final String feat2b;
  final String feat2c;
  final String step3Badge;
  final String screen3Title;
  final String screen3Subtitle;
  final String feat3a;
  final String feat3b;
  final String feat3c;
  final String step4Badge;
  final String screen4Title;
  final String screen4Subtitle;
  final String feat4a;
  final String feat4b;
  final String feat4c;
  final String referralCode;
  final String skip;
  final String next;
  final String getStarted;

  const _Strings({
    required this.step1Badge,
    required this.screen1Title,
    required this.screen1Subtitle,
    required this.feat1a,
    required this.feat1b,
    required this.feat1c,
    required this.step2Badge,
    required this.screen2Title,
    required this.screen2Subtitle,
    required this.feat2a,
    required this.feat2b,
    required this.feat2c,
    required this.step3Badge,
    required this.screen3Title,
    required this.screen3Subtitle,
    required this.feat3a,
    required this.feat3b,
    required this.feat3c,
    required this.step4Badge,
    required this.screen4Title,
    required this.screen4Subtitle,
    required this.feat4a,
    required this.feat4b,
    required this.feat4c,
    required this.referralCode,
    required this.skip,
    required this.next,
    required this.getStarted,
  });
}

const _english = _Strings(
  step1Badge: '\u2726  Step 1 of 4',
  screen1Title: 'Create Invoices\nin Seconds',
  screen1Subtitle:
      'Fill in client details, add your products or services, set a price \u2014 and your professional invoice is ready to share.',
  feat1a: 'Add client info',
  feat1b: 'Add line items with prices',
  feat1c: 'Apply % or flat discounts',
  step2Badge: '\u2726  Step 2 of 4',
  screen2Title: 'Track Everything,\nStress Nothing',
  screen2Subtitle:
      'Your dashboard gives you a live overview of revenue, outstanding payments, and discounts \u2014 filtered any way you need.',
  feat2a: 'Live revenue & collection stats',
  feat2b: 'Filter by status & date range',
  feat2c: 'Export & share as PDF',
  step3Badge: '\u2726  Step 3 of 4',
  screen3Title: 'Smart Customer\nManagement',
  screen3Subtitle:
      'Organise customers into groups \u2014 Retail, Wholesale, VIP \u2014 and instantly view their invoice history, total billed, and outstanding dues from one place.',
  feat3a: 'Create & assign customer groups',
  feat3b: 'Full invoice history per customer',
  feat3c: 'Track outstanding dues instantly',
  step4Badge: '\u2726  Step 4 of 4',
  screen4Title: 'Invite & Earn',
  screen4Subtitle:
      'Refer friends and get 1 month Pro free for each friend who joins BillEasy',
  feat4a: 'Share your unique referral code',
  feat4b: '1 month Pro free per referral',
  feat4c: 'Friends get a discount too',
  referralCode: 'BILLEASY2024',
  skip: 'Skip',
  next: 'Next',
  getStarted: 'Get Started',
);

const _hindi = _Strings(
  step1Badge: '\u2726  \u091a\u0930\u0923 1 / 4',
  screen1Title: '\u092a\u0932\u094b\u0902 \u092e\u0947\u0902 \u092c\u0928\u093e\u090f\u0902\n\u0907\u0928\u0935\u0949\u0907\u0938',
  screen1Subtitle:
      '\u0917\u094d\u0930\u093e\u0939\u0915 \u0915\u0940 \u091c\u093e\u0928\u0915\u093e\u0930\u0940 \u092d\u0930\u0947\u0902, \u0938\u093e\u092e\u093e\u0928 \u091c\u094b\u0921\u093c\u0947\u0902, \u0915\u0940\u092e\u0924 \u0938\u0947\u091f \u0915\u0930\u0947\u0902 \u2014 \u0914\u0930 \u0906\u092a\u0915\u093e \u0907\u0928\u0935\u0949\u0907\u0938 \u0936\u0947\u092f\u0930 \u0915\u0947 \u0932\u093f\u090f \u0924\u0948\u092f\u093e\u0930\u0964',
  feat1a: '\u0917\u094d\u0930\u093e\u0939\u0915 \u0915\u0940 \u091c\u093e\u0928\u0915\u093e\u0930\u0940 \u091c\u094b\u0921\u093c\u0947\u0902',
  feat1b: '\u0906\u0907\u091f\u092e \u0914\u0930 \u0915\u0940\u092e\u0924 \u091c\u094b\u0921\u093c\u0947\u0902',
  feat1c: '% \u092f\u093e \u092b\u094d\u0932\u0948\u091f \u091b\u0942\u091f \u0932\u0917\u093e\u090f\u0902',
  step2Badge: '\u2726  \u091a\u0930\u0923 2 / 4',
  screen2Title: '\u0938\u092c \u091f\u094d\u0930\u0948\u0915 \u0915\u0930\u0947\u0902,\n\u091a\u093f\u0902\u0924\u093e \u0928 \u0915\u0930\u0947\u0902',
  screen2Subtitle:
      '\u0921\u0948\u0936\u092c\u094b\u0930\u094d\u0921 \u0906\u092f, \u092c\u0915\u093e\u092f\u093e \u092d\u0941\u0917\u0924\u093e\u0928 \u0914\u0930 \u091b\u0942\u091f \u0915\u093e \u0932\u093e\u0907\u0935 \u0905\u0935\u0932\u094b\u0915\u0928 \u0926\u0947\u0924\u093e \u0939\u0948 \u2014 \u091c\u0948\u0938\u0947 \u091a\u093e\u0939\u0947\u0902 \u092b\u093c\u093f\u0932\u094d\u091f\u0930 \u0915\u0930\u0947\u0902\u0964',
  feat2a: '\u0932\u093e\u0907\u0935 \u0906\u092f \u0914\u0930 \u0938\u0902\u0917\u094d\u0930\u0939 \u0906\u0901\u0915\u0921\u093c\u0947',
  feat2b: '\u0938\u094d\u0925\u093f\u0924\u093f \u0914\u0930 \u0924\u093e\u0930\u0940\u0916 \u0938\u0947 \u092b\u093c\u093f\u0932\u094d\u091f\u0930',
  feat2c: 'PDF \u092e\u0947\u0902 \u0928\u093f\u0930\u094d\u092f\u093e\u0924 \u0915\u0930\u0947\u0902',
  step3Badge: '\u2726  \u091a\u0930\u0923 3 / 4',
  screen3Title: '\u0938\u094d\u092e\u093e\u0930\u094d\u091f \u0917\u094d\u0930\u093e\u0939\u0915\n\u092a\u094d\u0930\u092c\u0902\u0927\u0928',
  screen3Subtitle:
      '\u0917\u094d\u0930\u093e\u0939\u0915\u094b\u0902 \u0915\u094b \u0938\u092e\u0942\u0939\u094b\u0902 \u092e\u0947\u0902 \u092c\u093e\u0901\u091f\u0947\u0902 \u2014 \u0930\u093f\u091f\u0947\u0932, \u0925\u094b\u0915, VIP \u2014 \u0914\u0930 \u0909\u0928\u0915\u0947 \u0907\u0928\u0935\u0949\u0907\u0938 \u0907\u0924\u093f\u0939\u093e\u0938, \u0915\u0941\u0932 \u092c\u093f\u0932 \u0935 \u092c\u0915\u093e\u092f\u093e \u090f\u0915 \u0939\u0940 \u091c\u0917\u0939 \u0938\u0947 \u0926\u0947\u0916\u0947\u0902\u0964',
  feat3a: '\u0917\u094d\u0930\u093e\u0939\u0915 \u0938\u092e\u0942\u0939 \u092c\u0928\u093e\u090f\u0902 \u0914\u0930 \u0905\u0938\u093e\u0907\u0928 \u0915\u0930\u0947\u0902',
  feat3b: '\u0939\u0930 \u0917\u094d\u0930\u093e\u0939\u0915 \u0915\u093e \u092a\u0942\u0930\u093e \u0907\u0928\u0935\u0949\u0907\u0938 \u0907\u0924\u093f\u0939\u093e\u0938',
  feat3c: '\u092c\u0915\u093e\u092f\u093e \u0930\u093e\u0936\u093f \u0924\u0941\u0930\u0902\u0924 \u091f\u094d\u0930\u0948\u0915 \u0915\u0930\u0947\u0902',
  step4Badge: '\u2726  \u091a\u0930\u0923 4 / 4',
  screen4Title: '\u0906\u092e\u0902\u0924\u094d\u0930\u093f\u0924 \u0915\u0930\u0947\u0902\n\u0914\u0930 \u0915\u092e\u093e\u090f\u0902',
  screen4Subtitle:
      '\u0926\u094b\u0938\u094d\u0924\u094b\u0902 \u0915\u094b \u0930\u0947\u092b\u0930 \u0915\u0930\u0947\u0902 \u0914\u0930 \u0939\u0930 \u0926\u094b\u0938\u094d\u0924 \u0915\u0947 \u091c\u0941\u0921\u093c\u0928\u0947 \u092a\u0930 1 \u092e\u0939\u0940\u0928\u093e Pro \u092e\u0941\u092b\u094d\u0924 \u092a\u093e\u090f\u0902',
  feat4a: '\u0905\u092a\u0928\u093e \u0930\u0947\u092b\u0930\u0932 \u0915\u094b\u0921 \u0936\u0947\u092f\u0930 \u0915\u0930\u0947\u0902',
  feat4b: '\u0939\u0930 \u0930\u0947\u092b\u0930\u0932 \u092a\u0930 1 \u092e\u0939\u0940\u0928\u093e Pro \u092e\u0941\u092b\u094d\u0924',
  feat4c: '\u0926\u094b\u0938\u094d\u0924\u094b\u0902 \u0915\u094b \u092d\u0940 \u092e\u093f\u0932\u0924\u0940 \u0939\u0948 \u091b\u0942\u091f',
  referralCode: 'BILLEASY2024',
  skip: '\u091b\u094b\u0921\u093c\u0947\u0902',
  next: '\u0906\u0917\u0947',
  getStarted: '\u0936\u0941\u0930\u0942 \u0915\u0930\u0947\u0902',
);

const _assamese = _Strings(
  step1Badge: '\u2726  \u09aa\u09a6\u0995\u09cd\u09b7\u09c7\u09aa \u09e7 / \u09ea',
  screen1Title: '\u09ae\u09c1\u09b9\u09c2\u09f0\u09cd\u09a4\u09a4 \u09ac\u09a8\u09be\u0993\u0995\n\u09ac\u09bf\u09b2',
  screen1Subtitle:
      '\u0997\u09cd\u09f0\u09be\u09b9\u0995\u09f0 \u09a4\u09a5\u09cd\u09af \u09aa\u09c2\u09f0\u09a3 \u0995\u09f0\u0995, \u09b8\u09be\u09ae\u0997\u09cd\u09f0\u09c0 \u09af\u09cb\u0997 \u0995\u09f0\u0995, \u09ae\u09c2\u09b2\u09cd\u09af \u09a8\u09bf\u09f0\u09cd\u09a7\u09be\u09f0\u09a3 \u0995\u09f0\u0995 \u2014 \u0986\u09f0\u09c1 \u0986\u09aa\u09cb\u09a8\u09be\u09f0 \u09ac\u09bf\u09b2 \u09b6\u09cd\u09ac\u09c7\u09af\u09bc\u09be\u09f0\u09f0 \u09ac\u09be\u09ac\u09c7 \u09aa\u09cd\u09f0\u09b8\u09cd\u09a4\u09c1\u09a4\u0964',
  feat1a: '\u0997\u09cd\u09f0\u09be\u09b9\u0995\u09f0 \u09a4\u09a5\u09cd\u09af \u09af\u09cb\u0997 \u0995\u09f0\u0995',
  feat1b: '\u09b8\u09be\u09ae\u0997\u09cd\u09f0\u09c0 \u0986\u09f0\u09c1 \u09ae\u09c2\u09b2\u09cd\u09af \u09af\u09cb\u0997 \u0995\u09f0\u0995',
  feat1c: '% \u09ac\u09be \u09b8\u09ae\u09a4\u09b2 \u099b\u09be\u09dc \u09aa\u09cd\u09f0\u09af\u09bc\u09cb\u0997 \u0995\u09f0\u0995',
  step2Badge: '\u2726  \u09aa\u09a6\u0995\u09cd\u09b7\u09c7\u09aa \u09e8 / \u09ea',
  screen2Title: '\u09b8\u0995\u09b2\u09cb \u099f\u09cd\u09f0\u09c7\u0995 \u0995\u09f0\u0995,\n\u099a\u09bf\u09a8\u09cd\u09a4\u09be \u09a8\u0995\u09f0\u09bf\u09ac',
  screen2Subtitle:
      '\u09a1\u09cd\u09af\u09be\u09b6\u09ac\u09cb\u09f0\u09cd\u09a1\u09c7 \u0986\u09af\u09bc, \u09ac\u0995\u09c7\u09af\u09bc\u09be \u09aa\u09f0\u09bf\u09b6\u09cb\u09a7 \u0986\u09f0\u09c1 \u099b\u09be\u09dc\u09f0 \u09b2\u09be\u0987\u09ad \u09b8\u0982\u0995\u09cd\u09b7\u09bf\u09aa\u09cd\u09a4\u09b8\u09be\u09f0 \u09a6\u09bf\u09af\u09bc\u09c7 \u2014 \u09af\u09bf\u09a6\u09f0\u09c7 \u09ac\u09bf\u099a\u09be\u09f0\u09c7 \u09ab\u09bf\u09b2\u09cd\u099f\u09be\u09f0 \u0995\u09f0\u0995\u0964',
  feat2a: '\u09b2\u09be\u0987\u09ad \u0986\u09af\u09bc \u0986\u09f0\u09c1 \u09b8\u0982\u0997\u09cd\u09f0\u09b9\u09f0 \u09aa\u09f0\u09bf\u09b8\u0982\u0996\u09cd\u09af\u09be',
  feat2b: '\u09b8\u09cd\u09a5\u09bf\u09a4\u09bf \u0986\u09f0\u09c1 \u09a4\u09be\u09f0\u09bf\u0996 \u0985\u09a8\u09c1\u09b8\u09f0\u09bf \u09ab\u09bf\u09b2\u09cd\u099f\u09be\u09f0',
  feat2c: 'PDF \u09f0\u09c2\u09aa\u09a4 \u09f0\u09aa\u09cd\u09a4\u09be\u09a8\u09bf \u0995\u09f0\u0995',
  step3Badge: '\u2726  \u09aa\u09a6\u0995\u09cd\u09b7\u09c7\u09aa \u09e9 / \u09ea',
  screen3Title: '\u09b8\u09cd\u09ae\u09be\u09f0\u09cd\u099f \u0997\u09cd\u09f0\u09be\u09b9\u0995\n\u09aa\u09f0\u09bf\u099a\u09be\u09b2\u09a8\u09be',
  screen3Subtitle:
      '\u0997\u09cd\u09f0\u09be\u09b9\u0995\u09b8\u0995\u09b2\u0995 \u0997\u09cb\u099f\u09a4 \u09ad\u09be\u0997 \u0995\u09f0\u0995 \u2014 \u0996\u09c1\u099a\u09c1\u09f0\u09be, \u09aa\u09be\u0987\u0995\u09be\u09f0\u09c0, VIP \u2014 \u0986\u09f0\u09c1 \u09a4\u09c7\u0993\u0981\u09b2\u09cb\u0995\u09f0 \u09ac\u09bf\u09b2\u09f0 \u0987\u09a4\u09bf\u09b9\u09be\u09b8, \u09ae\u09c1\u09a0 \u09ac\u09bf\u09b2 \u0986\u09f0\u09c1 \u09ac\u0995\u09c7\u09af\u09bc\u09be \u098f\u09a0\u09be\u0987\u09f0 \u09aa\u09f0\u09be\u0987 \u099a\u09be\u0993\u0995\u0964',
  feat3a: '\u0997\u09cd\u09f0\u09be\u09b9\u0995 \u0997\u09cb\u099f \u09ac\u09a8\u09be\u0993\u0995 \u0986\u09f0\u09c1 \u09a8\u09bf\u09af\u09c1\u0995\u09cd\u09a4 \u0995\u09f0\u0995',
  feat3b: '\u09aa\u09cd\u09f0\u09a4\u09bf\u099c\u09a8 \u0997\u09cd\u09f0\u09be\u09b9\u0995\u09f0 \u09b8\u09ae\u09cd\u09aa\u09c2\u09f0\u09cd\u09a3 \u09ac\u09bf\u09b2\u09f0 \u0987\u09a4\u09bf\u09b9\u09be\u09b8',
  feat3c: '\u09ac\u0995\u09c7\u09af\u09bc\u09be \u09aa\u09f0\u09bf\u09ae\u09be\u09a3 \u09a4\u09ce\u0995\u09cd\u09b7\u09a3\u09be\u09ce \u099f\u09cd\u09f0\u09c7\u0995 \u0995\u09f0\u0995',
  step4Badge: '\u2726  \u09aa\u09a6\u0995\u09cd\u09b7\u09c7\u09aa \u09ea / \u09ea',
  screen4Title: '\u0986\u09ae\u09a8\u09cd\u09a4\u09cd\u09f0\u09a3 \u0995\u09f0\u0995\n\u0986\u09f0\u09c1 \u0989\u09aa\u09be\u09f0\u09cd\u099c\u09a8 \u0995\u09f0\u0995',
  screen4Subtitle:
      '\u09ac\u09a8\u09cd\u09a7\u09c1\u09b8\u0995\u09b2\u0995 \u09f0\u09c7\u09ab\u09be\u09f0 \u0995\u09f0\u0995 \u0986\u09f0\u09c1 \u09aa\u09cd\u09f0\u09a4\u09bf\u099c\u09a8 \u09ac\u09a8\u09cd\u09a7\u09c1\u09f0 \u09ac\u09be\u09ac\u09c7 \u09e7 \u09ae\u09be\u09b9 Pro \u09ac\u09bf\u09a8\u09be\u09ae\u09c2\u09b2\u09c0\u09af\u09bc\u09be\u0995\u09c8 \u09aa\u09be\u0993\u0995',
  feat4a: '\u0986\u09aa\u09cb\u09a8\u09be\u09f0 \u09f0\u09c7\u09ab\u09be\u09f0\u09c7\u09b2 \u0995\u09cb\u09a1 \u09b6\u09cd\u09ac\u09c7\u09af\u09bc\u09be\u09f0 \u0995\u09f0\u0995',
  feat4b: '\u09aa\u09cd\u09f0\u09a4\u09bf\u099f\u09cb \u09f0\u09c7\u09ab\u09be\u09f0\u09c7\u09b2\u09a4 \u09e7 \u09ae\u09be\u09b9 Pro \u09ac\u09bf\u09a8\u09be\u09ae\u09c2\u09b2\u09c0\u09af\u09bc\u09be',
  feat4c: '\u09ac\u09a8\u09cd\u09a7\u09c1\u09b8\u0995\u09b2\u09c7\u0993 \u099b\u09be\u09dc \u09aa\u09be\u09af\u09bc',
  referralCode: 'BILLEASY2024',
  skip: '\u098f\u09f0\u0995',
  next: '\u09aa\u09f0\u09f1\u09f0\u09cd\u09a4\u09c0',
  getStarted: '\u0986\u09f0\u09ae\u09cd\u09ad \u0995\u09f0\u0995',
);

_Strings _stringsFor(AppLanguage lang) {
  switch (lang) {
    case AppLanguage.hindi:
      return _hindi;
    case AppLanguage.assamese:
      return _assamese;
    case AppLanguage.gujarati:
    case AppLanguage.tamil:
    case AppLanguage.english:
      return _english;
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onCompleted,
    this.language = AppLanguage.english,
  });

  final VoidCallback onCompleted;
  final AppLanguage language;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  _Strings get _s => _stringsFor(widget.language);

  late AnimationController _floatController;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _floatAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _floatAnimation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _floatController.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _completeOnboarding() {
    widget.onCompleted();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _slideController.reset();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      _slideController.forward();
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (page) => setState(() => _currentPage = page),
            children: [_buildPage1(), _buildPage2(), _buildPage3(), _buildPage4()],
          ),
          // Bottom controls overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomControls(),
          ),
        ],
      ),
    );
  }

  // Clean white background — blue is secondary accent only
  BoxDecoration get _pageDecoration => const BoxDecoration(
    color: kSurfaceLowest,
  );

  Widget _buildPage1() {
    return Container(
      decoration: _pageDecoration,
      child: Stack(
        children: [
          _buildOrb(top: -60, right: -40, size: 220, opacity: 0.08),
          _buildOrb(bottom: 140, left: -60, size: 180, opacity: 0.06),

          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: TextButton(
                      onPressed: _completeOnboarding,
                      child: Text(
                        _s.skip,
                        style: const TextStyle(
                          color: kTextTertiary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    flex: 5,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: AnimatedBuilder(
                          animation: _floatAnimation,
                          builder: (context, child) => Transform.translate(
                            offset: Offset(0, _floatAnimation.value),
                            child: child,
                          ),
                          child: _buildInvoiceIllustration(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBadge(_s.step1Badge),
                        const SizedBox(height: 20),
                        _buildTitle(_s.screen1Title),
                        const SizedBox(height: 14),
                        _buildSubtitle(_s.screen1Subtitle),
                        const SizedBox(height: 28),
                        _buildFeatureRow(Icons.person_add_alt_1_rounded, _s.feat1a),
                        const SizedBox(height: 12),
                        _buildFeatureRow(Icons.add_shopping_cart_rounded, _s.feat1b),
                        const SizedBox(height: 12),
                        _buildFeatureRow(Icons.local_offer_rounded, _s.feat1c),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage2() {
    return Container(
      decoration: _pageDecoration,
      child: Stack(
        children: [
          _buildOrb(top: -80, left: -50, size: 260, opacity: 0.08),
          _buildOrb(bottom: 160, right: -50, size: 200, opacity: 0.06),

          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 44),
                  Expanded(
                    flex: 5,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: AnimatedBuilder(
                          animation: _floatAnimation,
                          builder: (context, child) => Transform.translate(
                            offset: Offset(0, _floatAnimation.value * 0.7),
                            child: child,
                          ),
                          child: _buildDashboardIllustration(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBadge(_s.step2Badge),
                        const SizedBox(height: 20),
                        _buildTitle(_s.screen2Title),
                        const SizedBox(height: 14),
                        _buildSubtitle(_s.screen2Subtitle),
                        const SizedBox(height: 28),
                        _buildFeatureRow(Icons.bar_chart_rounded, _s.feat2a),
                        const SizedBox(height: 12),
                        _buildFeatureRow(Icons.filter_alt_rounded, _s.feat2b),
                        const SizedBox(height: 12),
                        _buildFeatureRow(Icons.picture_as_pdf_rounded, _s.feat2c),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage3() {
    return Container(
      decoration: _pageDecoration,
      child: Stack(
        children: [
          _buildOrb(top: -70, right: -50, size: 240, opacity: 0.09),
          _buildOrb(bottom: 150, left: -60, size: 200, opacity: 0.07),

          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: TextButton(
                      onPressed: _completeOnboarding,
                      child: Text(
                        _s.skip,
                        style: const TextStyle(
                          color: kTextTertiary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    flex: 5,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: AnimatedBuilder(
                          animation: _floatAnimation,
                          builder: (context, child) => Transform.translate(
                            offset: Offset(0, _floatAnimation.value * 0.8),
                            child: child,
                          ),
                          child: _buildCustomerGroupsIllustration(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBadge(_s.step3Badge),
                        const SizedBox(height: 20),
                        _buildTitle(_s.screen3Title),
                        const SizedBox(height: 14),
                        _buildSubtitle(_s.screen3Subtitle),
                        const SizedBox(height: 28),
                        _buildFeatureRow(Icons.folder_special_rounded, _s.feat3a),
                        const SizedBox(height: 12),
                        _buildFeatureRow(Icons.history_rounded, _s.feat3b),
                        const SizedBox(height: 12),
                        _buildFeatureRow(Icons.account_balance_wallet_rounded, _s.feat3c),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage4() {
    return Container(
      decoration: _pageDecoration,
      child: Stack(
        children: [
          _buildOrb(top: -60, right: -40, size: 220, opacity: 0.09),
          _buildOrb(bottom: 140, left: -60, size: 180, opacity: 0.07),

          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: TextButton(
                      onPressed: _completeOnboarding,
                      child: Text(
                        _s.skip,
                        style: const TextStyle(
                          color: kTextTertiary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    flex: 5,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: AnimatedBuilder(
                          animation: _floatAnimation,
                          builder: (context, child) => Transform.translate(
                            offset: Offset(0, _floatAnimation.value * 0.8),
                            child: child,
                          ),
                          child: _buildReferralIllustration(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBadge(_s.step4Badge),
                        const SizedBox(height: 20),
                        _buildTitle(_s.screen4Title),
                        const SizedBox(height: 14),
                        _buildSubtitle(_s.screen4Subtitle),
                        const SizedBox(height: 28),
                        _buildFeatureRow(Icons.share_rounded, _s.feat4a),
                        const SizedBox(height: 12),
                        _buildFeatureRow(Icons.card_giftcard_rounded, _s.feat4b),
                        const SizedBox(height: 12),
                        _buildFeatureRow(Icons.emoji_events_rounded, _s.feat4c),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared text builders ────────────────────────────────────────────────

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: kPrimaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: kPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: kOnSurface,
        fontSize: 36,
        fontWeight: FontWeight.w800,
        height: 1.15,
        letterSpacing: -1.0,
      ),
    );
  }

  Widget _buildSubtitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: kOnSurfaceVariant,
        fontSize: 15.5,
        height: 1.55,
      ),
    );
  }

  // ── Illustrations ───────────────────────────────────────────────────────

  Widget _buildReferralIllustration() {
    return SizedBox(
      width: 310,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 240,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: kSurfaceContainerLow,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [kWhisperShadow],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (_, child) => Transform.scale(
                    scale: _pulseAnimation.value,
                    child: child,
                  ),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: kPrimaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.people_alt_rounded,
                      color: kPrimary,
                      size: 34,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Your Referral Code',
                  style: TextStyle(
                    color: kOnSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: kSurfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'BILLEASY2024',
                        style: TextStyle(
                          color: kOnSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                      SizedBox(width: 10),
                      Icon(Icons.copy_rounded, color: kOnSurfaceVariant, size: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: kPrimary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.share_rounded, size: 16, color: kOnPrimary),
                      SizedBox(width: 8),
                      Text(
                        'Share & Earn',
                        style: TextStyle(
                          color: kOnPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Floating reward badge
          Positioned(
            top: 8,
            right: 0,
            child: AnimatedBuilder(
              animation: _floatAnimation,
              builder: (_, child) => Transform.translate(
                offset: Offset(_floatAnimation.value * 0.5, 0),
                child: child,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: kPaidBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, color: kPaid, size: 12),
                    SizedBox(width: 4),
                    Text(
                      '1 Month Free',
                      style: TextStyle(color: kPaid, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Floating friend badge
          Positioned(
            bottom: 16,
            left: 0,
            child: AnimatedBuilder(
              animation: _floatAnimation,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, _floatAnimation.value * 0.5),
                child: child,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: kSurfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [kSubtleShadow],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_rounded, color: kPrimary, size: 12),
                    SizedBox(width: 4),
                    Text(
                      '3 Friends Joined',
                      style: TextStyle(color: kOnSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerGroupsIllustration() {
    return SizedBox(
      width: 310,
      height: 290,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _buildGroupHubCard(),
          Positioned(
            top: 10,
            right: 4,
            child: AnimatedBuilder(
              animation: _floatAnimation,
              builder: (_, child) => Transform.translate(
                offset: Offset(_floatAnimation.value * 0.5, 0),
                child: child,
              ),
              child: _buildGroupBadge(label: 'VIP', icon: Icons.star_rounded, color: kPending),
            ),
          ),
          Positioned(
            top: 20,
            left: 0,
            child: AnimatedBuilder(
              animation: _floatAnimation,
              builder: (_, child) => Transform.translate(
                offset: Offset(_floatAnimation.value * -0.4, 0),
                child: child,
              ),
              child: _buildGroupBadge(label: 'Wholesale', icon: Icons.inventory_2_rounded, color: kPaid),
            ),
          ),
          Positioned(
            bottom: 26,
            left: 4,
            child: AnimatedBuilder(
              animation: _floatAnimation,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, _floatAnimation.value * 0.5),
                child: child,
              ),
              child: _buildGroupBadge(label: 'Retail', icon: Icons.storefront_rounded, color: kOnSurfaceVariant),
            ),
          ),
          Positioned(
            bottom: 18,
            right: 0,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (_, child) =>
                  Transform.scale(scale: _pulseAnimation.value, child: child),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: kOverdue.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 11),
                    SizedBox(width: 4),
                    Text(
                      '\u20b94,200 due',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupHubCard() {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [kWhisperShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: kPrimaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.groups_2_rounded, color: kPrimary, size: 18),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CUSTOMERS',
                    style: TextStyle(color: kOnSurface, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                  ),
                  Text(
                    '3 Groups \u00b7 12 clients',
                    style: TextStyle(color: kTextTertiary, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _customerRow('Rajesh Kumar', 'VIP', kPending),
          const SizedBox(height: 6),
          _customerRow('Priya Stores', 'Retail', kOnSurfaceVariant),
          const SizedBox(height: 6),
          _customerRow('Mehta Traders', 'Wholesale', kPaid),
          const SizedBox(height: 10),
          const Divider(color: kSurfaceContainer, height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _groupStat('Total Billed', '\u20b91,24,500', kOnSurface),
              _groupStat('Collected', '\u20b998,200', kPaid),
            ],
          ),
        ],
      ),
    );
  }

  Widget _customerRow(String name, String group, Color groupColor) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: groupColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            name[0],
            style: TextStyle(color: groupColor, fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: kOnSurface, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: groupColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            group,
            style: TextStyle(color: groupColor, fontSize: 9, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _groupStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
        Text(label, style: const TextStyle(color: kTextTertiary, fontSize: 10)),
      ],
    );
  }

  Widget _buildGroupBadge({required String label, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    final isLast = _currentPage == 3;

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 36),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, kSurfaceLowest.withValues(alpha: 0.95)],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: List.generate(4, (index) {
              final isActive = index == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(right: 8),
                width: isActive ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive ? kPrimary : kSurfaceContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) => Transform.scale(
              scale: isLast ? _pulseAnimation.value : 1.0,
              child: child,
            ),
            child: GestureDetector(
              onTap: _nextPage,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: EdgeInsets.symmetric(
                  horizontal: isLast ? 32 : 28,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: kPrimary,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: const [kWhisperShadow],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isLast ? _s.getStarted : _s.next,
                      style: const TextStyle(
                        color: kOnPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isLast ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded,
                      color: kOnPrimary,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String label) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: kPrimaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: kPrimary, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: kOnSurface,
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrb({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double size,
    required double opacity,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [kPrimary.withValues(alpha: opacity), Colors.transparent],
          ),
        ),
      ),
    );
  }

  // ── Invoice Illustration ──────────────────────────────────────────────────

  Widget _buildInvoiceIllustration() {
    return SizedBox(
      width: 300,
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 18,
            child: Transform.rotate(
              angle: 0.08,
              child: _glassCard(width: 240, height: 240, opacity: 0.08),
            ),
          ),
          _buildInvoiceCard(),
          Positioned(
            top: 30,
            right: 20,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (_, child) =>
                  Transform.scale(scale: _pulseAnimation.value, child: child),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: kPaid,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text('PAID', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 10,
            child: AnimatedBuilder(
              animation: _floatAnimation,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, _floatAnimation.value * 0.5),
                child: child,
              ),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: kPrimaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  '\u20b9',
                  style: TextStyle(color: kPrimary, fontSize: 22, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard() {
    return Container(
      width: 230,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kSurfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [kWhisperShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('INVOICE', style: TextStyle(color: kOnSurface, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 2)),
                  Text('#INV-0042', style: const TextStyle(color: kTextTertiary, fontSize: 11)),
                ],
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: kPrimaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_long, color: kPrimary, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _invoiceRow('Rice (10 kg)', '\u20b9650'),
          const SizedBox(height: 6),
          _invoiceRow('Cooking Oil (5L)', '\u20b9780'),
          const SizedBox(height: 6),
          _invoiceRow('Sugar & Spices', '\u20b9420'),
          const SizedBox(height: 10),
          const Divider(color: kSurfaceContainer, height: 1),
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: TextStyle(color: kOnSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600)),
              Text('\u20b91,850', style: TextStyle(color: kOnSurface, fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _invoiceRow(String label, String amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kOnSurfaceVariant, fontSize: 12)),
        ),
        const SizedBox(width: 8),
        Text(amount, style: const TextStyle(color: kOnSurface, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ── Dashboard Illustration ────────────────────────────────────────────────

  Widget _buildDashboardIllustration() {
    return SizedBox(
      width: 310,
      height: 290,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _buildDashboardCard(),
          Positioned(
            top: 10,
            right: 0,
            child: AnimatedBuilder(
              animation: _floatAnimation,
              builder: (_, child) => Transform.translate(
                offset: Offset(_floatAnimation.value * 0.4, 0),
                child: child,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: kOverdue.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text('2 Overdue', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 0,
            child: AnimatedBuilder(
              animation: _floatAnimation,
              builder: (_, child) => Transform.translate(
                offset: Offset(_floatAnimation.value * -0.4, 0),
                child: child,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: kSurfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [kSubtleShadow],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_rounded, color: kPrimary, size: 11),
                    SizedBox(width: 5),
                    Text('This Month', style: TextStyle(color: kOnSurface, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard() {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [kWhisperShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Overview', style: TextStyle(color: kTextTertiary, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
          const SizedBox(height: 2),
          const Text('\u20b91,24,500', style: TextStyle(color: kOnSurface, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -1)),
          const Text('Total Billed', style: TextStyle(color: kOnSurfaceVariant, fontSize: 11)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _miniStat('Collected', '\u20b998,200', kPaid)),
              const SizedBox(width: 8),
              Expanded(child: _miniStat('Outstanding', '\u20b926,300', kPending)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statusPill('All', true),
              const SizedBox(width: 6),
              _statusPill('Paid', false),
              const SizedBox(width: 6),
              _statusPill('Pending', false),
            ],
          ),
          const SizedBox(height: 10),
          _buildMiniChart(),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: kOnSurfaceVariant, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _statusPill(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? kPrimary : kSurfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? kOnPrimary : kOnSurfaceVariant,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildMiniChart() {
    final bars = [0.4, 0.7, 0.55, 0.9, 0.65, 0.8, 1.0];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: bars.map((h) {
        return AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (_, child) {
            final scale = 1.0 + (h - 0.5) * (_pulseAnimation.value - 1.0) * 0.05;
            return Transform.scale(alignment: Alignment.bottomCenter, scaleY: scale, child: child);
          },
          child: Container(
            width: 20,
            height: 30 * h,
            decoration: BoxDecoration(
              color: kPrimary.withValues(alpha: 0.15 + h * 0.35),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _glassCard({required double width, required double height, double opacity = 0.1}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: kPrimary.withValues(alpha: opacity * 0.5),
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }
}
