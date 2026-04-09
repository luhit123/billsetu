import 'dart:async';
import 'dart:ui';

import 'package:billeasy/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:billeasy/l10n/app_strings.dart';
import 'package:billeasy/modals/business_profile.dart';
import 'package:billeasy/screens/force_update_screen.dart';
import 'package:billeasy/screens/login_screen.dart';
import 'package:billeasy/screens/maintenance_screen.dart';
import 'package:billeasy/screens/profile_setup_screen.dart';
import 'package:billeasy/screens/pending_invites_screen.dart';
import 'package:billeasy/screens/team_removed_screen.dart';
import 'package:billeasy/screens/trial_celebration_screen.dart';
import 'package:billeasy/services/auth_service.dart';
import 'package:billeasy/services/app_check_service.dart';
import 'package:billeasy/services/invoice_pdf_service.dart';
import 'package:billeasy/services/notification_service.dart';
import 'package:billeasy/services/sync_status_service.dart';
import 'package:billeasy/services/plan_service.dart';
import 'package:billeasy/services/remote_config_service.dart';
import 'package:billeasy/services/profile_service.dart';
import 'package:billeasy/services/session_service.dart';
import 'package:billeasy/modals/team_role.dart';
import 'package:billeasy/services/team_service.dart';
import 'package:billeasy/widgets/connectivity_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:billeasy/screens/home_screen.dart';
import 'package:billeasy/screens/onboarding_screen.dart';
import 'package:billeasy/services/theme_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:billeasy/widgets/skeleton_screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  // ── Crashlytics: catch all Flutter and platform errors ──────────────────
  // Crashlytics is not supported on web — guard with kIsWeb.
  if (!kIsWeb) {
    FlutterError.onError = (FlutterErrorDetails details) {
      if (kDebugMode) debugPrint('[FlutterError] ${details.exception}\n${details.stack}');
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      if (kDebugMode) debugPrint('[PlatformError] $error\n$stack');
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  // ── Enable Firestore offline persistence ──────────────────────────────────
  // After the first load, all data is served instantly from the on-device
  // cache. The app works offline and syncs when reconnected.
  // On web, persistence is enabled by default and cacheSizeBytes is not
  // supported — use default settings.
  if (!kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: 52428800, // 50 MB — [M2-FIX] reduced from 100 MB to conserve storage on low-end devices
    );
  }

  ConnectivityService.instance.init();

  // App Check + Remote Config in parallel — both are required before UI relies
  // on backend calls, but neither needs to wait for the other.
  await Future.wait([
    AppCheckService.activate(),
    RemoteConfigService.instance.init(),
  ]);

  // Team, plan, profile, and subscription listeners are loaded when the user
  // reaches [SignedInHomeGate] ([_refreshWorkspaceContext]). Running them
  // here blocked serially after every [Firebase.initializeApp] even when
  // [currentUser] was not yet restored, duplicating work and delaying first
  // frame. PDF fonts preload after first paint so bundle I/O doesn't extend
  // splash time.

  // Initialize sync status monitoring — detects pending writes that
  // haven't reached the server and surfaces warnings to the user.
  SyncStatusService.instance.init();

  // Initialize FCM — saves token to Firestore and sets up foreground
  // notification handling. Fire-and-forget so it doesn't block app start.
  NotificationService.instance.initialize().then((_) {
    NotificationService.instance.scheduleOverdueCheck();
  }).catchError((e) {
    // Non-critical — app works without push notifications
  });

  runApp(const BillRajaApp());

  // Warm PDF fonts on the next frame — first invoice build stays fast while
  // cold start no longer waits on asset loading.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    InvoicePdfService().preloadFonts().catchError((_) {});
  });
}

class BillRajaApp extends StatelessWidget {
  const BillRajaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ThemeProvider(
      child: LanguageProvider(
        child: Builder(
          builder: (context) => MaterialApp(
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            title: 'BillRaja',
            // ── Localizations for date pickers, text fields, etc. ───────────
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('hi')],
            themeMode: ThemeProvider.themeModeOf(context),
            darkTheme: _buildDarkTheme(),
            theme: ThemeData(
              useMaterial3: true,
              primaryColor: kPrimary,
              pageTransitionsTheme: const PageTransitionsTheme(
                builders: {
                  TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                  TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                  TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
                  TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
                  TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
                },
              ),
              colorScheme: ColorScheme.fromSeed(
                seedColor: kPrimary,
                brightness: Brightness.light,
                surface: kSurface,
                onSurface: kOnSurface,
                primary: kPrimary,
                onPrimary: kOnPrimary,
                error: kError,
              ),
              scaffoldBackgroundColor: kSurface,
              appBarTheme: const AppBarTheme(
                backgroundColor: kSurface,
                foregroundColor: kOnSurface,
                centerTitle: false,
                elevation: 0,
                scrolledUnderElevation: 0,
                surfaceTintColor: Colors.transparent,
              ),
              floatingActionButtonTheme: const FloatingActionButtonThemeData(
                backgroundColor: kPrimary,
                foregroundColor: kOnPrimary,
                elevation: 0,
                shape: StadiumBorder(),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: kOnPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  foregroundColor: kOnSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  side: BorderSide.none,
                  backgroundColor: kSurfaceContainerLow,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(foregroundColor: kPrimary),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: kSurfaceLowest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                hintStyle: const TextStyle(color: kTextTertiary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: UnderlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: kPrimary, width: 2),
                ),
              ),
              bottomNavigationBarTheme: const BottomNavigationBarThemeData(
                backgroundColor: kSurfaceLowest,
                selectedItemColor: kPrimary,
                unselectedItemColor: kTextTertiary,
                type: BottomNavigationBarType.fixed,
                elevation: 0,
                selectedLabelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: TextStyle(fontSize: 11),
              ),
              cardTheme: CardThemeData(
                color: kSurfaceLowest,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide.none,
                ),
              ),
              dividerTheme: const DividerThemeData(
                color: kSurfaceContainerLow,
                thickness: 1,
              ),
              chipTheme: ChipThemeData(
                backgroundColor: kSurfaceContainerLow,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            home: const AppGate(),
            // ── Global offline banner (Stack overlay) ─────────────────────────
            // Using Stack instead of Column so the banner overlays the top of
            // the screen without stealing layout space from child screens.
            // A Column approach subtracts banner height from the Navigator's
            // available height while MediaQuery.size still reports the full
            // screen — causing screens with fixed/flex layouts to overflow or
            // clip their bottom content when the banner is visible.
            builder: (context, child) => Stack(
              children: [
                child!,
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ConnectivityBanner(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

ThemeData _buildDarkTheme() {
  final cs = ColorScheme.fromSeed(
    seedColor: kPrimary,
    brightness: Brightness.dark,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: cs.surface,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: cs.surface,
      foregroundColor: cs.onSurface,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: cs.primary,
      foregroundColor: cs.onPrimary,
      elevation: 0,
      shape: const StadiumBorder(),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: cs.onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide.none,
        backgroundColor: cs.surfaceContainerLow,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: cs.primary),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cs.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: cs.onSurfaceVariant),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: UnderlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: cs.primary, width: 2),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: cs.surfaceContainer,
      selectedItemColor: cs.primary,
      unselectedItemColor: cs.onSurfaceVariant,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: const TextStyle(fontSize: 11),
    ),
    cardTheme: CardThemeData(
      color: cs.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide.none,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: cs.surfaceContainerHigh,
      thickness: 1,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: cs.surfaceContainerLow,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
  );
}

/// Top-level gate that checks force-update and maintenance mode before
/// allowing access to the rest of the app.
class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  @override
  void initState() {
    super.initState();
    // Rebuild when remote config changes (e.g. maintenance toggled off).
    RemoteConfigService.instance.onConfigUpdated.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final rc = RemoteConfigService.instance;

    // Priority 1: Force update
    if (rc.needsForceUpdate) {
      return const ForceUpdateScreen();
    }

    // Priority 2: Maintenance mode
    if (rc.maintenanceEnabled) {
      return const MaintenanceScreen();
    }

    // Normal flow
    return const AuthGate();
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checkingOnboarding = true;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('onboarding_seen') ?? false;
    if (mounted) {
      setState(() {
        _showOnboarding = !seen;
        _checkingOnboarding = false;
      });
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
    if (mounted) {
      setState(() => _showOnboarding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingOnboarding) {
      return const LoginSkeleton();
    }

    if (_showOnboarding) {
      return OnboardingScreen(onCompleted: _completeOnboarding);
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.idTokenChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoginSkeleton();
        }

        if (snapshot.data == null) {
          return const LoginScreen();
        }

        return const SignedInHomeGate();
      },
    );
  }
}

/// Restored sessions go straight to profile completion or home.
/// Shows a one-time celebration screen after first profile setup.
class SignedInHomeGate extends StatefulWidget {
  const SignedInHomeGate({super.key});

  @override
  State<SignedInHomeGate> createState() => _SignedInHomeGateState();
}

class _SignedInHomeGateState extends State<SignedInHomeGate> {
  /// null = not checked yet, true = show it, false = skip
  bool? _showCelebration;

  /// True if the user has never activated their plan (no createdAt in user doc).
  bool _isFirstTimeCelebration = false;

  /// null = not checked yet, true = show invites screen, false = skip
  bool? _showPendingInvites;

  /// True while the async post-login checks are running.
  bool _postLoginCheckRunning = false;

  /// True once post-login checks have completed (prevents re-runs).
  bool _postLoginCheckDone = false;

  /// True when the user was on a team and was removed / left.
  bool _showTeamRemoved = false;
  bool _wasRemovedByOwner = false;
  String _removedTeamName = '';

  /// True when this session has been taken over by another device.
  bool _showSessionRevoked = false;
  String _revokedMessage = '';

  /// Tracks whether the user was previously on a team (to detect removal).
  bool _wasOnTeam = false;
  StreamSubscription<TeamRole>? _roleSub;
  String _workspaceKey = '';
  bool _workspaceRefreshRunning = false;

  @override
  void initState() {
    super.initState();

    // Claim this device as the active session.
    SessionService.instance.claimSession(
      onSessionRevoked: () {
        if (mounted) {
          setState(() {
            _showSessionRevoked = true;
            _revokedMessage =
                'You\'ve been signed in on another device. Only one active session is allowed at a time.';
          });
        }
      },
    );

    final ts = TeamService.instance;
    _wasOnTeam = ts.isTeamMember;
    _workspaceKey = _buildWorkspaceKey(ts);
    // Capture team name while still available
    if (_wasOnTeam) _removedTeamName = ts.teamBusinessName;

    _roleSub = ts.roleStream.listen((_) {
      final nextWorkspaceKey = _buildWorkspaceKey(ts);
      if (_workspaceKey != nextWorkspaceKey) {
        _workspaceKey = nextWorkspaceKey;
        _refreshWorkspaceContext();
      }

      // If was on team but now solo → removed or left
      if (_wasOnTeam && ts.isSolo) {
        if (mounted) {
          setState(() {
            _showTeamRemoved = true;
            _wasRemovedByOwner = !ts.wasVoluntaryLeave;
          });
        }
      }
      if (ts.isTeamMember && !_wasOnTeam) {
        // Just joined a team — capture name
        _removedTeamName = ts.teamBusinessName;
      }
      _wasOnTeam = ts.isTeamMember;
    });

    // Load workspace (team → plan → profile) as early as possible: user is
    // already non-null from [AuthGate]. A microtask runs before the next frame,
    // so this starts sooner than addPostFrameCallback while avoiding the old
    // serial pre-runApp bottleneck.
    scheduleMicrotask(() {
      _refreshWorkspaceContext();
    });
  }

  String _buildWorkspaceKey(TeamService teamService) {
    final actualUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    String effectiveOwnerId;
    try {
      effectiveOwnerId = teamService.getEffectiveOwnerId();
    } catch (_) {
      effectiveOwnerId = actualUid;
    }
    return '$actualUid|$effectiveOwnerId|${teamService.isTeamMember}';
  }

  Future<void> _refreshWorkspaceContext() async {
    if (_workspaceRefreshRunning) return;

    _workspaceRefreshRunning = true;
    try {
      // Team context can change the effective owner id, so initialize it first.
      await TeamService.instance.init();

      PlanService.instance.reset();
      await PlanService.instance.loadPlan();

      ProfileService.instance.reset();
      await ProfileService.instance.init();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[SignedInHomeGate] Workspace refresh failed: $e');
    } finally {
      _workspaceRefreshRunning = false;
    }
  }

  @override
  void dispose() {
    _roleSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show session-revoked screen — another device took over
    if (_showSessionRevoked) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.orange.shade50,
                  ),
                  child: Icon(
                    Icons.devices_other_rounded,
                    size: 40,
                    color: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Signed in elsewhere',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _revokedMessage,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      await AuthService().signOut();
                    },
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('Sign in again'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show team removed/left screen
    if (_showTeamRemoved) {
      return TeamRemovedScreen(
        teamName: _removedTeamName,
        wasRemoved: _wasRemovedByOwner,
        onSignOut: () async {
          await AuthService().signOut();
        },
      );
    }

    // ── Step 1: Check for pending invites FIRST (before profile setup) ──
    // This ensures invited users see the invite before being asked to
    // create their own business profile.
    if (!_postLoginCheckDone && !_postLoginCheckRunning) {
      _postLoginCheckRunning = true;
      _runPostLoginChecks();
      return const HomeSkeleton();
    }
    if (_postLoginCheckRunning) {
      return const HomeSkeleton();
    }

    // ── Step 2: Show pending invites if any ──
    if (_showPendingInvites == true) {
      return PendingInvitesScreen(
        onDone: () {
          setState(() => _showPendingInvites = false);
          // After invites are handled, check celebration for new users
          if (_showCelebration == null) _checkAndShowCelebration();
        },
      );
    }

    // ── Step 3: Show celebration if needed ──
    if (_showCelebration == true) {
      return TrialCelebrationScreen(
        isFirstTime: _isFirstTimeCelebration,
        onContinue: () async {
          // On first activation, write createdAt to start the plan clock.
          if (_isFirstTimeCelebration) {
            try {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid != null) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .set(
                  {'createdAt': FieldValue.serverTimestamp()},
                  SetOptions(merge: true),
                );
                if (kDebugMode) debugPrint('[SignedInHomeGate] Plan activated — createdAt written');
                // Reload plan so it picks up the new createdAt
                await PlanService.instance.loadPlan();
              }
            } catch (e) {
              if (kDebugMode) debugPrint('[SignedInHomeGate] Failed to activate plan: $e');
            }
            _isFirstTimeCelebration = false;
          }
          if (mounted) setState(() => _showCelebration = false);
        },
      );
    }

    // ── Step 4: Profile check → setup or home ──
    return StreamBuilder<BusinessProfile?>(
      stream: ProfileService().watchCurrentProfile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const HomeSkeleton();
        }

        if (snapshot.hasError) {
          if (ConnectivityService.instance.isOffline) {
            return const HomeSkeleton();
          }
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppStrings.of(context).drawerProfileLoadError,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // If user just accepted an invite and joined a team, they use the
        // team owner's profile — no need for their own profile setup.
        if (snapshot.data == null && !TeamService.instance.isTeamMember) {
          return const ProfileSetupScreen(isRequiredSetup: true);
        }

        return const HomeScreen();
      },
    );
  }

  /// Runs invite check + celebration check exactly once after login.
  /// Wrapped with a 10-second timeout so the user is never stuck on the
  /// skeleton screen if Firestore reads hang (slow network, throttled
  /// background tab, etc.).
  Future<void> _runPostLoginChecks() async {
    try {
      await Future(() async {
        await _checkPendingInvites();
        if (_showPendingInvites == true) return;
        await _checkAndShowCelebration();
      }).timeout(const Duration(seconds: 10));
    } catch (e) {
      if (kDebugMode) debugPrint('[SignedInHomeGate] Post-login checks timed out: $e');
      // On timeout, skip invites and celebration — go straight to home.
      if (mounted) {
        setState(() {
          _showPendingInvites ??= false;
          _showCelebration ??= false;
        });
      }
    }
    if (mounted) {
      setState(() {
        _postLoginCheckRunning = false;
        _postLoginCheckDone = true;
      });
    }
  }

  Future<void> _checkPendingInvites() async {
    try {
      final invites = await TeamService.instance.getPendingInvites();
      if (kDebugMode) debugPrint('[SignedInHomeGate] Pending invites found: ${invites.length}');
      if (mounted) {
        setState(() => _showPendingInvites = invites.isNotEmpty);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[SignedInHomeGate] Invite check failed: $e');
      if (mounted) setState(() => _showPendingInvites = false);
    }
  }

  Future<void> _checkAndShowCelebration() async {
    // Only show celebration if there IS a trial to celebrate (duration > 0).
    final trialMonths = RemoteConfigService.instance.trialDurationMonths;
    if (trialMonths <= 0) {
      if (kDebugMode) debugPrint('[SignedInHomeGate] trial_duration_months=$trialMonths — skipping celebration');
      if (mounted) setState(() => _showCelebration = false);
      return;
    }

    // Check if user has already activated or is a returning user.
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        final data = userDoc.data();
        final hasCreatedAt = userDoc.exists &&
            data != null &&
            data['createdAt'] != null;
        final isReturningUser = userDoc.exists &&
            data != null &&
            data['returningUser'] == true;

        _isFirstTimeCelebration = !hasCreatedAt;

        // Returning users (deleted account + re-signed up) don't see celebration.
        if (isReturningUser) {
          if (kDebugMode) debugPrint('[SignedInHomeGate] Returning user — skipping celebration');
          if (mounted) setState(() => _showCelebration = false);
          return;
        }

        // Already activated users don't see celebration.
        if (hasCreatedAt) {
          if (kDebugMode) debugPrint('[SignedInHomeGate] User already activated — skipping celebration');
          if (mounted) setState(() => _showCelebration = false);
          return;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[SignedInHomeGate] createdAt check failed: $e');
    }
    if (mounted) setState(() => _showCelebration = true);
  }
}
