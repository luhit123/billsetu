import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  // Web OAuth 2.0 client ID (client_type: 3) from google-services.json.
  // Required on Android to request an ID token for Firebase authentication.
  static const String _webClientId =
      '742769968562-d7ojikpoakt595aobd2h78iasvtd9utb.apps.googleusercontent.com';

  AuthService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _googleSignIn =
           googleSignIn ??
           GoogleSignIn(serverClientId: kIsWeb ? null : _webClientId);

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

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
        if (kDebugMode) debugPrint('[AuthService] Auto-verification completed.');
        onAutoVerified?.call(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        if (kDebugMode) {
          debugPrint('[AuthService] verificationFailed: ${e.code} — ${e.message}');
        }
        String message;
        switch (e.code) {
          case 'invalid-phone-number':
            message = 'The phone number is invalid. Please check and try again.';
            break;
          case 'too-many-requests':
            message = 'Too many attempts. Please try again later.';
            break;
          case 'quota-exceeded':
            message = 'SMS quota exceeded. Please try again later.';
            break;
          default:
            message = e.message ?? 'Phone verification failed. Please try again.';
        }
        onError(message);
      },
      codeSent: (String verificationId, int? resendToken) {
        if (kDebugMode) debugPrint('[AuthService] OTP code sent. verificationId: $verificationId');
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (kDebugMode) debugPrint('[AuthService] Auto-retrieval timeout for: $verificationId');
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
    if (kDebugMode) debugPrint('[AuthService] OTP sign-in success: ${userCredential.user?.uid}');
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

    if (kDebugMode) debugPrint('[AuthService] Starting Google Sign-In...');

    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

    if (googleUser == null) {
      if (kDebugMode) debugPrint('[AuthService] Sign-in cancelled by user.');
      return null;
    }

    if (kDebugMode) debugPrint('[AuthService] Google account selected: ${googleUser.email}');

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

    if (kDebugMode) debugPrint('[AuthService] Signing in to Firebase...');

    final authCredential = GoogleAuthProvider.credential(
      idToken: idToken,
      accessToken: accessToken,
    );
    final userCredential = await _firebaseAuth.signInWithCredential(
      authCredential,
    );

    if (kDebugMode) debugPrint('[AuthService] Firebase sign-in success: ${userCredential.user?.uid}');
    return userCredential.user;
  }

  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        try {
          await _googleSignIn.disconnect();
        } catch (_) {
          await _googleSignIn.signOut();
        }
      }
    } finally {
      await _firebaseAuth.signOut();
    }
  }

  User? getCurrentUser() {
    return _firebaseAuth.currentUser;
  }
}
