import 'package:billeasy/services/invoice_pdf_service.dart';
import 'package:billeasy/services/plan_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Metadata for each template shown in the picker.
class _TemplateMeta {
  final InvoiceTemplate template;
  final String name;
  final Color swatch1;
  final Color swatch2;
  final Color swatch3;

  const _TemplateMeta({
    required this.template,
    required this.name,
    required this.swatch1,
    required this.swatch2,
    required this.swatch3,
  });
}

const _allTemplates = <_TemplateMeta>[
  _TemplateMeta(template: InvoiceTemplate.classic,      name: 'Classic',      swatch1: Color(0xFF124185), swatch2: Color(0xFF0F7D83), swatch3: Color(0xFF2457A6)),
  _TemplateMeta(template: InvoiceTemplate.modern,       name: 'Modern',       swatch1: Color(0xFF0A2450), swatch2: Color(0xFF0F7D83), swatch3: Color(0xFFF0F4FF)),
  _TemplateMeta(template: InvoiceTemplate.compact,      name: 'Compact',      swatch1: Color(0xFFB3B3B3), swatch2: Color(0xFF1A1A1A), swatch3: Color(0xFF737373)),
  _TemplateMeta(template: InvoiceTemplate.minimalist,   name: 'Minimalist',   swatch1: Color(0xFF262626), swatch2: Color(0xFF999999), swatch3: Color(0xFFF5F5F5)),
  _TemplateMeta(template: InvoiceTemplate.bold,         name: 'Bold',         swatch1: Color(0xFF1F1F1F), swatch2: Color(0xFFD93333), swatch3: Color(0xFFF2F2F2)),
  _TemplateMeta(template: InvoiceTemplate.elegant,      name: 'Elegant',      swatch1: Color(0xFF70542E), swatch2: Color(0xFFB89959), swatch3: Color(0xFFFCF5E8)),
  _TemplateMeta(template: InvoiceTemplate.professional, name: 'Professional', swatch1: Color(0xFF33618F), swatch2: Color(0xFF598CB8), swatch3: Color(0xFFF0F5FA)),
  _TemplateMeta(template: InvoiceTemplate.vibrant,      name: 'Vibrant',      swatch1: Color(0xFFE65933), swatch2: Color(0xFFF28C4D), swatch3: Color(0xFFFCF0EB)),
  _TemplateMeta(template: InvoiceTemplate.clean,        name: 'Clean',        swatch1: Color(0xFF667380), swatch2: Color(0xFF66A6CC), swatch3: Color(0xFFF5F7FA)),
  _TemplateMeta(template: InvoiceTemplate.royal,        name: 'Royal',        swatch1: Color(0xFF59268C), swatch2: Color(0xFFBF9933), swatch3: Color(0xFFF5F0FC)),
  _TemplateMeta(template: InvoiceTemplate.stripe,       name: 'Stripe',       swatch1: Color(0xFF0F6B70), swatch2: Color(0xFF1A9499), swatch3: Color(0xFFF0FAFA)),
  _TemplateMeta(template: InvoiceTemplate.grid,         name: 'Grid',         swatch1: Color(0xFF2E2E38), swatch2: Color(0xFF666673), swatch3: Color(0xFFF2F2F5)),
  _TemplateMeta(template: InvoiceTemplate.pastel,       name: 'Pastel',       swatch1: Color(0xFF8066A6), swatch2: Color(0xFF8CC7B8), swatch3: Color(0xFFF2E8FC)),
  _TemplateMeta(template: InvoiceTemplate.dark,         name: 'Dark',         swatch1: Color(0xFF1A1A2E), swatch2: Color(0xFFE6BF4D), swatch3: Color(0xFFF5F5F7)),
  _TemplateMeta(template: InvoiceTemplate.retail,       name: 'Retail',       swatch1: Color(0xFF268547), swatch2: Color(0xFF38A661), swatch3: Color(0xFFF0FAF2)),
  _TemplateMeta(template: InvoiceTemplate.wholesale,    name: 'Wholesale',    swatch1: Color(0xFF73522E), swatch2: Color(0xFF9E7A4D), swatch3: Color(0xFFFAF5ED)),
  _TemplateMeta(template: InvoiceTemplate.services,     name: 'Services',     swatch1: Color(0xFF405985), swatch2: Color(0xFF8094AD), swatch3: Color(0xFFF0F4FA)),
  _TemplateMeta(template: InvoiceTemplate.creative,     name: 'Creative',     swatch1: Color(0xFFE06159), swatch2: Color(0xFF59C7AD), swatch3: Color(0xFFFAF0F0)),
  _TemplateMeta(template: InvoiceTemplate.simple,       name: 'Simple',       swatch1: Color(0xFF000000), swatch2: Color(0xFF666666), swatch3: Color(0xFFFFFFFF)),
  _TemplateMeta(template: InvoiceTemplate.gstPro,       name: 'GST Pro',      swatch1: Color(0xFF3D388C), swatch2: Color(0xFF6159B8), swatch3: Color(0xFFF0F0FC)),
];

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
            const SizedBox(height: 16),
            // Template grid — scrollable
            SizedBox(
              height: 280,
              child: GridView.builder(
                itemCount: _allTemplates.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.82,
                ),
                itemBuilder: (context, index) {
                  final meta = _allTemplates[index];
                  final locked = !PlanService.instance.canUseTemplate(index);
                  final selected = _selected == meta.template;
                  return _TemplateGridCard(
                    meta: meta,
                    selected: selected,
                    locked: locked,
                    onTap: () {
                      if (locked) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Upgrade your plan to unlock this template')),
                        );
                        return;
                      }
                      setState(() => _selected = meta.template);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
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

class _TemplateGridCard extends StatelessWidget {
  const _TemplateGridCard({
    required this.meta,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final _TemplateMeta meta;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: locked
              ? kSurfaceDim
              : selected
                  ? kPrimaryContainer
                  : kSurfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: selected
              ? Border.all(color: kPrimary, width: 2)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Color swatches
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _swatch(meta.swatch1),
                const SizedBox(width: 4),
                _swatch(meta.swatch2),
                const SizedBox(width: 4),
                _swatch(meta.swatch3),
              ],
            ),
            const SizedBox(height: 8),
            // Template name
            Text(
              meta.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? kPrimary : (locked ? kTextTertiary : kOnSurface),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            // Selected / locked indicator
            if (selected)
              const Icon(Icons.check_circle_rounded, color: kPrimary, size: 16)
            else if (locked)
              Icon(Icons.lock, size: 14, color: Colors.amber.shade700),
          ],
        ),
      ),
    );
  }

  Widget _swatch(Color color) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black12, width: 0.5),
      ),
    );
  }
}
