import 'dart:ui';

import 'package:billeasy/l10n/app_strings.dart';
import 'package:billeasy/modals/business_profile.dart';
import 'package:billeasy/services/auth_service.dart';
import 'package:billeasy/services/profile_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final ProfileService _profileService = ProfileService();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _didPrefill = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final currentUser = FirebaseAuth.instance.currentUser;
    final promptTitle = widget.isRequiredSetup
        ? s.profilePromptTitleSetup
        : s.profilePromptTitleEdit;
    final promptBody = widget.isRequiredSetup
        ? s.profilePromptBodySetup
        : s.profilePromptBodyEdit;

    return PopScope(
      canPop: !widget.isRequiredSetup,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.isRequiredSetup,
          title: Text(widget.isRequiredSetup ? s.profileAppBarSetup : s.profileAppBarEdit),
          actions: [
            if (widget.isRequiredSetup)
              IconButton(
                onPressed: _isSaving ? null : _signOut,
                tooltip: s.profileSignOutTooltip,
                icon: const Icon(Icons.logout_rounded),
              ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFF0FBFB),
                Color(0xFFF6FAFF),
                Color(0xFFEFF4FF),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                            child: Container(
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(
                                  color: Colors.white.withAlpha(170),
                                ),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withAlpha(195),
                                    Colors.white.withAlpha(150),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x14000000),
                                    blurRadius: 28,
                                    offset: Offset(0, 16),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF123C85).withAlpha(18),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: const Color(0xFF123C85).withAlpha(30),
                                      ),
                                    ),
                                    child: Text(
                                      currentUser?.email ?? s.profileBadgeFallback,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF123C85),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Text(
                                    promptTitle,
                                    style: const TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF102746),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    promptBody,
                                    style: TextStyle(
                                      color: Colors.blueGrey.shade700,
                                      fontSize: 15,
                                      height: 1.55,
                                    ),
                                  ),
                                  const SizedBox(height: 26),
                                  TextField(
                                    controller: _storeNameController,
                                    textCapitalization: TextCapitalization.words,
                                    decoration: _inputDecoration(
                                      label: s.profileStoreLabel,
                                      hint: s.profileOptionalHint,
                                      icon: Icons.storefront_outlined,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _addressController,
                                    textCapitalization: TextCapitalization.sentences,
                                    maxLines: 3,
                                    decoration: _inputDecoration(
                                      label: s.profileAddressLabel,
                                      hint: s.profileOptionalHint,
                                      icon: Icons.location_on_outlined,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    decoration: _inputDecoration(
                                      label: s.profilePhoneLabel,
                                      hint: s.profileOptionalHint,
                                      icon: Icons.call_outlined,
                                    ),
                                  ),
                                  const SizedBox(height: 26),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _isSaving ? null : _saveProfile,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF123C85),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(18),
                                        ),
                                      ),
                                      child: Text(
                                        _isSaving
                                            ? s.profileSaving
                                            : widget.isRequiredSetup
                                            ? s.profileSaveAndContinue
                                            : s.profileSave,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white.withAlpha(180),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFD4E2F8)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFD4E2F8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: Color(0xFF123C85),
          width: 1.4,
        ),
      ),
    );
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _profileService.getCurrentProfile();

      if (!mounted) {
        return;
      }

      if (profile != null && !_didPrefill) {
        _storeNameController.text = profile.storeName;
        _addressController.text = profile.address;
        _phoneController.text = profile.phoneNumber;
        _didPrefill = true;
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).profileSignInRequired)),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final profile = BusinessProfile(
      ownerId: currentUser.uid,
      storeName: _storeNameController.text.trim(),
      address: _addressController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
    );

    try {
      await _profileService.saveCurrentProfile(profile);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).profileSavedSuccess)),
      );

      if (!widget.isRequiredSetup) {
        Navigator.pop(context);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).profileFailedSave(error.toString()))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await _authService.signOut();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).profileFailedSignOut(error.toString()))),
      );
    }
  }
}
