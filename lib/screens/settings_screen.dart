import 'package:billeasy/l10n/app_strings.dart';
import 'package:billeasy/screens/language_selection_screen.dart';
import 'package:billeasy/screens/customers_screen.dart';
import 'package:billeasy/screens/gst_report_screen.dart';
import 'package:billeasy/screens/invoices_screen.dart';
import 'package:billeasy/screens/login_screen.dart';
import 'package:billeasy/screens/products_screen.dart';
import 'package:billeasy/screens/profile_setup_screen.dart';
import 'package:billeasy/screens/subscription_screen.dart';
import 'package:billeasy/services/auth_service.dart';
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
    final accountLabel = _primaryContactFor(currentUser, strings);

    return Scaffold(
      appBar: AppBar(title: Text(strings.drawerSettings)),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEAF3FF), Color(0xFFF5FBFF), Color(0xFFFFFFFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HeroCard(
                title: strings.settingsHubTitle,
                subtitle: strings.settingsHubSubtitle,
                accountName: accountName,
                accountLabel: accountLabel,
                languageLabel: strings.settingsCurrentLanguage(
                  _nativeLanguageLabel(currentLanguage),
                ),
                onEditProfile: () => _openProfile(),
                onPrimaryAction: currentUser == null ? _openLogin : _signOut,
                primaryActionLabel: currentUser == null
                    ? strings.drawerLogIn
                    : strings.settingsSignOut,
                isPrimaryActionLoading: _isSigningOut,
              ),
              const SizedBox(height: 16),
              _SectionHeader(
                title: strings.settingsQuickActionsTitle,
                subtitle: strings.settingsQuickActionsSubtitle,
              ),
              const SizedBox(height: 12),
              _ActionCard(
                children: [
                  _ShortcutTile(
                    icon: Icons.badge_outlined,
                    title: strings.drawerMyProfile,
                    subtitle: strings.profilePromptBodyEdit,
                    onTap: _openProfile,
                  ),
                  const _ActionDivider(),
                  _ShortcutTile(
                    icon: Icons.people_alt_outlined,
                    title: strings.drawerCustomers,
                    subtitle: strings.drawerCustomersDesc,
                    onTap: _openCustomers,
                  ),
                  const _ActionDivider(),
                  _ShortcutTile(
                    icon: Icons.inventory_2_outlined,
                    title: strings.drawerProducts,
                    subtitle: strings.drawerProductsDesc,
                    onTap: _openProducts,
                  ),
                  const _ActionDivider(),
                  _ShortcutTile(
                    icon: Icons.receipt_long_outlined,
                    title: strings.homeBottomInvoices,
                    subtitle: strings.settingsInvoicesSubtitle,
                    onTap: _openInvoices,
                  ),
                  const _ActionDivider(),
                  _ShortcutTile(
                    icon: Icons.receipt_long_rounded,
                    title: strings.drawerGst,
                    subtitle: strings.drawerGstDesc,
                    onTap: _openGstReport,
                  ),
                  const _ActionDivider(),
                  _ShortcutTile(
                    icon: Icons.workspace_premium_outlined,
                    title: 'Subscription & Plans',
                    subtitle: 'Manage your plan, usage & billing',
                    onTap: _openSubscription,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionHeader(
                title: strings.settingsLanguageTitle,
                subtitle: strings.settingsLanguageSubtitle,
              ),
              const SizedBox(height: 12),
              _ActionCard(
                children: [
                  _LanguageOptionTile(
                    nativeLabel: 'English',
                    helperLabel: 'English',
                    isSelected: currentLanguage == AppLanguage.english,
                    isBusy: _isUpdatingLanguage,
                    onTap: () => _changeLanguage(AppLanguage.english),
                  ),
                  const _ActionDivider(),
                  _LanguageOptionTile(
                    nativeLabel: 'हिन्दी',
                    helperLabel: 'Hindi',
                    isSelected: currentLanguage == AppLanguage.hindi,
                    isBusy: _isUpdatingLanguage,
                    onTap: () => _changeLanguage(AppLanguage.hindi),
                  ),
                  const _ActionDivider(),
                  _LanguageOptionTile(
                    nativeLabel: 'অসমীয়া',
                    helperLabel: 'Assamese',
                    isSelected: currentLanguage == AppLanguage.assamese,
                    isBusy: _isUpdatingLanguage,
                    onTap: () => _changeLanguage(AppLanguage.assamese),
                  ),
                  const _ActionDivider(),
                  _LanguageOptionTile(
                    nativeLabel: 'ગુજરાતી',
                    helperLabel: 'Gujarati',
                    isSelected: currentLanguage == AppLanguage.gujarati,
                    isBusy: _isUpdatingLanguage,
                    onTap: () => _changeLanguage(AppLanguage.gujarati),
                  ),
                  const _ActionDivider(),
                  _LanguageOptionTile(
                    nativeLabel: 'தமிழ்',
                    helperLabel: 'Tamil',
                    isSelected: currentLanguage == AppLanguage.tamil,
                    isBusy: _isUpdatingLanguage,
                    onTap: () => _changeLanguage(AppLanguage.tamil),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionHeader(
                title: strings.settingsAboutTitle,
                subtitle: strings.settingsAboutBody,
              ),
              const SizedBox(height: 12),
              _ActionCard(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    leading: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E3A8A), Color(0xFF6366F1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.diamond_outlined,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      strings.settingsHelpTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    subtitle: Text(
                      strings.settingsHelpBody,
                      style: TextStyle(
                        color: Colors.blueGrey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSigningOut
                      ? null
                      : (currentUser == null ? _openLogin : _signOut),
                  icon: _isSigningOut
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          currentUser == null
                              ? Icons.login_rounded
                              : Icons.logout_rounded,
                        ),
                  label: Text(
                    currentUser == null
                        ? strings.drawerLogIn
                        : strings.settingsSignOut,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentUser == null
                        ? const Color(0xFF123C85)
                        : const Color(0xFFB3261E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changeLanguage(AppLanguage language) async {
    final currentLanguage = AppStrings.of(context).language;
    if (_isUpdatingLanguage || currentLanguage == language) {
      return;
    }

    setState(() {
      _isUpdatingLanguage = true;
    });

    try {
      await LanguageProvider.setLanguage(context, language);

      if (!mounted) {
        return;
      }

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
      if (mounted) {
        setState(() {
          _isUpdatingLanguage = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    if (_isSigningOut) {
      return;
    }

    setState(() {
      _isSigningOut = true;
    });

    try {
      await _authService.signOut();
      if (!mounted) {
        return;
      }

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.of(context).profileFailedSignOut(error.toString()),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });
      }
    }
  }

  void _openLogin() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ProfileSetupScreen(isRequiredSetup: false),
      ),
    );
  }

  void _openCustomers() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CustomersScreen()));
  }

  void _openProducts() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProductsScreen()));
  }

  void _openInvoices() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const InvoicesScreen()));
  }

  void _openGstReport() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const GstReportScreen()));
  }

  void _openSubscription() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
  }

  String _displayNameFor(User? user, AppStrings strings) {
    final displayName = user?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    return strings.drawerMyProfileFallback;
  }

  String _primaryContactFor(User? user, AppStrings strings) {
    final email = user?.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email;
    }

    final phone = user?.phoneNumber?.trim();
    if (phone != null && phone.isNotEmpty) {
      return phone;
    }

    return strings.drawerNotSignedIn;
  }

  String _nativeLanguageLabel(AppLanguage language) {
    return switch (language) {
      AppLanguage.english => 'English',
      AppLanguage.hindi => 'हिन्दी',
      AppLanguage.assamese => 'অসমীয়া',
      AppLanguage.gujarati => 'ગુજરાતી',
      AppLanguage.tamil => 'தமிழ்',
    };
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.subtitle,
    required this.accountName,
    required this.accountLabel,
    required this.languageLabel,
    required this.onEditProfile,
    required this.onPrimaryAction,
    required this.primaryActionLabel,
    required this.isPrimaryActionLoading,
  });

  final String title;
  final String subtitle;
  final String accountName;
  final String accountLabel;
  final String languageLabel;
  final VoidCallback onEditProfile;
  final VoidCallback onPrimaryAction;
  final String primaryActionLabel;
  final bool isPrimaryActionLoading;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF123C85), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroChip(icon: Icons.person_outline_rounded, label: accountName),
              _HeroChip(icon: Icons.language_rounded, label: languageLabel),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            accountLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            strings.settingsHeroHint,
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEditProfile,
                  icon: const Icon(Icons.badge_outlined, size: 18),
                  label: Text(strings.settingsEditProfile),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.38),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onPrimaryAction,
                  icon: isPrimaryActionLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.logout_rounded, size: 18),
                  label: Text(primaryActionLabel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF123C85),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: Colors.blueGrey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFD7E2F3)),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _ActionDivider extends StatelessWidget {
  const _ActionDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, indent: 18, endIndent: 18);
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF8FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: const Color(0xFF123C85)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: Colors.blueGrey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.blueGrey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageOptionTile extends StatelessWidget {
  const _LanguageOptionTile({
    required this.nativeLabel,
    required this.helperLabel,
    required this.isSelected,
    required this.isBusy,
    required this.onTap,
  });

  final String nativeLabel;
  final String helperLabel;
  final bool isSelected;
  final bool isBusy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isBusy ? null : onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEAF8FF) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF123C85)
                  : const Color(0xFFD7E2F3),
              width: isSelected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFE4F7F8),
                foregroundColor: const Color(0xFF6366F1),
                child: const Icon(Icons.language_rounded),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nativeLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      helperLabel,
                      style: TextStyle(
                        color: Colors.blueGrey.shade700,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (isBusy && isSelected)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              else
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.chevron_right_rounded,
                  color: isSelected
                      ? const Color(0xFF123C85)
                      : Colors.blueGrey.shade400,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
