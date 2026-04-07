import 'package:billeasy/l10n/app_strings.dart';
import 'package:billeasy/screens/business_card_screen.dart';
import 'package:billeasy/screens/how_to_use_screen.dart';
import 'package:billeasy/screens/language_selection_screen.dart';
import 'package:billeasy/services/remote_config_service.dart';
import 'package:billeasy/screens/login_screen.dart';
import 'package:billeasy/screens/profile_setup_screen.dart';
import 'package:billeasy/screens/privacy_policy_screen.dart';
import 'package:billeasy/screens/subscription_screen.dart';
import 'package:billeasy/screens/terms_conditions_screen.dart';
import 'package:billeasy/screens/upgrade_screen.dart';
import 'package:billeasy/screens/team_management_screen.dart';
import 'package:billeasy/screens/team_settings_screen.dart';
import 'package:billeasy/services/auth_service.dart';
import 'package:billeasy/services/plan_service.dart';
import 'package:billeasy/services/team_service.dart';
import 'package:billeasy/services/theme_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:billeasy/utils/public_links.dart';
import 'package:billeasy/widgets/aurora_app_backdrop.dart';
import 'package:billeasy/widgets/connectivity_banner.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:billeasy/utils/responsive.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  bool _isUpdatingLanguage = false;
  bool _isDeletingAccount = false;
  bool _isSigningOut = false;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final currentLanguage = strings.language;
    final currentUser = FirebaseAuth.instance.currentUser;
    final accountName = _displayNameFor(currentUser, strings);
    final accountEmail = _primaryContactFor(currentUser, strings);
    final planName = PlanService.instance.currentLimits.displayName;
    final expanded = windowSizeOf(context) == WindowSize.expanded;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          strings.settingsTitle,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AuroraAppBackdrop()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: expanded ? 1080 : kWebFormMaxWidth,
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                  children: [
                    _buildSettingsOverviewCard(
                      accountName: accountName,
                      accountEmail: accountEmail,
                      planName: planName,
                      currentUser: currentUser,
                    ),
                    const SizedBox(height: 14),
                    if (expanded)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildProfileCard(
                              currentUser: currentUser,
                              accountName: accountName,
                              accountEmail: accountEmail,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildPlanCard(
                              strings: strings,
                              planName: planName,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _buildProfileCard(
                        currentUser: currentUser,
                        accountName: accountName,
                        accountEmail: accountEmail,
                      ),
                      const SizedBox(height: 10),
                      _buildPlanCard(strings: strings, planName: planName),
                    ],

                    // ── Business Card ──
                    const SizedBox(height: 10),
                    if (TeamService.instance.can.canEditProfile)
                      _TonalCard(
                        child: _SettingsTile(
                          icon: Icons.contact_page_rounded,
                          iconBg: const Color(0xFF7C3AED),
                          title: 'Business Card',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const BusinessCardScreen(),
                            ),
                          ),
                        ),
                      ),

                    // ── Appearance ──
                    const SizedBox(height: 28),
                    _SectionLabel(title: 'APPEARANCE'),
                    const SizedBox(height: 8),
                    _TonalCard(
                      child: Column(
                        children: [
                          _buildThemeTile(
                            context,
                            AppThemeMode.system,
                            'System default',
                            Icons.brightness_auto_rounded,
                          ),
                          const _TileDivider(),
                          _buildThemeTile(
                            context,
                            AppThemeMode.light,
                            'Light',
                            Icons.light_mode_rounded,
                          ),
                          const _TileDivider(),
                          _buildThemeTile(
                            context,
                            AppThemeMode.dark,
                            'Dark',
                            Icons.dark_mode_rounded,
                          ),
                        ],
                      ),
                    ),

                    // ── Billing (owner-only) ──
                    if (TeamService.instance.can.canManageSubscription) ...[
                      const SizedBox(height: 28),
                      _SectionLabel(title: strings.settingsBilling),
                      const SizedBox(height: 8),
                      _TonalCard(
                        child: Column(
                          children: [
                            _SettingsTile(
                              icon: Icons.credit_card_outlined,
                              iconBg: const Color(0xFFAF52DE),
                              title: strings.settingsBillingPayments,
                              onTap: _openSubscription,
                            ),
                            const _TileDivider(),
                            _SettingsTile(
                              icon: Icons.auto_awesome_outlined,
                              iconBg: const Color(0xFFFF2D55),
                              title: strings.settingsUpgradePlan,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const UpgradeScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ── Team ──
                    const SizedBox(height: 28),
                    const _SectionLabel(title: 'TEAM'),
                    const SizedBox(height: 8),
                    _TonalCard(
                      child: _SettingsTile(
                        icon: Icons.groups_rounded,
                        iconBg: const Color(0xFF34C759),
                        title: TeamService.instance.isTeamMember
                            ? 'Team Settings'
                            : 'Manage Team',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TeamService.instance.isTeamMember
                                ? const TeamSettingsScreen()
                                : const TeamManagementScreen(),
                          ),
                        ),
                      ),
                    ),

                    // ── Language ──
                    const SizedBox(height: 28),
                    _SectionLabel(
                      title: strings.settingsLanguageTitle.toUpperCase(),
                    ),
                    const SizedBox(height: 8),
                    _TonalCard(
                      child: Column(
                        children: _buildLanguageTiles(currentLanguage),
                      ),
                    ),

                    // ── Legal ──
                    const SizedBox(height: 28),
                    _SectionLabel(title: strings.settingsLegal),
                    const SizedBox(height: 8),
                    _TonalCard(
                      child: Column(
                        children: [
                          _SettingsTile(
                            icon: Icons.shield_outlined,
                            iconBg: const Color(0xFF007AFF),
                            title: strings.settingsPrivacyPolicy,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const PrivacyPolicyScreen(),
                              ),
                            ),
                          ),
                          const _TileDivider(),
                          _SettingsTile(
                            icon: Icons.description_outlined,
                            iconBg: const Color(0xFF5856D6),
                            title: strings.settingsTermsConditions,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const TermsConditionsScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Trust & Support ──
                    const SizedBox(height: 28),
                    const _SectionLabel(title: 'TRUST & SUPPORT'),
                    const SizedBox(height: 8),
                    _TonalCard(
                      child: Column(
                        children: [
                          _SettingsTile(
                            icon: Icons.sell_rounded,
                            iconBg: const Color(0xFF0EA5E9),
                            title: 'Pricing & Plans',
                            onTap: () => _openPublicPage(PublicLinks.pricing),
                          ),
                          const _TileDivider(),
                          _SettingsTile(
                            icon: Icons.shield_rounded,
                            iconBg: const Color(0xFF2563EB),
                            title: 'Security Overview',
                            onTap: () => _openPublicPage(PublicLinks.security),
                          ),
                          const _TileDivider(),
                          _SettingsTile(
                            icon: Icons.support_agent_rounded,
                            iconBg: const Color(0xFF14B8A6),
                            title: 'Support & Reliability',
                            onTap: () => _openPublicPage(PublicLinks.support),
                          ),
                        ],
                      ),
                    ),

                    // ── Help ──
                    const SizedBox(height: 28),
                    const _SectionLabel(title: 'HELP'),
                    const SizedBox(height: 8),
                    _TonalCard(
                      child: _SettingsTile(
                        icon: Icons.menu_book_rounded,
                        iconBg: const Color(0xFF34C759),
                        title: 'How to Use BillRaja',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const HowToUseScreen(),
                          ),
                        ),
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
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: context.cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              strings.settingsHelpBody,
                              style: TextStyle(
                                fontSize: 13,
                                color: context.cs.onSurfaceVariant,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (currentUser != null &&
                        TeamService.instance.can.canEditProfile) ...[
                      const SizedBox(height: 28),
                      const _SectionLabel(title: 'DANGER ZONE'),
                      const SizedBox(height: 8),
                      _TonalCard(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: kOverdue.withAlpha(28),
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: const Icon(
                                      Icons.warning_amber_rounded,
                                      color: kOverdue,
                                      size: 19,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Erase profile permanently',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: context.cs.onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Deletes your account, business profile, invoices, customers, products, shared invoice links, and cancels any active subscription first.',
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: context.cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _isDeletingAccount
                                      ? null
                                      : _deleteAccount,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: kOverdue,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: kOverdue.withAlpha(
                                      140,
                                    ),
                                    disabledForegroundColor: Colors.white
                                        .withAlpha(220),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: _isDeletingAccount
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.delete_forever_rounded,
                                          size: 18,
                                        ),
                                  label: Text(
                                    _isDeletingAccount
                                        ? 'Erasing account...'
                                        : 'Erase profile permanently',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

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
                    Center(
                      child: Text(
                        'BillRaja v1.0',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.cs.onSurfaceVariant.withAlpha(153),
                        ),
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

  Widget _buildSettingsOverviewCard({
    required String accountName,
    required String accountEmail,
    required String planName,
    required User? currentUser,
  }) {
    final planState = !PlanService.instance.isFullAccess
        ? 'Upgrade available'
        : TeamService.instance.isTeamMember
        ? 'Team workspace ready'
        : 'Workspace ready';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: kSignatureGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [kWhisperShadow],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            backgroundImage: currentUser?.photoURL != null
                ? NetworkImage(currentUser!.photoURL!)
                : null,
            child: currentUser?.photoURL == null
                ? Text(
                    accountName.isNotEmpty ? accountName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  accountEmail,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SettingsHeroChip(label: '$planName Plan'),
                    _SettingsHeroChip(label: planState),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard({
    required User? currentUser,
    required String accountName,
    required String accountEmail,
  }) {
    return _TonalCard(
      child: InkWell(
        onTap: _openProfile,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: context.cs.surfaceContainerLow,
                backgroundImage: currentUser?.photoURL != null
                    ? NetworkImage(currentUser!.photoURL!)
                    : null,
                child: currentUser?.photoURL == null
                    ? Text(
                        accountName.isNotEmpty
                            ? accountName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: context.cs.onSurface,
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      accountEmail,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: context.cs.onSurfaceVariant.withAlpha(153),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required AppStrings strings,
    required String planName,
  }) {
    return _TonalCard(
      child: InkWell(
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const UpgradeScreen())),
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
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: context.cs.onPrimary,
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
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      !PlanService.instance.isFullAccess
                          ? strings.settingsUpgradeHint
                          : strings.settingsManageSubscription,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: !PlanService.instance.isFullAccess
                      ? context.cs.primaryContainer
                      : kPaidBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  !PlanService.instance.isFullAccess ? 'Upgrade' : 'Active',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: !PlanService.instance.isFullAccess
                        ? kPrimary
                        : kPaid,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Theme ──

  Widget _buildThemeTile(
    BuildContext context,
    AppThemeMode mode,
    String label,
    IconData icon,
  ) {
    final current = ThemeProvider.appThemeModeOf(context);
    final isActive = current == mode;
    final cs = context.cs;
    return InkWell(
      onTap: () => ThemeProvider.setThemeMode(context, mode),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: isActive ? cs.primary : cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(
                icon,
                color: isActive ? cs.onPrimary : cs.onSurfaceVariant,
                size: 17,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: cs.onSurface,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (isActive)
              Icon(Icons.check_rounded, color: cs.primary, size: 20),
          ],
        ),
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

  Future<void> _deleteAccount() async {
    if (_isDeletingAccount) return;
    if (ConnectivityService.instance.isOffline) {
      _showSettingsSnackBar('Go online to permanently erase your account.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirmed = await _confirmDeleteAccount();
    if (!confirmed || !mounted) return;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    setState(() => _isDeletingAccount = true);

    try {
      await _authService.deleteAccount();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      final message = error.code == 'failed-precondition'
          ? 'For security, sign out, sign back in, and then try deleting your account again.'
          : (error.message ??
                'Could not erase your account right now. Please try again.');
      _showSettingsSnackBar(message);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      _showSettingsSnackBar(
        error.message ?? 'Could not erase your account right now.',
      );
    } catch (_) {
      if (!mounted) return;
      _showSettingsSnackBar(
        'Could not erase your account right now. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isDeletingAccount = false);
    }
  }

  Future<bool> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    return confirmed ?? false;
  }

  void _showSettingsSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _openLogin() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const LoginScreen()));

  void _openProfile() {
    if (!TeamService.instance.can.canEditProfile) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the team owner can edit the business profile'),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ProfileSetupScreen(isRequiredSetup: false),
      ),
    );
  }

  void _openSubscription() {
    if (!TeamService.instance.can.canManageSubscription) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Only owner-level team members can manage subscriptions',
          ),
        ),
      );
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
  }

  Future<void> _openPublicPage(String url) async {
    try {
      await PublicLinks.open(url);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open page right now. Please try again.'),
        ),
      );
      debugPrint('[Settings] Failed to open public page: $error');
    }
  }

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

  /// Builds language tiles dynamically, filtered by Remote Config.
  List<Widget> _buildLanguageTiles(AppLanguage currentLanguage) {
    final rc = RemoteConfigService.instance;
    final enabled = rc.enabledLanguages;
    final languages = enabled.isEmpty
        ? AppLanguage.values
        : AppLanguage.values.where((l) => enabled.contains(l.name)).toList();

    final tiles = <Widget>[];
    for (var i = 0; i < languages.length; i++) {
      if (i > 0) tiles.add(const _TileDivider());
      final lang = languages[i];
      tiles.add(
        _LanguageTile(
          label: _nativeLanguageLabel(lang),
          isSelected: currentLanguage == lang,
          isBusy: _isUpdatingLanguage,
          onTap: () => _changeLanguage(lang),
        ),
      );
    }
    return tiles;
  }

  static const _nativeLabels = <AppLanguage, String>{
    AppLanguage.english: 'English',
    AppLanguage.hindi: '\u0939\u093f\u0928\u094d\u0926\u0940',
    AppLanguage.tamil: '\u0ba4\u0bae\u0bbf\u0bb4\u0bcd',
    AppLanguage.gujarati: '\u0a97\u0ac1\u0a9c\u0ab0\u0abe\u0aa4\u0ac0',
    AppLanguage.assamese: '\u0985\u09b8\u09ae\u09c0\u09af\u09bc\u09be',
  };

  String _nativeLanguageLabel(AppLanguage language) {
    return _nativeLabels[language] ?? language.name;
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
        color: context.cs.surfaceContainerLowest,
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
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: context.cs.onSurfaceVariant,
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
      color: context.cs.surfaceContainerLow,
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _canConfirm = false;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    final next = _controller.text.trim().toUpperCase() == 'DELETE';
    if (next == _canConfirm || !mounted) return;
    setState(() => _canConfirm = next);
  }

  Future<void> _confirm() async {
    if (!_canConfirm || _isClosing) return;
    setState(() => _isClosing = true);
    FocusManager.instance.primaryFocus?.unfocus();
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Erase profile permanently?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This cannot be undone. Your BillRaja account and all saved business data will be deleted forever.',
          ),
          const SizedBox(height: 12),
          Text(
            'For security, you may be asked to sign in again before deletion can finish.',
            style: TextStyle(fontSize: 13, color: context.cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Text(
            'Type DELETE to continue.',
            style: TextStyle(fontSize: 13, color: context.cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            onSubmitted: (_) => _confirm(),
            decoration: const InputDecoration(hintText: 'DELETE'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isClosing ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canConfirm ? _confirm : null,
          style: FilledButton.styleFrom(
            backgroundColor: kOverdue,
            foregroundColor: Colors.white,
          ),
          child: Text(_isClosing ? 'Erasing...' : 'Erase forever'),
        ),
      ],
    );
  }
}

class _SettingsHeroChip extends StatelessWidget {
  const _SettingsHeroChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
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
                style: TextStyle(fontSize: 15, color: context.cs.onSurface),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.cs.onSurfaceVariant,
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
        color: isSelected ? context.cs.primaryContainer.withAlpha(77) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: context.cs.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (isBusy && isSelected)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: kPrimary,
                ),
              )
            else if (isSelected)
              const Icon(Icons.check_rounded, color: kPrimary, size: 20),
          ],
        ),
      ),
    );
  }
}
