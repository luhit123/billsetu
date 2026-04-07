import 'package:billeasy/modals/member.dart';
import 'package:billeasy/modals/subscription_plan.dart';
import 'package:billeasy/services/membership_service.dart';
import 'package:billeasy/utils/error_helpers.dart';
import 'package:billeasy/services/team_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:billeasy/widgets/permission_denied_dialog.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:intl/intl.dart';

class MemberFormScreen extends StatefulWidget {
  const MemberFormScreen({super.key, this.member, this.preselectedPlan});

  final Member? member;
  final SubscriptionPlan? preselectedPlan;

  @override
  State<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends State<MemberFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final MembershipService _membershipService = MembershipService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  bool get _isEditing => widget.member != null && widget.member!.id.isNotEmpty;

  List<SubscriptionPlan> _plans = [];
  bool _loadingPlans = true;
  SubscriptionPlan? _selectedPlan;

  DateTime _startDate = DateTime.now();
  bool _autoRenew = true;
  bool _isSaving = false;

  DateTime get _endDate =>
      _startDate.add(Duration(days: _selectedPlan?.durationDays ?? 0));

  double get _planPrice => _selectedPlan?.price ?? 0;
  double get _joiningFee => _selectedPlan?.joiningFee ?? 0;
  double get _discountPercent => _selectedPlan?.discountPercent ?? 0;
  double get _discountAmount => _planPrice * _discountPercent / 100;
  double get _total => (_planPrice - _discountAmount) + _joiningFee;

  @override
  void initState() {
    super.initState();
    _loadPlans();

    final m = widget.member;
    if (m != null) {
      _nameController.text = m.name;
      _phoneController.text = m.phone;
      _emailController.text = m.email;
      _notesController.text = m.notes;
      _startDate = m.startDate;
      _autoRenew = m.autoRenew;
    }

    if (widget.preselectedPlan != null) {
      _selectedPlan = widget.preselectedPlan;
      _autoRenew = widget.preselectedPlan!.autoRenew;
    }
  }

  Future<void> _loadPlans() async {
    try {
      final plans = await _membershipService.getActivePlans();
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _loadingPlans = false;

        // If editing, match existing plan
        if (_isEditing && _selectedPlan == null) {
          final match = plans.where((p) => p.id == widget.member!.planId);
          if (match.isNotEmpty) {
            _selectedPlan = match.first;
            _autoRenew = widget.member!.autoRenew;
          }
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPlans = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: kPrimary,
              onPrimary: Colors.white,
              surface: context.cs.surfaceContainerLowest,
              onSurface: context.cs.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _save() async {
    if (!PermissionDenied.check(
      context,
      TeamService.instance.can.canManageSubscription,
      'manage members',
    )) {
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    if (_selectedPlan == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a plan')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final plan = _selectedPlan!;
      final planChanged = _isEditing && widget.member!.planId != plan.id;
      final amountPaid = (!_isEditing || planChanged)
          ? plan.effectivePrice
          : widget.member!.amountPaid;
      final joiningFeePaid = (!_isEditing || planChanged)
          ? plan.joiningFee
          : widget.member!.joiningFeePaid;

      final member = Member(
        id: widget.member?.id ?? '',
        ownerId: widget.member?.ownerId ?? '',
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        notes: _notesController.text.trim(),
        planId: plan.id,
        planName: plan.name,
        status: widget.member?.status ?? MemberStatus.active,
        startDate: _startDate,
        endDate: _endDate,
        autoRenew: _autoRenew,
        amountPaid: amountPaid,
        joiningFeePaid: joiningFeePaid,
        attendanceCount: widget.member?.attendanceCount ?? 0,
        lastCheckIn: widget.member?.lastCheckIn,
        frozenUntil: widget.member?.frozenUntil,
        createdAt: widget.member?.createdAt ?? now,
        updatedAt: now,
      );

      final saved = await _membershipService.saveMember(member);
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFriendlyError(e, fallback: 'Failed to save member. Please try again.'))));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Input decoration helper ─────────────────────────────────────────────────
  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? prefix,
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: context.cs.onSurfaceVariant, size: 20),
      prefixText: prefix,
      prefixStyle: TextStyle(color: context.cs.onSurface, fontSize: 15),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: context.cs.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kPrimary, width: 1.8),
      ),
      labelStyle: TextStyle(color: context.cs.onSurfaceVariant, fontSize: 14),
      hintStyle: TextStyle(
        color: context.cs.onSurfaceVariant.withAlpha(153),
        fontSize: 14,
      ),
    );
  }

  Future<void> _pickFromContacts() async {
    try {
      final contact = await FlutterContacts.openExternalPick();
      if (contact == null || !mounted) return;

      Contact? fullContact;
      if (await FlutterContacts.requestPermission()) {
        fullContact = await FlutterContacts.getContact(
          contact.id,
          withProperties: true,
          withAccounts: false,
          withPhoto: false,
        );
      }

      if (!mounted) return;
      final source = fullContact ?? contact;

      final name = source.displayName;
      final phone = source.phones.isNotEmpty
          ? source.phones.first.number
                .replaceAll(RegExp(r'[\s\-()]'), '')
                .replaceFirst(RegExp(r'^\+91'), '')
          : '';
      final email = source.emails.isNotEmpty ? source.emails.first.address : '';

      setState(() {
        if (name.isNotEmpty && _nameController.text.isEmpty) {
          _nameController.text = name;
        }
        if (phone.isNotEmpty) _phoneController.text = phone;
        if (email.isNotEmpty && _emailController.text.isEmpty) {
          _emailController.text = email;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open contacts')),
        );
      }
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cs.surface,
      appBar: kBuildGradientAppBar(
        titleText: _isEditing ? 'Edit Member' : 'Add Member',
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Member Details ────────────────────────────────────────
                    _sectionHeader('MEMBER DETAILS'),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDecoration(
                        label: 'Name',
                        icon: Icons.person_outline,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Name is required'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDecoration(
                        label: 'Phone',
                        icon: Icons.phone_outlined,
                        prefix: '+91 ',
                        suffixIcon: kIsWeb
                            ? null
                            : IconButton(
                                icon: const Icon(
                                  Icons.contacts_rounded,
                                  color: kPrimary,
                                  size: 20,
                                ),
                                tooltip: 'Pick from contacts',
                                onPressed: _pickFromContacts,
                              ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputDecoration(
                        label: 'Email (optional)',
                        icon: Icons.email_outlined,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: _inputDecoration(
                        label: 'Notes (optional)',
                        icon: Icons.notes_outlined,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Plan Selection ────────────────────────────────────────
                    _sectionHeader('SELECT PLAN'),
                    const SizedBox(height: 12),
                    _buildPlanSelector(),

                    // ── Membership Details (visible after plan selected) ──────
                    if (_selectedPlan != null) ...[
                      const SizedBox(height: 28),
                      _sectionHeader('MEMBERSHIP DETAILS'),
                      const SizedBox(height: 12),
                      _buildMembershipDetails(),

                      const SizedBox(height: 28),

                      // ── Payment Summary ────────────────────────────────────
                      _sectionHeader('PAYMENT SUMMARY'),
                      const SizedBox(height: 12),
                      _buildPaymentSummary(),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),

          // ── Save Button ──────────────────────────────────────────────────
          _buildSaveButton(),
        ],
      ),
    );
  }

  // ── Section header ──────────────────────────────────────────────────────────
  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: context.cs.onSurfaceVariant,
        letterSpacing: 1.1,
      ),
    );
  }

  // ── Plan Selector ───────────────────────────────────────────────────────────
  Widget _buildPlanSelector() {
    if (_loadingPlans) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2),
        ),
      );
    }

    if (_plans.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        decoration: BoxDecoration(
          color: context.cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              Icons.info_outline,
              color: context.cs.onSurfaceVariant.withAlpha(153),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'No plans created yet',
              style: TextStyle(
                color: context.cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Create a subscription plan first, then add members.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.cs.onSurfaceVariant.withAlpha(153),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _plans.map((plan) {
        final isSelected = _selectedPlan?.id == plan.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedPlan = plan;
                _autoRenew = plan.autoRenew;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected
                    ? context.cs.primaryContainer
                    : context.cs.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? kPrimary : Colors.transparent,
                  width: isSelected ? 1.8 : 0,
                ),
                boxShadow: isSelected ? null : const [kWhisperShadow],
              ),
              child: Row(
                children: [
                  // Radio indicator
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? kPrimary
                            : context.cs.outlineVariant,
                        width: isSelected ? 6 : 2,
                      ),
                      color: isSelected ? Colors.white : Colors.transparent,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Plan info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? kPrimary : context.cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          plan.durationLabel,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Price + discount badge
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _currencyFormat.format(plan.price),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? kPrimary : context.cs.onSurface,
                        ),
                      ),
                      if (plan.discountPercent > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: kPaid.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${plan.discountPercent.toStringAsFixed(0)}% OFF',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: kPaid,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Membership Details ──────────────────────────────────────────────────────
  Widget _buildMembershipDetails() {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Column(
      children: [
        // Start Date
        GestureDetector(
          onTap: _pickStartDate,
          child: AbsorbPointer(
            child: TextFormField(
              decoration:
                  _inputDecoration(
                    label: 'Start Date',
                    icon: Icons.calendar_today_outlined,
                  ).copyWith(
                    hintText: dateFormat.format(_startDate),
                    hintStyle: TextStyle(
                      color: context.cs.onSurface,
                      fontSize: 15,
                    ),
                    suffixIcon: const Icon(
                      Icons.edit_calendar,
                      color: kPrimary,
                      size: 20,
                    ),
                  ),
              controller: TextEditingController(
                text: dateFormat.format(_startDate),
              ),
              readOnly: true,
            ),
          ),
        ),
        const SizedBox(height: 14),

        // End Date (read-only, auto-calculated)
        TextFormField(
          decoration:
              _inputDecoration(
                label: 'End Date (auto-calculated)',
                icon: Icons.event_outlined,
              ).copyWith(
                filled: true,
                fillColor: context.cs.surfaceContainerHighest,
              ),
          controller: TextEditingController(text: dateFormat.format(_endDate)),
          readOnly: true,
          enabled: false,
          style: TextStyle(color: context.cs.onSurfaceVariant),
        ),
        const SizedBox(height: 14),

        // Auto-Renew Toggle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: context.cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                Icons.autorenew,
                color: context.cs.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Auto-Renew',
                  style: TextStyle(
                    fontSize: 15,
                    color: context.cs.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Switch.adaptive(
                value: _autoRenew,
                activeColor: kPrimary,
                onChanged: (v) => setState(() => _autoRenew = v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Payment Summary ─────────────────────────────────────────────────────────
  Widget _buildPaymentSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cs.primaryContainer.withOpacity(0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _summaryRow('Plan price', _currencyFormat.format(_planPrice)),
          if (_joiningFee > 0) ...[
            const SizedBox(height: 8),
            _summaryRow('Joining fee', _currencyFormat.format(_joiningFee)),
          ],
          if (_discountPercent > 0) ...[
            const SizedBox(height: 8),
            _summaryRow(
              'Discount (${_discountPercent.toStringAsFixed(0)}%)',
              '- ${_currencyFormat.format(_discountAmount)}',
              valueColor: kPaid,
            ),
          ],
          Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: context.cs.outlineVariant),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.cs.onSurface,
                ),
              ),
              Text(
                _currencyFormat.format(_total),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: kPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: context.cs.onSurfaceVariant),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor ?? context.cs.onSurface,
          ),
        ),
      ],
    );
  }

  // ── Save Button ─────────────────────────────────────────────────────────────
  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: context.cs.surfaceContainerLowest,
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: kSignatureGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    _isEditing ? 'Update Member' : 'Add Member',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
