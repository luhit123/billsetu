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

  Future<User?> signInWithGoogle() async {
    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider();
      final userCredential = await _firebaseAuth.signInWithPopup(
        googleProvider,
      );
      return userCredential.user;
    }

    debugPrint('[AuthService] Starting Google Sign-In...');

    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

    if (googleUser == null) {
      debugPrint('[AuthService] Sign-in cancelled by user.');
      return null;
    }

    debugPrint('[AuthService] Google account selected: ${googleUser.email}');

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    debugPrint('[AuthService] idToken present: ${idToken != null}');
    debugPrint('[AuthService] accessToken present: ${accessToken != null}');

    if (idToken == null && accessToken == null) {
      throw FirebaseAuthException(
        code: 'missing-google-tokens',
        message:
            'Google Sign-In did not return any authentication tokens. '
            'Ensure the web client ID in google-services.json is correct.',
      );
    }

    debugPrint('[AuthService] Signing in to Firebase...');

    final authCredential = GoogleAuthProvider.credential(
      idToken: idToken,
      accessToken: accessToken,
    );
    final userCredential = await _firebaseAuth.signInWithCredential(
      authCredential,
    );

    debugPrint(
      '[AuthService] Firebase sign-in success: ${userCredential.user?.uid}',
    );
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
