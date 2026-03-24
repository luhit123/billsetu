import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:billeasy/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:billeasy/l10n/app_strings.dart';
import 'package:billeasy/modals/business_profile.dart';
import 'package:billeasy/screens/force_update_screen.dart';
import 'package:billeasy/screens/login_screen.dart';
import 'package:billeasy/screens/maintenance_screen.dart';
import 'package:billeasy/screens/profile_setup_screen.dart';
import 'package:billeasy/services/app_check_service.dart';
import 'package:billeasy/services/plan_service.dart';
import 'package:billeasy/services/remote_config_service.dart';
import 'package:billeasy/services/profile_service.dart';
import 'package:billeasy/widgets/connectivity_banner.dart';
import 'package:flutter/material.dart';
import 'package:billeasy/screens/home_screen.dart';
import 'package:billeasy/theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Route Flutter and platform errors to Crashlytics in release mode;
  // keep debug prints in debug mode for developer convenience.
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kDebugMode) {
      debugPrint('[FlutterError] ${details.exception}\n${details.stack}');
    } else {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      debugPrint('[PlatformError] $error\n$stack');
    } else {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
    return true;
  };
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  // ── Enable Firestore offline persistence ──────────────────────────────────
  // After the first load, all data is served instantly from the on-device
  // cache. The app works offline and syncs when reconnected.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: 104857600, // 100 MB — prevents device storage abuse
  );

  // Enable Crashlytics in release; disable in debug so errors show in IDE.
  await FirebaseCrashlytics.instance
      .setCrashlyticsCollectionEnabled(!kDebugMode);

  ConnectivityService.instance.init();
  await AppCheckService.activate();

  // ── Firebase Remote Config ────────────────────────────────────────────────
  // Must init before PlanService so that plan limits are available.
  await RemoteConfigService.instance.init();

  await PlanService.instance.loadPlan();
  runApp(const BillRajaApp());
}

class BillRajaApp extends StatelessWidget {
  const BillRajaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return LanguageProvider(
      child: Builder(
        builder: (context) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'BillRaja',
          theme: ThemeData(
            useMaterial3: true,
            primaryColor: kPrimary,
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: kPrimary,
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: kSurfaceLowest,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
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
        ),
      ),
    );
  }
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

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
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
class SignedInHomeGate extends StatelessWidget {
  const SignedInHomeGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BusinessProfile?>(
      stream: ProfileService().watchCurrentProfile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  AppStrings.of(context).drawerProfileLoadError,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        if (snapshot.data == null) {
          return const ProfileSetupScreen(isRequiredSetup: true);
        }

        return const HomeScreen();
      },
    );
  }
}
