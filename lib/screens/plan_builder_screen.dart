import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:billeasy/modals/subscription_plan.dart';
import 'package:billeasy/services/membership_service.dart';
import 'package:billeasy/services/team_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:billeasy/widgets/permission_denied_dialog.dart';

class PlanBuilderScreen extends StatefulWidget {
  const PlanBuilderScreen({super.key, this.plan});

  final SubscriptionPlan? plan;

  @override
  State<PlanBuilderScreen> createState() => _PlanBuilderScreenState();
}

class _PlanBuilderScreenState extends State<PlanBuilderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _joiningFeeCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _gracePeriodCtrl = TextEditingController();
  final _customDaysCtrl = TextEditingController();

  PlanDuration _duration = PlanDuration.monthly;
  PlanType _planType = PlanType.recurring;
  bool _autoRenew = true;
  List<TextEditingController> _benefitControllers = [];
  bool _saving = false;
  String _colorHex = '#1E3A8A';
  bool _gstEnabled = false;
  double _gstRate = 18.0;
  String _gstType = 'cgst_sgst';

  bool get _isEditing => widget.plan != null;

  static const List<_PlanColor> _planColors = [
    _PlanColor('#1E3A8A', 'Navy', Color(0xFF1E3A8A)),
    _PlanColor('#0057FF', 'Blue', Color(0xFF0057FF)),
    _PlanColor('#7C3AED', 'Purple', Color(0xFF7C3AED)),
    _PlanColor('#DB2777', 'Pink', Color(0xFFDB2777)),
    _PlanColor('#DC2626', 'Red', Color(0xFFDC2626)),
    _PlanColor('#EA580C', 'Orange', Color(0xFFEA580C)),
    _PlanColor('#CA8A04', 'Gold', Color(0xFFCA8A04)),
    _PlanColor('#16A34A', 'Green', Color(0xFF16A34A)),
    _PlanColor('#0D9488', 'Teal', Color(0xFF0D9488)),
    _PlanColor('#475569', 'Slate', Color(0xFF475569)),
    _PlanColor('#1E1E1E', 'Black', Color(0xFF1E1E1E)),
    _PlanColor('#92400E', 'Brown', Color(0xFF92400E)),
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final p = widget.plan!;
      _nameCtrl.text = p.name;
      _descCtrl.text = p.description;
      _priceCtrl.text = p.price > 0 ? p.price.toStringAsFixed(0) : '';
      _joiningFeeCtrl.text = p.joiningFee > 0
          ? p.joiningFee.toStringAsFixed(0)
          : '';
      _discountCtrl.text = p.discountPercent > 0
          ? p.discountPercent.toStringAsFixed(0)
          : '';
      _gracePeriodCtrl.text = p.gracePeriodDays.toString();
      _customDaysCtrl.text = p.customDays.toString();
      _duration = p.duration;
      _planType = p.planType;
      _autoRenew = p.autoRenew;
      _colorHex = p.colorHex;
      _gstEnabled = p.gstEnabled;
      _gstRate = p.gstRate;
      _gstType = p.gstType;
      _benefitControllers = p.benefits.isEmpty
          ? [TextEditingController()]
          : p.benefits.map((b) => TextEditingController(text: b)).toList();
    } else {
      _gracePeriodCtrl.text = '3';
      _customDaysCtrl.text = '30';
      _benefitControllers = [TextEditingController()];
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _joiningFeeCtrl.dispose();
    _discountCtrl.dispose();
    _gracePeriodCtrl.dispose();
    _customDaysCtrl.dispose();
    for (final c in _benefitControllers) {
      c.dispose();
    }
    super.dispose();
  }

  double get _baseEffectivePrice {
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    final discount = double.tryParse(_discountCtrl.text) ?? 0;
    if (discount > 0 && price > 0) return price - (price * discount / 100);
    return price;
  }

  double get _effectivePrice {
    if (_gstEnabled) return _baseEffectivePrice * (1 + _gstRate / 100);
    return _baseEffectivePrice;
  }

  InputDecoration _inputDecoration({
    String? label,
    String? hint,
    Widget? prefix,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: context.cs.onSurfaceVariant, fontSize: 14),
      hintStyle: TextStyle(
        color: context.cs.onSurfaceVariant.withAlpha(153),
        fontSize: 14,
      ),
      filled: true,
      fillColor: context.cs.surfaceContainerLow,
      prefix: prefix,
      suffix: suffix,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kPrimary, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kOverdue, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kOverdue, width: 1.8),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: context.cs.onSurfaceVariant.withAlpha(153),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _sectionCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [kWhisperShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildDurationChip(PlanDuration dur, String label) {
    final selected = _duration == dur;
    return GestureDetector(
      onTap: () => setState(() => _duration = dur),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? kPrimary : context.cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected
                ? context.cs.onPrimary
                : context.cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!PermissionDenied.check(
      context,
      TeamService.instance.can.canManageSubscription,
      'manage membership plans',
    )) {
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final benefits = _benefitControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final plan = SubscriptionPlan(
      id: widget.plan?.id ?? '',
      ownerId: widget.plan?.ownerId ?? '',
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      benefits: benefits,
      duration: _duration,
      customDays: int.tryParse(_customDaysCtrl.text) ?? 30,
      price: double.tryParse(_priceCtrl.text) ?? 0,
      joiningFee: _planType == PlanType.package
          ? 0
          : (double.tryParse(_joiningFeeCtrl.text) ?? 0),
      discountPercent: double.tryParse(_discountCtrl.text) ?? 0,
      gracePeriodDays: int.tryParse(_gracePeriodCtrl.text) ?? 3,
      planType: _planType,
      autoRenew: _planType == PlanType.package ? false : _autoRenew,
      isActive: widget.plan?.isActive ?? true,
      memberCount: widget.plan?.memberCount ?? 0,
      colorHex: _colorHex,
      gstEnabled: _gstEnabled,
      gstRate: _gstRate,
      gstType: _gstType,
      createdAt: widget.plan?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      final savedPlan = await MembershipService().savePlan(plan);
      if (!mounted) return;
      Navigator.of(context).pop(savedPlan);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save plan: $e'),
          backgroundColor: kOverdue,
        ),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final plan = widget.plan;
    if (plan == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Plan?'),
        content: Text(
          plan.memberCount > 0
              ? 'This plan has ${plan.memberCount} active member${plan.memberCount == 1 ? '' : 's'}. '
                    'Deleting it will archive the plan for existing members and hide it from new enrollments.'
              : 'Are you sure you want to delete "${plan.name}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: kOverdue),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    if (!PermissionDenied.check(
      context,
      TeamService.instance.can.canManageSubscription,
      'delete membership plans',
    )) {
      return;
    }

    setState(() => _saving = true);
    try {
      await MembershipService().deletePlan(plan.id);
      if (!mounted) return;
      Navigator.of(context).pop('deleted');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete: $e'),
          backgroundColor: kOverdue,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cs.surface,
      appBar: kBuildGradientAppBar(
        titleText: _isEditing ? 'Edit Plan' : 'Create Plan',
        actions: [
          if (_isEditing)
            IconButton(
              onPressed: _saving ? null : _confirmDelete,
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Delete Plan',
            ),
          IconButton(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: kPrimary,
                    ),
                  )
                : const Icon(Icons.check_rounded),
            tooltip: 'Save',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            // ── BASIC INFO ──────────────────────────────────────────────
            _sectionTitle('BASIC INFO'),
            _sectionCard(
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: _inputDecoration(
                    label: 'Plan Name',
                    hint: 'e.g. Gold Membership',
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descCtrl,
                  decoration: _inputDecoration(
                    label: 'Description',
                    hint: 'What does this plan include?',
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                  minLines: 2,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── PLAN TYPE ─────────────────────────────────────────────
            _sectionTitle('PLAN TYPE'),
            _sectionCard(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _planType = PlanType.recurring),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _planType == PlanType.recurring
                                ? kPrimary
                                : context.cs.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.autorenew_rounded,
                                size: 22,
                                color: _planType == PlanType.recurring
                                    ? context.cs.onPrimary
                                    : context.cs.onSurfaceVariant,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Recurring',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _planType == PlanType.recurring
                                      ? context.cs.onPrimary
                                      : context.cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Pays every cycle',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _planType == PlanType.recurring
                                      ? context.cs.onPrimary.withValues(alpha: 0.7)
                                      : context.cs.onSurfaceVariant.withAlpha(
                                          153,
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _planType = PlanType.package;
                          _autoRenew = false;
                          _joiningFeeCtrl.clear();
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _planType == PlanType.package
                                ? kPrimary
                                : context.cs.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.card_giftcard_rounded,
                                size: 22,
                                color: _planType == PlanType.package
                                    ? context.cs.onPrimary
                                    : context.cs.onSurfaceVariant,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Package',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _planType == PlanType.package
                                      ? context.cs.onPrimary
                                      : context.cs.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'One-time payment',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _planType == PlanType.package
                                      ? context.cs.onPrimary.withValues(alpha: 0.7)
                                      : context.cs.onSurfaceVariant.withAlpha(
                                          153,
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── DURATION ────────────────────────────────────────────────
            _sectionTitle('DURATION'),
            _sectionCard(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildDurationChip(PlanDuration.weekly, 'Weekly'),
                    _buildDurationChip(PlanDuration.monthly, 'Monthly'),
                    _buildDurationChip(PlanDuration.quarterly, 'Quarterly'),
                    _buildDurationChip(PlanDuration.halfYearly, '6 Months'),
                    _buildDurationChip(PlanDuration.yearly, 'Yearly'),
                    _buildDurationChip(PlanDuration.custom, 'Custom'),
                  ],
                ),
                if (_duration == PlanDuration.custom) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _customDaysCtrl,
                    decoration: _inputDecoration(
                      label: 'Custom Days',
                      hint: 'e.g. 45',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      if (_duration != PlanDuration.custom) return null;
                      final days = int.tryParse(v ?? '') ?? 0;
                      if (days <= 0) return 'Enter a valid number of days';
                      return null;
                    },
                  ),
                ],
              ],
            ),

            const SizedBox(height: 20),

            // ── PRICING ─────────────────────────────────────────────────
            _sectionTitle(
              _planType == PlanType.package ? 'PACKAGE FEE' : 'PRICING',
            ),
            _sectionCard(
              children: [
                TextFormField(
                  controller: _priceCtrl,
                  decoration: _inputDecoration(
                    label: _planType == PlanType.package
                        ? 'Package Fee'
                        : 'Price per cycle',
                    hint: '0',
                    prefix: Text(
                      '₹ ',
                      style: TextStyle(
                        color: context.cs.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                ),
                if (_planType == PlanType.recurring) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _joiningFeeCtrl,
                    decoration: _inputDecoration(
                      label: 'Joining Fee (one-time)',
                      hint: '0',
                      prefix: Text(
                        '₹ ',
                        style: TextStyle(
                          color: context.cs.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ],
                const SizedBox(height: 14),
                TextFormField(
                  controller: _discountCtrl,
                  decoration: _inputDecoration(
                    label: 'Discount',
                    hint: '0',
                    suffix: Text(
                      '%',
                      style: TextStyle(
                        color: context.cs.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: context.cs.primaryContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Effective Price',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: context.cs.onSurfaceVariant,
                            ),
                          ),
                          if (_gstEnabled)
                            Text(
                              'incl. ${_gstRate.toStringAsFixed(0)}% GST',
                              style: TextStyle(
                                fontSize: 10,
                                color: context.cs.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        '₹ ${_effectivePrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: kPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── SETTINGS ────────────────────────────────────────────────
            _sectionTitle('SETTINGS'),
            _sectionCard(
              children: [
                TextFormField(
                  controller: _gracePeriodCtrl,
                  decoration: _inputDecoration(
                    label: 'Grace Period',
                    hint: '3',
                    suffix: Text(
                      'days',
                      style: TextStyle(
                        color: context.cs.onSurfaceVariant,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                if (_planType == PlanType.recurring) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Auto-Renew',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: context.cs.onSurface,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Automatically renew when the plan expires',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _autoRenew,
                        activeTrackColor: kPrimary,
                        onChanged: (v) => setState(() => _autoRenew = v),
                      ),
                    ],
                  ),
                ],
              ],
            ),

            const SizedBox(height: 20),

            // ── GST ─────────────────────────────────────────────────────
            _sectionTitle('GST'),
            _sectionCard(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Enable GST',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: context.cs.onSurface,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Add GST to invoice/receipt',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _gstEnabled,
                      activeTrackColor: kPrimary,
                      onChanged: (v) => setState(() => _gstEnabled = v),
                    ),
                  ],
                ),
                if (_gstEnabled) ...[
                  const SizedBox(height: 14),
                  // Rate selector
                  Text(
                    'GST Rate',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [5.0, 12.0, 18.0, 28.0].map((rate) {
                      final selected = _gstRate == rate;
                      return GestureDetector(
                        onTap: () => setState(() => _gstRate = rate),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? kPrimary
                                : context.cs.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${rate.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? context.cs.onPrimary
                                  : context.cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  // GST type
                  Text(
                    'GST Type',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _gstType = 'cgst_sgst'),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _gstType == 'cgst_sgst'
                                  ? kPrimary
                                  : context.cs.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'CGST + SGST',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _gstType == 'cgst_sgst'
                                        ? context.cs.onPrimary
                                        : context.cs.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  'Intra-state',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _gstType == 'cgst_sgst'
                                        ? context.cs.onPrimary.withValues(alpha: 0.7)
                                        : context.cs.onSurfaceVariant.withAlpha(
                                            153,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _gstType = 'igst'),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _gstType == 'igst'
                                  ? kPrimary
                                  : context.cs.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'IGST',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _gstType == 'igst'
                                        ? context.cs.onPrimary
                                        : context.cs.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  'Inter-state',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _gstType == 'igst'
                                        ? context.cs.onPrimary.withValues(alpha: 0.7)
                                        : context.cs.onSurfaceVariant.withAlpha(
                                            153,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: context.cs.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Base Price',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.cs.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '₹ ${_baseEffectivePrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: context.cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: context.cs.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'GST (${_gstRate.toStringAsFixed(0)}%)',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.cs.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '₹ ${(_baseEffectivePrice * _gstRate / 100).toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: context.cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 20),

            // ── BENEFITS ────────────────────────────────────────────────
            _sectionTitle('BENEFITS'),
            _sectionCard(
              children: [
                for (int i = 0; i < _benefitControllers.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: i < _benefitControllers.length - 1 ? 10 : 0,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _benefitControllers[i],
                            decoration: _inputDecoration(
                              hint: 'e.g. Access to all equipment',
                            ),
                            textCapitalization: TextCapitalization.sentences,
                          ),
                        ),
                        if (_benefitControllers.length > 1) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _benefitControllers[i].dispose();
                                _benefitControllers.removeAt(i);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: kOverdueBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: kOverdue,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _benefitControllers.add(TextEditingController());
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 14,
                    ),
                    decoration: BoxDecoration(
                      color: context.cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.add_rounded, size: 18, color: kPrimary),
                        SizedBox(width: 6),
                        Text(
                          'Add Benefit',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: kPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── CARD COLOR ────────────────────────────────────────────
            _sectionTitle('CARD COLOUR'),
            _sectionCard(
              children: [
                // Preview card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _parseColor(_colorHex),
                        _parseColor(_colorHex).withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _nameCtrl.text.isEmpty
                                  ? 'Plan Name'
                                  : _nameCtrl.text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _planType == PlanType.package
                                  ? 'Package'
                                  : 'Recurring',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _duration == PlanDuration.custom
                            ? '${_customDaysCtrl.text} Days'
                            : _duration.name[0].toUpperCase() +
                                  _duration.name.substring(1),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _effectivePrice == 0
                            ? 'FREE'
                            : '₹ ${_effectivePrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Color grid
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _planColors.map((pc) {
                    final selected = _colorHex == pc.hex;
                    return GestureDetector(
                      onTap: () => setState(() => _colorHex = pc.hex),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: pc.color,
                          borderRadius: BorderRadius.circular(12),
                          border: selected
                              ? Border.all(
                                  color: context.cs.onSurface,
                                  width: 2.5,
                                )
                              : Border.all(
                                  color: Colors.transparent,
                                  width: 2.5,
                                ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: pc.color.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: selected
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 20,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ── SAVE BUTTON ─────────────────────────────────────────────
            GestureDetector(
              onTap: _saving ? null : _save,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: _saving ? null : kSignatureGradient,
                  color: _saving ? context.cs.surfaceContainerHighest : null,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _saving ? null : const [kWhisperShadow],
                ),
                child: Center(
                  child: _saving
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: context.cs.onSurfaceVariant,
                          ),
                        )
                      : Text(
                          _isEditing ? 'Update Plan' : 'Create Plan',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.cs.onPrimary,
                            letterSpacing: 0.3,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _parseColor(String hex) {
    final h = hex.replaceFirst('#', '');
    if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
    return const Color(0xFF1E3A8A);
  }
}

class _PlanColor {
  const _PlanColor(this.hex, this.label, this.color);
  final String hex;
  final String label;
  final Color color;
}
