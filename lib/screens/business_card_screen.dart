import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:billeasy/modals/business_profile.dart';
import 'package:billeasy/services/profile_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// ══════════════════════════════════════════════════════════════════════════════
// ENUMS & OPTIONS
// ══════════════════════════════════════════════════════════════════════════════

enum _CardTheme {
  royal,    // Blue deep gradient
  elegant,  // Dark navy + gold
  fresh,    // Clean white + accent strip
  sunset,   // Purple → Rose → Amber
  forest,   // Dark forest green
  minimal,  // Pure white typographic
  neon,     // Near-black + electric cyan
  saffron,  // Indian saffron + white
}

class _CardMeta {
  final String label;
  final String emoji;
  final List<Color> swatch;   // for the selector preview
  final bool supportsAccent;  // whether user accent colour applies
  const _CardMeta(this.label, this.emoji, this.swatch, {this.supportsAccent = false});
}

const _themeMeta = <_CardTheme, _CardMeta>{
  _CardTheme.royal:   _CardMeta('Royal',   '💎', [Color(0xFF0057FF), Color(0xFF001F6B)], supportsAccent: true),
  _CardTheme.elegant: _CardMeta('Elegant', '🌙', [Color(0xFF0D0D1A), Color(0xFF1A1A3E)]),
  _CardTheme.fresh:   _CardMeta('Fresh',   '✨', [Color(0xFFFFFFFF), Color(0xFFE8EEFF)], supportsAccent: true),
  _CardTheme.sunset:  _CardMeta('Sunset',  '🌅', [Color(0xFF6B21A8), Color(0xFFEA580C)]),
  _CardTheme.forest:  _CardMeta('Forest',  '🌿', [Color(0xFF052E16), Color(0xFF166534)]),
  _CardTheme.minimal: _CardMeta('Minimal', '📋', [Color(0xFFFFFFFF), Color(0xFFF1F5F9)], supportsAccent: true),
  _CardTheme.neon:    _CardMeta('Neon',    '⚡', [Color(0xFF08080F), Color(0xFF0A1628)]),
  _CardTheme.saffron: _CardMeta('Saffron', '🪔', [Color(0xFFFF9933), Color(0xFFFFFFFF)], supportsAccent: true),
};

// Preset accent colours
const _accentPresets = [
  Color(0xFF0057FF), // Royal Blue
  Color(0xFF6366F1), // Indigo
  Color(0xFF8B5CF6), // Purple
  Color(0xFFE11D48), // Rose
  Color(0xFFD97706), // Amber
  Color(0xFF0D9488), // Teal
  Color(0xFF166534), // Forest
  Color(0xFF0EA5E9), // Sky
];

class _CardOptions {
  final Color accent;
  final bool showPhone;
  final bool showGstin;
  final bool showAddress;
  final bool showUpi;
  final bool showWatermark;
  final bool square;

  const _CardOptions({
    this.accent = const Color(0xFF0057FF),
    this.showPhone = true,
    this.showGstin = true,
    this.showAddress = true,
    this.showUpi = true,
    this.showWatermark = true,
    this.square = false,
  });

  double get aspectRatio => square ? 1.0 : 1.75;

  _CardOptions copyWith({
    Color? accent,
    bool? showPhone,
    bool? showGstin,
    bool? showAddress,
    bool? showUpi,
    bool? showWatermark,
    bool? square,
  }) =>
      _CardOptions(
        accent: accent ?? this.accent,
        showPhone: showPhone ?? this.showPhone,
        showGstin: showGstin ?? this.showGstin,
        showAddress: showAddress ?? this.showAddress,
        showUpi: showUpi ?? this.showUpi,
        showWatermark: showWatermark ?? this.showWatermark,
        square: square ?? this.square,
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class BusinessCardScreen extends StatefulWidget {
  const BusinessCardScreen({super.key});

  @override
  State<BusinessCardScreen> createState() => _BusinessCardScreenState();
}

class _BusinessCardScreenState extends State<BusinessCardScreen> {
  BusinessProfile? _profile;
  bool _loading = true;
  bool _sharing = false;
  _CardTheme _selectedTheme = _CardTheme.royal;
  _CardOptions _options = const _CardOptions();
  final GlobalKey _cardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await ProfileService().getCurrentProfile();
    if (mounted) setState(() { _profile = profile; _loading = false; });
  }

  // ── Share ─────────────────────────────────────────────────────────────────

  Future<void> _shareCard() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      final boundary = _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('PNG encode failed');
      final Uint8List bytes = byteData.buffer.asUint8List();
      if (kIsWeb) {
        // On web, share as XFile from bytes directly
        if (!mounted) return;
        await SharePlus.instance.share(ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'image/png', name: 'business_card.png')],
          subject: '${_profile?.storeName ?? 'Business'} — Business Card',
        ));
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/business_card_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(bytes);
        if (!mounted) return;
        await SharePlus.instance.share(ShareParams(
          files: [XFile(file.path)],
          subject: '${_profile?.storeName ?? 'Business'} — Business Card',
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not share card: $e'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  // ── Customise bottom sheet ────────────────────────────────────────────────

  void _showCustomiseSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomiseSheet(
        options: _options,
        theme: _selectedTheme,
        onChanged: (opts) => setState(() => _options = opts),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cs.surface,
      appBar: AppBar(
        title: Text('Business Card',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: context.cs.onSurface)),
        backgroundColor: context.cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: context.cs.onSurface,
        iconTheme: IconThemeData(color: context.cs.onSurface),
        actions: [
          if (!_loading)
            TextButton.icon(
              onPressed: _showCustomiseSheet,
              icon: const Icon(Icons.tune_rounded, size: 18, color: kPrimary),
              label: const Text('Customise',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kPrimary)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(kPrimary)))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Theme selector ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 0, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Choose Style',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                              color: context.cs.onSurfaceVariant, letterSpacing: 0.8)),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 48,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(right: 20),
                          children: _CardTheme.values.map((theme) {
                            final meta = _themeMeta[theme]!;
                            final selected = _selectedTheme == theme;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _ThemePill(
                                meta: meta,
                                selected: selected,
                                onTap: () => setState(() => _selectedTheme = theme),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Card preview ──
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Column(
                      children: [
                        // Drop shadow wrapper
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: context.cs.onSurface.withValues(alpha: 0.2), blurRadius: 40, offset: Offset(0, 16)),
                              BoxShadow(color: context.cs.onSurface.withValues(alpha: 0.08), blurRadius: 10, offset: Offset(0, 4)),
                            ],
                          ),
                          child: RepaintBoundary(
                            key: _cardKey,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 320),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, anim) => FadeTransition(
                                  opacity: anim,
                                  child: ScaleTransition(scale: Tween(begin: 0.95, end: 1.0).animate(anim), child: child),
                                ),
                                child: KeyedSubtree(
                                  key: ValueKey(_selectedTheme),
                                  child: _buildCard(),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Customisation summary chips
                        _buildOptionSummary(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _loading ? null : _buildShareBar(),
    );
  }

  Widget _buildCard() {
    final p = _profile;
    switch (_selectedTheme) {
      case _CardTheme.royal:   return _RoyalCard(profile: p, options: _options);
      case _CardTheme.elegant: return _ElegantCard(profile: p, options: _options);
      case _CardTheme.fresh:   return _FreshCard(profile: p, options: _options);
      case _CardTheme.sunset:  return _SunsetCard(profile: p, options: _options);
      case _CardTheme.forest:  return _ForestCard(profile: p, options: _options);
      case _CardTheme.minimal: return _MinimalCard(profile: p, options: _options);
      case _CardTheme.neon:    return _NeonCard(profile: p, options: _options);
      case _CardTheme.saffron: return _SaffronCard(profile: p, options: _options);
    }
  }

  Widget _buildOptionSummary() {
    final hidden = <String>[];
    if (!_options.showPhone) hidden.add('Phone');
    if (!_options.showGstin) hidden.add('GSTIN');
    if (!_options.showAddress) hidden.add('Address');
    if (!_options.showUpi) hidden.add('UPI');

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        if (_options.square)
          _SummaryChip(icon: Icons.crop_square_rounded, label: 'Square'),
        if (hidden.isNotEmpty)
          _SummaryChip(icon: Icons.visibility_off_outlined, label: '${hidden.length} field${hidden.length > 1 ? 's' : ''} hidden'),
        if (_themeMeta[_selectedTheme]!.supportsAccent)
          _SummaryChip(
            icon: Icons.circle,
            label: 'Custom colour',
            iconColor: _options.accent,
          ),
      ],
    );
  }

  Widget _buildShareBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: context.cs.onSurface.withValues(alpha: 0.06), blurRadius: 16, offset: Offset(0, -4))],
        border: const Border(top: BorderSide(color: Color(0xFFEEF2F6))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Customise button
            Container(
              height: 52,
              decoration: BoxDecoration(
                color: context.cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: IconButton(
                onPressed: _showCustomiseSheet,
                icon: Icon(Icons.tune_rounded, color: context.cs.onSurface),
                tooltip: 'Customise',
              ),
            ),
            const SizedBox(width: 12),
            // Share button
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _sharing ? null : _shareCard,
                  icon: _sharing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.share_rounded, size: 20),
                  label: Text(_sharing ? 'Preparing…' : 'Share as Image',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.cs.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: context.cs.surfaceContainerHighest,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CUSTOMISE BOTTOM SHEET
// ══════════════════════════════════════════════════════════════════════════════

class _CustomiseSheet extends StatefulWidget {
  const _CustomiseSheet({required this.options, required this.theme, required this.onChanged});
  final _CardOptions options;
  final _CardTheme theme;
  final ValueChanged<_CardOptions> onChanged;

  @override
  State<_CustomiseSheet> createState() => _CustomiseSheetState();
}

class _CustomiseSheetState extends State<_CustomiseSheet> {
  late _CardOptions _opts;

  @override
  void initState() {
    super.initState();
    _opts = widget.options;
  }

  void _update(_CardOptions opts) {
    setState(() => _opts = opts);
    widget.onChanged(opts);
  }

  @override
  Widget build(BuildContext context) {
    final supportsAccent = _themeMeta[widget.theme]!.supportsAccent;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: context.cs.surfaceContainer, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Text('Customise Card',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.cs.onSurface)),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Accent colour ──
                  if (supportsAccent) ...[
                    _sheetLabel('Accent Colour'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _accentPresets.map((c) {
                        final selected = _opts.accent == c;
                        return GestureDetector(
                          onTap: () => _update(_opts.copyWith(accent: c)),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: selected ? Border.all(color: context.cs.onSurface, width: 2.5) : null,
                              boxShadow: selected
                                  ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 10, offset: const Offset(0, 3))]
                                  : null,
                            ),
                            child: selected
                                ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── Fields ──
                  _sheetLabel('Show on Card'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ToggleChip(label: 'Phone',   icon: Icons.phone_rounded,           value: _opts.showPhone,     onChanged: (v) => _update(_opts.copyWith(showPhone: v))),
                      _ToggleChip(label: 'GSTIN',   icon: Icons.receipt_long_rounded,    value: _opts.showGstin,     onChanged: (v) => _update(_opts.copyWith(showGstin: v))),
                      _ToggleChip(label: 'Address', icon: Icons.location_on_rounded,     value: _opts.showAddress,   onChanged: (v) => _update(_opts.copyWith(showAddress: v))),
                      _ToggleChip(label: 'UPI',     icon: Icons.currency_rupee_rounded,  value: _opts.showUpi,       onChanged: (v) => _update(_opts.copyWith(showUpi: v))),
                      _ToggleChip(label: 'BillRaja watermark', icon: Icons.water_drop_rounded, value: _opts.showWatermark, onChanged: (v) => _update(_opts.copyWith(showWatermark: v))),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Card shape ──
                  _sheetLabel('Card Shape'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _ShapeOption(
                        label: 'Landscape',
                        icon: Icons.crop_landscape_rounded,
                        selected: !_opts.square,
                        onTap: () => _update(_opts.copyWith(square: false)),
                      ),
                      const SizedBox(width: 12),
                      _ShapeOption(
                        label: 'Square',
                        icon: Icons.crop_square_rounded,
                        selected: _opts.square,
                        onTap: () => _update(_opts.copyWith(square: true)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetLabel(String text) => Text(text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
          color: context.cs.onSurfaceVariant, letterSpacing: 0.7));
}

// ══════════════════════════════════════════════════════════════════════════════
// SMALL HELPER WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _ThemePill extends StatelessWidget {
  const _ThemePill({required this.meta, required this.selected, required this.onTap});
  final _CardMeta meta;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: selected
              ? LinearGradient(colors: meta.swatch.length >= 2 ? [meta.swatch.first, meta.swatch.last] : [meta.swatch.first, meta.swatch.first])
              : null,
          color: selected ? null : context.cs.surfaceContainerLowest,
          border: selected ? null : Border.all(color: context.cs.outlineVariant),
          boxShadow: selected
              ? [BoxShadow(color: meta.swatch.first.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))]
              : null,
        ),
        height: 44,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(meta.emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(meta.label, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: selected
                  ? (meta.swatch.first.computeLuminance() > 0.4 ? context.cs.onSurface : Colors.white)
                  : context.cs.onSurface,
            )),
          ],
        ),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({required this.label, required this.icon, required this.value, required this.onChanged});
  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: value ? context.cs.primaryContainer : context.cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: value ? kPrimary.withValues(alpha: 0.4) : context.cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(value ? icon : Icons.visibility_off_outlined,
                size: 14, color: value ? kPrimary : context.cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: value ? kPrimary : context.cs.onSurfaceVariant,
            )),
          ],
        ),
      ),
    );
  }
}

class _ShapeOption extends StatelessWidget {
  const _ShapeOption({required this.label, required this.icon, required this.selected, required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 72,
          decoration: BoxDecoration(
            color: selected ? context.cs.primaryContainer : context.cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? kPrimary : context.cs.outlineVariant.withValues(alpha: 0.5),
              width: selected ? 2.0 : 1.0,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: selected ? kPrimary : context.cs.onSurfaceVariant),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: selected ? kPrimary : context.cs.onSurfaceVariant,
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.icon, required this.label, this.iconColor});
  final IconData icon;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor ?? context.cs.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, color: context.cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED HELPER — Profile data extraction
// ══════════════════════════════════════════════════════════════════════════════

class _ProfileData {
  final String name;
  final String initials;
  final String phone;
  final String gstin;
  final String address;
  final String upi;
  final String logoUrl;

  _ProfileData({required this.name, required this.initials, required this.phone,
      required this.gstin, required this.address, required this.upi, required this.logoUrl});

  bool get hasLogo => logoUrl.isNotEmpty;

  factory _ProfileData.from(BusinessProfile? p) {
    final name = p?.storeName.trim().isNotEmpty == true ? p!.storeName : 'Your Business';
    final parts = name.split(RegExp(r'\s+'));
    final initials = (parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'
        : name.isNotEmpty
            ? name.substring(0, name.length.clamp(0, 2))
            : 'BR').toUpperCase();
    return _ProfileData(
      name: name,
      initials: initials,
      phone: p?.phoneNumber ?? '',
      gstin: p?.gstin ?? '',
      address: p?.address ?? '',
      upi: p?.upiId ?? '',
      logoUrl: p?.logoUrl ?? '',
    );
  }

  /// Returns a logo image widget or falls back to initials circle.
  Widget logoOrInitials({
    required double size,
    required Color bgColor,
    required Color textColor,
    double fontSize = 22,
  }) {
    if (hasLogo) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          logoUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initialsCircle(size, bgColor, textColor, fontSize),
        ),
      );
    }
    return _initialsCircle(size, bgColor, textColor, fontSize);
  }

  Widget _initialsCircle(double size, Color bgColor, Color textColor, double fontSize) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: bgColor),
      alignment: Alignment.center,
      child: Text(initials, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900, color: textColor)),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CARD THEME 1: ROYAL (Blue gradient)
// ══════════════════════════════════════════════════════════════════════════════

class _RoyalCard extends StatelessWidget {
  const _RoyalCard({required this.profile, required this.options});
  final BusinessProfile? profile;
  final _CardOptions options;

  @override
  Widget build(BuildContext context) {
    final d = _ProfileData.from(profile);
    final accent = options.accent;
    final accentDark = Color.fromARGB(255,
      ((accent.r * 255.0).round() * 0.6).round(),
      ((accent.g * 255.0).round() * 0.6).round(),
      ((((accent.b * 255.0).round() * 0.8).round()) + 30).clamp(0, 255),
    );

    return AspectRatio(
      aspectRatio: options.aspectRatio,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [accent, Color.lerp(accent, accentDark, 0.5)!, accentDark],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned(right: -40, top: -40, child: _blob(180, Colors.white.withValues(alpha: 0.05))),
            Positioned(right: 30, bottom: -70, child: _blob(150, Colors.white.withValues(alpha: 0.04))),
            Positioned(left: -30, bottom: -30, child: _blob(110, Colors.white.withValues(alpha: 0.03))),
            Positioned(top: 0, left: 0, right: 0, child: Container(height: 2.5,
              decoration: BoxDecoration(gradient: LinearGradient(
                colors: [Colors.transparent, Colors.white.withValues(alpha: 0.4), Colors.transparent])))),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 24, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5, height: 1.15), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Container(width: 40, height: 2.5, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(2))),
                        const Spacer(),
                        if (options.showPhone && d.phone.isNotEmpty)    _row(Icons.phone_rounded, d.phone),
                        if (options.showGstin && d.gstin.isNotEmpty)    ...[const SizedBox(height: 4), _row(Icons.receipt_long_rounded, 'GSTIN: ${d.gstin}')],
                        if (options.showAddress && d.address.isNotEmpty) ...[const SizedBox(height: 4), _row(Icons.location_on_rounded, d.address)],
                        if (options.showUpi && d.upi.isNotEmpty)         ...[const SizedBox(height: 4), _row(Icons.currency_rupee_rounded, d.upi)],
                        const SizedBox(height: 8),
                        if (options.showWatermark) Text('via BillRaja', style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.35), letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                          color: d.hasLogo ? Colors.white : Colors.white.withValues(alpha: 0.12)),
                        alignment: Alignment.center,
                        child: d.logoOrInitials(size: 60, bgColor: Colors.white.withValues(alpha: 0.12), textColor: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blob(double s, Color c) => Container(width: s, height: s, decoration: BoxDecoration(shape: BoxShape.circle, color: c));

  Widget _row(IconData icon, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 11, color: Colors.white.withValues(alpha: 0.7)),
      const SizedBox(width: 5),
      Expanded(child: Text(text, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w500, height: 1.3), maxLines: 1, overflow: TextOverflow.ellipsis)),
    ],
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// CARD THEME 2: ELEGANT (Dark navy + gold)
// ══════════════════════════════════════════════════════════════════════════════

class _ElegantCard extends StatelessWidget {
  const _ElegantCard({required this.profile, required this.options});
  final BusinessProfile? profile;
  final _CardOptions options;

  static const _bg = Color(0xFF0D0D1A);
  static const _accent = Color(0xFF4A9EFF);
  static const _gold = Color(0xFFFFD166);

  @override
  Widget build(BuildContext context) {
    final d = _ProfileData.from(profile);
    return AspectRatio(
      aspectRatio: options.aspectRatio,
      child: Container(
        color: _bg,
        child: Stack(
          children: [
            Positioned(top: 0, left: 0, child: Container(width: 6, height: double.infinity,
              decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_gold, _accent])))),
            Positioned.fill(child: CustomPaint(painter: _DotGridPainter(color: Colors.white.withValues(alpha: 0.04)))),
            Positioned(right: -10, bottom: -20, child: Text(d.initials, style: TextStyle(fontSize: 110, fontWeight: FontWeight.w900, color: Colors.white.withValues(alpha: 0.035), letterSpacing: -4))),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 22, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.3, height: 1.15), maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 6),
                          Row(children: [
                            Container(width: 20, height: 2, color: _gold),
                            const SizedBox(width: 4),
                            Container(width: 8, height: 2, color: _accent),
                          ]),
                        ],
                      )),
                      Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _accent.withValues(alpha: 0.4), width: 1.5),
                          color: d.hasLogo ? Colors.white : _accent.withValues(alpha: 0.08)),
                        alignment: Alignment.center,
                        child: d.hasLogo
                            ? ClipRRect(borderRadius: BorderRadius.circular(10),
                                child: Image.network(d.logoUrl, width: 46, height: 46, fit: BoxFit.cover, errorBuilder: (_, __, ___) =>
                                    Text(d.initials, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _accent))))
                            : Text(d.initials, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _accent)),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Wrap(
                    spacing: 16, runSpacing: 6,
                    children: [
                      if (options.showPhone && d.phone.isNotEmpty)    _det(Icons.phone_rounded,           d.phone,              _accent),
                      if (options.showGstin && d.gstin.isNotEmpty)    _det(Icons.verified_rounded,        d.gstin,              _gold),
                      if (options.showAddress && d.address.isNotEmpty) _det(Icons.location_on_rounded,    d.address,            _accent),
                      if (options.showUpi && d.upi.isNotEmpty)         _det(Icons.currency_rupee_rounded, d.upi,                _gold),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (options.showWatermark) Align(alignment: Alignment.centerRight,
                    child: Text('via BillRaja', style: TextStyle(fontSize: 8.5, color: Colors.white.withValues(alpha: 0.2), letterSpacing: 0.5))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _det(IconData icon, String text, Color c) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 10, color: c),
      const SizedBox(width: 4),
      ConstrainedBox(constraints: const BoxConstraints(maxWidth: 160),
        child: Text(text, style: const TextStyle(fontSize: 10.5, color: Color(0xFFCCDDEE), fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis, maxLines: 1)),
    ],
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// CARD THEME 3: FRESH (Clean white + accent strip)
// ══════════════════════════════════════════════════════════════════════════════

class _FreshCard extends StatelessWidget {
  const _FreshCard({required this.profile, required this.options});
  final BusinessProfile? profile;
  final _CardOptions options;

  @override
  Widget build(BuildContext context) {
    final d = _ProfileData.from(profile);
    final accent = options.accent;
    final accentDark = Color.fromARGB(255,
      ((accent.r * 255.0).round() * 0.65).round(),
      ((accent.g * 255.0).round() * 0.65).round(),
      ((((accent.b * 255.0).round() * 0.85).round()) + 20).clamp(0, 255),
    );

    return AspectRatio(
      aspectRatio: options.aspectRatio,
      child: Container(
        color: Colors.white,
        child: Row(
          children: [
            Container(width: 8,
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [accent, accentDark]))),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0D1B2A), letterSpacing: -0.4, height: 1.15), maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 8),
                          Container(width: 36, height: 3, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2))),
                          const Spacer(),
                          if (options.showPhone && d.phone.isNotEmpty)     _row(Icons.phone_rounded, d.phone, accent),
                          if (options.showGstin && d.gstin.isNotEmpty)     ...[const SizedBox(height: 5), _row(Icons.receipt_long_rounded, 'GSTIN: ${d.gstin}', accent)],
                          if (options.showAddress && d.address.isNotEmpty) ...[const SizedBox(height: 5), _row(Icons.location_on_rounded, d.address, accent)],
                          if (options.showUpi && d.upi.isNotEmpty)         ...[const SizedBox(height: 5), _row(Icons.currency_rupee_rounded, d.upi, accent)],
                          const SizedBox(height: 8),
                          if (options.showWatermark) Text('via BillRaja', style: TextStyle(fontSize: 8.5, color: context.cs.onSurface.withValues(alpha: 0.2), letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 60, height: 60,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
                            gradient: d.hasLogo ? null : LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [accent, accentDark]),
                            color: d.hasLogo ? Colors.white : null),
                          alignment: Alignment.center,
                          child: d.hasLogo
                              ? ClipRRect(borderRadius: BorderRadius.circular(14),
                                  child: Image.network(d.logoUrl, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_, __, ___) =>
                                      Text(d.initials, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white))))
                              : Text(d.initials, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text, Color accent) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 11, color: accent),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontWeight: FontWeight.w500, height: 1.35), maxLines: 1, overflow: TextOverflow.ellipsis)),
    ],
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// CARD THEME 4: SUNSET (Purple → Rose → Amber)
// ══════════════════════════════════════════════════════════════════════════════

class _SunsetCard extends StatelessWidget {
  const _SunsetCard({required this.profile, required this.options});
  final BusinessProfile? profile;
  final _CardOptions options;

  @override
  Widget build(BuildContext context) {
    final d = _ProfileData.from(profile);
    return AspectRatio(
      aspectRatio: options.aspectRatio,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF6B21A8), Color(0xFFBE185D), Color(0xFFEA580C), Color(0xFFF59E0B)],
            stops: [0.0, 0.35, 0.7, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Organic blob decorations
            Positioned(right: -50, top: -50, child: _blob(200, Colors.white.withValues(alpha: 0.06))),
            Positioned(left: 60, bottom: -80, child: _blob(180, Colors.white.withValues(alpha: 0.04))),
            // Noise/texture overlay via dots
            Positioned.fill(child: CustomPaint(painter: _DotGridPainter(color: Colors.white.withValues(alpha: 0.03), spacing: 12, radius: 0.8))),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 22, 22, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tag line area
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                            child: Text('BUSINESS', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.8), letterSpacing: 1.5)),
                          ),
                          const SizedBox(height: 6),
                          Text(d.name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.4, height: 1.15), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      )),
                      // Diamond monogram / Logo
                      SizedBox(
                        width: 56, height: 56,
                        child: d.hasLogo
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(d.logoUrl, width: 56, height: 56, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => CustomPaint(
                                    size: const Size(56, 56),
                                    painter: _DiamondPainter(text: d.initials, borderColor: Colors.white.withValues(alpha: 0.4), fillColor: Colors.white.withValues(alpha: 0.12)),
                                  ),
                                ),
                              )
                            : CustomPaint(
                                size: const Size(56, 56),
                                painter: _DiamondPainter(text: d.initials, borderColor: Colors.white.withValues(alpha: 0.4), fillColor: Colors.white.withValues(alpha: 0.12)),
                              ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Details
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: context.cs.onSurface.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (options.showPhone && d.phone.isNotEmpty)     _row(Icons.phone_rounded, d.phone),
                        if (options.showGstin && d.gstin.isNotEmpty)     ...[const SizedBox(height: 3), _row(Icons.receipt_long_rounded, d.gstin)],
                        if (options.showAddress && d.address.isNotEmpty) ...[const SizedBox(height: 3), _row(Icons.location_on_rounded, d.address)],
                        if (options.showUpi && d.upi.isNotEmpty)         ...[const SizedBox(height: 3), _row(Icons.currency_rupee_rounded, d.upi)],
                      ],
                    ),
                  ),
                  if (options.showWatermark) ...[
                    const SizedBox(height: 6),
                    Align(alignment: Alignment.centerRight,
                      child: Text('via BillRaja', style: TextStyle(fontSize: 8.5, color: Colors.white.withValues(alpha: 0.35), letterSpacing: 0.5))),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blob(double s, Color c) => Container(width: s, height: s, decoration: BoxDecoration(shape: BoxShape.circle, color: c));

  Widget _row(IconData icon, String text) => Row(
    children: [
      Icon(icon, size: 10, color: Colors.white.withValues(alpha: 0.8)),
      const SizedBox(width: 5),
      Expanded(child: Text(text, style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.95), fontWeight: FontWeight.w500, height: 1.3), maxLines: 1, overflow: TextOverflow.ellipsis)),
    ],
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// CARD THEME 5: FOREST (Dark green, earthy)
// ══════════════════════════════════════════════════════════════════════════════

class _ForestCard extends StatelessWidget {
  const _ForestCard({required this.profile, required this.options});
  final BusinessProfile? profile;
  final _CardOptions options;

  static const _bg     = Color(0xFF052E16);
  static const _mid    = Color(0xFF14532D);
  static const _sage   = Color(0xFF86EFAC);
  static const _mint   = Color(0xFFBBF7D0);

  @override
  Widget build(BuildContext context) {
    final d = _ProfileData.from(profile);
    return AspectRatio(
      aspectRatio: options.aspectRatio,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [_bg, _mid]),
        ),
        child: Stack(
          children: [
            // Hex grid
            Positioned.fill(child: CustomPaint(painter: _HexGridPainter(color: _sage.withValues(alpha: 0.06)))),
            // Top accent bar
            Positioned(top: 0, left: 0, right: 0, child: Container(height: 3,
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [_sage, _mint, _sage])))),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 22, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Leaf icon badge
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: _sage.withValues(alpha: 0.12),
                          border: Border.all(color: _sage.withValues(alpha: 0.25), width: 1.5),
                        ),
                        child: Center(child: d.hasLogo
                            ? ClipRRect(borderRadius: BorderRadius.circular(10),
                                child: Image.network(d.logoUrl, width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (_, __, ___) =>
                                    Text(d.initials, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _sage))))
                            : Text(d.initials, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _sage))),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.3, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Row(children: [
                            Container(width: 16, height: 2, color: _sage, margin: const EdgeInsets.only(right: 4)),
                            Container(width: 8, height: 2, color: _mint.withValues(alpha: 0.5)),
                          ]),
                        ],
                      )),
                    ],
                  ),
                  const Spacer(),
                  // Details in clean rows
                  if (options.showPhone && d.phone.isNotEmpty)      _row(Icons.phone_rounded, d.phone),
                  if (options.showGstin && d.gstin.isNotEmpty)      ...[const SizedBox(height: 5), _row(Icons.receipt_long_rounded, 'GSTIN  ${d.gstin}')],
                  if (options.showAddress && d.address.isNotEmpty)  ...[const SizedBox(height: 5), _row(Icons.location_on_rounded, d.address)],
                  if (options.showUpi && d.upi.isNotEmpty)          ...[const SizedBox(height: 5), _row(Icons.currency_rupee_rounded, d.upi)],
                  if (options.showWatermark) ...[
                    const SizedBox(height: 10),
                    Align(alignment: Alignment.centerRight,
                      child: Text('via BillRaja', style: TextStyle(fontSize: 8.5, color: Colors.white.withValues(alpha: 0.2), letterSpacing: 0.5))),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text) => Row(
    children: [
      Icon(icon, size: 11, color: _sage),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 10.5, color: _mint, fontWeight: FontWeight.w500, height: 1.3), maxLines: 1, overflow: TextOverflow.ellipsis)),
    ],
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// CARD THEME 6: MINIMAL (Pure typographic)
// ══════════════════════════════════════════════════════════════════════════════

class _MinimalCard extends StatelessWidget {
  const _MinimalCard({required this.profile, required this.options});
  final BusinessProfile? profile;
  final _CardOptions options;

  @override
  Widget build(BuildContext context) {
    final d = _ProfileData.from(profile);
    final accent = options.accent;

    return AspectRatio(
      aspectRatio: options.aspectRatio,
      child: Container(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 22, 28, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Accent bar top
              Container(width: 32, height: 4, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 14),
              // Store name — big, bold
              Text(d.name,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0A0A0A), letterSpacing: -0.8, height: 1.1),
                maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              // Thin rule
              Container(height: 0.8, color: const Color(0xFFDDE1E7)),
              const Spacer(),
              // Details — no icons, clean monospace-like
              if (options.showPhone && d.phone.isNotEmpty)     _line(d.phone, accent),
              if (options.showGstin && d.gstin.isNotEmpty)     _line('GST  ${d.gstin}', const Color(0xFF64748B)),
              if (options.showAddress && d.address.isNotEmpty) _line(d.address, const Color(0xFF64748B)),
              if (options.showUpi && d.upi.isNotEmpty)         _line(d.upi, const Color(0xFF64748B)),
              const SizedBox(height: 8),
              // Bottom thin rule + watermark
              Container(height: 0.8, color: const Color(0xFFDDE1E7)),
              if (options.showWatermark) ...[
                const SizedBox(height: 6),
                Align(alignment: Alignment.centerRight,
                  child: Text('via BillRaja', style: TextStyle(fontSize: 8.5, color: context.cs.onSurface.withValues(alpha: 0.2), letterSpacing: 0.5))),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(String text, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600, letterSpacing: 0.1, height: 1.4), maxLines: 1, overflow: TextOverflow.ellipsis),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// CARD THEME 7: NEON (Dark + electric cyan)
// ══════════════════════════════════════════════════════════════════════════════

class _NeonCard extends StatelessWidget {
  const _NeonCard({required this.profile, required this.options});
  final BusinessProfile? profile;
  final _CardOptions options;

  static const _bg    = Color(0xFF08080F);
  static const _cyan  = Color(0xFF00E5FF);
  static const _lime  = Color(0xFFB2FF59);

  @override
  Widget build(BuildContext context) {
    final d = _ProfileData.from(profile);
    return AspectRatio(
      aspectRatio: options.aspectRatio,
      child: Container(
        color: _bg,
        child: Stack(
          children: [
            // Grid lines
            Positioned.fill(child: CustomPaint(painter: _GridLinePainter(color: _cyan.withValues(alpha: 0.04)))),
            // Glowing corner blob
            Positioned(right: -40, top: -40, child: Container(
              width: 150, height: 150,
              decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: RadialGradient(colors: [_cyan.withValues(alpha: 0.12), Colors.transparent])),
            )),
            Positioned(left: -20, bottom: -30, child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: RadialGradient(colors: [_lime.withValues(alpha: 0.08), Colors.transparent])),
            )),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 22, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Glow text effect
                          Stack(
                            children: [
                              Text(d.name, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900,
                                color: _cyan.withValues(alpha: 0.25), letterSpacing: -0.4, height: 1.15,
                                shadows: [Shadow(color: _cyan.withValues(alpha: 0.6), blurRadius: 12)]),
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                              Text(d.name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900,
                                color: Colors.white, letterSpacing: -0.4, height: 1.15),
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Glowing underline
                          Container(height: 1.5,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [_cyan, _lime, Colors.transparent]),
                              boxShadow: [BoxShadow(color: _cyan.withValues(alpha: 0.6), blurRadius: 6)],
                            ),
                          ),
                        ],
                      )),
                      const SizedBox(width: 12),
                      // Hexagon monogram / Logo
                      SizedBox(
                        width: 52, height: 52,
                        child: d.hasLogo
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(d.logoUrl, width: 52, height: 52, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => CustomPaint(
                                    size: const Size(52, 52),
                                    painter: _HexMonogramPainter(text: d.initials, color: _cyan),
                                  ),
                                ),
                              )
                            : CustomPaint(
                                size: const Size(52, 52),
                                painter: _HexMonogramPainter(text: d.initials, color: _cyan),
                              ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Details
                  if (options.showPhone && d.phone.isNotEmpty)     _row(d.phone, _cyan),
                  if (options.showGstin && d.gstin.isNotEmpty)     ...[const SizedBox(height: 4), _row(d.gstin, _lime)],
                  if (options.showAddress && d.address.isNotEmpty) ...[const SizedBox(height: 4), _row(d.address, _cyan)],
                  if (options.showUpi && d.upi.isNotEmpty)         ...[const SizedBox(height: 4), _row(d.upi, _lime)],
                  if (options.showWatermark) ...[
                    const SizedBox(height: 10),
                    Align(alignment: Alignment.centerRight,
                      child: Text('via BillRaja', style: TextStyle(fontSize: 8.5, color: Colors.white.withValues(alpha: 0.15), letterSpacing: 0.5))),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String text, Color c) => Row(
    children: [
      Container(width: 3, height: 3, decoration: BoxDecoration(shape: BoxShape.circle, color: c,
        boxShadow: [BoxShadow(color: c.withValues(alpha: 0.8), blurRadius: 4)])),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w500, letterSpacing: 0.2), maxLines: 1, overflow: TextOverflow.ellipsis)),
    ],
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// CARD THEME 8: SAFFRON (Indian-inspired)
// ══════════════════════════════════════════════════════════════════════════════

class _SaffronCard extends StatelessWidget {
  const _SaffronCard({required this.profile, required this.options});
  final BusinessProfile? profile;
  final _CardOptions options;

  static const _saffron  = Color(0xFFFF9933);
  static const _green    = Color(0xFF138808);
  static const _navy     = Color(0xFF000080);
  static const _bgWhite  = Color(0xFFFFFDF9);

  @override
  Widget build(BuildContext context) {
    final d = _ProfileData.from(profile);
    final accent = options.accent;

    return AspectRatio(
      aspectRatio: options.aspectRatio,
      child: Container(
        color: _bgWhite,
        child: Column(
          children: [
            // Saffron top strip
            Container(
              height: options.square ? 56 : 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight,
                  colors: [_saffron, Color.lerp(_saffron, accent, 0.3)!]),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  // Ashoka-inspired 24-spoke wheel (simple circle stand-in)
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
                    ),
                    child: CustomPaint(painter: _SpokesPainter(color: Colors.white.withValues(alpha: 0.8), spokes: 12)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(d.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.3),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                  // Monogram
                  Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                      color: d.hasLogo ? Colors.white : Colors.white.withValues(alpha: 0.2),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1)),
                    alignment: Alignment.center,
                    child: d.hasLogo
                        ? ClipRRect(borderRadius: BorderRadius.circular(14),
                            child: Image.network(d.logoUrl, width: 26, height: 26, fit: BoxFit.cover, errorBuilder: (_, __, ___) =>
                                Text(d.initials, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white))))
                        : Text(d.initials, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ],
              ),
            ),
            // Green accent thin bar
            Container(height: 3, color: _green),
            // White content area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Details
                    if (options.showPhone && d.phone.isNotEmpty)     _row(Icons.phone_rounded, d.phone, _navy),
                    if (options.showGstin && d.gstin.isNotEmpty)     ...[const SizedBox(height: 6), _row(Icons.verified_rounded, 'GSTIN: ${d.gstin}', _green)],
                    if (options.showAddress && d.address.isNotEmpty) ...[const SizedBox(height: 6), _row(Icons.location_on_rounded, d.address, const Color(0xFF475569))],
                    if (options.showUpi && d.upi.isNotEmpty)         ...[const SizedBox(height: 6), _row(Icons.currency_rupee_rounded, d.upi, _saffron)],
                    const Spacer(),
                    // Bottom bar — green
                    Row(
                      children: [
                        Container(width: 24, height: 2.5, decoration: BoxDecoration(color: _saffron, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 4),
                        Container(width: 24, height: 2.5, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 4),
                        Container(width: 24, height: 2.5, decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(2))),
                        const Spacer(),
                        if (options.showWatermark)
                          Text('via BillRaja', style: TextStyle(fontSize: 8.5, color: context.cs.onSurface.withValues(alpha: 0.2), letterSpacing: 0.5)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text, Color color) => Row(
    children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 7),
      Expanded(child: Text(text, style: TextStyle(fontSize: 11.5, color: const Color(0xFF1E293B), fontWeight: FontWeight.w600, height: 1.3), maxLines: 1, overflow: TextOverflow.ellipsis)),
    ],
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// CUSTOM PAINTERS
// ══════════════════════════════════════════════════════════════════════════════

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter({required this.color, this.spacing = 18.0, this.radius = 1.0});
  final Color color;
  final double spacing;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter old) => old.color != color;
}

class _HexGridPainter extends CustomPainter {
  const _HexGridPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 0.8;
    const r = 18.0;
    final h = r * math.sqrt(3);
    for (double col = 0; col * 1.5 * r < size.width + r; col++) {
      for (double row = 0; row * h < size.height + h; row++) {
        final cx = col * 1.5 * r;
        final cy = row * h + (col.toInt().isOdd ? h / 2 : 0);
        _drawHex(canvas, Offset(cx, cy), r, paint);
      }
    }
  }

  void _drawHex(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = math.pi / 3 * i - math.pi / 6;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HexGridPainter old) => old.color != color;
}

class _GridLinePainter extends CustomPainter {
  const _GridLinePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 0.5;
    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridLinePainter old) => old.color != color;
}

class _DiamondPainter extends CustomPainter {
  const _DiamondPainter({required this.text, required this.borderColor, required this.fillColor});
  final String text;
  final Color borderColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.42;

    final path = Path()
      ..moveTo(cx, cy - r)
      ..lineTo(cx + r, cy)
      ..lineTo(cx, cy + r)
      ..lineTo(cx - r, cy)
      ..close();

    canvas.drawPath(path, Paint()..color = fillColor..style = PaintingStyle.fill);
    canvas.drawPath(path, Paint()..color = borderColor..style = PaintingStyle.stroke..strokeWidth = 1.5);

    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: size.width * 0.28, fontWeight: FontWeight.w900, color: Colors.white)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _HexMonogramPainter extends CustomPainter {
  const _HexMonogramPainter({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.44;

    // Hex border
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = math.pi / 3 * i - math.pi / 6;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
    }
    path.close();

    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.1)..style = PaintingStyle.fill);
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = 1.5
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.5));
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.0);

    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: size.width * 0.28, fontWeight: FontWeight.w900, color: color,
        shadows: [Shadow(color: color.withValues(alpha: 0.8), blurRadius: 8)])),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _SpokesPainter extends CustomPainter {
  const _SpokesPainter({required this.color, required this.spokes});
  final Color color;
  final int spokes;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) * 0.75;
    final paint = Paint()..color = color..strokeWidth = 0.8;

    for (int i = 0; i < spokes; i++) {
      final angle = 2 * math.pi * i / spokes;
      canvas.drawLine(Offset(cx, cy), Offset(cx + r * math.cos(angle), cy + r * math.sin(angle)), paint);
    }
    canvas.drawCircle(Offset(cx, cy), 1.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
