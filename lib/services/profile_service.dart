import 'dart:async';

import 'package:billeasy/modals/business_profile.dart';
import 'package:billeasy/services/logo_cache_service.dart';
import 'package:billeasy/services/signature_service.dart';
import 'package:billeasy/services/team_service.dart';
import 'package:billeasy/utils/firestore_helpers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Singleton profile service with in-memory + Firestore caching.
///
/// Profile data (including logoUrl) is fetched from Firestore once, then
/// served from memory on subsequent calls. A real-time listener keeps the
/// cache in sync whenever the Firestore doc changes.
///
/// Logo and signature bytes are cached in [LogoCacheService] and
/// [SignatureService] (SharedPreferences + memory). The first call to
/// [ensureImagesLoaded] downloads the logo image if needed and caches it
/// locally — all future accesses are instant and offline-safe.
class ProfileService {
  ProfileService._internal({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  }) => _instance;

  /// Direct access to the singleton for convenience.
  static ProfileService get instance => _instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  // ── In-memory profile cache ───────────────────────────────────────────────

  BusinessProfile? _cachedProfile;
  String? _cachedUid;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;
  StreamController<BusinessProfile?> _profileController =
      StreamController<BusinessProfile?>.broadcast();

  /// Emits whenever the profile changes (real-time from Firestore listener).
  Stream<BusinessProfile?> get profileStream => _profileController.stream;

  /// Returns the cached profile instantly, or null if not yet loaded.
  BusinessProfile? get cachedProfile => _cachedProfile;

  // ── Image bytes (logo + signature) ────────────────────────────────────────

  Uint8List? _logoBytes;
  Uint8List? _signatureBytes;
  bool _imagesLoaded = false;

  /// Cached logo image bytes. Null if no logo is set or not yet loaded.
  Uint8List? get logoBytes => _logoBytes;

  /// Cached signature image bytes. Null if no signature or not yet loaded.
  Uint8List? get signatureBytes => _signatureBytes;

  /// Whether [ensureImagesLoaded] has completed at least once.
  bool get imagesLoaded => _imagesLoaded;

  // ── Firestore helpers ─────────────────────────────────────────────────────

  DocumentReference<Map<String, dynamic>> _profileDoc(String ownerId) {
    return _firestore.collection('users').doc(ownerId);
  }

  // ── Initialization — call once at startup after auth ──────────────────────

  /// Guards against concurrent init() calls.
  bool _initInProgress = false;

  /// Starts the real-time profile listener and loads cached images.
  /// Safe to call multiple times — skips if already listening for this user.
  Future<void> init() async {
    // Use effective owner so team members load the owner's business profile
    // (logo, business name, bank details for invoices).
    String? uid;
    try {
      uid = TeamService.instance.getEffectiveOwnerId();
    } catch (_) {
      uid = _firebaseAuth.currentUser?.uid;
    }
    if (uid == null) return;
    if (_cachedUid == uid && _profileSub != null) return; // already listening
    if (_initInProgress) return; // prevent concurrent init calls
    _initInProgress = true;

    // Cancel old listener if switching users
    _profileSub?.cancel();
    _cachedUid = uid;

    // Load from Firestore once for instant UI
    try {
      final snapshot = await resilientGet(_profileDoc(uid));
      if (snapshot.exists && snapshot.data() != null) {
        _cachedProfile = BusinessProfile.fromMap(
          snapshot.data()!,
          ownerId: uid,
        );
        _profileController.add(_cachedProfile);
      }
    } catch (e) {
      debugPrint('[ProfileService] Initial load failed: $e');
    }

    // Start real-time listener to keep cache fresh
    _profileSub = _profileDoc(uid).snapshots().listen(
      (snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          final oldLogoUrl = _cachedProfile?.logoUrl;
          final oldSigUrl = _cachedProfile?.signatureUrl;
          _cachedProfile = BusinessProfile.fromMap(
            snapshot.data()!,
            ownerId: uid,
          );
          _profileController.add(_cachedProfile);

          // If logo URL changed, re-download and cache the new image
          if (_cachedProfile!.logoUrl != oldLogoUrl) {
            _downloadAndCacheLogo(_cachedProfile!.logoUrl);
          }
          // If signature URL changed, re-download and cache
          if (_cachedProfile!.signatureUrl != oldSigUrl) {
            _downloadAndCacheSignature(_cachedProfile!.signatureUrl);
          }
        } else {
          _cachedProfile = null;
          _profileController.add(null);
        }
      },
      onError: (e) {
        debugPrint('[ProfileService] Listener error: $e');
      },
    );

    _initInProgress = false;

    // Load images in parallel (non-blocking)
    await ensureImagesLoaded();
  }

  // ── Profile access ────────────────────────────────────────────────────────

  /// Returns the cached profile, or fetches from Firestore if cache is empty.
  Future<BusinessProfile?> getCurrentProfile() async {
    if (_cachedProfile != null) return _cachedProfile;

    final ownerId = TeamService.instance.getEffectiveOwnerId();
    final snapshot = await resilientGet(_profileDoc(ownerId));
    if (!snapshot.exists || snapshot.data() == null) return null;

    _cachedProfile = BusinessProfile.fromMap(
      snapshot.data()!,
      ownerId: snapshot.id,
    );
    return _cachedProfile;
  }

  /// Real-time stream — delegates to the internal listener.
  Stream<BusinessProfile?> watchCurrentProfile() {
    String? ownerId;
    try {
      ownerId = TeamService.instance.getEffectiveOwnerId();
    } catch (_) {
      ownerId = _firebaseAuth.currentUser?.uid;
    }
    if (ownerId == null) {
      return Stream.value(null);
    }

    return _profileDoc(ownerId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      _cachedProfile = BusinessProfile.fromMap(
        snapshot.data()!,
        ownerId: snapshot.id,
      );
      return _cachedProfile;
    });
  }

  Future<void> saveCurrentProfile(BusinessProfile profile) async {
    final currentUser = _requireCurrentUser();

    final existing = await resilientGet(_profileDoc(currentUser.uid));
    final isNew = !existing.exists;

    await _profileDoc(currentUser.uid).set({
      ...profile.toMap(),
      'ownerId': currentUser.uid,
      'email': currentUser.email,
      'displayName': currentUser.displayName,
      'updatedAt': FieldValue.serverTimestamp(),
      if (isNew) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Update cache immediately (listener will also fire but this is faster)
    _cachedProfile = profile;
    _profileController.add(_cachedProfile);
  }

  Future<void> updateCurrentLogoUrl(String logoUrl) async {
    final currentUser = _requireCurrentUser();
    final doc = _profileDoc(currentUser.uid);
    final existing = await resilientGet(doc);

    await doc.set({
      'ownerId': currentUser.uid,
      'email': currentUser.email,
      'displayName': currentUser.displayName,
      'logoUrl': logoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
      if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (_cachedProfile != null) {
      _cachedProfile = _cachedProfile!.copyWith(logoUrl: logoUrl);
      _profileController.add(_cachedProfile);
    }
  }

  // ── Image loading & caching ───────────────────────────────────────────────

  /// Loads logo and signature bytes from local cache (SharedPreferences).
  /// If logo cache is empty but a logoUrl exists, downloads and caches it.
  /// Call once at startup — subsequent calls are instant no-ops.
  Future<void> ensureImagesLoaded() async {
    if (_imagesLoaded) return;

    try {
      // Load from local caches in parallel
      final results = await Future.wait([
        LogoCacheService.load(),
        SignatureService.load(),
      ]);
      _logoBytes = results[0];
      _signatureBytes = results[1];

      // If no cached logo bytes but we have a URL, download and cache
      if (_logoBytes == null && (_cachedProfile?.logoUrl.isNotEmpty ?? false)) {
        await _downloadAndCacheLogo(_cachedProfile!.logoUrl);
      }
      // If no cached signature but we have a URL, download and cache
      if (_signatureBytes == null &&
          (_cachedProfile?.signatureUrl.isNotEmpty ?? false)) {
        await _downloadAndCacheSignature(_cachedProfile!.signatureUrl);
      }
    } catch (e) {
      debugPrint('[ProfileService] Image load error: $e');
    }

    _imagesLoaded = true;
  }

  /// Maximum allowed image download size (2 MB).
  static const _kMaxImageBytes = 2 * 1024 * 1024;

  /// Downloads logo from Firebase Storage URL and saves to local cache.
  Future<void> _downloadAndCacheLogo(String url) async {
    if (url.isEmpty) return;
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200 &&
          response.bodyBytes.isNotEmpty &&
          response.bodyBytes.length <= _kMaxImageBytes) {
        _logoBytes = response.bodyBytes;
        await LogoCacheService.save(_logoBytes!);
      }
    } catch (e) {
      debugPrint('[ProfileService] Logo download failed: $e');
    }
  }

  /// Updates the cached logo bytes (call after upload).
  Future<void> updateLogoBytes(Uint8List bytes) async {
    _logoBytes = bytes;
    await LogoCacheService.save(bytes);
  }

  /// Clears the cached logo bytes (call after logo removal).
  Future<void> clearLogoBytes() async {
    _logoBytes = null;
    await LogoCacheService.clear();
  }

  /// Downloads signature from URL and saves to local cache.
  Future<void> _downloadAndCacheSignature(String url) async {
    if (url.isEmpty) return;
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200 &&
          response.bodyBytes.isNotEmpty &&
          response.bodyBytes.length <= _kMaxImageBytes) {
        _signatureBytes = response.bodyBytes;
        await SignatureService.save(_signatureBytes!);
      }
    } catch (e) {
      debugPrint('[ProfileService] Signature download failed: $e');
    }
  }

  /// Uploads signature to Firebase Storage and saves URL.
  ///
  /// - **Owner / solo user:** uploads to `users/{uid}/signature.png` and saves
  ///   the URL to the business profile doc (shared with team).
  /// - **Team member:** uploads to `users/{theirUID}/signature.png` (own path
  ///   in Storage, which they have write permission for) and caches locally.
  ///   The member's personal signature is used on invoices they generate.
  Future<void> uploadSignature(Uint8List bytes) async {
    final actualUid = TeamService.instance.getActualUserId();
    final effectiveUid = TeamService.instance.getEffectiveOwnerId();
    final isTeamMember = TeamService.instance.isTeamMember;

    // Always upload to the caller's OWN Storage path (they have write access)
    final ref = FirebaseStorage.instance.ref('users/$actualUid/signature.png');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/png'));
    final url = await ref.getDownloadURL();

    // Owner: save URL to business profile (synced to team)
    if (!isTeamMember) {
      await _profileDoc(effectiveUid).set({
        'signatureUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (_cachedProfile != null) {
        _cachedProfile = _cachedProfile!.copyWith(signatureUrl: url);
        _profileController.add(_cachedProfile);
      }
    }

    // Always update local caches
    _signatureBytes = bytes;
    await SignatureService.save(bytes);
  }

  /// Updates the cached signature bytes (call after drawing).
  Future<void> updateSignatureBytes(Uint8List bytes) async {
    _signatureBytes = bytes;
    await SignatureService.save(bytes);
  }

  /// Clears the cached signature bytes and removes from cloud.
  Future<void> clearSignatureBytes() async {
    _signatureBytes = null;
    await SignatureService.clear();

    final actualUid = TeamService.instance.getActualUserId();
    final isTeamMember = TeamService.instance.isTeamMember;

    try {
      // Remove from Storage (own path)
      final ref = FirebaseStorage.instance.ref(
        'users/$actualUid/signature.png',
      );
      await ref.delete();

      // Owner: also clear from profile doc
      if (!isTeamMember) {
        final uid = TeamService.instance.getEffectiveOwnerId();
        await _profileDoc(uid).set({
          'signatureUrl': '',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {
      // Ignore if file doesn't exist
    }
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  /// Call on sign-out to stop listening and clear caches.
  void reset() {
    _profileSub?.cancel();
    _profileSub = null;
    _cachedProfile = null;
    _cachedUid = null;
    _logoBytes = null;
    _signatureBytes = null;
    _imagesLoaded = false;

    // Close the old controller to release any listeners, then create a fresh
    // one so subsequent `init()` calls can emit to new subscribers.
    if (!_profileController.isClosed) {
      _profileController.close();
    }
    _profileController = StreamController<BusinessProfile?>.broadcast();
  }

  void dispose() {
    _profileSub?.cancel();
    _profileController.close();
  }

  // ── Auth helpers ──────────────────────────────────────────────────────────

  User _requireCurrentUser() {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      throw StateError('Sign in is required to access your profile.');
    }
    return currentUser;
  }
}
