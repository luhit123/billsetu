import 'package:billeasy/services/invoice_pdf_service.dart';
import 'package:billeasy/services/plan_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Bottom sheet that lets the user pick an [InvoiceTemplate].
///
/// Usage:
/// ```dart
/// final template = await showModalBottomSheet<InvoiceTemplate>(
///   context: context,
///   builder: (_) => const TemplatePicker(current: InvoiceTemplate.classic),
/// );
/// ```
class TemplatePicker extends StatefulWidget {
  const TemplatePicker({super.key, this.current = InvoiceTemplate.classic});

  final InvoiceTemplate current;

  @override
  State<TemplatePicker> createState() => _TemplatePickerState();
}

class _TemplatePickerState extends State<TemplatePicker> {
  late InvoiceTemplate _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: kSurfaceLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: kSurfaceContainerHigh,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            const Text(
              'Choose Template',
              style: TextStyle(
                color: kOnSurface,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Select a design for your invoice PDF',
              style: TextStyle(color: kOnSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 20),
            // Template cards — horizontal row
            Row(
              children: [
                Expanded(
                  child: _TemplateCard(
                    template: InvoiceTemplate.classic,
                    icon: Icons.receipt_long_rounded,
                    name: 'Classic',
                    description: 'Clean, professional layout with gradient accents',
                    selected: _selected == InvoiceTemplate.classic,
                    onTap: () => setState(() => _selected = InvoiceTemplate.classic),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TemplateCard(
                    template: InvoiceTemplate.modern,
                    icon: Icons.auto_awesome_rounded,
                    name: 'Modern',
                    description: 'Bold header with accent highlights',
                    selected: _selected == InvoiceTemplate.modern,
                    locked: !PlanService.instance.canUseTemplate(1),
                    onTap: () {
                      if (!PlanService.instance.canUseTemplate(1)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Upgrade to Raja or above to unlock this template')),
                        );
                        return;
                      }
                      setState(() => _selected = InvoiceTemplate.modern);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TemplateCard(
                    template: InvoiceTemplate.compact,
                    icon: Icons.compress_rounded,
                    name: 'Compact',
                    description: 'Dense single-page, ideal for thermal printers',
                    selected: _selected == InvoiceTemplate.compact,
                    locked: !PlanService.instance.canUseTemplate(2),
                    onTap: () {
                      if (!PlanService.instance.canUseTemplate(2)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Upgrade to Maharaja to unlock this template')),
                        );
                        return;
                      }
                      setState(() => _selected = InvoiceTemplate.compact);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Confirm button
            SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: kSignatureGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Use This Template',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
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

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.icon,
    required this.name,
    required this.description,
    required this.selected,
    required this.onTap,
    this.locked = false,
  });

  final InvoiceTemplate template;
  final IconData icon;
  final String name;
  final String description;
  final bool selected;
  final VoidCallback onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: locked
              ? kSurfaceDim
              : selected
                  ? kPrimaryContainer
                  : kSurfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon badge with lock overlay
            Stack(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: locked
                        ? kSurfaceContainerHigh
                        : kPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: locked ? kTextTertiary : kPrimary, size: 20),
                ),
                if (locked)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock, size: 9, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              name,
              style: TextStyle(
                color: selected ? kPrimary : kOnSurface,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(
                color: kOnSurfaceVariant,
                fontSize: 10,
                height: 1.4,
              ),
            ),
            if (selected) ...[
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: kPrimary, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Selected',
                    style: TextStyle(
                      color: kPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
