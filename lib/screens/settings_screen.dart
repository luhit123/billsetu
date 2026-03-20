import 'package:billeasy/l10n/app_strings.dart';
import 'package:billeasy/screens/language_selection_screen.dart';
import 'package:billeasy/screens/customers_screen.dart';
import 'package:billeasy/screens/gst_report_screen.dart';
import 'package:billeasy/screens/invoices_screen.dart';
import 'package:billeasy/screens/login_screen.dart';
import 'package:billeasy/screens/products_screen.dart';
import 'package:billeasy/screens/profile_setup_screen.dart';
import 'package:billeasy/screens/privacy_policy_screen.dart';
import 'package:billeasy/screens/subscription_screen.dart';
import 'package:billeasy/screens/terms_conditions_screen.dart';
import 'package:billeasy/screens/upgrade_screen.dart';
import 'package:billeasy/services/auth_service.dart';
import 'package:billeasy/services/plan_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  bool _isUpdatingLanguage = false;
  bool _isSigningOut = false;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final currentLanguage = strings.language;
    final currentUser = FirebaseAuth.instance.currentUser;
    final accountName = _displayNameFor(currentUser, strings);
    final accountEmail = _primaryContactFor(currentUser, strings);
    final planName = PlanService.instance.currentLimits.displayName;

    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: kOnSurface,
          ),
        ),
        backgroundColor: kSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          // ── Profile ──
          _TonalCard(
            child: InkWell(
              onTap: _openProfile,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: kSurfaceContainerLow,
                      backgroundImage: currentUser?.photoURL != null
                          ? NetworkImage(currentUser!.photoURL!)
                          : null,
                      child: currentUser?.photoURL == null
                          ? Text(
                              accountName.isNotEmpty
                                  ? accountName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: kOnSurface,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            accountName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: kOnSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            accountEmail,
                            style: const TextStyle(
                              fontSize: 13,
                              color: kOnSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: kTextTertiary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Plan ──
          const SizedBox(height: 10),
          _TonalCard(
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UpgradeScreen()),
              ),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: kSignatureGradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.workspace_premium_rounded,
                        color: kOnPrimary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$planName Plan',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: kOnSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            planName == 'Free'
                                ? 'Upgrade for more features'
                                : 'Manage subscription',
                            style: const TextStyle(
                              fontSize: 13,
                              color: kOnSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: planName == 'Free'
                            ? kPrimaryContainer
                            : kPaidBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        planName == 'Free' ? 'Upgrade' : 'Active',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: planName == 'Free' ? kPrimary : kPaid,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Business ──
          const SizedBox(height: 28),
          const _SectionLabel(title: 'BUSINESS'),
          const SizedBox(height: 8),
          _TonalCard(
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.people_alt_outlined,
                  iconBg: const Color(0xFF007AFF),
                  title: strings.drawerCustomers,
                  onTap: _openCustomers,
                ),
                const _TileDivider(),
                _SettingsTile(
                  icon: Icons.inventory_2_outlined,
                  iconBg: const Color(0xFFFF9500),
                  title: strings.drawerProducts,
                  onTap: _openProducts,
                ),
                const _TileDivider(),
                _SettingsTile(
                  icon: Icons.receipt_long_outlined,
                  iconBg: const Color(0xFF34C759),
                  title: strings.homeBottomInvoices,
                  onTap: _openInvoices,
                ),
                const _TileDivider(),
                _SettingsTile(
                  icon: Icons.assessment_outlined,
                  iconBg: const Color(0xFF5856D6),
                  title: strings.drawerGst,
                  onTap: _openGstReport,
                ),
              ],
            ),
          ),

          // ── Billing ──
          const SizedBox(height: 28),
          const _SectionLabel(title: 'BILLING'),
          const SizedBox(height: 8),
          _TonalCard(
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.credit_card_outlined,
                  iconBg: const Color(0xFFAF52DE),
                  title: 'Billing & Payments',
                  onTap: _openSubscription,
                ),
                const _TileDivider(),
                _SettingsTile(
                  icon: Icons.auto_awesome_outlined,
                  iconBg: const Color(0xFFFF2D55),
                  title: 'Upgrade Plan',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const UpgradeScreen()),
                  ),
                ),
              ],
            ),
          ),

          // ── Language ──
          const SizedBox(height: 28),
          _SectionLabel(
              title: strings.settingsLanguageTitle.toUpperCase()),
          const SizedBox(height: 8),
          _TonalCard(
            child: Column(
              children: [
                _LanguageTile(
                  label: 'English',
                  isSelected: currentLanguage == AppLanguage.english,
                  isBusy: _isUpdatingLanguage,
                  onTap: () => _changeLanguage(AppLanguage.english),
                ),
                const _TileDivider(),
                _LanguageTile(
                  label: '\u0939\u093F\u0928\u094D\u0926\u0940',
                  isSelected: currentLanguage == AppLanguage.hindi,
                  isBusy: _isUpdatingLanguage,
                  onTap: () => _changeLanguage(AppLanguage.hindi),
                ),
                const _TileDivider(),
                _LanguageTile(
                  label: '\u0985\u09B8\u09AE\u09C0\u09AF\u09BC\u09BE',
                  isSelected: currentLanguage == AppLanguage.assamese,
                  isBusy: _isUpdatingLanguage,
                  onTap: () => _changeLanguage(AppLanguage.assamese),
                ),
                const _TileDivider(),
                _LanguageTile(
                  label: '\u0A97\u0AC1\u0A9C\u0AB0\u0ABE\u0AA4\u0AC0',
                  isSelected: currentLanguage == AppLanguage.gujarati,
                  isBusy: _isUpdatingLanguage,
                  onTap: () => _changeLanguage(AppLanguage.gujarati),
                ),
                const _TileDivider(),
                _LanguageTile(
                  label: '\u0BA4\u0BAE\u0BBF\u0BB4\u0BCD',
                  isSelected: currentLanguage == AppLanguage.tamil,
                  isBusy: _isUpdatingLanguage,
                  onTap: () => _changeLanguage(AppLanguage.tamil),
                ),
              ],
            ),
          ),

          // ── Legal ──
          const SizedBox(height: 28),
          const _SectionLabel(title: 'LEGAL'),
          const SizedBox(height: 8),
          _TonalCard(
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.shield_outlined,
                  iconBg: const Color(0xFF007AFF),
                  title: 'Privacy Policy',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyScreen()),
                  ),
                ),
                const _TileDivider(),
                _SettingsTile(
                  icon: Icons.description_outlined,
                  iconBg: const Color(0xFF5856D6),
                  title: 'Terms & Conditions',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const TermsConditionsScreen()),
                  ),
                ),
              ],
            ),
          ),

          // ── About ──
          const SizedBox(height: 28),
          const _SectionLabel(title: 'ABOUT'),
          const SizedBox(height: 8),
          _TonalCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.settingsHelpTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: kOnSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    strings.settingsHelpBody,
                    style: const TextStyle(
                      fontSize: 13,
                      color: kOnSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Sign Out ──
          const SizedBox(height: 28),
          _TonalCard(
            child: InkWell(
              onTap: _isSigningOut
                  ? null
                  : (currentUser == null ? _openLogin : _signOut),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: _isSigningOut
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: kPrimary,
                          ),
                        )
                      : Text(
                          currentUser == null
                              ? strings.drawerLogIn
                              : strings.settingsSignOut,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: currentUser == null
                                ? kPrimary
                                : kOverdue,
                          ),
                        ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),
          const Center(
            child: Text(
              'BillEasy v1.0',
              style: TextStyle(fontSize: 12, color: kTextTertiary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Actions ──

  Future<void> _changeLanguage(AppLanguage language) async {
    final currentLanguage = AppStrings.of(context).language;
    if (_isUpdatingLanguage || currentLanguage == language) return;

    setState(() => _isUpdatingLanguage = true);

    try {
      await LanguageProvider.setLanguage(context, language);
      if (!mounted) return;

      final strings = AppStrings.of(context);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              strings.settingsLanguageChanged(_nativeLanguageLabel(language)),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _isUpdatingLanguage = false);
    }
  }

  Future<void> _signOut() async {
    if (_isSigningOut) return;
    setState(() => _isSigningOut = true);

    try {
      await _authService.signOut();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.of(context).profileFailedSignOut(error.toString()),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  void _openLogin() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const LoginScreen()));

  void _openProfile() => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const ProfileSetupScreen(isRequiredSetup: false)));

  void _openCustomers() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const CustomersScreen()));

  void _openProducts() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const ProductsScreen()));

  void _openInvoices() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const InvoicesScreen()));

  void _openGstReport() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const GstReportScreen()));

  void _openSubscription() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const SubscriptionScreen()));

  String _displayNameFor(User? user, AppStrings strings) {
    final displayName = user?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    return strings.drawerMyProfileFallback;
  }

  String _primaryContactFor(User? user, AppStrings strings) {
    final email = user?.email?.trim();
    if (email != null && email.isNotEmpty) return email;
    final phone = user?.phoneNumber?.trim();
    if (phone != null && phone.isNotEmpty) return phone;
    return strings.drawerNotSignedIn;
  }

  String _nativeLanguageLabel(AppLanguage language) {
    return switch (language) {
      AppLanguage.english => 'English',
      AppLanguage.hindi => '\u0939\u093F\u0928\u094D\u0926\u0940',
      AppLanguage.assamese => '\u0985\u09B8\u09AE\u09C0\u09AF\u09BC\u09BE',
      AppLanguage.gujarati => '\u0A97\u0AC1\u0A9C\u0AB0\u0ABE\u0AA4\u0AC0',
      AppLanguage.tamil => '\u0BA4\u0BAE\u0BBF\u0BB4\u0BCD',
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tonal Components (no borders — surface layering only)
// ═══════════════════════════════════════════════════════════════════════════════

class _TonalCard extends StatelessWidget {
  const _TonalCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: kSurfaceLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: kTextTertiary,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.only(left: 52),
      color: kSurfaceContainerLow,
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.iconBg,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color iconBg;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, color: Colors.white, size: 17),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  color: kOnSurface,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: kTextTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.label,
    required this.isSelected,
    required this.isBusy,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool isBusy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isBusy ? null : onTap,
      child: Container(
        color: isSelected ? kPrimaryContainer.withOpacity(0.3) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: kOnSurface,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (isBusy && isSelected)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: kPrimary),
              )
            else if (isSelected)
              const Icon(Icons.check_rounded, color: kPrimary, size: 20),
          ],
        ),
      ),
    );
  }
}
