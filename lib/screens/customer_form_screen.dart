import 'package:billeasy/l10n/app_strings.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:billeasy/modals/client.dart';
import 'package:billeasy/services/client_service.dart';
import 'package:billeasy/services/team_service.dart';
import 'package:billeasy/utils/error_helpers.dart';
import 'package:flutter/material.dart';

class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key, this.initialClient});

  final Client? initialClient;

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ClientService _clientService = ClientService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _gstinController = TextEditingController();

  bool _isSaving = false;

  bool get _isEditing =>
      widget.initialClient != null && widget.initialClient!.id.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final client = widget.initialClient;
    if (client != null) {
      _nameController.text = client.name;
      _phoneController.text = client.phone;
      _addressController.text = client.address;
      _gstinController.text = client.gstin;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _gstinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final title = _isEditing ? s.customerFormTitleEdit : s.customerFormTitleAdd;
    final subtitle = _isEditing ? s.customerFormSubtitleEdit : s.customerFormSubtitleAdd;

    return Scaffold(
      backgroundColor: context.cs.surface,
      appBar: AppBar(
        backgroundColor: context.cs.surface,
        foregroundColor: context.cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          title,
          style: TextStyle(
            color: context.cs.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        iconTheme: IconThemeData(color: context.cs.onSurface),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header card
              _buildCard(
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: context.cs.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1_rounded,
                        color: kPrimary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: context.cs.onSurface,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: context.cs.onSurfaceVariant,
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Form fields card
              _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel(s.customerFormNameLabel),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDecoration(
                        hint: s.customerFormNameRequired,
                        icon: Icons.person_outline,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return s.customerFormNameError;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    _sectionLabel(s.customerFormPhoneLabel),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDecoration(
                        hint: s.customerFormOptionalHint,
                        icon: Icons.call_outlined,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _sectionLabel(s.customerFormAddressLabel),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _addressController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 3,
                      decoration: _inputDecoration(
                        hint: s.customerFormOptionalHint,
                        icon: Icons.location_on_outlined,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _sectionLabel(s.customerGstinLabel),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _gstinController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: _inputDecoration(
                        hint: s.customerGstinHint,
                        icon: Icons.receipt_long_outlined,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveCustomer,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.1,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined, color: Colors.white),
                  label: Text(
                    _isSaving
                        ? s.customerFormSaving
                        : _isEditing
                        ? s.customerFormSaveChanges
                        : s.customerFormCreate,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.cs.primary,
                    disabledBackgroundColor: kPrimary.withValues(alpha: 0.50),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [kWhisperShadow],
      ),
      child: child,
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.cs.onSurfaceVariant,
        letterSpacing: 0.1,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: context.cs.onSurfaceVariant.withAlpha(153), fontSize: 14),
      errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 12),
      prefixIcon: Icon(icon, color: context.cs.onSurfaceVariant, size: 20),
      filled: true,
      fillColor: context.cs.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kPrimary, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.8),
      ),
    );
  }

  Future<void> _saveCustomer() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final isEditing = widget.initialClient != null;
    if (!(isEditing
        ? TeamService.instance.can.canEditCustomer
        : TeamService.instance.can.canAddCustomer)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'You don\'t have permission to edit customers.'
                : 'You don\'t have permission to add customers.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final savedClient = await _clientService.saveClient(
        Client(
          id: widget.initialClient?.id ?? '',
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          email: widget.initialClient?.email ?? '',
          address: _addressController.text.trim(),
          notes: widget.initialClient?.notes ?? '',
          groupId: widget.initialClient?.groupId ?? '',
          groupName: widget.initialClient?.groupName ?? '',
          gstin: _gstinController.text.trim().toUpperCase(),
          createdAt: widget.initialClient?.createdAt,
          updatedAt: widget.initialClient?.updatedAt,
        ),
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(savedClient);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).customerFormFailedSave(userFriendlyError(error, fallback: 'Unknown error')))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
