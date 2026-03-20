import 'package:flutter/material.dart';
import 'package:billeasy/screens/language_selection_screen.dart';

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
  step1Badge: '✦  Step 1 of 4',
  screen1Title: 'Create Invoices\nin Seconds',
  screen1Subtitle:
      'Fill in client details, add your products or services, set a price — and your professional invoice is ready to share.',
  feat1a: 'Add client info',
  feat1b: 'Add line items with prices',
  feat1c: 'Apply % or flat discounts',
  step2Badge: '✦  Step 2 of 4',
  screen2Title: 'Track Everything,\nStress Nothing',
  screen2Subtitle:
      'Your dashboard gives you a live overview of revenue, outstanding payments, and discounts — filtered any way you need.',
  feat2a: 'Live revenue & collection stats',
  feat2b: 'Filter by status & date range',
  feat2c: 'Export & share as PDF',
  step3Badge: '✦  Step 3 of 4',
  screen3Title: 'Smart Customer\nManagement',
  screen3Subtitle:
      'Organise customers into groups — Retail, Wholesale, VIP — and instantly view their invoice history, total billed, and outstanding dues from one place.',
  feat3a: 'Create & assign customer groups',
  feat3b: 'Full invoice history per customer',
  feat3c: 'Track outstanding dues instantly',
  step4Badge: '✦  Step 4 of 4',
  screen4Title: 'Invite & Earn',
  screen4Subtitle:
      'Refer friends and get 1 month Pro free for each friend who joins BillRaja',
  feat4a: 'Share your unique referral code',
  feat4b: '1 month Pro free per referral',
  feat4c: 'Friends get a discount too',
  referralCode: 'BILLRAJA2024',
  skip: 'Skip',
  next: 'Next',
  getStarted: 'Get Started',
);

const _hindi = _Strings(
  step1Badge: '✦  चरण 1 / 4',
  screen1Title: 'पलों में बनाएं\nइनवॉइस',
  screen1Subtitle:
      'ग्राहक की जानकारी भरें, सामान जोड़ें, कीमत सेट करें — और आपका इनवॉइस शेयर के लिए तैयार।',
  feat1a: 'ग्राहक की जानकारी जोड़ें',
  feat1b: 'आइटम और कीमत जोड़ें',
  feat1c: '% या फ्लैट छूट लगाएं',
  step2Badge: '✦  चरण 2 / 4',
  screen2Title: 'सब ट्रैक करें,\nचिंता न करें',
  screen2Subtitle:
      'डैशबोर्ड आय, बकाया भुगतान और छूट का लाइव अवलोकन देता है — जैसे चाहें फ़िल्टर करें।',
  feat2a: 'लाइव आय और संग्रह आँकड़े',
  feat2b: 'स्थिति और तारीख से फ़िल्टर',
  feat2c: 'PDF में निर्यात करें',
  step3Badge: '✦  चरण 3 / 4',
  screen3Title: 'स्मार्ट ग्राहक\nप्रबंधन',
  screen3Subtitle:
      'ग्राहकों को समूहों में बाँटें — रिटेल, थोक, VIP — और उनके इनवॉइस इतिहास, कुल बिल व बकाया एक ही जगह से देखें।',
  feat3a: 'ग्राहक समूह बनाएं और असाइन करें',
  feat3b: 'हर ग्राहक का पूरा इनवॉइस इतिहास',
  feat3c: 'बकाया राशि तुरंत ट्रैक करें',
  step4Badge: '✦  चरण 4 / 4',
  screen4Title: 'आमंत्रित करें\nऔर कमाएं',
  screen4Subtitle:
      'दोस्तों को रेफर करें और हर दोस्त के जुड़ने पर 1 महीना Pro मुफ्त पाएं',
  feat4a: 'अपना रेफरल कोड शेयर करें',
  feat4b: 'हर रेफरल पर 1 महीना Pro मुफ्त',
  feat4c: 'दोस्तों को भी मिलती है छूट',
  referralCode: 'BILLRAJA2024',
  skip: 'छोड़ें',
  next: 'आगे',
  getStarted: 'शुरू करें',
);

const _assamese = _Strings(
  step1Badge: '✦  পদক্ষেপ ১ / ৪',
  screen1Title: 'মুহূর্তত বনাওক\nবিল',
  screen1Subtitle:
      'গ্ৰাহকৰ তথ্য পূৰণ কৰক, সামগ্ৰী যোগ কৰক, মূল্য নিৰ্ধাৰণ কৰক — আৰু আপোনাৰ বিল শ্বেয়াৰৰ বাবে প্ৰস্তুত।',
  feat1a: 'গ্ৰাহকৰ তথ্য যোগ কৰক',
  feat1b: 'সামগ্ৰী আৰু মূল্য যোগ কৰক',
  feat1c: '% বা সমতল ছাড় প্ৰয়োগ কৰক',
  step2Badge: '✦  পদক্ষেপ ২ / ৪',
  screen2Title: 'সকলো ট্ৰেক কৰক,\nচিন্তা নকৰিব',
  screen2Subtitle:
      'ড্যাশব\'ৰ্ডে আয়, বকেয়া পৰিশোধ আৰু ছাড়ৰ লাইভ সংক্ষিপ্তসাৰ দিয়ে — যিদৰে বিচাৰে ফিল্টাৰ কৰক।',
  feat2a: 'লাইভ আয় আৰু সংগ্ৰহৰ পৰিসংখ্যা',
  feat2b: 'স্থিতি আৰু তাৰিখ অনুসৰি ফিল্টাৰ',
  feat2c: 'PDF ৰূপত ৰপ্তানি কৰক',
  step3Badge: '✦  পদক্ষেপ ৩ / ৪',
  screen3Title: 'স্মাৰ্ট গ্ৰাহক\nপৰিচালনা',
  screen3Subtitle:
      'গ্ৰাহকসকলক গোটত ভাগ কৰক — খুচুৰা, পাইকাৰী, VIP — আৰু তেওঁলোকৰ বিলৰ ইতিহাস, মুঠ বিল আৰু বকেয়া এঠাইৰ পৰাই চাওক।',
  feat3a: 'গ্ৰাহক গোট বনাওক আৰু নিযুক্ত কৰক',
  feat3b: 'প্ৰতিজন গ্ৰাহকৰ সম্পূৰ্ণ বিলৰ ইতিহাস',
  feat3c: 'বকেয়া পৰিমাণ তৎক্ষণাৎ ট্ৰেক কৰক',
  step4Badge: '✦  পদক্ষেপ ৪ / ৪',
  screen4Title: 'আমন্ত্ৰণ কৰক\nআৰু উপাৰ্জন কৰক',
  screen4Subtitle:
      'বন্ধুসকলক ৰেফাৰ কৰক আৰু প্ৰতিজন বন্ধুৰ বাবে ১ মাহ Pro বিনামূলীয়াকৈ পাওক',
  feat4a: 'আপোনাৰ ৰেফাৰেল কোড শ্বেয়াৰ কৰক',
  feat4b: 'প্ৰতিটো ৰেফাৰেলত ১ মাহ Pro বিনামূলীয়া',
  feat4c: 'বন্ধুসকলেও ছাড় পায়',
  referralCode: 'BILLRAJA2024',
  skip: 'এৰক',
  next: 'পৰৱৰ্তী',
  getStarted: 'আৰম্ভ কৰক',
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

  Widget _buildPage1() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A8A), Color(0xFF4361EE), Color(0xFF6366F1)],
        ),
      ),
      child: Stack(
        children: [
          // Ambient orbs
          _buildOrb(top: -60, right: -40, size: 220, opacity: 0.08),
          _buildOrb(bottom: 140, left: -60, size: 180, opacity: 0.06),
          _buildOrb(top: 200, right: -30, size: 120, opacity: 0.05),

          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Skip button
                  Align(
                    alignment: Alignment.topRight,
                    child: TextButton(
                      onPressed: _completeOnboarding,
                      child: Text(
                        _s.skip,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Illustration
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

                  // Text content
                  SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.25),
                            ),
                          ),
                          child: Text(
                            _s.step1Badge,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _s.screen1Title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            letterSpacing: -1.0,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _s.screen1Subtitle,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.72),
                            fontSize: 15.5,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 28),
                        _buildFeatureRow(
                          Icons.person_add_alt_1_rounded,
                          _s.feat1a,
                        ),
                        const SizedBox(height: 12),
                        _buildFeatureRow(
                          Icons.add_shopping_cart_rounded,
                          _s.feat1b,
                        ),
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF004D40), Color(0xFF00695C), Color(0xFF00897B)],
        ),
      ),
      child: Stack(
        children: [
          // Ambient orbs
          _buildOrb(top: -80, left: -50, size: 260, opacity: 0.08),
          _buildOrb(bottom: 160, right: -50, size: 200, opacity: 0.06),

          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Empty top row for alignment
                  const SizedBox(height: 44),

                  // Dashboard illustration
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

                  // Text content
                  SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.25),
                            ),
                          ),
                          child: Text(
                            _s.step2Badge,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _s.screen2Title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            letterSpacing: -1.0,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _s.screen2Subtitle,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.72),
                            fontSize: 15.5,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 28),
                        _buildFeatureRow(Icons.bar_chart_rounded, _s.feat2a),
                        const SizedBox(height: 12),
                        _buildFeatureRow(Icons.filter_alt_rounded, _s.feat2b),
                        const SizedBox(height: 12),
                        _buildFeatureRow(
                          Icons.picture_as_pdf_rounded,
                          _s.feat2c,
                        ),
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A0533), Color(0xFF4527A0), Color(0xFF6A1B9A)],
        ),
      ),
      child: Stack(
        children: [
          // Ambient orbs
          _buildOrb(top: -70, right: -50, size: 240, opacity: 0.09),
          _buildOrb(bottom: 150, left: -60, size: 200, opacity: 0.07),
          _buildOrb(top: 220, right: -20, size: 130, opacity: 0.05),

          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Skip button
                  Align(
                    alignment: Alignment.topRight,
                    child: TextButton(
                      onPressed: _completeOnboarding,
                      child: Text(
                        _s.skip,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Illustration
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

                  // Text content
                  SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.25),
                            ),
                          ),
                          child: Text(
                            _s.step3Badge,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _s.screen3Title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            letterSpacing: -1.0,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _s.screen3Subtitle,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.72),
                            fontSize: 15.5,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 28),
                        _buildFeatureRow(
                          Icons.folder_special_rounded,
                          _s.feat3a,
                        ),
                        const SizedBox(height: 12),
                        _buildFeatureRow(
                          Icons.history_rounded,
                          _s.feat3b,
                        ),
                        const SizedBox(height: 12),
                        _buildFeatureRow(
                          Icons.account_balance_wallet_rounded,
                          _s.feat3c,
                        ),
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFBF360C), Color(0xFFE64A19), Color(0xFFFFA000)],
        ),
      ),
      child: Stack(
        children: [
          // Ambient orbs
          _buildOrb(top: -60, right: -40, size: 220, opacity: 0.09),
          _buildOrb(bottom: 140, left: -60, size: 180, opacity: 0.07),
          _buildOrb(top: 200, right: -30, size: 120, opacity: 0.05),

          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Skip button
                  Align(
                    alignment: Alignment.topRight,
                    child: TextButton(
                      onPressed: _completeOnboarding,
                      child: Text(
                        _s.skip,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Illustration
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

                  // Text content
                  SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.25),
                            ),
                          ),
                          child: Text(
                            _s.step4Badge,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _s.screen4Title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            letterSpacing: -1.0,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _s.screen4Subtitle,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.72),
                            fontSize: 15.5,
                            height: 1.55,
                          ),
                        ),
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

  Widget _buildReferralIllustration() {
    return SizedBox(
      width: 310,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Central referral card
          Container(
            width: 240,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withOpacity(0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (_, child) => Transform.scale(
                    scale: _pulseAnimation.value,
                    child: child,
                  ),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.people_alt_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Your Referral Code',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'BILLRAJA2024',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.copy_rounded,
                        color: Colors.white70,
                        size: 16,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.share_rounded,
                        size: 16,
                        color: Color(0xFFE64A19),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Share & Earn',
                        style: TextStyle(
                          color: Color(0xFFE64A19),
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

          // Floating reward badge — top right
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF176).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFF176).withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      color: Color(0xFFE65100),
                      size: 12,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '1 Month Free',
                      style: TextStyle(
                        color: Color(0xFFE65100),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Floating friend badge — bottom left
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF80D8FF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF80D8FF).withOpacity(0.4),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people_rounded,
                      color: Color(0xFF80D8FF),
                      size: 12,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '3 Friends Joined',
                      style: TextStyle(
                        color: Color(0xFF80D8FF),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
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
          // Central hub card
          _buildGroupHubCard(),

          // Floating "VIP" group badge — top right
          Positioned(
            top: 10,
            right: 4,
            child: AnimatedBuilder(
              animation: _floatAnimation,
              builder: (_, child) => Transform.translate(
                offset: Offset(_floatAnimation.value * 0.5, 0),
                child: child,
              ),
              child: _buildGroupBadge(
                label: 'VIP',
                icon: Icons.star_rounded,
                color: const Color(0xFFFFD740),
              ),
            ),
          ),

          // Floating "Wholesale" badge — top left
          Positioned(
            top: 20,
            left: 0,
            child: AnimatedBuilder(
              animation: _floatAnimation,
              builder: (_, child) => Transform.translate(
                offset: Offset(_floatAnimation.value * -0.4, 0),
                child: child,
              ),
              child: _buildGroupBadge(
                label: 'Wholesale',
                icon: Icons.inventory_2_rounded,
                color: const Color(0xFF69F0AE),
              ),
            ),
          ),

          // Floating "Retail" badge — bottom left
          Positioned(
            bottom: 26,
            left: 4,
            child: AnimatedBuilder(
              animation: _floatAnimation,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, _floatAnimation.value * 0.5),
                child: child,
              ),
              child: _buildGroupBadge(
                label: 'Retail',
                icon: Icons.storefront_rounded,
                color: const Color(0xFF80D8FF),
              ),
            ),
          ),

          // Floating "Outstanding" stat — bottom right
          Positioned(
            bottom: 18,
            right: 0,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (_, child) =>
                  Transform.scale(scale: _pulseAnimation.value, child: child),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF5350).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEF5350).withOpacity(0.45),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_balance_wallet_rounded,
                        color: Colors.white, size: 11),
                    SizedBox(width: 4),
                    Text(
                      '₹4,200 due',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
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
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFCE93D8), Color(0xFF7B1FA2)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.groups_2_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CUSTOMERS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    '3 Groups · 12 clients',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Customer row 1
          _customerRow('Rajesh Kumar', 'VIP', const Color(0xFFFFD740)),
          const SizedBox(height: 6),
          _customerRow('Priya Stores', 'Retail', const Color(0xFF80D8FF)),
          const SizedBox(height: 6),
          _customerRow('Mehta Traders', 'Wholesale', const Color(0xFF69F0AE)),
          const SizedBox(height: 10),

          Divider(color: Colors.white.withOpacity(0.2), height: 1),
          const SizedBox(height: 10),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _groupStat('Total Billed', '₹1,24,500',
                  const Color(0xFFCE93D8)),
              _groupStat(
                  'Collected', '₹98,200', const Color(0xFF69F0AE)),
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
            color: groupColor.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: groupColor.withOpacity(0.4)),
          ),
          alignment: Alignment.center,
          child: Text(
            name[0],
            style: TextStyle(
              color: groupColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: groupColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: groupColor.withOpacity(0.3)),
          ),
          child: Text(
            group,
            style: TextStyle(
              color: groupColor,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _groupStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildGroupBadge({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    final isLast = _currentPage == 3;
    final pageBottomColor = switch (_currentPage) {
      0 => const Color(0xFF6366F1),
      1 => const Color(0xFF00897B),
      2 => const Color(0xFF4527A0),
      _ => const Color(0xFFE65100),
    };
    final buttonTextColor = switch (_currentPage) {
      0 => const Color(0xFF1E3A8A),
      1 => const Color(0xFF00695C),
      2 => const Color(0xFF4527A0),
      _ => const Color(0xFFE65100),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 36),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, pageBottomColor.withOpacity(0.95)],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Page dots (4)
          Row(
            children: List.generate(4, (index) {
              final isActive = index == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(right: 8),
                width: isActive ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white
                      : Colors.white.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),

          // Next / Get Started button
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isLast ? _s.getStarted : _s.next,
                      style: TextStyle(
                        color: buttonTextColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isLast
                          ? Icons.rocket_launch_rounded
                          : Icons.arrow_forward_rounded,
                      color: buttonTextColor,
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
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
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
            colors: [Colors.white.withOpacity(opacity), Colors.transparent],
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
          // Background card (shadow)
          Positioned(
            top: 18,
            child: Transform.rotate(
              angle: 0.08,
              child: _glassCard(width: 240, height: 240, opacity: 0.08),
            ),
          ),

          // Main invoice card
          _buildInvoiceCard(),

          // Floating badge: "PAID"
          Positioned(
            top: 30,
            right: 20,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (_, child) =>
                  Transform.scale(scale: _pulseAnimation.value, child: child),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4CAF50).withOpacity(0.5),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'PAID',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Floating rupee badge
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
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF00E5FF).withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: const Text(
                  '₹',
                  style: TextStyle(
                    color: Color(0xFF00E5FF),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
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
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'INVOICE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  Text(
                    '#INV-0042',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00E5FF), Color(0xFF00897B)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _invoiceRow('Rice (10 kg)', '₹650'),
          const SizedBox(height: 6),
          _invoiceRow('Cooking Oil (5L)', '₹780'),
          const SizedBox(height: 6),
          _invoiceRow('Sugar & Spices', '₹420'),
          const SizedBox(height: 10),
          Divider(color: Colors.white.withOpacity(0.2), height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Text(
                '₹1,850',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
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
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          amount,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
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
          // Main dashboard card
          _buildDashboardCard(),

          // Floating "Overdue" alert
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5252).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF5252).withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 12,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '2 Overdue',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Floating "This Month" badge
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      color: Colors.white,
                      size: 11,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'This Month',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
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

  Widget _buildDashboardCard() {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Overview',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            '₹1,24,500',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          Text(
            'Total Billed',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 10),

          // Mini stat grid
          Row(
            children: [
              Expanded(
                child: _miniStat(
                  'Collected',
                  '₹98,200',
                  const Color(0xFF69F0AE),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniStat(
                  'Outstanding',
                  '₹26,300',
                  const Color(0xFFFFD740),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Status filter pills
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

          // Mini bar chart
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
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active
              ? const Color(0xFF00695C)
              : Colors.white.withOpacity(0.6),
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
            final scale =
                1.0 + (h - 0.5) * (_pulseAnimation.value - 1.0) * 0.05;
            return Transform.scale(
              alignment: Alignment.bottomCenter,
              scaleY: scale,
              child: child,
            );
          },
          child: Container(
            width: 20,
            height: 30 * h,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.white.withOpacity(0.6),
                  Colors.white.withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _glassCard({
    required double width,
    required double height,
    double opacity = 0.1,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(opacity),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
    );
  }
}
