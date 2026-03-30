import 'dart:typed_data';

import 'package:billeasy/l10n/app_strings.dart';
import 'package:billeasy/modals/business_profile.dart';
import 'package:billeasy/services/auth_service.dart';
import 'package:billeasy/services/logo_cache_service.dart';
import 'package:billeasy/services/profile_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:billeasy/utils/upi_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({
    super.key,
    this.isRequiredSetup = false,
  });

  final bool isRequiredSetup;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final AuthService _authService = AuthService();
  final _storeNameController    = TextEditingController();
  final _addressController      = TextEditingController();
  final _phoneController        = TextEditingController();
  final _gstinController        = TextEditingController();
  final _upiIdController        = TextEditingController();
  // Preserved from existing profiles (not shown in UI, written back unchanged)
  String _upiQrUrl    = '';
  String _upiNumber   = '';
  String _bankAccountName   = '';
  String _bankAccountNumber = '';
  String _bankIfsc          = '';
  String _bankName          = '';

  // Logo state
  String _logoUrl = '';
  bool _isUploadingLogo = false;

  final ProfileService _profileService = ProfileService();

  bool _isLoading  = true;
  bool _isSaving   = false;
  bool _didPrefill = false;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadProfile();
    // Rebuild avatar when store name changes
    _storeNameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _gstinController.dispose();
    _upiIdController.dispose();
    super.dispose();
  }

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> _loadProfile() async {
    try {
      final profile = await _profileService.getCurrentProfile();
      if (!mounted) return;
      if (profile != null && !_didPrefill) {
        _storeNameController.text = profile.storeName;
        _addressController.text   = profile.address;
        _phoneController.text     = profile.phoneNumber;
        _gstinController.text     = profile.gstin;
        _logoUrl          = profile.logoUrl;
        _upiIdController.text = profile.upiId;
        // Preserve hidden fields so they survive a re-save
        _upiQrUrl         = profile.upiQrUrl;
        _upiNumber        = profile.upiNumber;
        _bankAccountName  = profile.bankAccountName;
        _bankAccountNumber = profile.bankAccountNumber;
        _bankIfsc         = profile.bankIfsc;
        _bankName         = profile.bankName;
        _didPrefill = true;
      }
    } catch (_) {
      // ignore — user can still fill manually
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _saveProfile() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).profileSignInRequired)),
      );
      return;
    }

    if (widget.isRequiredSetup && _storeNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your business name to continue')),
      );
      return;
    }

    final gstin = _gstinController.text.trim();
    if (gstin.isNotEmpty &&
        !RegExp(r'^\d{2}[A-Z]{5}\d{4}[A-Z][A-Z0-9]Z[A-Z0-9]$').hasMatch(gstin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid GSTIN format. Expected 15 characters, e.g. 07AABCU9603R1ZX')),
      );
      return;
    }

    final upiId = _upiIdController.text.trim();
    if (upiId.isNotEmpty) {
      final upiError = validateUpiId(upiId);
      if (upiError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid UPI ID: $upiError')),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    final profile = BusinessProfile(
      ownerId:           currentUser.uid,
      storeName:         _storeNameController.text.trim(),
      address:           _addressController.text.trim(),
      phoneNumber:       _phoneController.text.trim(),
      gstin:             gstin,
      logoUrl:           _logoUrl,
      upiId:             _upiIdController.text.trim(),
      upiNumber:         _upiNumber,
      upiQrUrl:          _upiQrUrl,
      bankAccountName:   _bankAccountName,
      bankAccountNumber: _bankAccountNumber,
      bankIfsc:          _bankIfsc,
      bankName:          _bankName,
    );

    try {
      await _profileService.saveCurrentProfile(profile);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).profileSavedSuccess)),
      );
      if (!widget.isRequiredSetup) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).profileFailedSave(error.toString()))),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await _authService.signOut();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).profileFailedSignOut(error.toString()))),
      );
    }
  }

  // ── Logo ────────────────────────────────────────────────────────────────────

  Future<void> _pickAndUploadLogo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _isUploadingLogo = true);
    try {
      final bytes = await picked.readAsBytes();
      await LogoCacheService.save(bytes);
      final ref = FirebaseStorage.instance.ref('users/$uid/logo.png');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/png'));
      final url = await ref.getDownloadURL();
      if (!mounted) return;
      setState(() {
        _logoUrl = url;
        _isUploadingLogo = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingLogo = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload logo: $e')),
      );
    }
  }

  Future<void> _removeLogo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _isUploadingLogo = true);
    await LogoCacheService.clear();
    try {
      final ref = FirebaseStorage.instance.ref('users/$uid/logo.png');
      await ref.delete();
    } catch (_) {
      // File may not exist — ignore
    }
    if (!mounted) return;
    setState(() {
      _logoUrl = '';
      _isUploadingLogo = false;
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String get _initials {
    final name = _storeNameController.text.trim();
    if (name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length.clamp(0, 2)).toUpperCase();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return PopScope(
      canPop: !widget.isRequiredSetup,
      child: Scaffold(
        backgroundColor: kSurface,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: kPrimary))
            : widget.isRequiredSetup
                ? _buildSetupLayout(s)
                : _buildEditLayout(s),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SETUP LAYOUT  (first-time, required)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSetupLayout(AppStrings s) {
    return Column(
      children: [
        // ── Gradient hero ──
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0057FF), Color(0xFF003BB5)],
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            28, MediaQuery.of(context).padding.top + 24, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sign-out action
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _isSaving ? null : _signOut,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.logout_rounded, size: 14, color: Colors.white),
                        SizedBox(width: 5),
                        Text('Sign out', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Logo / Avatar
              _buildLogoAvatar(64),
              const SizedBox(height: 16),
              Text(
                s.profilePromptTitleSetup,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2),
              ),
              const SizedBox(height: 8),
              Text(
                s.profilePromptBodySetup,
                style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.8), height: 1.5),
              ),
            ],
          ),
        ),

        // ── Form ──
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: Column(
              children: [
                _SectionCard(
                  icon: Icons.storefront_rounded,
                  title: 'Business Info',
                  children: [
                    _Field(
                      controller: _storeNameController,
                      label: s.profileStoreLabel,
                      hint: 'Required',
                      icon: Icons.storefront_outlined,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 14),
                    _Field(
                      controller: _phoneController,
                      label: s.profilePhoneLabel,
                      hint: s.profileOptionalHint,
                      icon: Icons.call_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _buildSaveButton(s),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EDIT LAYOUT  (settings → edit profile)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildEditLayout(AppStrings s) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    return CustomScrollView(
      slivers: [
        // ── App bar with inline profile header ──
        SliverAppBar(
          expandedHeight: 180,
          pinned: true,
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          surfaceTintColor: Colors.transparent,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0057FF), Color(0xFF001F6B)],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
                  child: Row(
                    children: [
                      _buildLogoAvatar(60),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _storeNameController.text.trim().isEmpty
                                  ? 'Your Business'
                                  : _storeNameController.text.trim(),
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                            if (email.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(email, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            title: const Text('Edit Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17)),
            titlePadding: const EdgeInsetsDirectional.fromSTEB(56, 0, 0, 14),
            collapseMode: CollapseMode.parallax,
          ),
        ),

        // ── Form sections ──
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([

              // ── Business Logo ─────────────────────────────────────────
              _buildLogoSection(),
              const SizedBox(height: 14),

              // ── Business Info ──────────────────────────────────────────
              _SectionCard(
                icon: Icons.storefront_rounded,
                title: 'Business Info',
                children: [
                  _Field(
                    controller: _storeNameController,
                    label: s.profileStoreLabel,
                    hint: s.profileOptionalHint,
                    icon: Icons.storefront_outlined,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 14),
                  _Field(
                    controller: _phoneController,
                    label: s.profilePhoneLabel,
                    hint: s.profileOptionalHint,
                    icon: Icons.call_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 14),
                  _Field(
                    controller: _addressController,
                    label: s.profileAddressLabel,
                    hint: s.profileOptionalHint,
                    icon: Icons.location_on_outlined,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 3,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Tax & GST ──────────────────────────────────────────────
              _SectionCard(
                icon: Icons.receipt_long_rounded,
                title: 'Tax & GST',
                subtitle: 'Printed on invoices when provided',
                children: [
                  _Field(
                    controller: _gstinController,
                    label: s.profileGstinLabel,
                    hint: s.profileGstinHint,
                    icon: Icons.verified_outlined,
                    textCapitalization: TextCapitalization.characters,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Payment Settings ──────────────────────────────────────
              _SectionCard(
                icon: Icons.account_balance_wallet_rounded,
                title: 'Payment Settings',
                subtitle: 'Customers pay directly to your UPI',
                children: [
                  _Field(
                    controller: _upiIdController,
                    label: 'UPI ID',
                    hint: 'yourname@bankhandle',
                    icon: Icons.payment_rounded,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your invoice QR codes will use this UPI ID so customers can pay you directly — zero fees.',
                    style: TextStyle(fontSize: 11.5, color: kOnSurfaceVariant, height: 1.4),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              _buildSaveButton(s),
            ]),
          ),
        ),
      ],
    );
  }

  // ── Logo avatar widget ──────────────────────────────────────────────────────

  Widget _buildLogoAvatar(double size) {
    if (_isUploadingLogo) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.2),
        ),
        child: const Center(
          child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
        ),
      );
    }
    if (_logoUrl.isNotEmpty) {
      return GestureDetector(
        onTap: _pickAndUploadLogo,
        onLongPress: () => _showLogoOptions(context),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [BoxShadow(color: kPrimary.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
            image: DecorationImage(
              image: NetworkImage(_logoUrl),
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: _pickAndUploadLogo,
      child: Stack(
        children: [
          _AvatarCircle(initials: _initials, size: size),
          Positioned(
            bottom: 0, right: 0,
            child: Container(
              width: size * 0.34, height: size * 0.34,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)],
              ),
              child: Icon(Icons.camera_alt_rounded, size: size * 0.18, color: kPrimary),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurfaceLowest,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: kSurfaceContainerHigh, borderRadius: BorderRadius.circular(2))),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: kPrimary),
              title: const Text('Change Logo', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadLogo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE53935)),
              title: const Text('Remove Logo', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFE53935))),
              onTap: () {
                Navigator.pop(context);
                _removeLogo();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Logo section card for edit layout ──────────────────────────────────────

  Widget _buildLogoSection() {
    return _SectionCard(
      icon: Icons.image_rounded,
      title: 'Business Logo',
      subtitle: 'Shown on your invoices',
      children: [
        Center(
          child: Column(
            children: [
              // Logo preview
              if (_isUploadingLogo)
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    color: kSurfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: kPrimary)),
                )
              else if (_logoUrl.isNotEmpty)
                GestureDetector(
                  onTap: _pickAndUploadLogo,
                  child: Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kSurfaceContainerHigh, width: 1.5),
                      image: DecorationImage(
                        image: NetworkImage(_logoUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: _pickAndUploadLogo,
                  child: Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      color: kSurfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kSurfaceContainerHigh, width: 1.5, strokeAlign: BorderSide.strokeAlignInside),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, size: 32, color: kOnSurfaceVariant),
                        SizedBox(height: 6),
                        Text('Add Logo', style: TextStyle(fontSize: 12, color: kOnSurfaceVariant, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: _isUploadingLogo ? null : _pickAndUploadLogo,
                    icon: Icon(_logoUrl.isEmpty ? Icons.upload_rounded : Icons.swap_horiz_rounded, size: 18),
                    label: Text(_logoUrl.isEmpty ? 'Upload Logo' : 'Change'),
                    style: TextButton.styleFrom(foregroundColor: kPrimary),
                  ),
                  if (_logoUrl.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _isUploadingLogo ? null : _removeLogo,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Remove'),
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFFE53935)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Shared save button ─────────────────────────────────────────────────────

  Widget _buildSaveButton(AppStrings s) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _isSaving
              ? null
              : kSignatureGradient,
          color: _isSaving ? kSurfaceDim : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isSaving
              ? null
              : [const BoxShadow(color: Color(0x440057FF), blurRadius: 16, offset: Offset(0, 6))],
        ),
        child: ElevatedButton(
          onPressed: _isSaving ? null : _saveProfile,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledForegroundColor: kOnSurfaceVariant,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: kOnSurfaceVariant),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.isRequiredSetup
                          ? s.profileSaveAndContinue
                          : s.profileSave,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.2),
                    ),
                    if (widget.isRequiredSetup) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// REUSABLE WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

/// Circular initials avatar with blue gradient background.
class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.initials, required this.size});
  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
        ),
        boxShadow: [BoxShadow(color: kPrimary.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

/// Grouped section card with a header row (icon + title + optional subtitle).
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.children,
    this.subtitle,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [kWhisperShadow],
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: kPrimaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: kPrimary),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kOnSurface)),
                  if (subtitle != null)
                    Text(subtitle!, style: const TextStyle(fontSize: 11.5, color: kOnSurfaceVariant)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: kSurfaceContainerLow),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}


/// Consistent styled TextField for the profile form.
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: kOnSurface),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: kTextTertiary, fontSize: 13.5),
        labelStyle: const TextStyle(color: kOnSurfaceVariant, fontSize: 13.5),
        prefixIcon: Icon(icon, size: 20, color: kOnSurfaceVariant),
        filled: true,
        fillColor: kSurfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kPrimary, width: 1.6),
        ),
      ),
    );
  }
}
