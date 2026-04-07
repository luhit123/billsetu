import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'logo_cache_service.dart';
import 'plan_service.dart';
import 'profile_service.dart';
import 'session_service.dart';
import 'signature_service.dart';
import 'team_service.dart';

class AuthService {
  // Web OAuth 2.0 client ID (client_type: 3) from google-services.json.
  // Required on Android to request an ID token for Firebase authentication.
  static const String _webClientId =
      '742769968562-d7ojikpoakt595aobd2h78iasvtd9utb.apps.googleusercontent.com';

  AuthService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    FirebaseFunctions? functions,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _googleSignIn =
           googleSignIn ??
           GoogleSignIn(serverClientId: kIsWeb ? null : _webClientId),
       _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final FirebaseFunctions _functions;

  static String friendlyErrorMessage(
    Object error, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-phone-number':
          return 'The phone number looks invalid. Please check it and try again.';
        case 'invalid-verification-code':
        case 'session-expired':
          return 'The OTP is invalid or expired. Please try again.';
        case 'too-many-requests':
        case 'quota-exceeded':
          return 'Too many attempts right now. Please try again later.';
        case 'network-request-failed':
          return 'Network issue detected. Please check your connection and try again.';
        case 'popup-blocked':
          return 'Your browser blocked the Google sign-in popup. Please allow popups and try again.';
        case 'popup-closed-by-user':
        case 'cancelled-popup-request':
          return 'Google sign-in was cancelled before it could finish.';
        case 'account-exists-with-different-credential':
          return 'This account already uses a different sign-in method.';
        case 'invalid-credential':
        case 'credential-already-in-use':
          return 'That sign-in session is no longer valid. Please try again.';
        case 'user-disabled':
          return 'This account has been disabled. Please contact support.';
        case 'operation-not-allowed':
          return 'This sign-in method is not available right now.';
        case 'missing-google-tokens':
          return 'Google sign-in could not be completed. Please try again.';
        default:
          return fallback;
      }
    }
    return fallback;
  }

  // ── Phone OTP Auth ──────────────────────────────────────────────────────────

  /// Sends an OTP to the given [phoneNumber] (should include country code, e.g. +91...).
  ///
  /// [onCodeSent] is called with the verification ID when the SMS is dispatched.
  /// [onError] is called with a human-readable error message on failure.
  /// [onAutoVerified] is called when Android auto-verifies the SMS (optional).
  Future<void> sendOtp(
    String phoneNumber, {
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    Function(PhoneAuthCredential)? onAutoVerified,
  }) async {
    // Suppress reCAPTCHA web redirect on Android — use native Play Integrity
    // or silent APNs verification on iOS instead.
    if (!kIsWeb) {
      await _firebaseAuth.setSettings(
        appVerificationDisabledForTesting: false,
        forceRecaptchaFlow: false,
      );
    }

    await _firebaseAuth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) {
        if (kDebugMode) {
          debugPrint('[AuthService] Auto-verification completed.');
        }
        onAutoVerified?.call(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        if (kDebugMode) {
          debugPrint(
            '[AuthService] verificationFailed: ${e.code} — ${e.message}',
          );
        }
        String message;
        switch (e.code) {
          case 'invalid-phone-number':
            message =
                'The phone number is invalid. Please check and try again.';
            break;
          case 'too-many-requests':
            message = 'Too many attempts. Please try again later.';
            break;
          case 'quota-exceeded':
            message = 'SMS quota exceeded. Please try again later.';
            break;
          default:
            message = friendlyErrorMessage(
              e,
              fallback: 'Phone verification failed. Please try again.',
            );
        }
        onError(message);
      },
      codeSent: (String verificationId, int? resendToken) {
        if (kDebugMode) {
          debugPrint(
            '[AuthService] OTP code sent. verificationId: $verificationId',
          );
        }
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (kDebugMode) {
          debugPrint(
            '[AuthService] Auto-retrieval timeout for: $verificationId',
          );
        }
      },
    );
  }

  /// Verifies the OTP [smsCode] against [verificationId] and signs in.
  /// Returns the [User] on success, or null on failure.
  Future<User?> verifyOtp(String verificationId, String smsCode) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final userCredential = await _firebaseAuth.signInWithCredential(credential);
    if (kDebugMode) {
      debugPrint(
        '[AuthService] OTP sign-in success: ${userCredential.user?.uid}',
      );
    }
    return userCredential.user;
  }

  // ── Google Sign-In ──────────────────────────────────────────────────────────

  Future<User?> signInWithGoogle() async {
    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider();
      final userCredential = await _firebaseAuth.signInWithPopup(
        googleProvider,
      );
      return userCredential.user;
    }

    if (kDebugMode) {
      debugPrint('[AuthService] Starting Google Sign-In...');
    }

    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

    if (googleUser == null) {
      if (kDebugMode) {
        debugPrint('[AuthService] Sign-in cancelled by user.');
      }
      return null;
    }

    if (kDebugMode) {
      debugPrint('[AuthService] Google account selected: ${googleUser.email}');
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (kDebugMode) {
      debugPrint('[AuthService] idToken present: ${idToken != null}');
      debugPrint('[AuthService] accessToken present: ${accessToken != null}');
    }

    if (idToken == null && accessToken == null) {
      throw FirebaseAuthException(
        code: 'missing-google-tokens',
        message:
            'Google Sign-In did not return any authentication tokens. '
            'Ensure the web client ID in google-services.json is correct.',
      );
    }

    if (kDebugMode) {
      debugPrint('[AuthService] Signing in to Firebase...');
    }

    final authCredential = GoogleAuthProvider.credential(
      idToken: idToken,
      accessToken: accessToken,
    );
    final userCredential = await _firebaseAuth.signInWithCredential(
      authCredential,
    );

    if (kDebugMode) {
      debugPrint(
        '[AuthService] Firebase sign-in success: ${userCredential.user?.uid}',
      );
    }
    return userCredential.user;
  }

  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        // Only attempt Google sign-out if user signed in with Google.
        // OTP-only users don't have a Google session — calling disconnect/signOut
        // on them throws a PlatformException (channel-error).
        try {
          final isGoogleUser =
              _firebaseAuth.currentUser?.providerData.any(
                (p) => p.providerId == 'google.com',
              ) ??
              false;
          if (isGoogleUser) {
            try {
              await _googleSignIn.disconnect();
            } catch (_) {
              await _googleSignIn.signOut();
            }
          }
        } catch (_) {
          // Swallow any remaining errors — sign-out must not fail
        }
      }
    } finally {
      await _clearLocalSession();
      await _firebaseAuth.signOut();
    }
  }

  Future<void> deleteAccount() async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      throw FirebaseAuthException(
        code: 'not-signed-in',
        message: 'Sign in required.',
      );
    }

    await currentUser.getIdToken(true);
    await _functions.httpsCallable('deleteMyAccount').call();
    await signOut();
  }

  User? getCurrentUser() {
    return _firebaseAuth.currentUser;
  }

  Future<void> _clearLocalSession() async {
    SessionService.instance.reset();
    TeamService.instance.reset();
    PlanService.instance.reset();
    ProfileService.instance.reset();
    await Future.wait([LogoCacheService.clear(), SignatureService.clear()]);
  }
}
