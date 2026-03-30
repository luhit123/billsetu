import 'package:flutter/material.dart';
import 'package:billeasy/theme/app_colors.dart';

// ── Section data model ──────────────────────────────────────────────────────

class _GuideSection {
  final int number;
  final String title;
  final String description;
  final IconData icon;
  final List<String> steps;
  final Widget Function() illustrationBuilder;

  const _GuideSection({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
    required this.steps,
    required this.illustrationBuilder,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// HowToUseScreen — Illustrated feature guide
// ═══════════════════════════════════════════════════════════════════════════════

class HowToUseScreen extends StatefulWidget {
  const HowToUseScreen({super.key});

  @override
  State<HowToUseScreen> createState() => _HowToUseScreenState();
}

class _HowToUseScreenState extends State<HowToUseScreen> {
  late final List<_GuideSection> _sections;

  @override
  void initState() {
    super.initState();
    _sections = [
      _GuideSection(
        number: 1,
        title: 'Create Invoices',
        description:
            'Generate professional GST-compliant invoices in seconds and share them instantly.',
        icon: Icons.receipt_long_rounded,
        steps: ['Add client', 'Add items', 'Set price', 'Apply discount', 'Share PDF'],
        illustrationBuilder: _buildInvoiceIllustration,
      ),
      _GuideSection(
        number: 2,
        title: 'Track Payments',
        description:
            'Record payments, track statuses, and never miss an overdue invoice again.',
        icon: Icons.payments_rounded,
        steps: ['Record payments', 'Auto-status updates', 'Payment history'],
        illustrationBuilder: _buildPaymentIllustration,
      ),
      _GuideSection(
        number: 3,
        title: 'Manage Customers',
        description:
            'Organise contacts into groups and view their complete invoice history at a glance.',
        icon: Icons.people_rounded,
        steps: ['Add contacts', 'Group customers', 'View history', 'Track dues'],
        illustrationBuilder: _buildCustomerIllustration,
      ),
      _GuideSection(
        number: 4,
        title: 'Products & Inventory',
        description:
            'Manage your product catalogue with HSN codes, prices, and real-time stock levels.',
        icon: Icons.inventory_2_rounded,
        steps: ['Add with HSN', 'Set prices', 'Track stock', 'Low stock alerts'],
        illustrationBuilder: _buildProductIllustration,
      ),
      _GuideSection(
        number: 5,
        title: 'GST Compliance',
        description:
            'Automatic tax calculations with CGST/SGST and IGST support for every invoice.',
        icon: Icons.account_balance_rounded,
        steps: ['Set GSTIN', 'Choose tax type', 'Auto calculation', 'GST reports'],
        illustrationBuilder: _buildGstIllustration,
      ),
      _GuideSection(
        number: 6,
        title: 'Purchase Orders',
        description:
            'Create purchase orders, track deliveries, and manage your supplier relationships.',
        icon: Icons.shopping_cart_rounded,
        steps: ['Create PO', 'Track deliveries', 'Manage suppliers'],
        illustrationBuilder: _buildPurchaseOrderIllustration,
      ),
      _GuideSection(
        number: 7,
        title: 'Share & Export',
        description:
            'Share invoices via WhatsApp, export data as CSV, print or email with one tap.',
        icon: Icons.share_rounded,
        steps: ['WhatsApp', 'Export CSV', 'Print', 'Email'],
        illustrationBuilder: _buildShareIllustration,
      ),
      _GuideSection(
        number: 8,
        title: 'Business Profile & Cards',
        description:
            'Set up your business profile, generate digital business cards, and customise templates.',
        icon: Icons.business_rounded,
        steps: ['Set up profile', 'Business cards', 'Custom templates'],
        illustrationBuilder: _buildBusinessProfileIllustration,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: kSurface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── App bar ──────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: kSurface,
            foregroundColor: kOnSurface,
            elevation: 0,
            scrolledUnderElevation: 0.5,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            title: const Text(
              'How to Use BillRaja',
              style: TextStyle(
                color: kOnSurface,
                fontWeight: FontWeight.w700,
                fontSize: 18,
                letterSpacing: -0.3,
              ),
            ),
          ),

          // ── Header ───────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: kPrimaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      '\u2726  Quick Guide',
                      style: TextStyle(
                        color: kPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Everything you need\nto run your business',
                    style: TextStyle(
                      color: kOnSurface,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '8 powerful features, explained step by step.',
                    style: TextStyle(
                      color: kOnSurfaceVariant,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Section cards ────────────────────────────────────────────────
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return _AnimatedSectionCard(
                  section: _sections[index],
                  index: index,
                );
              },
              childCount: _sections.length,
            ),
          ),

          // ── Bottom button ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomPadding),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: kSignatureGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [kWhisperShadow],
                  ),
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: kOnPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Got it!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Illustrations — built purely from Flutter widgets
  // ═══════════════════════════════════════════════════════════════════════════

  // ── 1. Invoice illustration ──────────────────────────────────────────────
  static Widget _buildInvoiceIllustration() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 130,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kSurfaceLowest,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [kSubtleShadow],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: kPrimaryContainer,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, size: 11, color: kPrimary),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'INVOICE',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: kOnSurface,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _mockLine(width: 80, color: kSurfaceContainerLow),
                const SizedBox(height: 3),
                _mockLine(width: 60, color: kSurfaceContainerLow),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '\u20b91,250',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: kPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: kPaidBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'PAID',
                        style: TextStyle(fontSize: 6, fontWeight: FontWeight.w700, color: kPaid),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _miniActionChip(Icons.picture_as_pdf_rounded, 'PDF'),
              const SizedBox(height: 6),
              _miniActionChip(Icons.share_rounded, 'Share'),
            ],
          ),
        ],
      );
  }

  // ── 2. Payment tracking illustration ─────────────────────────────────────
  static Widget _buildPaymentIllustration() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _statusBadge('Paid', kPaid, kPaidBg, Icons.check_circle_rounded),
        const SizedBox(width: 8),
        _statusBadge('Pending', kPending, kPendingBg, Icons.schedule_rounded),
        const SizedBox(width: 8),
        _statusBadge('Overdue', kOverdue, kOverdueBg, Icons.warning_rounded),
      ],
    );
  }

  // ── 3. Customer illustration ─────────────────────────────────────────────
  static Widget _buildCustomerIllustration() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _miniCustomerCard('Rajesh K.', 'VIP', kPending),
        const SizedBox(width: 8),
        _miniCustomerCard('Priya S.', 'Retail', kOnSurfaceVariant),
        const SizedBox(width: 8),
        _miniCustomerCard('Mehta T.', 'Wholesale', kPaid),
      ],
    );
  }

  // ── 4. Product illustration ──────────────────────────────────────────────
  static Widget _buildProductIllustration() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 150,
          padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kSurfaceLowest,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [kSubtleShadow],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: kPrimaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.inventory_2_rounded, size: 12, color: kPrimary),
                    ),
                    const SizedBox(width: 6),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Widget Pro',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: kOnSurface,
                          ),
                        ),
                        Text(
                          'HSN: 8471',
                          style: TextStyle(fontSize: 7, color: kTextTertiary),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '\u20b9450/unit',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: kPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: kPaidBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '120 in stock',
                        style: TextStyle(fontSize: 7, fontWeight: FontWeight.w600, color: kPaid),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: kOverdueBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.notifications_active_rounded, size: 14, color: kOverdue),
                SizedBox(height: 2),
                Text(
                  'Low\nStock',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 7, fontWeight: FontWeight.w700, color: kOverdue),
                ),
              ],
            ),
          ),
        ],
      );
  }

  // ── 5. GST illustration ──────────────────────────────────────────────────
  static Widget _buildGstIllustration() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kSurfaceLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [kSubtleShadow],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'TAX BREAKDOWN',
                style: TextStyle(
                  fontSize: 7,
                  fontWeight: FontWeight.w800,
                  color: kTextTertiary,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              _taxRow('Subtotal', '\u20b910,000'),
              const SizedBox(height: 2),
              _taxRow('CGST @9%', '\u20b9900'),
              const SizedBox(height: 2),
              _taxRow('SGST @9%', '\u20b9900'),
              const SizedBox(height: 3),
              Container(height: 1, width: 100, color: kSurfaceContainer),
              const SizedBox(height: 3),
              const Row(
                children: [
                  Text(
                    'Total',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kOnSurface),
                  ),
                  SizedBox(width: 20),
                  Text(
                    '\u20b911,800',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kPrimary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 14),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: kPrimaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '18%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: kPrimary,
                  ),
                ),
                Text(
                  'GST',
                  style: TextStyle(fontSize: 7, fontWeight: FontWeight.w600, color: kPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 6. Purchase order illustration ───────────────────────────────────────
  static Widget _buildPurchaseOrderIllustration() {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kSurfaceLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [kSubtleShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: kPrimaryContainer,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Icon(Icons.shopping_cart_rounded, size: 11, color: kPrimary),
              ),
              const SizedBox(width: 6),
              const Text(
                'PO-2026-001',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: kOnSurface,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _mockLine(width: 100, color: kSurfaceContainerLow),
          const SizedBox(height: 3),
          _mockLine(width: 70, color: kSurfaceContainerLow),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '\u20b98,500',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kPrimary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: kConfirmedBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'CONFIRMED',
                  style: TextStyle(fontSize: 6, fontWeight: FontWeight.w700, color: kConfirmed),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 7. Share illustration ────────────────────────────────────────────────
  static Widget _buildShareIllustration() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _shareIcon(Icons.chat_rounded, 'WhatsApp', const Color(0xFF25D366)),
        const SizedBox(width: 12),
        _shareIcon(Icons.table_chart_rounded, 'CSV', kPrimary),
        const SizedBox(width: 12),
        _shareIcon(Icons.print_rounded, 'Print', kOnSurfaceVariant),
        const SizedBox(width: 12),
        _shareIcon(Icons.email_rounded, 'Email', kPending),
      ],
    );
  }

  // ── 8. Business profile illustration ─────────────────────────────────────
  static Widget _buildBusinessProfileIllustration() {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kSurfaceLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [kSubtleShadow],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: kSignatureGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text(
                'BR',
                style: TextStyle(
                  color: kOnPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Your Business',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: kOnSurface,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'GSTIN: 22AAAAA0000A1Z5',
                  style: TextStyle(fontSize: 7, color: kTextTertiary),
                ),
                SizedBox(height: 2),
                Text(
                  'yourname@email.com',
                  style: TextStyle(fontSize: 7, color: kTextTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Shared illustration helpers
  // ═══════════════════════════════════════════════════════════════════════════

  static Widget _mockLine({required double width, required Color color}) {
    return Container(
      width: width,
      height: 4,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  static Widget _miniActionChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: kPrimaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: kPrimary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: kPrimary),
          ),
        ],
      ),
    );
  }

  static Widget _statusBadge(String label, Color color, Color bg, IconData icon) {
    return Container(
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _miniCustomerCard(String name, String group, Color groupColor) {
    return Container(
      width: 80,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: kSurfaceLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [kSubtleShadow],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: kSurfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.person_rounded, size: 14, color: kOnSurfaceVariant),
          ),
          const SizedBox(height: 5),
          Text(
            name,
            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: kOnSurface),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: groupColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              group,
              style: TextStyle(fontSize: 6.5, fontWeight: FontWeight.w700, color: groupColor),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _taxRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 8, color: kOnSurfaceVariant),
        ),
        const SizedBox(width: 16),
        Text(
          value,
          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: kOnSurface),
        ),
      ],
    );
  }

  static Widget _shareIcon(IconData icon, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Animated section card — fades + slides in on scroll
// ═══════════════════════════════════════════════════════════════════════════════

class _AnimatedSectionCard extends StatefulWidget {
  final _GuideSection section;
  final int index;

  const _AnimatedSectionCard({required this.section, required this.index});

  @override
  State<_AnimatedSectionCard> createState() => _AnimatedSectionCardState();
}

class _AnimatedSectionCardState extends State<_AnimatedSectionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Stagger the animation slightly per card
    Future.delayed(Duration(milliseconds: 80 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final section = widget.section;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Container(
            decoration: BoxDecoration(
              color: kSurfaceLowest,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [kWhisperShadow],
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header row ─────────────────────────────────────────
                  Row(
                    children: [
                      // Number badge
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: kSignatureGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            '${section.number}',
                            style: const TextStyle(
                              color: kOnPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Icon + title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              section.title,
                              style: const TextStyle(
                                color: kOnSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Section icon
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: kPrimaryContainer,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(section.icon, size: 18, color: kPrimary),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // ── Description ────────────────────────────────────────
                  Text(
                    section.description,
                    style: const TextStyle(
                      color: kOnSurfaceVariant,
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Step chips (horizontal scroll) ─────────────────────
                  SizedBox(
                    height: 30,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: section.steps.length,
                      separatorBuilder: (_, _) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 8,
                          color: kTextTertiary.withValues(alpha: 0.5),
                        ),
                      ),
                      itemBuilder: (_, i) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: kSurfaceContainerLow,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            section.steps[i],
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: kOnSurfaceVariant,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Illustration ───────────────────────────────────────
                  Center(child: section.illustrationBuilder()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
