import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'firebase_options.dart';

typedef _Json = Map<String, dynamic>;

const kCanvas = Color(0xFFF4F7FB);
const kInk = Color(0xFF0F172A);
const kPrimary = Color(0xFF2563FF);
const kPrimarySoft = Color(0xFF87A8FF);
const kMint = Color(0xFF22C55E);
const kAmber = Color(0xFFF59E0B);
const kRose = Color(0xFFF43F5E);
const kCyan = Color(0xFF06B6D4);
const kViolet = Color(0xFF8B5CF6);
const kSlate = Color(0xFF64748B);
const kSurfaceBorder = Color(0xFFE2E8F0);

final _db = FirebaseFirestore.instance;
final _currencyFormat = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '\u20B9',
);
final _compactFormat = NumberFormat.compact(locale: 'en_IN');
final _shortDate = DateFormat('dd MMM yyyy');
final _shortDateTime = DateFormat('dd MMM, hh:mm a');

extension _ColorSchemeX on BuildContext {
  TextTheme get tt => Theme.of(this).textTheme;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: kPrimary,
        brightness: Brightness.light,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: kCanvas,
    );

    final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme)
        .copyWith(
          displayLarge: GoogleFonts.spaceGrotesk(
            fontSize: 46,
            fontWeight: FontWeight.w700,
            color: kInk,
          ),
          displayMedium: GoogleFonts.spaceGrotesk(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: kInk,
          ),
          headlineLarge: GoogleFonts.spaceGrotesk(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: kInk,
          ),
          headlineMedium: GoogleFonts.spaceGrotesk(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: kInk,
          ),
          titleLarge: GoogleFonts.spaceGrotesk(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: kInk,
          ),
          titleMedium: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: kInk,
          ),
          bodyLarge: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: kInk,
          ),
          bodyMedium: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: kInk,
          ),
          labelLarge: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: kInk,
          ),
        );

    return MaterialApp(
      title: 'BillRaja Admin',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        textTheme: textTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: kInk,
          centerTitle: false,
          titleTextStyle: textTheme.titleLarge,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: kSurfaceBorder.withValues(alpha: 0.7),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: kPrimary, width: 1.25),
          ),
        ),
        chipTheme: base.chipTheme.copyWith(
          side: BorderSide(color: kSurfaceBorder.withValues(alpha: 0.8)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: kPrimary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: kInk,
            side: BorderSide(color: kSurfaceBorder.withValues(alpha: 0.9)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;
  bool _isAuthorized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    setState(() {
      _checking = true;
      _error = null;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _checking = false);
      return;
    }

    try {
      final doc = await _db
          .collection('authorizedAdmins')
          .doc(user.email)
          .get();
      if (!mounted) return;
      setState(() {
        _isAuthorized = doc.exists;
        _checking = false;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;
      if (e.code == 'permission-denied') {
        setState(() {
          _isAuthorized = false;
          _checking = false;
          _error = null;
        });
        return;
      }
      setState(() {
        _checking = false;
        _error = 'Failed to verify admin access: $e';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = 'Failed to verify admin access: $e';
      });
    }
  }

  Future<void> _signIn() async {
    setState(() {
      _checking = true;
      _error = null;
    });

    try {
      final provider = GoogleAuthProvider()..addScope('email');
      await FirebaseAuth.instance.signInWithPopup(provider);
      await _checkAuth();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = 'Sign-in failed: $e';
      });
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _isAuthorized = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _buildLoginScreen(context);
    if (!_isAuthorized) return _buildAccessDenied(context, user);
    return AdminDashboard(onSignOut: _signOut);
  }

  Widget _buildLoginScreen(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 960;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8FBFF), Color(0xFFF5F7FB), Color(0xFFEEF3FF)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              left: -120,
              child: _GlowOrb(color: kPrimary, size: 280),
            ),
            Positioned(
              bottom: -140,
              right: -80,
              child: _GlowOrb(color: kCyan, size: 240),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: wide
                      ? Row(
                          children: [
                            Expanded(child: _buildLoginIntro(context)),
                            const SizedBox(width: 28),
                            SizedBox(
                              width: 420,
                              child: _buildLoginCard(context),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildLoginIntro(context, compact: true),
                            const SizedBox(height: 24),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: _buildLoginCard(context),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginIntro(BuildContext context, {bool compact = false}) {
    return Padding(
      padding: EdgeInsets.only(right: compact ? 0 : 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: compact
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: kPrimary.withValues(alpha: 0.12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: kMint,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Secure admin console for BillRaja',
                  style: context.tt.labelLarge?.copyWith(color: kSlate),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Operate growth, billing, and risk from one beautiful dashboard.',
            textAlign: compact ? TextAlign.center : TextAlign.start,
            style: context.tt.displayMedium?.copyWith(height: 1.06),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(
              'Track user growth, subscriptions, revenue, team activity, and broadcasts from one place.',
              textAlign: compact ? TextAlign.center : TextAlign.start,
              style: context.tt.bodyLarge?.copyWith(color: kSlate, height: 1.5),
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            alignment: compact ? WrapAlignment.center : WrapAlignment.start,
            spacing: 12,
            runSpacing: 12,
            children: const [
              _FeaturePill(
                icon: Icons.auto_graph_rounded,
                label: 'Growth insights',
              ),
              _FeaturePill(
                icon: Icons.security_rounded,
                label: 'Admin-only access',
              ),
              _FeaturePill(
                icon: Icons.campaign_rounded,
                label: 'Live operations',
              ),
              _FeaturePill(
                icon: Icons.payments_rounded,
                label: 'Billing control',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: kSurfaceBorder.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 50,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F4CFF), Color(0xFF49A5FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(height: 20),
          Text('Sign in to BillRaja Admin', style: context.tt.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Only allow-listed Google accounts can enter the dashboard.',
            style: context.tt.bodyMedium?.copyWith(color: kSlate, height: 1.5),
          ),
          if (_error != null) ...[
            const SizedBox(height: 18),
            _InlineNotice(
              color: kRose,
              icon: Icons.error_outline_rounded,
              message: _error!,
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _signIn,
              icon: const Icon(Icons.login_rounded),
              label: const Text('Continue with Google'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessDenied(BuildContext context, User user) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: kSurfaceBorder.withValues(alpha: 0.9),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: kRose.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_person_rounded,
                      size: 40,
                      color: kRose,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Access denied', style: context.tt.headlineMedium),
                  const SizedBox(height: 10),
                  Text(
                    'The account "${user.email}" is not listed in `authorizedAdmins`.',
                    textAlign: TextAlign.center,
                    style: context.tt.bodyLarge?.copyWith(
                      color: kSlate,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Sign out and use another account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminDashboard extends StatefulWidget {
  final VoidCallback onSignOut;

  const AdminDashboard({super.key, required this.onSignOut});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedTab = 0;

  static const _tabs = [
    _AdminTabInfo(
      icon: Icons.space_dashboard_rounded,
      label: 'Command',
      description: 'App performance and live alerts',
    ),
    _AdminTabInfo(
      icon: Icons.people_alt_rounded,
      label: 'Users',
      description: 'Access, trial, and account actions',
    ),
    _AdminTabInfo(
      icon: Icons.card_membership_rounded,
      label: 'Subscriptions',
      description: 'MRR, renewals, and plan health',
    ),
    _AdminTabInfo(
      icon: Icons.groups_rounded,
      label: 'Teams',
      description: 'Ownership and member operations',
    ),
    _AdminTabInfo(
      icon: Icons.settings_suggest_rounded,
      label: 'Ops',
      description: 'Notifications and system tools',
    ),
  ];

  void _selectTab(int index) {
    if (_selectedTab == index) {
      if (!(_scaffoldKey.currentState?.isDrawerOpen ?? false)) return;
    }

    setState(() => _selectedTab = index);
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 1080;
    final user = FirebaseAuth.instance.currentUser;

    final page = IndexedStack(
      index: _selectedTab,
      children: [
        _CommandCenterTab(onNavigate: _selectTab),
        const _UserManagementTab(),
        const _SubscriptionManagementTab(),
        const _TeamManagementTab(),
        const _SystemToolsTab(),
      ],
    );

    final shell = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8FBFF), Color(0xFFF3F6FB), Color(0xFFEFF4FF)],
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (isWide)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 0, 18),
                child: SizedBox(
                  width: 290,
                  child: _SidebarContent(
                    email: user?.email ?? '',
                    selectedIndex: _selectedTab,
                    tabs: _tabs,
                    onSelect: _selectTab,
                    onSignOut: widget.onSignOut,
                  ),
                ),
              ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(isWide ? 18 : 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(isWide ? 32 : 0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.86),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF0F172A,
                          ).withValues(alpha: 0.07),
                          blurRadius: 50,
                          offset: const Offset(0, 26),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        if (!isWide)
                          _MobileShellHeader(
                            currentTab: _tabs[_selectedTab],
                            onMenu: () =>
                                _scaffoldKey.currentState?.openDrawer(),
                            onSignOut: widget.onSignOut,
                          ),
                        Expanded(child: page),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.transparent,
      drawer: isWide
          ? null
          : Drawer(
              shape: const RoundedRectangleBorder(),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _SidebarContent(
                    email: user?.email ?? '',
                    selectedIndex: _selectedTab,
                    tabs: _tabs,
                    onSelect: _selectTab,
                    onSignOut: widget.onSignOut,
                    compact: true,
                  ),
                ),
              ),
            ),
      body: shell,
    );
  }
}

class _AdminTabInfo {
  final IconData icon;
  final String label;
  final String description;

  const _AdminTabInfo({
    required this.icon,
    required this.label,
    required this.description,
  });
}

class _SidebarContent extends StatelessWidget {
  final String email;
  final int selectedIndex;
  final List<_AdminTabInfo> tabs;
  final ValueChanged<int> onSelect;
  final VoidCallback onSignOut;
  final bool compact;

  const _SidebarContent({
    required this.email,
    required this.selectedIndex,
    required this.tabs,
    required this.onSelect,
    required this.onSignOut,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B1324), Color(0xFF13243E), Color(0xFF0F2B63)],
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5EA0FF), Color(0xFF87F4FF)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'BillRaja Admin',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Beautiful control for billing, growth, and operations.',
                  style: context.tt.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                const _SidebarStatusPill(
                  icon: Icons.wifi_tethering_rounded,
                  label: 'Connected to Firestore',
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Workspace',
            style: context.tt.labelLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.56),
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < tabs.length; i++) ...[
            _SidebarButton(
              info: tabs[i],
              selected: i == selectedIndex,
              compact: compact,
              onTap: () => onSelect(i),
            ),
            const SizedBox(height: 8),
          ],
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                  child: Text(
                    email.isNotEmpty ? email[0].toUpperCase() : 'A',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        email.isEmpty ? 'Signed in' : email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.bodyMedium?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Authorized admin',
                        style: context.tt.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Sign out',
                  onPressed: onSignOut,
                  icon: const Icon(Icons.logout_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarButton extends StatelessWidget {
  final _AdminTabInfo info;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  const _SidebarButton({
    required this.info,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.04),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.14)
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(info.icon, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.label,
                      style: context.tt.titleMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    if (!compact)
                      Text(
                        info.description,
                        style: context.tt.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.66),
                        ),
                      ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarStatusPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SidebarStatusPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF9AE6B4)),
          const SizedBox(width: 8),
          Text(
            label,
            style: context.tt.labelLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileShellHeader extends StatelessWidget {
  final _AdminTabInfo currentTab;
  final VoidCallback onMenu;
  final VoidCallback onSignOut;

  const _MobileShellHeader({
    required this.currentTab,
    required this.onMenu,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Row(
        children: [
          IconButton(onPressed: onMenu, icon: const Icon(Icons.menu_rounded)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(currentTab.label, style: context.tt.titleMedium),
                Text(
                  currentTab.description,
                  style: context.tt.bodySmall?.copyWith(color: kSlate),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onSignOut,
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
    );
  }
}

class _AdminPage extends StatelessWidget {
  final String badge;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final Future<void> Function()? onRefresh;
  final List<Widget> children;

  const _AdminPage({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.children,
    this.trailing,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final scroll = LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth >= 960 ? 28.0 : 18.0;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(horizontal, 22, horizontal, 28),
          children: [
            _PageHero(
              badge: badge,
              title: title,
              subtitle: subtitle,
              trailing: trailing,
            ),
            const SizedBox(height: 22),
            ...children,
          ],
        );
      },
    );

    if (onRefresh == null) return scroll;
    return RefreshIndicator(onRefresh: onRefresh!, child: scroll);
  }
}

class _PageHero extends StatelessWidget {
  final String badge;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _PageHero({
    required this.badge,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 980;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF8FBFF)],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: kSurfaceBorder.withValues(alpha: 0.8)),
      ),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _PageHeroText(
                    badge: badge,
                    title: title,
                    subtitle: subtitle,
                  ),
                ),
                ...(trailing == null ? const <Widget>[] : <Widget>[trailing!]),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PageHeroText(badge: badge, title: title, subtitle: subtitle),
                if (trailing != null) ...[
                  const SizedBox(height: 16),
                  trailing!,
                ],
              ],
            ),
    );
  }
}

class _PageHeroText extends StatelessWidget {
  final String badge;
  final String title;
  final String subtitle;

  const _PageHeroText({
    required this.badge,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: kPrimary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            badge,
            style: context.tt.labelLarge?.copyWith(color: kPrimary),
          ),
        ),
        const SizedBox(height: 16),
        Text(title, style: context.tt.headlineLarge),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Text(
            subtitle,
            style: context.tt.bodyLarge?.copyWith(color: kSlate, height: 1.6),
          ),
        ),
      ],
    );
  }
}

class _InlineNotice extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String message;

  const _InlineNotice({
    required this.color,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: context.tt.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kSurfaceBorder.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: kPrimary, size: 18),
          const SizedBox(width: 8),
          Text(label, style: context.tt.labelLarge),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.22),
              color.withValues(alpha: 0.1),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: kSurfaceBorder.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.tt.titleLarge),
                    if (subtitle != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle!,
                        style: context.tt.bodyMedium?.copyWith(
                          color: kSlate,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  final IconData icon;
  final Color accent;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: kSurfaceBorder.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: context.tt.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: context.tt.labelLarge?.copyWith(color: kSlate)),
          const SizedBox(height: 8),
          Text(
            hint,
            style: context.tt.bodySmall?.copyWith(
              color: kSlate.withValues(alpha: 0.92),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _StatusPill({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
          ],
          Text(label, style: context.tt.labelLarge?.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _DistributionRow extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;
  final String? suffix;

  const _DistributionRow({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total <= 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: context.tt.bodyMedium)),
            Text(
              suffix ?? _compactFormat.format(value),
              style: context.tt.labelLarge?.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 9,
            backgroundColor: color.withValues(alpha: 0.12),
            color: color,
          ),
        ),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final _ActivityItem item;

  const _ActivityTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: item.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: context.tt.titleMedium),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: context.tt.bodySmall?.copyWith(
                    color: kSlate,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _timeAgo(item.time),
            style: context.tt.bodySmall?.copyWith(color: kSlate),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: kPrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: kPrimary),
          ),
          const SizedBox(height: 14),
          Text(title, style: context.tt.titleMedium),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.tt.bodyMedium?.copyWith(color: kSlate, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _AdminAlert {
  final String title;
  final String message;
  final IconData icon;
  final Color color;

  const _AdminAlert({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
  });
}

class _ActivityItem {
  final String title;
  final String subtitle;
  final DateTime? time;
  final IconData icon;
  final Color color;

  const _ActivityItem({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.icon,
    required this.color,
  });
}

class _CommandCenterTab extends StatefulWidget {
  final ValueChanged<int> onNavigate;

  const _CommandCenterTab({required this.onNavigate});

  @override
  State<_CommandCenterTab> createState() => _CommandCenterTabState();
}

class _CommandCenterTabState extends State<_CommandCenterTab> {
  bool _loading = true;
  String _period = '30d';

  int _totalUsers = 0;
  int _activeSubscriptions = 0;
  int _totalTeams = 0;
  int _mrrInPaise = 0;
  int _trialUsers = 0;
  int _expiredSubscriptions = 0;
  int _atRiskSubscriptions = 0;
  int _inactiveTeams = 0;
  int _windowUsers = 0;
  Map<String, int> _planDistribution = {};
  List<_AdminAlert> _alerts = const [];
  List<_ActivityItem> _activity = const [];
  DateTime? _lastLoadedAt;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  DateTime get _cutoff {
    final now = DateTime.now();
    switch (_period) {
      case '7d':
        return now.subtract(const Duration(days: 7));
      case '90d':
        return now.subtract(const Duration(days: 90));
      default:
        return now.subtract(const Duration(days: 30));
    }
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final cutoffTs = Timestamp.fromDate(_cutoff);
      final results = await Future.wait<dynamic>([
        _db.collection('users').count().get(), // 0
        _db
            .collection('subscriptions')
            .where('status', isEqualTo: 'active')
            .count()
            .get(), // 1
        _db.collection('teams').count().get(), // 2
        _db
            .collection('users')
            .where(
              'trialExpiresAt',
              isGreaterThan: Timestamp.fromDate(DateTime.now()),
            )
            .count()
            .get(), // 3
        _db
            .collection('subscriptions')
            .where('status', isEqualTo: 'expired')
            .count()
            .get(), // 4
        _db
            .collection('subscriptions')
            .where('status', whereIn: ['paused', 'halted', 'cancelled'])
            .count()
            .get(), // 5
        _db
            .collection('teams')
            .where('isActive', isEqualTo: false)
            .count()
            .get(), // 6
        _db.collection('subscriptions').limit(250).get(), // 7
        _db
            .collection('users')
            .where('createdAt', isGreaterThanOrEqualTo: cutoffTs)
            .count()
            .get(), // 8
        _db
            .collection('users')
            .orderBy('createdAt', descending: true)
            .limit(8)
            .get(), // 9
        _db
            .collection('notificationRequests')
            .orderBy('createdAt', descending: true)
            .limit(8)
            .get(), // 10
      ]);

      final subDocs = (results[7] as QuerySnapshot).docs;
      final recentUsers = (results[9] as QuerySnapshot).docs;
      final recentNotifications = (results[10] as QuerySnapshot).docs;

      var mrr = 0;
      final planDist = <String, int>{};
      for (final doc in subDocs) {
        final data = _docMap(doc);
        final plan = _text(data['plan'], fallback: 'free').toLowerCase();
        final status = _text(data['status'], fallback: 'unknown').toLowerCase();
        final cycle = _text(
          data['billingCycle'],
          fallback: 'monthly',
        ).toLowerCase();
        planDist[plan] = (planDist[plan] ?? 0) + 1;
        if (status == 'active') {
          final price = _toInt(data['priceInPaise']);
          mrr += cycle == 'annual' ? (price / 12).round() : price;
        }
      }

      final alerts = <_AdminAlert>[
        if ((results[4] as AggregateQuerySnapshot).count != null &&
            ((results[4] as AggregateQuerySnapshot).count! > 0 ||
                (results[5] as AggregateQuerySnapshot).count! > 0))
          _AdminAlert(
            title: 'Renewal risk is building up',
            message:
                '${(results[4] as AggregateQuerySnapshot).count ?? 0} expired and ${(results[5] as AggregateQuerySnapshot).count ?? 0} paused or cancelled subscriptions.',
            icon: Icons.restart_alt_rounded,
            color: kAmber,
          ),
        if ((results[6] as AggregateQuerySnapshot).count != null &&
            (results[6] as AggregateQuerySnapshot).count! > 0)
          _AdminAlert(
            title: 'Inactive teams detected',
            message:
                '${(results[6] as AggregateQuerySnapshot).count} teams are marked inactive.',
            icon: Icons.group_off_rounded,
            color: kViolet,
          ),
      ];

      final activity =
          <_ActivityItem>[
            ...recentUsers.take(5).map((doc) {
              final data = _docMap(doc);
              return _ActivityItem(
                title: 'New user: ${_bestUserName(data)}',
                subtitle: data['email']?.toString().isNotEmpty == true
                    ? data['email'].toString()
                    : data['phone']?.toString() ?? 'New account created',
                time: _toDate(data['createdAt']),
                icon: Icons.person_add_alt_1_rounded,
                color: kPrimary,
              );
            }),
            ...recentNotifications.take(3).map((doc) {
              final data = _docMap(doc);
              final status = _text(data['status'], fallback: 'pending');
              return _ActivityItem(
                title: _text(data['title'], fallback: 'Broadcast request'),
                subtitle:
                    '${status.toUpperCase()} • ${_targetLabel(data['target'])}',
                time: _toDate(data['createdAt']),
                icon: Icons.campaign_rounded,
                color: status == 'completed' ? kMint : kAmber,
              );
            }),
          ]..sort(
            (a, b) => (b.time ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(a.time ?? DateTime.fromMillisecondsSinceEpoch(0)),
          );

      if (!mounted) return;
      setState(() {
        _totalUsers = (results[0] as AggregateQuerySnapshot).count ?? 0;
        _activeSubscriptions =
            (results[1] as AggregateQuerySnapshot).count ?? 0;
        _totalTeams = (results[2] as AggregateQuerySnapshot).count ?? 0;
        _trialUsers = (results[3] as AggregateQuerySnapshot).count ?? 0;
        _expiredSubscriptions =
            (results[4] as AggregateQuerySnapshot).count ?? 0;
        _atRiskSubscriptions =
            (results[5] as AggregateQuerySnapshot).count ?? 0;
        _inactiveTeams = (results[6] as AggregateQuerySnapshot).count ?? 0;
        _mrrInPaise = mrr;
        _windowUsers = (results[8] as AggregateQuerySnapshot).count ?? 0;
        _planDistribution = planDist;
        _alerts = alerts;
        _activity = activity.take(8).toList();
        _lastLoadedAt = DateTime.now();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Failed to load command center data: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: kRose));
  }

  @override
  Widget build(BuildContext context) {
    return _AdminPage(
      badge: 'Command Center',
      title: 'Live admin pulse',
      subtitle:
          'Track user growth, subscriptions, revenue, and team operations from a single overview. Last synced ${_timeAgo(_lastLoadedAt)}.',
      trailing: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _PeriodChoice(
            value: _period,
            onChanged: (value) {
              setState(() => _period = value);
              _loadStats();
            },
          ),
          FilledButton.tonalIcon(
            onPressed: _loadStats,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
          ),
        ],
      ),
      onRefresh: _loadStats,
      children: _loading
          ? const [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 120),
                child: Center(child: CircularProgressIndicator()),
              ),
            ]
          : [
              _buildSpotlight(context),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final columns = width >= 1280
                      ? 5
                      : width >= 840
                      ? 3
                      : 1;
                  final cardWidth = _splitWidth(width, columns);
                  final cards = [
                    _MetricCard(
                      label: 'Total users',
                      value: _compactFormat.format(_totalUsers),
                      hint:
                          '${_compactFormat.format(_windowUsers)} joined in this period',
                      icon: Icons.people_alt_rounded,
                      accent: kPrimary,
                    ),
                    _MetricCard(
                      label: 'Active subscriptions',
                      value: _compactFormat.format(_activeSubscriptions),
                      hint:
                          '${_compactFormat.format(_trialUsers)} accounts are still on trial',
                      icon: Icons.workspace_premium_rounded,
                      accent: kViolet,
                    ),
                    _MetricCard(
                      label: 'MRR',
                      value: _currencyFormat.format(_mrrInPaise / 100),
                      hint:
                          '${_compactFormat.format(_expiredSubscriptions + _atRiskSubscriptions)} subs need follow-up',
                      icon: Icons.currency_rupee_rounded,
                      accent: kMint,
                    ),
                    _MetricCard(
                      label: 'Teams',
                      value: _compactFormat.format(_totalTeams),
                      hint:
                          '${_compactFormat.format(_inactiveTeams)} marked inactive',
                      icon: Icons.groups_rounded,
                      accent: kCyan,
                    ),
                  ];

                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: cards
                        .map((card) => SizedBox(width: cardWidth, child: card))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1040;
                  final panelWidth = wide
                      ? _splitWidth(constraints.maxWidth, 2)
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                        width: panelWidth,
                        child: _buildAlertsCard(context),
                      ),
                      SizedBox(
                        width: panelWidth,
                        child: _buildActivityCard(context),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              _buildPlanCard(context),
            ],
    );
  }

  Widget _buildSpotlight(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E214E), Color(0xFF1747B8), Color(0xFF2A8DFF)],
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 860;
          final summary = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_compactFormat.format(_totalUsers)} users, ${_compactFormat.format(_activeSubscriptions)} active subscriptions, MRR ${_currencyFormat.format(_mrrInPaise / 100)}.',
                style: context.tt.headlineMedium?.copyWith(
                  color: Colors.white,
                  height: 1.18,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${_compactFormat.format(_windowUsers)} new users this ${_periodLabel(_period).toLowerCase()}. ${_compactFormat.format(_trialUsers)} on trial, ${_compactFormat.format(_expiredSubscriptions)} expired.',
                style: context.tt.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
                  height: 1.6,
                ),
              ),
            ],
          );

          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _QuickJumpButton(
                icon: Icons.people_alt_rounded,
                label: 'Review users',
                onTap: () => widget.onNavigate(1),
              ),
              _QuickJumpButton(
                icon: Icons.workspace_premium_rounded,
                label: 'Subscriptions',
                onTap: () => widget.onNavigate(2),
              ),
              _QuickJumpButton(
                icon: Icons.groups_rounded,
                label: 'Teams',
                onTap: () => widget.onNavigate(3),
              ),
              _QuickJumpButton(
                icon: Icons.campaign_rounded,
                label: 'Broadcasts',
                onTap: () => widget.onNavigate(4),
              ),
            ],
          );

          if (wide) {
            return Row(
              children: [
                Expanded(child: summary),
                const SizedBox(width: 20),
                SizedBox(width: 280, child: actions),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [summary, const SizedBox(height: 18), actions],
          );
        },
      ),
    );
  }

  Widget _buildAlertsCard(BuildContext context) {
    return _SectionCard(
      title: 'Operational alerts',
      subtitle: 'The queue that needs a human decision soonest.',
      child: _alerts.isEmpty
          ? const _EmptyState(
              icon: Icons.check_circle_outline_rounded,
              title: 'No critical alerts',
              message:
                  'The current snapshot looks healthy. Refresh if you are expecting new activity.',
            )
          : Column(
              children: _alerts
                  .map(
                    (alert) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: alert.color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: alert.color.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: alert.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(alert.icon, color: alert.color),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  alert.title,
                                  style: context.tt.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  alert.message,
                                  style: context.tt.bodyMedium?.copyWith(
                                    color: kSlate,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildActivityCard(BuildContext context) {
    return _SectionCard(
      title: 'Recent activity',
      subtitle: 'A blended feed from signups and admin broadcasts.',
      child: _activity.isEmpty
          ? const _EmptyState(
              icon: Icons.timeline_rounded,
              title: 'No recent activity',
              message: 'Recent user signups and admin events will appear here.',
            )
          : Column(
              children: _activity
                  .map(
                    (item) => Column(
                      children: [
                        _ActivityTile(item: item),
                        if (item != _activity.last) const Divider(height: 1),
                      ],
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildPlanCard(BuildContext context) {
    final total = _planDistribution.values.fold<int>(
      0,
      (runningTotal, value) => runningTotal + value,
    );
    final entries = _planDistribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _SectionCard(
      title: 'Plan mix',
      subtitle: 'How subscription inventory is split right now.',
      child: entries.isEmpty
          ? const _EmptyState(
              icon: Icons.pie_chart_outline_rounded,
              title: 'No subscriptions found',
              message:
                  'Once subscriptions are available, the plan mix will show up here.',
            )
          : Column(
              children: entries
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _DistributionRow(
                        label: entry.key.toUpperCase(),
                        value: entry.value,
                        total: total,
                        color: _planColor(entry.key),
                        suffix: '${entry.value}',
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _QuickJumpButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickJumpButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        backgroundColor: Colors.white.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _PeriodChoice extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _PeriodChoice({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final option in const [
          ('7d', '7D'),
          ('30d', '30D'),
          ('90d', '90D'),
        ])
          ChoiceChip(
            selected: option.$1 == value,
            label: Text(option.$2),
            onSelected: (_) => onChanged(option.$1),
          ),
      ],
    );
  }
}

class _UserManagementTab extends StatefulWidget {
  const _UserManagementTab();

  @override
  State<_UserManagementTab> createState() => _UserManagementTabState();
}

class _UserManagementTabState extends State<_UserManagementTab> {
  final _searchController = TextEditingController();
  List<QueryDocumentSnapshot> _users = [];
  List<QueryDocumentSnapshot> _filteredUsers = [];
  Map<String, _Json> _subsByUid = {};
  Map<String, _Json> _teamByUid = {};
  bool _loading = true;
  DocumentSnapshot? _lastDoc;
  bool _hasMore = true;
  String _filter = 'all';

  static const _pageSize = 60;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers({bool loadMore = false}) async {
    if (!loadMore) {
      setState(() => _loading = true);
      _users = [];
      _lastDoc = null;
      _hasMore = true;
    }

    try {
      var query = _db
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(_pageSize);
      if (_lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }

      final futures = await Future.wait<dynamic>([
        query.get(),
        _db.collection('subscriptions').limit(300).get(),
        _db.collection('userTeamMap').limit(300).get(),
      ]);

      final userSnap = futures[0] as QuerySnapshot;
      final subsSnap = futures[1] as QuerySnapshot;
      final teamSnap = futures[2] as QuerySnapshot;

      final subsByUid = <String, _Json>{};
      for (final doc in subsSnap.docs) {
        subsByUid[doc.id] = _docMap(doc);
      }

      final teamByUid = <String, _Json>{};
      for (final doc in teamSnap.docs) {
        final data = _docMap(doc);
        final key = _text(data['userId'], fallback: doc.id);
        if (key.isNotEmpty) teamByUid[key] = data;
      }

      if (!mounted) return;
      setState(() {
        _users.addAll(userSnap.docs);
        _lastDoc = userSnap.docs.isNotEmpty ? userSnap.docs.last : _lastDoc;
        _hasMore = userSnap.docs.length == _pageSize;
        _subsByUid = subsByUid;
        _teamByUid = teamByUid;
        _loading = false;
      });
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Failed to load users: $e');
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredUsers = _users.where((doc) {
        final data = _docMap(doc);
        final haystack = [
          _bestUserName(data),
          _text(data['email']),
          _text(data['phone']),
          _text(data['storeName']),
          _text(data['businessName']),
          doc.id,
        ].join(' ').toLowerCase();

        final matchesSearch = query.isEmpty || haystack.contains(query);
        final matchesFilter = switch (_filter) {
          'paid' => _isPaidSubscription(_subsByUid[doc.id]),
          'trial' => _isTrialUser(data, _subsByUid[doc.id]),
          'team' => _teamLabel(doc.id) != 'Solo',
          'recent' => _createdRecently(data),
          'missing_email' => _text(data['email']).isEmpty,
          _ => true,
        };

        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  int get _trialCount => _users
      .where((doc) => _isTrialUser(_docMap(doc), _subsByUid[doc.id]))
      .length;
  int get _paidCount =>
      _users.where((doc) => _isPaidSubscription(_subsByUid[doc.id])).length;
  int get _teamCount =>
      _users.where((doc) => _teamLabel(doc.id) != 'Solo').length;
  int get _recentCount =>
      _users.where((doc) => _createdRecently(_docMap(doc))).length;

  bool _createdRecently(_Json data) {
    final created = _toDate(data['createdAt']);
    return created != null &&
        created.isAfter(DateTime.now().subtract(const Duration(days: 30)));
  }

  String _teamLabel(String uid) {
    final team = _teamByUid[uid];
    final teamId = _text(team?['teamId']);
    if (teamId.isEmpty || teamId == uid) return 'Solo';
    return 'Team';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: kRose));
  }

  @override
  Widget build(BuildContext context) {
    return _AdminPage(
      badge: 'Users',
      title: 'Customer accounts and access',
      subtitle:
          'Search users, scan trial or paid cohorts, and jump into account-level admin actions without leaving the dashboard.',
      trailing: FilledButton.tonalIcon(
        onPressed: _loadUsers,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Refresh'),
      ),
      onRefresh: _loadUsers,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = width >= 1080
                ? 4
                : width >= 680
                ? 2
                : 1;
            final cardWidth = _splitWidth(width, columns);
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _MetricCard(
                    label: 'Loaded users',
                    value: _compactFormat.format(_users.length),
                    hint:
                        '${_compactFormat.format(_filteredUsers.length)} matching filters',
                    icon: Icons.people_alt_rounded,
                    accent: kPrimary,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _MetricCard(
                    label: 'Paid accounts',
                    value: _compactFormat.format(_paidCount),
                    hint: 'Active Pro or Enterprise access',
                    icon: Icons.workspace_premium_rounded,
                    accent: kMint,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _MetricCard(
                    label: 'Trial accounts',
                    value: _compactFormat.format(_trialCount),
                    hint: 'Still inside the trial window',
                    icon: Icons.timelapse_rounded,
                    accent: kAmber,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _MetricCard(
                    label: 'Team members',
                    value: _compactFormat.format(_teamCount),
                    hint:
                        '${_compactFormat.format(_recentCount)} joined in 30 days',
                    icon: Icons.groups_rounded,
                    accent: kCyan,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'User explorer',
          subtitle:
              'Search across the loaded user set and isolate the cohort you want to work on.',
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Search by name, email, phone, business, or UID',
                ),
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChipButton(
                      selected: _filter == 'all',
                      label: 'All users',
                      onTap: () {
                        setState(() => _filter = 'all');
                        _applyFilters();
                      },
                    ),
                    _FilterChipButton(
                      selected: _filter == 'paid',
                      label: 'Paid',
                      onTap: () {
                        setState(() => _filter = 'paid');
                        _applyFilters();
                      },
                    ),
                    _FilterChipButton(
                      selected: _filter == 'trial',
                      label: 'Trial',
                      onTap: () {
                        setState(() => _filter = 'trial');
                        _applyFilters();
                      },
                    ),
                    _FilterChipButton(
                      selected: _filter == 'team',
                      label: 'On a team',
                      onTap: () {
                        setState(() => _filter = 'team');
                        _applyFilters();
                      },
                    ),
                    _FilterChipButton(
                      selected: _filter == 'recent',
                      label: 'Joined in 30d',
                      onTap: () {
                        setState(() => _filter = 'recent');
                        _applyFilters();
                      },
                    ),
                    _FilterChipButton(
                      selected: _filter == 'missing_email',
                      label: 'Missing email',
                      onTap: () {
                        setState(() => _filter = 'missing_email');
                        _applyFilters();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text(
                    '${_filteredUsers.length} users visible',
                    style: context.tt.labelLarge?.copyWith(color: kSlate),
                  ),
                  const Spacer(),
                  if (_hasMore && !_loading)
                    TextButton.icon(
                      onPressed: () => _loadUsers(loadMore: true),
                      icon: const Icon(Icons.expand_more_rounded),
                      label: const Text('Load more'),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _loading && _users.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            : _filteredUsers.isEmpty
            ? const _SectionCard(
                title: 'No users match',
                child: _EmptyState(
                  icon: Icons.person_search_rounded,
                  title: 'Nothing matched this search',
                  message: 'Try widening the filter or loading more users.',
                ),
              )
            : _SectionCard(
                title: 'Results',
                subtitle:
                    'Tap a user to open the action sheet with plan controls and context.',
                child: Column(
                  children: _filteredUsers.map((doc) {
                    final data = _docMap(doc);
                    final sub = _subsByUid[doc.id];
                    final trial = _isTrialUser(data, sub);
                    final plan = _subscriptionLabel(sub);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _showUserActions(doc.id, data),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: kPrimary.withValues(alpha: 0.12),
                              child: Text(
                                _bestUserName(
                                  data,
                                ).characters.first.toUpperCase(),
                                style: const TextStyle(
                                  color: kPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _bestUserName(data),
                                    style: context.tt.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    [
                                      if (_text(data['email']).isNotEmpty)
                                        _text(data['email']),
                                      if (_text(data['phone']).isNotEmpty)
                                        _text(data['phone']),
                                    ].join(' • ').ifEmpty('No contact info'),
                                    style: context.tt.bodySmall?.copyWith(
                                      color: kSlate,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _StatusPill(
                                        label: plan,
                                        color: _planColor(plan.toLowerCase()),
                                      ),
                                      if (trial)
                                        const _StatusPill(
                                          label: 'TRIAL',
                                          color: kAmber,
                                          icon: Icons.timelapse_rounded,
                                        ),
                                      _StatusPill(
                                        label: _teamLabel(doc.id),
                                        color: _teamLabel(doc.id) == 'Solo'
                                            ? kSlate
                                            : kCyan,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _dateLabel(_toDate(data['createdAt'])),
                                  style: context.tt.bodySmall?.copyWith(
                                    color: kSlate,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 16,
                                  color: kSlate,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
      ],
    );
  }

  void _showUserActions(String uid, _Json data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _UserActionSheet(
        uid: uid,
        data: data,
        onDone: () {
          Navigator.pop(ctx);
          _loadUsers();
        },
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: selected,
        label: Text(label),
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _UserActionSheet extends StatefulWidget {
  final String uid;
  final _Json data;
  final VoidCallback onDone;

  const _UserActionSheet({
    required this.uid,
    required this.data,
    required this.onDone,
  });

  @override
  State<_UserActionSheet> createState() => _UserActionSheetState();
}

class _UserActionSheetState extends State<_UserActionSheet> {
  bool _loading = false;
  int _invoiceCount = 0;
  _Json? _subscription;
  _Json? _team;
  bool _dataLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  Future<void> _loadUserDetails() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>([
        _db
            .collection('invoices')
            .where('ownerId', isEqualTo: widget.uid)
            .count()
            .get(),
        _db.collection('subscriptions').doc(widget.uid).get(),
        _db
            .collection('userTeamMap')
            .where('userId', isEqualTo: widget.uid)
            .limit(1)
            .get(),
      ]);

      final subDoc = results[1] as DocumentSnapshot;
      final teamSnap = results[2] as QuerySnapshot;

      if (!mounted) return;
      setState(() {
        _invoiceCount = (results[0] as AggregateQuerySnapshot).count ?? 0;
        _subscription = subDoc.exists ? _docMap(subDoc) : null;
        _team = teamSnap.docs.isNotEmpty ? _docMap(teamSnap.docs.first) : null;
        _loading = false;
        _dataLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _dataLoaded = true;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: kRose));
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: kMint));
  }

  Future<void> _copy(String label, String value) async {
    if (value.isEmpty) {
      _showError('No $label to copy.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: value));
    _showSuccess('$label copied');
  }

  Future<void> _setPlan(String plan, String status) async {
    try {
      await _db.collection('subscriptions').doc(widget.uid).set({
        'userId': widget.uid,
        'plan': plan,
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _showSuccess('Plan updated to $plan ($status)');
      widget.onDone();
    } catch (e) {
      _showError('Failed to update subscription: $e');
    }
  }

  Future<void> _setTrial(int days) async {
    try {
      final expires = DateTime.now().add(Duration(days: days));
      await _db.collection('users').doc(widget.uid).set({
        'trialExpiresAt': Timestamp.fromDate(expires),
      }, SetOptions(merge: true));
      _showSuccess('Trial extended by $days days');
      widget.onDone();
    } catch (e) {
      _showError('Failed to update trial: $e');
    }
  }

  Future<void> _deleteSubscription() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete subscription'),
        content: Text(
          'Delete the subscription doc for ${widget.uid}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: kRose),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _db.collection('subscriptions').doc(widget.uid).delete();
      _showSuccess('Subscription deleted');
      widget.onDone();
    } catch (e) {
      _showError('Failed to delete subscription: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _bestUserName(widget.data);
    final email = _text(widget.data['email']);
    final phone = _text(widget.data['phone']);
    final trialEnds = _dateLabel(_toDate(widget.data['trialExpiresAt']));

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 760),
        decoration: const BoxDecoration(color: Colors.transparent),
        child: DraggableScrollableSheet(
          initialChildSize: 0.84,
          minChildSize: 0.4,
          maxChildSize: 0.96,
          builder: (context, controller) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
            ),
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: kSurfaceBorder,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(name, style: context.tt.headlineMedium),
                const SizedBox(height: 8),
                if (email.isNotEmpty)
                  Text(
                    email,
                    style: context.tt.bodyLarge?.copyWith(color: kSlate),
                  ),
                if (phone.isNotEmpty)
                  Text(
                    phone,
                    style: context.tt.bodyLarge?.copyWith(color: kSlate),
                  ),
                const SizedBox(height: 8),
                SelectionArea(
                  child: Text(
                    'UID: ${widget.uid}',
                    style: context.tt.bodySmall?.copyWith(
                      color: kSlate,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _copy('UID', widget.uid),
                      icon: const Icon(Icons.copy_all_rounded, size: 18),
                      label: const Text('Copy UID'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _copy('email', email),
                      icon: const Icon(Icons.email_rounded, size: 18),
                      label: const Text('Copy email'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_dataLoaded) ...[
                  _SectionCard(
                    title: 'Account context',
                    child: Column(
                      children: [
                        _InfoRow('Invoices', '$_invoiceCount'),
                        _InfoRow(
                          'Joined',
                          _dateLabel(_toDate(widget.data['createdAt'])),
                        ),
                        _InfoRow('Trial ends', trialEnds),
                        _InfoRow('Plan', _subscriptionLabel(_subscription)),
                        _InfoRow(
                          'Status',
                          _text(
                            _subscription?['status'],
                            fallback: 'none',
                          ).toUpperCase(),
                        ),
                        _InfoRow(
                          'Billing cycle',
                          _text(_subscription?['billingCycle'], fallback: '—'),
                        ),
                        _InfoRow(
                          'Price',
                          _subscription == null
                              ? '—'
                              : _currencyFormat.format(
                                  _toInt(_subscription?['priceInPaise']) / 100,
                                ),
                        ),
                        _InfoRow(
                          'Team',
                          _text(_team?['teamId'], fallback: 'None'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SectionCard(
                    title: 'Actions',
                    subtitle:
                        'Use these controls for billing and access intervention.',
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _ActionChip(
                          label: 'Set Pro',
                          icon: Icons.star_rounded,
                          color: kViolet,
                          onTap: () => _setPlan('pro', 'active'),
                        ),
                        _ActionChip(
                          label: 'Set Enterprise',
                          icon: Icons.workspace_premium_rounded,
                          color: kPrimary,
                          onTap: () => _setPlan('enterprise', 'active'),
                        ),
                        _ActionChip(
                          label: 'Pause billing',
                          icon: Icons.pause_circle_rounded,
                          color: kAmber,
                          onTap: () => _setPlan(
                            _text(_subscription?['plan'], fallback: 'pro'),
                            'paused',
                          ),
                        ),
                        _ActionChip(
                          label: 'Mark expired',
                          icon: Icons.timer_off_rounded,
                          color: kSlate,
                          onTap: () => _setPlan(
                            _text(_subscription?['plan'], fallback: 'pro'),
                            'expired',
                          ),
                        ),
                        _ActionChip(
                          label: 'Trial +7 days',
                          icon: Icons.timelapse_rounded,
                          color: kAmber,
                          onTap: () => _setTrial(7),
                        ),
                        _ActionChip(
                          label: 'Trial +30 days',
                          icon: Icons.more_time_rounded,
                          color: kAmber,
                          onTap: () => _setTrial(30),
                        ),
                        _ActionChip(
                          label: 'Delete subscription',
                          icon: Icons.delete_forever_rounded,
                          color: kRose,
                          onTap: _deleteSubscription,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: context.tt.bodyMedium?.copyWith(
                color: kSlate,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Text(value, style: context.tt.bodyLarge)),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
      onPressed: onTap,
      side: BorderSide(color: color.withValues(alpha: 0.18)),
      backgroundColor: color.withValues(alpha: 0.08),
    );
  }
}

class _SubscriptionManagementTab extends StatefulWidget {
  const _SubscriptionManagementTab();

  @override
  State<_SubscriptionManagementTab> createState() =>
      _SubscriptionManagementTabState();
}

class _SubscriptionManagementTabState
    extends State<_SubscriptionManagementTab> {
  final _searchController = TextEditingController();
  List<QueryDocumentSnapshot> _subs = [];
  List<QueryDocumentSnapshot> _filteredSubs = [];
  bool _loading = true;
  String? _planFilter;
  String? _statusFilter;
  String? _cycleFilter;
  int _mrrInPaise = 0;
  int _renewalSoon = 0;

  @override
  void initState() {
    super.initState();
    _loadSubs();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSubs() async {
    setState(() => _loading = true);
    try {
      final snap = await _db.collection('subscriptions').limit(250).get();
      final docs = snap.docs.toList()
        ..sort((a, b) {
          final aDate =
              _toDate(_docMap(a)['updatedAt']) ??
              _toDate(_docMap(a)['createdAt']) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bDate =
              _toDate(_docMap(b)['updatedAt']) ??
              _toDate(_docMap(b)['createdAt']) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });

      var mrr = 0;
      var renewalSoon = 0;
      for (final doc in docs) {
        final data = _docMap(doc);
        if (_isPaidSubscription(data)) {
          final price = _toInt(data['priceInPaise']);
          final cycle = _text(data['billingCycle'], fallback: 'monthly');
          mrr += cycle == 'annual' ? (price / 12).round() : price;
        }
        final periodEnd = _toDate(data['currentPeriodEnd']);
        if (_isPaidSubscription(data) &&
            periodEnd != null &&
            periodEnd.isBefore(DateTime.now().add(const Duration(days: 7)))) {
          renewalSoon++;
        }
      }

      if (!mounted) return;
      setState(() {
        _subs = docs;
        _mrrInPaise = mrr;
        _renewalSoon = renewalSoon;
        _loading = false;
      });
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Failed to load subscriptions: $e');
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredSubs = _subs.where((doc) {
        final data = _docMap(doc);
        final plan = _text(data['plan'], fallback: 'free').toLowerCase();
        final status = _text(data['status'], fallback: 'unknown').toLowerCase();
        final cycle = _text(
          data['billingCycle'],
          fallback: 'monthly',
        ).toLowerCase();
        final haystack = [
          doc.id,
          _text(data['razorpaySubscriptionId']),
          plan,
          status,
        ].join(' ').toLowerCase();
        return (_planFilter == null || plan == _planFilter) &&
            (_statusFilter == null || status == _statusFilter) &&
            (_cycleFilter == null || cycle == _cycleFilter) &&
            (query.isEmpty || haystack.contains(query));
      }).toList();
    });
  }

  int get _activeCount =>
      _subs.where((doc) => _text(_docMap(doc)['status']) == 'active').length;
  int get _annualCount => _subs
      .where((doc) => _text(_docMap(doc)['billingCycle']) == 'annual')
      .length;
  int get _atRiskCount => _subs
      .where(
        (doc) => const {
          'paused',
          'halted',
          'cancelled',
          'expired',
        }.contains(_text(_docMap(doc)['status'])),
      )
      .length;

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: kRose));
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: kMint));
  }

  Future<void> _setSubStatus(String docId, String status) async {
    try {
      await _db.collection('subscriptions').doc(docId).set({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _showSuccess('Subscription marked $status');
      _loadSubs();
    } catch (e) {
      _showError('Failed to update subscription: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final renewals = _subs
        .where((doc) {
          final data = _docMap(doc);
          final end = _toDate(data['currentPeriodEnd']);
          return _text(data['status']) == 'active' &&
              end != null &&
              end.isBefore(DateTime.now().add(const Duration(days: 14)));
        })
        .take(5)
        .toList();

    return _AdminPage(
      badge: 'Subscriptions',
      title: 'Recurring revenue engine',
      subtitle:
          'Scan plan inventory, isolate renewal risk, and manually intervene on subscription status when needed.',
      trailing: FilledButton.tonalIcon(
        onPressed: _loadSubs,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Refresh'),
      ),
      onRefresh: _loadSubs,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1080
                ? 4
                : constraints.maxWidth >= 680
                ? 2
                : 1;
            final width = _splitWidth(constraints.maxWidth, columns);
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: width,
                  child: _MetricCard(
                    label: 'MRR',
                    value: _currencyFormat.format(_mrrInPaise / 100),
                    hint: 'Estimated from active subscriptions',
                    icon: Icons.currency_rupee_rounded,
                    accent: kMint,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _MetricCard(
                    label: 'Active',
                    value: _compactFormat.format(_activeCount),
                    hint:
                        '${_compactFormat.format(_renewalSoon)} renewal(s) inside 7 days',
                    icon: Icons.check_circle_rounded,
                    accent: kPrimary,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _MetricCard(
                    label: 'At risk',
                    value: _compactFormat.format(_atRiskCount),
                    hint: 'Paused, halted, expired, or cancelled',
                    icon: Icons.warning_amber_rounded,
                    accent: kRose,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _MetricCard(
                    label: 'Annual billing',
                    value: _compactFormat.format(_annualCount),
                    hint:
                        '${_compactFormat.format(_filteredSubs.length)} visible after filters',
                    icon: Icons.event_repeat_rounded,
                    accent: kViolet,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'Subscription explorer',
          subtitle:
              'Search by UID or Razorpay ID, then layer filters for plan, status, and cycle.',
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Search by UID or Razorpay subscription ID',
                ),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 860;
                  final childWidth = wide
                      ? _splitWidth(constraints.maxWidth, 4)
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: childWidth,
                        child: _FilterDropdown(
                          label: 'Plan',
                          value: _planFilter,
                          items: const ['pro', 'enterprise', 'free'],
                          onChanged: (value) {
                            setState(() => _planFilter = value);
                            _applyFilters();
                          },
                        ),
                      ),
                      SizedBox(
                        width: childWidth,
                        child: _FilterDropdown(
                          label: 'Status',
                          value: _statusFilter,
                          items: const [
                            'active',
                            'pending',
                            'paused',
                            'halted',
                            'cancelled',
                            'expired',
                          ],
                          onChanged: (value) {
                            setState(() => _statusFilter = value);
                            _applyFilters();
                          },
                        ),
                      ),
                      SizedBox(
                        width: childWidth,
                        child: _FilterDropdown(
                          label: 'Cycle',
                          value: _cycleFilter,
                          items: const ['monthly', 'annual'],
                          onChanged: (value) {
                            setState(() => _cycleFilter = value);
                            _applyFilters();
                          },
                        ),
                      ),
                      SizedBox(
                        width: childWidth,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _planFilter = null;
                              _statusFilter = null;
                              _cycleFilter = null;
                            });
                            _applyFilters();
                          },
                          icon: const Icon(Icons.clear_all_rounded),
                          label: const Text('Clear filters'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1040;
            final panelWidth = wide
                ? _splitWidth(constraints.maxWidth, 2)
                : constraints.maxWidth;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: panelWidth,
                  child: _SectionCard(
                    title: 'Plan split',
                    child: Column(
                      children: [
                        _DistributionRow(
                          label: 'Pro',
                          value: _subs
                              .where(
                                (doc) => _text(_docMap(doc)['plan']) == 'pro',
                              )
                              .length,
                          total: math.max(_subs.length, 1),
                          color: kPrimary,
                        ),
                        const SizedBox(height: 14),
                        _DistributionRow(
                          label: 'Enterprise',
                          value: _subs
                              .where(
                                (doc) =>
                                    _text(_docMap(doc)['plan']) == 'enterprise',
                              )
                              .length,
                          total: math.max(_subs.length, 1),
                          color: kViolet,
                        ),
                        const SizedBox(height: 14),
                        _DistributionRow(
                          label: 'Free or other',
                          value: _subs.where((doc) {
                            final plan = _text(_docMap(doc)['plan']);
                            return plan != 'pro' && plan != 'enterprise';
                          }).length,
                          total: math.max(_subs.length, 1),
                          color: kAmber,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: panelWidth,
                  child: _SectionCard(
                    title: 'Renewal watchlist',
                    subtitle:
                        'Active subscriptions renewing inside the next 14 days.',
                    child: renewals.isEmpty
                        ? const _EmptyState(
                            icon: Icons.event_available_rounded,
                            title: 'No urgent renewals',
                            message:
                                'Renewals close to period end will appear here.',
                          )
                        : Column(
                            children: renewals.map((doc) {
                              final data = _docMap(doc);
                              final end = _toDate(data['currentPeriodEnd']);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            doc.id,
                                            style: context.tt.titleMedium,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${_subscriptionLabel(data)} • ${_text(data['billingCycle'], fallback: 'monthly').toUpperCase()}',
                                            style: context.tt.bodySmall
                                                ?.copyWith(color: kSlate),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        _StatusPill(
                                          label: _daysUntil(end),
                                          color: kAmber,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _dateLabel(end),
                                          style: context.tt.bodySmall?.copyWith(
                                            color: kSlate,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            : _filteredSubs.isEmpty
            ? const _SectionCard(
                title: 'No subscriptions found',
                child: _EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Nothing matches the current filters',
                  message: 'Widen the filter set to see more subscriptions.',
                ),
              )
            : _SectionCard(
                title: 'Subscriptions',
                subtitle: 'Use Activate or Cancel for quick lifecycle changes.',
                child: Column(
                  children: _filteredSubs.map((doc) {
                    final data = _docMap(doc);
                    final status = _text(data['status'], fallback: 'unknown');
                    final cycle = _text(
                      data['billingCycle'],
                      fallback: 'monthly',
                    );
                    final periodEnd = _toDate(data['currentPeriodEnd']);
                    final price = _toInt(data['priceInPaise']);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _StatusPill(
                                label: status.toUpperCase(),
                                color: _statusColor(status),
                              ),
                              const SizedBox(width: 8),
                              _StatusPill(
                                label: _subscriptionLabel(data),
                                color: _planColor(_text(data['plan'])),
                              ),
                              const Spacer(),
                              Text(
                                _currencyFormat.format(price / 100),
                                style: context.tt.titleMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(doc.id, style: context.tt.titleMedium),
                          const SizedBox(height: 4),
                          Text(
                            [
                              cycle.toUpperCase(),
                              if (_text(
                                data['razorpaySubscriptionId'],
                              ).isNotEmpty)
                                'Razorpay ${_text(data['razorpaySubscriptionId'])}',
                              if (periodEnd != null)
                                'Renews ${_dateLabel(periodEnd)}',
                            ].join(' • '),
                            style: context.tt.bodySmall?.copyWith(
                              color: kSlate,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (status == 'active')
                                TextButton.icon(
                                  onPressed: () =>
                                      _setSubStatus(doc.id, 'cancelled'),
                                  icon: const Icon(
                                    Icons.cancel_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Cancel'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: kRose,
                                  ),
                                ),
                              if (status != 'active')
                                TextButton.icon(
                                  onPressed: () =>
                                      _setSubStatus(doc.id, 'active'),
                                  icon: const Icon(
                                    Icons.check_circle_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Activate'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: kMint,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
      ],
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        DropdownMenuItem<String>(value: null, child: Text('All $label')),
        ...items.map(
          (item) => DropdownMenuItem<String>(
            value: item,
            child: Text(item.toUpperCase()),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class _TeamManagementTab extends StatefulWidget {
  const _TeamManagementTab();

  @override
  State<_TeamManagementTab> createState() => _TeamManagementTabState();
}

class _TeamManagementTabState extends State<_TeamManagementTab> {
  final _searchController = TextEditingController();
  List<QueryDocumentSnapshot> _teams = [];
  List<QueryDocumentSnapshot> _filteredTeams = [];
  Map<String, _Json> _subsByTeam = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTeams();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTeams() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>([
        _db.collection('teams').limit(150).get(),
        _db.collection('subscriptions').limit(250).get(),
      ]);
      final teamSnap = results[0] as QuerySnapshot;
      final subSnap = results[1] as QuerySnapshot;
      final subsByTeam = <String, _Json>{};
      for (final doc in subSnap.docs) {
        subsByTeam[doc.id] = _docMap(doc);
      }
      if (!mounted) return;
      setState(() {
        _teams = teamSnap.docs;
        _subsByTeam = subsByTeam;
        _loading = false;
      });
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Failed to load teams: $e');
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredTeams = _teams.where((doc) {
        final data = _docMap(doc);
        final haystack = [
          doc.id,
          _text(data['businessName']),
          _text(data['name']),
          _text(data['ownerId']),
        ].join(' ').toLowerCase();
        return query.isEmpty || haystack.contains(query);
      }).toList();
    });
  }

  int get _activeTeams => _teams
      .where((doc) => (_docMap(doc)['isActive'] as bool?) != false)
      .length;
  int get _inactiveTeams => _teams
      .where((doc) => (_docMap(doc)['isActive'] as bool?) == false)
      .length;
  int get _memberTotal => _teams.fold<int>(
    0,
    (runningTotal, doc) => runningTotal + _toInt(_docMap(doc)['memberCount']),
  );
  int get _nearCapacity => _teams.where((doc) {
    final data = _docMap(doc);
    final sub = _subsByTeam[doc.id];
    final maxMembers = _maxMembersForTeam(sub);
    final memberCount = _toInt(data['memberCount']);
    return maxMembers > 0 && memberCount >= maxMembers;
  }).length;

  void _showSuccess(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: kMint));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: kRose));
  }

  Future<void> _deactivateTeam(String teamId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate team'),
        content: Text('Deactivate team $teamId?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: kRose),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _db.collection('teams').doc(teamId).set({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _showSuccess('Team deactivated');
      _loadTeams();
    } catch (e) {
      _showError('Failed to update team: $e');
    }
  }

  Future<void> _viewMembers(String teamId) async {
    try {
      final activeMembers = await _db
          .collection('teams')
          .doc(teamId)
          .collection('members')
          .where('status', isEqualTo: 'active')
          .limit(60)
          .get();

      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Team members (${activeMembers.docs.length})',
                style: context.tt.titleLarge,
              ),
              const SizedBox(height: 14),
              if (activeMembers.docs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No active members found'),
                )
              else
                ...activeMembers.docs.map((doc) {
                  final data = _docMap(doc);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_rounded),
                    title: Text(
                      doc.id,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                    subtitle: Text(
                      'Role: ${_text(data['role'], fallback: 'member')}',
                    ),
                  );
                }),
            ],
          ),
        ),
      );
    } catch (e) {
      _showError('Failed to load members: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AdminPage(
      badge: 'Teams',
      title: 'Team operations',
      subtitle:
          'See which businesses are operating in teams, who is close to plan limits, and where access should be tightened.',
      trailing: FilledButton.tonalIcon(
        onPressed: _loadTeams,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Refresh'),
      ),
      onRefresh: _loadTeams,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1080
                ? 4
                : constraints.maxWidth >= 680
                ? 2
                : 1;
            final width = _splitWidth(constraints.maxWidth, columns);
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: width,
                  child: _MetricCard(
                    label: 'Active teams',
                    value: _compactFormat.format(_activeTeams),
                    hint: '${_compactFormat.format(_inactiveTeams)} inactive',
                    icon: Icons.groups_rounded,
                    accent: kPrimary,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _MetricCard(
                    label: 'Team members',
                    value: _compactFormat.format(_memberTotal),
                    hint: 'Member count across loaded teams',
                    icon: Icons.group_add_rounded,
                    accent: kCyan,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _MetricCard(
                    label: 'Near capacity',
                    value: _compactFormat.format(_nearCapacity),
                    hint: 'At or beyond the plan member limit',
                    icon: Icons.speed_rounded,
                    accent: kAmber,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _MetricCard(
                    label: 'Visible teams',
                    value: _compactFormat.format(_filteredTeams.length),
                    hint: 'Matches the current search',
                    icon: Icons.search_rounded,
                    accent: kViolet,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'Search teams',
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search by team name, owner ID, or team ID',
            ),
          ),
        ),
        const SizedBox(height: 18),
        _loading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            : _filteredTeams.isEmpty
            ? const _SectionCard(
                title: 'No teams found',
                child: _EmptyState(
                  icon: Icons.groups_2_rounded,
                  title: 'No team matches',
                  message:
                      'Adjust the query to surface the team you are looking for.',
                ),
              )
            : _SectionCard(
                title: 'Team list',
                subtitle:
                    'Use the member sheet to inspect who currently has access.',
                child: Column(
                  children: _filteredTeams.map((doc) {
                    final data = _docMap(doc);
                    final name = _text(
                      data['businessName'],
                      fallback: _text(data['name'], fallback: 'Unnamed Team'),
                    );
                    final owner = _text(data['ownerId'], fallback: '—');
                    final memberCount = _toInt(data['memberCount']);
                    final isActive = (data['isActive'] as bool?) != false;
                    final maxMembers = _maxMembersForTeam(_subsByTeam[doc.id]);
                    final utilization = maxMembers <= 0
                        ? null
                        : '${math.min(memberCount, maxMembers)}/$maxMembers';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: context.tt.titleMedium,
                                ),
                              ),
                              _StatusPill(
                                label: isActive ? 'ACTIVE' : 'INACTIVE',
                                color: isActive ? kMint : kRose,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            [
                              'Owner ${_ownerPreview(owner)}',
                              'Members $memberCount',
                              if (utilization != null) 'Capacity $utilization',
                              _subscriptionLabel(_subsByTeam[doc.id]),
                            ].join(' • '),
                            style: context.tt.bodySmall?.copyWith(
                              color: kSlate,
                            ),
                          ),
                          if (maxMembers > 0) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: (memberCount / maxMembers).clamp(
                                  0.0,
                                  1.0,
                                ),
                                minHeight: 8,
                                backgroundColor: kPrimary.withValues(
                                  alpha: 0.08,
                                ),
                                color: memberCount >= maxMembers
                                    ? kAmber
                                    : kPrimary,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () => _viewMembers(doc.id),
                                icon: const Icon(
                                  Icons.people_rounded,
                                  size: 18,
                                ),
                                label: const Text('Members'),
                              ),
                              if (isActive)
                                TextButton.icon(
                                  onPressed: () => _deactivateTeam(doc.id),
                                  icon: const Icon(
                                    Icons.block_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Deactivate'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: kRose,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
      ],
    );
  }
}

class _SystemToolsTab extends StatefulWidget {
  const _SystemToolsTab();

  @override
  State<_SystemToolsTab> createState() => _SystemToolsTabState();
}

class _SystemToolsTabState extends State<_SystemToolsTab> {
  List<QueryDocumentSnapshot> _configDocs = [];
  List<QueryDocumentSnapshot> _usedTrials = [];
  List<QueryDocumentSnapshot> _recentRequests = [];
  List<QueryDocumentSnapshot> _authorizedAdmins = [];
  int _usedTrialCount = 0;
  bool _opsLoading = true;
  bool _configLoading = false;
  bool _trialsLoading = false;

  final _uidController = TextEditingController();
  String _overridePlan = 'pro';
  String _overrideStatus = 'active';
  String _overrideCycle = 'monthly';
  bool _overrideSaving = false;

  final _notifTitleController = TextEditingController();
  final _notifBodyController = TextEditingController();
  final _notifUidController = TextEditingController();
  String _notifTarget = 'all';
  bool _notifSending = false;
  Uint8List? _notifImageBytes;
  String? _notifImageName;
  bool _notifImageUploading = false;

  @override
  void initState() {
    super.initState();
    _notifTitleController.addListener(() => setState(() {}));
    _notifBodyController.addListener(() => setState(() {}));
    _loadOpsSummary();
  }

  @override
  void dispose() {
    _uidController.dispose();
    _notifTitleController.dispose();
    _notifBodyController.dispose();
    _notifUidController.dispose();
    super.dispose();
  }

  Future<void> _loadOpsSummary() async {
    setState(() => _opsLoading = true);
    try {
      final results = await Future.wait<dynamic>([
        _db.collection('config').limit(12).get(),
        _db
            .collection('notificationRequests')
            .orderBy('createdAt', descending: true)
            .limit(8)
            .get(),
        _db.collection('authorizedAdmins').limit(20).get(),
        _db.collection('usedTrials').count().get(),
      ]);

      if (!mounted) return;
      setState(() {
        _configDocs = (results[0] as QuerySnapshot).docs;
        _recentRequests = (results[1] as QuerySnapshot).docs;
        _authorizedAdmins = (results[2] as QuerySnapshot).docs;
        _usedTrialCount = (results[3] as AggregateQuerySnapshot).count ?? 0;
        _opsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _opsLoading = false);
      _showError('Failed to load ops summary: $e');
    }
  }

  Future<void> _loadConfig() async {
    setState(() => _configLoading = true);
    try {
      final snap = await _db.collection('config').limit(20).get();
      if (!mounted) return;
      setState(() {
        _configDocs = snap.docs;
        _configLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _configLoading = false);
      _showError('Failed to load config: $e');
    }
  }

  Future<void> _loadUsedTrials() async {
    setState(() => _trialsLoading = true);
    try {
      final snap = await _db.collection('usedTrials').limit(100).get();
      if (!mounted) return;
      setState(() {
        _usedTrials = snap.docs;
        _trialsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _trialsLoading = false);
      _showError('Failed to load trial ledger: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: kRose));
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: kMint));
  }

  Future<void> _applyManualOverride() async {
    final uid = _uidController.text.trim();
    if (uid.isEmpty) {
      _showError('User UID is required');
      return;
    }

    setState(() => _overrideSaving = true);
    try {
      await _db.collection('subscriptions').doc(uid).set({
        'userId': uid,
        'plan': _overridePlan,
        'status': _overrideStatus,
        'billingCycle': _overrideCycle,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _showSuccess('Override applied for $uid');
      _uidController.clear();
    } catch (e) {
      _showError('Failed to apply override: $e');
    } finally {
      if (mounted) setState(() => _overrideSaving = false);
    }
  }

  Future<void> _pickNotifImage() async {
    final uploadInput = html.FileUploadInputElement()..accept = 'image/*';
    uploadInput.click();
    await uploadInput.onChange.first;
    if (uploadInput.files == null || uploadInput.files!.isEmpty) return;

    final file = uploadInput.files!.first;
    if (file.size > 5 * 1024 * 1024) {
      _showError('Image must be under 5 MB.');
      return;
    }

    setState(() => _notifImageUploading = true);
    try {
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoad.first;
      final bytes = Uint8List.fromList(reader.result as List<int>);
      if (mounted) {
        setState(() {
          _notifImageBytes = bytes;
          _notifImageName = file.name;
          _notifImageUploading = false;
        });
      }
    } catch (e) {
      _showError('Failed to read image.');
      if (mounted) setState(() => _notifImageUploading = false);
    }
  }

  /// Uploads the picked image to Firebase Storage and returns the download URL.
  Future<String?> _uploadNotifImage() async {
    if (_notifImageBytes == null) return null;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext = _notifImageName?.split('.').last ?? 'png';
    final ref = FirebaseStorage.instance.ref('broadcasts/$timestamp.$ext');
    await ref.putData(
      _notifImageBytes!,
      SettableMetadata(contentType: 'image/$ext'),
    );
    return ref.getDownloadURL();
  }

  Future<void> _sendBroadcastNotification() async {
    final title = _notifTitleController.text.trim();
    final body = _notifBodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      _showError('Title and body are required.');
      return;
    }
    if (_notifTarget == 'user' && _notifUidController.text.trim().isEmpty) {
      _showError('User UID is required for a specific user notification.');
      return;
    }

    final target = switch (_notifTarget) {
      'user' => {'type': 'user', 'uid': _notifUidController.text.trim()},
      'pro' ||
      'enterprise' ||
      'trial' ||
      'expired' => {'type': 'plan', 'plan': _notifTarget},
      _ => {'type': 'all'},
    };

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send broadcast'),
        content: Text(
          'Send this notification to ${_targetLabel(target)}?\n\n$title\n$body',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _notifSending = true);
    try {
      // Upload image if attached
      String? imageUrl;
      if (_notifImageBytes != null) {
        imageUrl = await _uploadNotifImage();
      }

      final requestRef = await _db.collection('notificationRequests').add({
        'title': title,
        'body': body,
        'target': target,
        if (imageUrl != null) 'imageUrl': imageUrl,
        'status': 'pending',
        'sentBy': FirebaseAuth.instance.currentUser?.email ?? '',
        'sentByUid': FirebaseAuth.instance.currentUser?.uid ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Listen for real-time updates instead of polling (avoids cache issues)
      await for (final snap in requestRef.snapshots()) {
        final data = snap.data();
        if (data != null && data['status'] != 'pending') {
          final sent = _toInt(data['sent']);
          final failed = _toInt(data['failed']);
          final total = _toInt(data['total']);
          if (mounted) {
            _showSuccess(
              'Sent to $sent/$total users${failed > 0 ? ' ($failed failed)' : ''}',
            );
            _notifTitleController.clear();
            _notifBodyController.clear();
            _notifUidController.clear();
            _notifImageBytes = null;
            _notifImageName = null;
            _loadOpsSummary();
          }
          break;
        }
      }
    } catch (e) {
      _showError(
        'Failed to send notification: ${e.toString().replaceAll('Exception: ', '')}',
      );
    } finally {
      if (mounted) setState(() => _notifSending = false);
    }
  }

  void _reuseNotification(_Json data) {
    _notifTitleController.text = _text(data['title']);
    _notifBodyController.text = _text(data['body']);
    final target = data['target'];
    if (target is Map<String, dynamic>) {
      final type = _text(target['type']);
      if (type == 'user') {
        _notifTarget = 'user';
        _notifUidController.text = _text(target['uid']);
      } else if (type == 'plan') {
        _notifTarget = _text(target['plan'], fallback: 'all');
      } else {
        _notifTarget = 'all';
      }
    } else {
      _notifTarget = 'all';
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return _AdminPage(
      badge: 'Operations',
      title: 'Admin tools and broadcasts',
      subtitle:
          'Inspect configuration, review admin activity, manage trial history, and ship targeted notifications to the user base.',
      trailing: FilledButton.tonalIcon(
        onPressed: _loadOpsSummary,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Refresh'),
      ),
      onRefresh: _loadOpsSummary,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1080
                ? 4
                : constraints.maxWidth >= 680
                ? 2
                : 1;
            final width = _splitWidth(constraints.maxWidth, columns);
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: width,
                  child: _MetricCard(
                    label: 'Authorized admins',
                    value: _compactFormat.format(_authorizedAdmins.length),
                    hint: 'Loaded from `authorizedAdmins`',
                    icon: Icons.admin_panel_settings_rounded,
                    accent: kPrimary,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _MetricCard(
                    label: 'Config docs',
                    value: _compactFormat.format(_configDocs.length),
                    hint: 'Top-level config documents',
                    icon: Icons.cloud_rounded,
                    accent: kCyan,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _MetricCard(
                    label: 'Used trials',
                    value: _compactFormat.format(_usedTrialCount),
                    hint: 'Historical trial lock records',
                    icon: Icons.timelapse_rounded,
                    accent: kAmber,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _MetricCard(
                    label: 'Broadcast history',
                    value: _compactFormat.format(_recentRequests.length),
                    hint: 'Recent notification requests',
                    icon: Icons.campaign_rounded,
                    accent: kViolet,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1040;
            final panelWidth = wide
                ? _splitWidth(constraints.maxWidth, 2)
                : constraints.maxWidth;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: panelWidth,
                  child: _buildBroadcastHistory(context),
                ),
                SizedBox(
                  width: panelWidth,
                  child: _buildAuthorizedAdmins(context),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1040;
            final panelWidth = wide
                ? _splitWidth(constraints.maxWidth, 2)
                : constraints.maxWidth;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: panelWidth,
                  child: _buildConfigExplorer(context),
                ),
                SizedBox(
                  width: panelWidth,
                  child: _buildManualOverride(context),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1040;
            final panelWidth = wide
                ? _splitWidth(constraints.maxWidth, 2)
                : constraints.maxWidth;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(width: panelWidth, child: _buildTrialLedger(context)),
                SizedBox(
                  width: panelWidth,
                  child: _buildBroadcastComposer(context),
                ),
              ],
            );
          },
        ),
        if (_opsLoading)
          const Padding(
            padding: EdgeInsets.only(top: 18),
            child: LinearProgressIndicator(minHeight: 3),
          ),
      ],
    );
  }

  Widget _buildAuthorizedAdmins(BuildContext context) {
    return _SectionCard(
      title: 'Authorized admins',
      subtitle: 'Loaded directly from the allow-list collection.',
      child: _authorizedAdmins.isEmpty
          ? const _EmptyState(
              icon: Icons.lock_person_rounded,
              title: 'No admins loaded',
              message: 'Refresh if you expect allow-listed admin accounts.',
            )
          : Column(
              children: _authorizedAdmins.map((doc) {
                final data = _docMap(doc);
                final email = doc.id.contains('@')
                    ? doc.id
                    : _text(data['email'], fallback: doc.id);
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0x142563FF),
                    child: Icon(
                      Icons.admin_panel_settings_rounded,
                      color: kPrimary,
                      size: 18,
                    ),
                  ),
                  title: Text(email, style: context.tt.bodyMedium),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildBroadcastHistory(BuildContext context) {
    return _SectionCard(
      title: 'Recent broadcasts',
      subtitle: 'Reuse a past request to send a similar message faster.',
      child: _recentRequests.isEmpty
          ? const _EmptyState(
              icon: Icons.campaign_rounded,
              title: 'No broadcast history',
              message:
                  'Notification requests will appear here after the first send.',
            )
          : Column(
              children: _recentRequests.map((doc) {
                final data = _docMap(doc);
                final status = _text(data['status'], fallback: 'pending');
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _text(
                                data['title'],
                                fallback: 'Untitled request',
                              ),
                              style: context.tt.titleMedium,
                            ),
                          ),
                          _StatusPill(
                            label: status.toUpperCase(),
                            color: status == 'completed' ? kMint : kAmber,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_targetLabel(data['target'])} • ${_dateLabel(_toDate(data['createdAt']))}',
                        style: context.tt.bodySmall?.copyWith(color: kSlate),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _text(data['body']),
                        style: context.tt.bodySmall?.copyWith(
                          color: kSlate,
                          height: 1.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _reuseNotification(data),
                          icon: const Icon(Icons.restart_alt_rounded, size: 18),
                          label: const Text('Reuse'),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildConfigExplorer(BuildContext context) {
    return _SectionCard(
      title: 'Configuration explorer',
      subtitle: 'Inspect top-level config docs without leaving the console.',
      trailing: _configLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              onPressed: _loadConfig,
              icon: const Icon(Icons.download_rounded),
            ),
      child: _configDocs.isEmpty
          ? const _EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'No config loaded',
              message: 'Use the download icon to refresh config documents.',
            )
          : Column(
              children: _configDocs.map((doc) {
                final data = _docMap(doc);
                return ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(doc.id, style: context.tt.titleMedium),
                  subtitle: Text(
                    '${data.length} key(s)',
                    style: context.tt.bodySmall?.copyWith(color: kSlate),
                  ),
                  children: data.entries
                      .map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 130,
                                child: Text(
                                  entry.key,
                                  style: context.tt.bodySmall?.copyWith(
                                    color: kSlate,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: SelectionArea(
                                  child: Text(
                                    '${entry.value}',
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildManualOverride(BuildContext context) {
    return _SectionCard(
      title: 'Manual plan override',
      subtitle:
          'Patch a user subscription doc directly for support or recovery cases.',
      child: Column(
        children: [
          TextField(
            controller: _uidController,
            decoration: InputDecoration(
              labelText: 'User UID',
              hintText: 'Paste the user UID here',
              suffixIcon: IconButton(
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data?.text != null) _uidController.text = data!.text!;
                },
                icon: const Icon(Icons.paste_rounded),
              ),
            ),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 700;
              final width = wide
                  ? _splitWidth(constraints.maxWidth, 3)
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: width,
                    child: _LabeledDropdown(
                      label: 'Plan',
                      value: _overridePlan,
                      items: const ['pro', 'enterprise'],
                      onChanged: (value) =>
                          setState(() => _overridePlan = value ?? 'pro'),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _LabeledDropdown(
                      label: 'Status',
                      value: _overrideStatus,
                      items: const [
                        'active',
                        'pending',
                        'paused',
                        'cancelled',
                        'expired',
                      ],
                      onChanged: (value) =>
                          setState(() => _overrideStatus = value ?? 'active'),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _LabeledDropdown(
                      label: 'Billing cycle',
                      value: _overrideCycle,
                      items: const ['monthly', 'annual'],
                      onChanged: (value) =>
                          setState(() => _overrideCycle = value ?? 'monthly'),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _overrideSaving ? null : _applyManualOverride,
              icon: _overrideSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: const Text('Apply override'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrialLedger(BuildContext context) {
    return _SectionCard(
      title: 'Trial ledger',
      subtitle:
          'Historical list of phone numbers or emails that have already consumed a trial.',
      trailing: _trialsLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              onPressed: _loadUsedTrials,
              icon: const Icon(Icons.download_rounded),
            ),
      child: _usedTrials.isEmpty
          ? const _EmptyState(
              icon: Icons.timelapse_rounded,
              title: 'Trial ledger not loaded',
              message:
                  'Use the download icon to inspect historical trial records.',
            )
          : Column(
              children: _usedTrials.map((doc) {
                final data = _docMap(doc);
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.history_toggle_off_rounded,
                    color: kAmber,
                  ),
                  title: Text(
                    doc.id,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                  subtitle: Text(
                    _dateLabel(_toDate(data['usedAt'])),
                    style: context.tt.bodySmall?.copyWith(color: kSlate),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildBroadcastComposer(BuildContext context) {
    return _SectionCard(
      title: 'Broadcast composer',
      subtitle:
          'Send a push message to all users, a paid segment, expired accounts, or a single UID.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _notifTarget,
            decoration: const InputDecoration(labelText: 'Audience'),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All users')),
              DropdownMenuItem(value: 'pro', child: Text('Pro users')),
              DropdownMenuItem(
                value: 'enterprise',
                child: Text('Enterprise users'),
              ),
              DropdownMenuItem(value: 'trial', child: Text('Trial users')),
              DropdownMenuItem(value: 'expired', child: Text('Expired users')),
              DropdownMenuItem(value: 'user', child: Text('Specific user')),
            ],
            onChanged: (value) => setState(() => _notifTarget = value ?? 'all'),
          ),
          if (_notifTarget == 'user') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _notifUidController,
              decoration: InputDecoration(
                labelText: 'User UID',
                suffixIcon: IconButton(
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null) {
                      _notifUidController.text = data!.text!;
                    }
                  },
                  icon: const Icon(Icons.paste_rounded),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _notifTitleController,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'Feature launch, renewal reminder, support note...',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notifBodyController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Body',
              hintText: 'Message to deliver to the selected segment',
            ),
          ),
          const SizedBox(height: 12),
          // ── Image attachment ─────────────────────────────────
          if (_notifImageBytes != null)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _notifImageBytes!,
                      width: 64,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _notifImageName ?? 'image.png',
                      style: context.tt.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => setState(() {
                      _notifImageBytes = null;
                      _notifImageName = null;
                    }),
                  ),
                ],
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: _notifImageUploading ? null : _pickNotifImage,
              icon: _notifImageUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: Text(
                _notifImageUploading ? 'Picking...' : 'Attach image (optional)',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
              ),
            ),
          if (_notifTitleController.text.isNotEmpty ||
              _notifBodyController.text.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: kPrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: kPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _notifTitleController.text.ifEmpty('Title'),
                          style: context.tt.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _notifBodyController.text.ifEmpty(
                            'Notification preview',
                          ),
                          style: context.tt.bodySmall?.copyWith(color: kSlate),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _notifSending ? null : _sendBroadcastNotification,
              icon: _notifSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(_notifSending ? 'Sending...' : 'Send notification'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item.toUpperCase()),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

_Json _docMap(DocumentSnapshot doc) =>
    (doc.data() as _Json?) ?? <String, dynamic>{};

String _text(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _toDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is int) {
    if (value < 100000000000) {
      return DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String _bestUserName(_Json data) {
  return _text(
    data['displayName'],
    fallback: _text(
      data['storeName'],
      fallback: _text(data['businessName'], fallback: 'Unknown user'),
    ),
  );
}

String _ownerPreview(String ownerId) {
  if (ownerId.isEmpty) return 'No owner';
  if (ownerId.length <= 10) return ownerId;
  return '${ownerId.substring(0, 8)}...';
}

String _dateLabel(DateTime? value) {
  if (value == null) return '—';
  return _shortDate.format(value.toLocal());
}

String _timeAgo(DateTime? value) {
  if (value == null) return 'never';
  final now = DateTime.now();
  final diff = now.difference(value);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return _shortDateTime.format(value.toLocal());
}

Color _statusColor(String status) {
  return switch (status.toLowerCase()) {
    'paid' || 'active' || 'completed' => kMint,
    'pending' || 'paused' || 'trial' => kAmber,
    'overdue' || 'cancelled' || 'expired' || 'halted' => kRose,
    _ => kSlate,
  };
}

Color _planColor(String plan) {
  return switch (plan.toLowerCase()) {
    'enterprise' => kPrimary,
    'pro' => kViolet,
    'free' || 'trial' => kAmber,
    _ => kSlate,
  };
}

bool _isPaidSubscription(_Json? sub) {
  if (sub == null) return false;
  final status = _text(sub['status']).toLowerCase();
  final plan = _text(sub['plan']).toLowerCase();
  return status == 'active' && (plan == 'pro' || plan == 'enterprise');
}

bool _isTrialUser(_Json user, _Json? sub) {
  if (_isPaidSubscription(sub)) return false;
  final trialEnds = _toDate(user['trialExpiresAt']);
  return trialEnds != null && trialEnds.isAfter(DateTime.now());
}

String _subscriptionLabel(_Json? sub) {
  if (sub == null) return 'FREE';
  final plan = _text(sub['plan'], fallback: 'free').toUpperCase();
  return plan;
}

int _maxMembersForTeam(_Json? sub) {
  if (sub == null) return 1;
  if (_text(sub['status']) != 'active') return 1;
  return switch (_text(sub['plan'])) {
    'enterprise' => -1,
    'pro' => 3,
    _ => 1,
  };
}

String _daysUntil(DateTime? value) {
  if (value == null) return 'No date';
  final diff = value.difference(DateTime.now()).inDays;
  if (diff <= 0) return 'Due now';
  if (diff == 1) return '1 day left';
  return '$diff days left';
}

String _targetLabel(dynamic target) {
  if (target is! Map) return 'all users';
  final type = _text(target['type'], fallback: 'all');
  if (type == 'user') return 'user ${_text(target['uid'])}';
  if (type == 'plan') {
    return '${_text(target['plan'], fallback: 'unknown')} users';
  }
  return 'all users';
}

String _periodLabel(String period) {
  return switch (period) {
    '7d' => 'Last 7 days',
    '90d' => 'Last 90 days',
    _ => 'Last 30 days',
  };
}

double _splitWidth(double width, int columns, {double gap = 16}) {
  final available = width - (gap * (columns - 1));
  return columns <= 1 ? width : math.max(0, available) / columns;
}

extension _StringX on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
