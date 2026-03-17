import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  bool _isGoogleSignInInitialized = false;

  Future<User?> signInWithGoogle() async {
    if (kIsWeb || !_googleSignIn.supportsAuthenticate()) {
      final googleProvider = GoogleAuthProvider();
      final userCredential = await _firebaseAuth.signInWithPopup(
        googleProvider,
      );
      return userCredential.user;
    }

    await _ensureGoogleSignInInitialized();

    final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
    final String? idToken = googleUser.authentication.idToken;

    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'missing-google-id-token',
        message: 'Google Sign-In did not return an ID token.',
      );
    }

    final authCredential = GoogleAuthProvider.credential(idToken: idToken);
    final userCredential = await _firebaseAuth.signInWithCredential(
      authCredential,
    );

    return userCredential.user;
  }

  Future<void> signOut() async {
    try {
      if (!kIsWeb && _isGoogleSignInInitialized) {
        await _googleSignIn.signOut();
      }
    } finally {
      await _firebaseAuth.signOut();
    }
  }

  User? getCurrentUser() {
    return _firebaseAuth.currentUser;
  }

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_isGoogleSignInInitialized) {
      return;
    }

    await _googleSignIn.initialize();
    _isGoogleSignInInitialized = true;
  }
}
