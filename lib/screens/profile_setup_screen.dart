import 'package:billeasy/l10n/app_strings.dart';
import 'package:billeasy/modals/business_profile.dart';
import 'package:billeasy/services/auth_service.dart';
import 'package:billeasy/services/profile_service.dart';
import 'package:billeasy/theme/app_colors.dart';
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
  final TextEditingController _gstinController = TextEditingController();
  final TextEditingController _bankAccountNameController = TextEditingController();
  final TextEditingController _bankAccountNumberController = TextEditingController();
  final TextEditingController _bankIfscController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _upiIdController = TextEditingController();
  final ProfileService _profileService = ProfileService();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _didPrefill = false;
  bool _showBankDetails = false;

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
    _gstinController.dispose();
    _bankAccountNameController.dispose();
    _bankAccountNumberController.dispose();
    _bankIfscController.dispose();
    _bankNameController.dispose();
    _upiIdController.dispose();
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
        backgroundColor: kSurface,
        body: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          color: kSurfaceLowest,
                          boxShadow: const [kWhisperShadow],
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
                                color: kPrimaryContainer,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                currentUser?.email ?? s.profileBadgeFallback,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: kPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              promptTitle,
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: kOnSurface,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              promptBody,
                              style: const TextStyle(
                                color: kOnSurfaceVariant,
                                fontSize: 15,
                                height: 1.55,
                              ),
                            ),
                            const SizedBox(height: 26),

                            // ── Business Info ──────────────────────────
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
                            const SizedBox(height: 16),
                            TextField(
                              controller: _gstinController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: _inputDecoration(
                                label: s.profileGstinLabel,
                                hint: s.profileGstinHint,
                                icon: Icons.receipt_long_outlined,
                              ),
                            ),
                            const SizedBox(height: 26),

                            // ── UPI ID ─────────────────────────────────
                            TextField(
                              controller: _upiIdController,
                              decoration: _inputDecoration(
                                label: 'UPI ID',
                                hint: 'e.g. yourname@upi',
                                icon: Icons.payment_outlined,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // ── Bank Details Toggle ────────────────────
                            InkWell(
                              onTap: () => setState(() => _showBankDetails = !_showBankDetails),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: kPrimaryContainer,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.account_balance_outlined, color: kPrimary),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        'Bank Account Details',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: kPrimary,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      _showBankDetails
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons.keyboard_arrow_down_rounded,
                                      color: kPrimary,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            if (_showBankDetails) ...[
                              const SizedBox(height: 16),
                              TextField(
                                controller: _bankAccountNameController,
                                textCapitalization: TextCapitalization.words,
                                decoration: _inputDecoration(
                                  label: 'Account Holder Name',
                                  hint: s.profileOptionalHint,
                                  icon: Icons.person_outline,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _bankAccountNumberController,
                                keyboardType: TextInputType.number,
                                decoration: _inputDecoration(
                                  label: 'Account Number',
                                  hint: s.profileOptionalHint,
                                  icon: Icons.credit_card_outlined,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _bankIfscController,
                                textCapitalization: TextCapitalization.characters,
                                decoration: _inputDecoration(
                                  label: 'IFSC Code',
                                  hint: 'e.g. SBIN0001234',
                                  icon: Icons.code_outlined,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _bankNameController,
                                textCapitalization: TextCapitalization.words,
                                decoration: _inputDecoration(
                                  label: 'Bank Name',
                                  hint: s.profileOptionalHint,
                                  icon: Icons.account_balance_outlined,
                                ),
                              ),
                            ],

                            const SizedBox(height: 26),
                            SizedBox(
                              width: double.infinity,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: kSignatureGradient,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: ElevatedButton(
                                  onPressed: _isSaving ? null : _saveProfile,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
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
                            ),
                          ],
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
      fillColor: kSurfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: kPrimary,
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
        _gstinController.text = profile.gstin;
        _bankAccountNameController.text = profile.bankAccountName;
        _bankAccountNumberController.text = profile.bankAccountNumber;
        _bankIfscController.text = profile.bankIfsc;
        _bankNameController.text = profile.bankName;
        _upiIdController.text = profile.upiId;

        // Auto-expand bank section if any bank field has data
        if (profile.bankAccountName.isNotEmpty ||
            profile.bankAccountNumber.isNotEmpty ||
            profile.bankIfsc.isNotEmpty ||
            profile.bankName.isNotEmpty) {
          _showBankDetails = true;
        }

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
      gstin: _gstinController.text.trim(),
      bankAccountName: _bankAccountNameController.text.trim(),
      bankAccountNumber: _bankAccountNumberController.text.trim(),
      bankIfsc: _bankIfscController.text.trim(),
      bankName: _bankNameController.text.trim(),
      upiId: _upiIdController.text.trim(),
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
