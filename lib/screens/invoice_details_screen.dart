import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:billeasy/l10n/app_strings.dart';
import 'package:billeasy/modals/business_profile.dart';
import 'package:billeasy/screens/language_selection_screen.dart';
import 'package:billeasy/modals/invoice.dart';
import 'package:billeasy/screens/template_picker_sheet.dart';
import 'package:billeasy/modals/client.dart';
import 'package:billeasy/services/client_service.dart';
import 'package:billeasy/services/firebase_service.dart';
import 'package:billeasy/services/logo_cache_service.dart';
import 'package:billeasy/services/invoice_link_service.dart';
import 'package:billeasy/services/invoice_pdf_service.dart';
import 'package:billeasy/services/profile_service.dart';
import 'package:billeasy/services/signature_service.dart';
import 'package:billeasy/widgets/signature_pad.dart';
import 'package:billeasy/screens/create_invoice_screen.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:billeasy/widgets/invoice_preview_widget.dart';
import 'package:billeasy/widgets/whatsapp_share_sheet.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:billeasy/utils/upi_utils.dart';
import 'package:billeasy/services/plan_service.dart';
import 'package:billeasy/services/remote_config_service.dart';
import 'package:billeasy/services/usage_tracking_service.dart';
import 'package:billeasy/widgets/limit_reached_dialog.dart';

const _kTemplatePrefsKey = 'invoice_template';

class InvoiceDetailsScreen extends StatefulWidget {
  const InvoiceDetailsScreen({super.key, required this.invoice});

  final Invoice invoice;

  @override
  State<InvoiceDetailsScreen> createState() => _InvoiceDetailsScreenState();
}

class _InvoiceDetailsScreenState extends State<InvoiceDetailsScreen> {
  final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  InvoiceTemplate _template = InvoiceTemplate.vyapar;
  BusinessProfile? _profile;
  Client? _clientDetails;
  Uint8List? _signatureImage;
  Uint8List? _logoImage;
  Uint8List? _cachedPdfBytes;
  Uint8List? _previewImage; // Rasterized preview for structural templates
  String _termsText = 'Thank you for doing business with us.';
  bool _loading = true;

  /// Templates available via arrow cycling — Vyapar first, then structural layouts.
  static const _structuralTemplates = {
    InvoiceTemplate.vyapar,
    InvoiceTemplate.banner,
    InvoiceTemplate.sidebarLayout,
    InvoiceTemplate.bordered,
    InvoiceTemplate.twoColumn,
    InvoiceTemplate.receipt,
  };

  bool get _isStructuralTemplate => _structuralTemplates.contains(_template);

  /// Live invoice — starts with the widget prop and updates from Firestore stream.
  late Invoice _liveInvoice;
  StreamSubscription? _invoiceSub;

  @override
  void initState() {
    super.initState();
    _liveInvoice = widget.invoice;
    _listenToInvoice();
    _init();
  }

  void _listenToInvoice() {
    _invoiceSub = FirebaseFirestore.instance
        .collection('invoices')
        .doc(_liveInvoice.id)
        .snapshots()
        .listen((snap) {
      if (snap.exists && snap.data() != null && mounted) {
        setState(() {
          _liveInvoice = Invoice.fromMap(snap.data()!, docId: snap.id);
          _cachedPdfBytes = null; // Invalidate cached PDF
        });
      }
    });
  }

  @override
  void dispose() {
    _invoiceSub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    // Show preview immediately — don't wait for anything
    if (mounted) setState(() => _loading = false);

    // Load prefs, profile, signature & client all in parallel
    try {
      final results = await Future.wait([
        SharedPreferences.getInstance(),
        ProfileService().getCurrentProfile(),
        SignatureService.load(),
        ClientService().getClient(_liveInvoice.clientId),
        LogoCacheService.load(),
      ]).timeout(const Duration(seconds: 5), onTimeout: () => [null, null, null, null, null]);

      final prefs = results[0] as SharedPreferences?;
      if (prefs != null) {
        final saved = prefs.getString(_kTemplatePrefsKey);
        if (saved != null) {
          final match = InvoiceTemplate.values.where((t) => t.name == saved);
          if (match.isNotEmpty) _template = match.first;
        }
        _termsText = prefs.getString('invoice_terms') ?? 'Thank you for doing business with us.';
      }
      if (mounted) {
        setState(() {
          _profile = results[1] as BusinessProfile?;
          _signatureImage = results[2] as Uint8List?;
          _clientDetails = results[3] as Client?;
          _logoImage = results[4] as Uint8List?;
        });
      }
    } catch (e) {
      debugPrint('[InvoiceDetails] Failed to load profile/signature: $e');
    }
  }

  void _invalidatePdf() {
    _cachedPdfBytes = null;
    _previewImage = null;
  }

  Future<Uint8List> _ensurePdfBytes() async {
    if (_cachedPdfBytes != null) return _cachedPdfBytes!;
    _profile ??= await ProfileService().getCurrentProfile();
    // Fetch client if not loaded yet
    _clientDetails ??= await ClientService().getClient(_liveInvoice.clientId);
    final bytes = await InvoicePdfService().buildInvoicePdf(
      invoice: _liveInvoice,
      profile: _profile,
      client: _clientDetails,
      language: AppStrings.of(context).language,
      template: _template,
    );
    _cachedPdfBytes = bytes;
    return bytes;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final invoice = _liveInvoice;
    final s = AppStrings.of(context);

    final (statusColor, statusBg, statusLabel) = switch (invoice.effectiveStatus) {
      InvoiceStatus.paid => (kPaid, kPaidBg, s.statusPaid),
      InvoiceStatus.pending => (const Color(0xFFEF4444), const Color(0xFFFEE2E2), 'Unpaid'),
      InvoiceStatus.overdue => (kOverdue, kOverdueBg, s.statusOverdue),
      InvoiceStatus.partiallyPaid => (const Color(0xFFEAB308), const Color(0xFFFEF3C7), 'Partial'),
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: kOnSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoice.invoiceNumber,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: kOnSurface,
                    ),
                  ),
                  Text(
                    '${invoice.clientName} · ${_currency.format(invoice.grandTotal)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: kTextTertiary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusLabel.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Edit — opens create screen with this invoice's data
          IconButton(
            tooltip: 'Edit Invoice',
            icon: const Icon(Icons.edit_rounded, size: 20),
            onPressed: () async {
              final result = await Navigator.push<Invoice>(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateInvoiceScreen(editingInvoice: _liveInvoice),
                ),
              );
              if (result != null && mounted) {
                // Refresh with updated invoice
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InvoiceDetailsScreen(invoice: result),
                  ),
                );
              }
            },
          ),
          IconButton(
            tooltip: 'Change Template',
            icon: const Icon(Icons.style_rounded, size: 22),
            onPressed: () => _changeTemplate(context),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 22),
            onSelected: (v) => _handleMenuAction(v, context),
            itemBuilder: (_) => _buildMenuItems(invoice),
          ),
        ],
      ),

      // ── Bottom bar — instant share icons ────────────────────────────────
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // WhatsApp — shows Image/PDF choice
              _ShareIcon(
                icon: Icons.chat,
                iconWidget: const FaIcon(FontAwesomeIcons.whatsapp, color: Color(0xFF25D366), size: 24),
                label: 'WhatsApp',
                color: const Color(0xFF25D366),
                onTap: () => _shareViaWhatsApp(context),
              ),
              // SMS — opens SMS directly
              _ShareIcon(
                icon: Icons.sms_outlined,
                label: 'SMS',
                color: const Color(0xFF1565C0),
                onTap: () => _shareViaSms(context),
              ),
              // Print
              _ShareIcon(
                icon: Icons.print_outlined,
                label: 'Print',
                color: kOnSurfaceVariant,
                onTap: () => _printPdf(context),
              ),
            ],
          ),
        ),
      ),

      // ── Body ──────────────────────────────────────────────────────────
      body: Column(
        children: [
          // ── Payment info strip ──
          if (invoice.amountReceived > 0 || invoice.effectiveStatus == InvoiceStatus.partiallyPaid)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: invoice.isFullyPaid ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                border: Border(bottom: BorderSide(color: invoice.isFullyPaid ? const Color(0xFFA5D6A7) : const Color(0xFFFFCC80))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Received: ${_currency.format(invoice.amountReceived)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32)),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (invoice.balanceDue > 0)
                          Text('Balance: ${_currency.format(invoice.balanceDue)}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFE65100)),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: invoice.isFullyPaid ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      invoice.isFullyPaid ? 'PAID' : 'PARTIAL',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          // ── Invoice preview with template arrows ──
          Expanded(
            child: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : Stack(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    return InteractiveViewer(
                      constrained: false,
                      minScale: 0.5,
                      maxScale: 4.0,
                      boundaryMargin: EdgeInsets.symmetric(
                        horizontal: constraints.maxWidth * 0.3,
                        vertical: constraints.maxHeight * 0.3,
                      ),
                      child: Container(
                        width: constraints.maxWidth - 16,
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(14),
                        child: InvoicePreviewWidget(
                          invoice: invoice,
                          profile: _profile,
                          template: _template,
                          signatureImage: _signatureImage,
                          logoImage: _logoImage,
                          termsText: _termsText,
                          onSignatureTap: () => _openSignaturePad(context),
                          onTermsTap: () => _editTerms(context),
                        ),
                      ),
                    );
                  },
                ),
                // Template name label at top
                Positioned(
                  top: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _template.name[0].toUpperCase() + _template.name.substring(1),
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
                // Left arrow — top of invoice
                Positioned(
                  left: 4,
                  top: 12,
                  child: _TemplateArrowButton(
                    icon: Icons.chevron_left_rounded,
                    onTap: () => _cycleTemplate(-1),
                  ),
                ),
                // Right arrow — top of invoice
                Positioned(
                  right: 4,
                  top: 12,
                  child: _TemplateArrowButton(
                    icon: Icons.chevron_right_rounded,
                    onTap: () => _cycleTemplate(1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Signature & Terms ───────────────────────────────────────────────────

  Future<void> _openSignaturePad(BuildContext context) async {
    final result = await SignaturePadSheet.show(
      context,
      existingSignature: _signatureImage,
    );
    if (result != null) {
      await SignatureService.save(result);
      _invalidatePdf();
      setState(() => _signatureImage = result);
    }
  }

  Future<void> _editTerms(BuildContext context) async {
    final controller = TextEditingController(text: _termsText);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terms & Conditions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter your terms and conditions...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('invoice_terms', result);
      _invalidatePdf();
      setState(() => _termsText = result);
    }
  }

  // ── Actions ─────────────────────────────────────────────────────────────

  Future<Uint8List?> _ensurePreviewImage() async {
    if (_previewImage != null) return _previewImage;
    try {
      final pdfBytes = await _ensurePdfBytes();
      final pages = await Printing.raster(pdfBytes, pages: [0], dpi: 150).toList();
      if (pages.isNotEmpty) {
        final rasterPage = pages.first;
        final rawImage = await rasterPage.toImage();
        // Draw white background
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(
          Rect.fromLTWH(0, 0, rawImage.width.toDouble(), rawImage.height.toDouble()),
          Paint()..color = Colors.white,
        );
        canvas.drawImage(rawImage, Offset.zero, Paint());
        final picture = recorder.endRecording();
        final composited = await picture.toImage(rawImage.width, rawImage.height);
        final byteData = await composited.toByteData(format: ui.ImageByteFormat.png);
        rawImage.dispose();
        composited.dispose();
        if (byteData != null) {
          _previewImage = byteData.buffer.asUint8List();
        }
      }
    } catch (e) {
      debugPrint('[InvoiceDetails] Preview raster error: $e');
    }
    return _previewImage;
  }

  void _cycleTemplate(int direction) async {
    // Arrows cycle only through the 5 structural layouts, not colour variants.
    final templates = _structuralTemplates.toList();
    final currentIdx = templates.indexOf(_template);
    // If the current template isn't structural, start from index 0.
    final safeIdx = currentIdx == -1 ? 0 : currentIdx;
    final nextIdx = (safeIdx + direction) % templates.length;
    final next = templates[nextIdx];
    if (next != _template) {
      _invalidatePdf();
      setState(() => _template = next);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTemplatePrefsKey, next.name);
    }
  }

  Future<void> _changeTemplate(BuildContext context) async {
    final result = await showModalBottomSheet<InvoiceTemplate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TemplatePicker(current: _template),
    );
    if (result != null && result != _template) {
      _invalidatePdf();
      setState(() => _template = result);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kTemplatePrefsKey, result.name);
    }
  }

  Future<void> _printPdf(BuildContext context) async {
    try {
      final bytes = await _ensurePdfBytes();
      await Printing.layoutPdf(
        name: InvoicePdfService().fileNameForInvoice(_liveInvoice),
        onLayout: (_) async => bytes,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _openShareSheet(BuildContext context) async {
    File? pdfFile;
    Uint8List? pdfBytes;
    String? clientPhone;

    try {
      pdfBytes = await _ensurePdfBytes();
      if (!kIsWeb) {
        final dir = await getTemporaryDirectory();
        final fileName = InvoicePdfService().fileNameForInvoice(_liveInvoice);
        pdfFile = File('${dir.path}/$fileName');
        await pdfFile.writeAsBytes(pdfBytes);
      }
    } catch (e) {
      debugPrint('[InvoiceDetails] PDF write error: $e');
    }

    try {
      final client = await ClientService().getClient(_liveInvoice.clientId);
      clientPhone = client?.phone;
    } catch (e) {
      debugPrint('[InvoiceDetails] Client fetch error: $e');
    }

    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WhatsAppShareSheet(
        invoice: _liveInvoice,
        pdfFile: pdfFile,
        pdfBytes: pdfBytes,
        currencyFormat: _currency,
        clientPhone: clientPhone,
        upiId: _profile?.upiId,
        businessName: _profile?.storeName,

      ),
    );
  }

  /// WhatsApp — show quick "Image or PDF?" choice, then share
  Future<void> _shareViaWhatsApp(BuildContext context) async {
    // Plan gate — respects global kill switch + monthly quota
    final shareCount = await UsageTrackingService.instance.getWhatsAppShareCount();
    if (!PlanService.instance.canShareWhatsApp(shareCount)) {
      if (!context.mounted) return;
      final killSwitchOff = !RemoteConfigService.instance.featureWhatsAppShare;
      final max = PlanService.instance.currentLimits.maxWhatsAppSharesPerMonth;
      String msg;
      if (killSwitchOff) {
        msg = 'WhatsApp sharing is temporarily unavailable. Please restart the app.';
      } else if (max == 0) {
        msg = 'WhatsApp sharing is available on Pro plan.';
      } else {
        msg = 'You\'ve used $shareCount/$max WhatsApp shares this month.';
      }
      await LimitReachedDialog.show(
        context,
        title: 'WhatsApp Share Limit',
        message: msg,
        featureName: 'WhatsApp sharing',
      );
      return;
    }

    // Fetch client phone
    String? clientPhone;
    String? clientName;
    try {
      final client = await ClientService().getClient(_liveInvoice.clientId);
      clientPhone = client?.phone;
      clientName = client?.name;
    } catch (_) {}

    if (!mounted) return;

    final rawPhone = (clientPhone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (rawPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number for this customer')),
      );
      return;
    }
    final whatsAppPhone = rawPhone.length == 10 ? '91$rawPhone' : rawPhone;

    // Fetch store name for the message
    String? storeName;
    try {
      final profile = await ProfileService().getCurrentProfile();
      storeName = profile?.storeName;
    } catch (_) {}

    final inv = _liveInvoice;
    final name = clientName ?? inv.clientName;
    final shop = (storeName != null && storeName.isNotEmpty) ? storeName : 'BillRaja';

    // Add UPI payment link if available (uses balance due)
    String upiPart = '';
    if (_profile != null && _profile!.upiId.isNotEmpty && inv.grandTotal > 0) {
      // Use received amount (what customer is paying now), or grand total if nothing recorded
      final payAmount = inv.amountReceived > 0 ? inv.amountReceived : inv.grandTotal;
      final payLink = buildUpiWebPaymentLink(
        upiId: _profile!.upiId,
        businessName: _profile!.storeName,
        amount: payAmount,
        invoiceNumber: inv.invoiceNumber,
      );
      upiPart = '\n\nPay now: $payLink';
    }

    // On web, skip format popup — just share the download link directly
    if (kIsWeb) {
      String? downloadLink;
      try {
        downloadLink = await InvoiceLinkService.shareLink(invoice: _liveInvoice);
      } catch (_) {}

      final webMsg = 'Hi $name, your invoice *#${inv.invoiceNumber}* '
          'of *${_currency.format(inv.grandTotal)}* from *$shop*.'
          '${downloadLink != null ? '\n\nDownload: $downloadLink' : ''}'
          '$upiPart';
      final waUri = Uri.parse('https://wa.me/$whatsAppPhone?text=${Uri.encodeComponent(webMsg)}');
      await launchUrl(waUri, mode: LaunchMode.externalApplication);
      await UsageTrackingService.instance.incrementWhatsAppShareCount();
      return;
    }

    // Native: show PDF vs Image choice
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4, margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              const Text('Share via WhatsApp', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ShareChoiceButton(
                    icon: Icons.image_outlined,
                    label: 'Image',
                    color: const Color(0xFF7C3AED),
                    onTap: () => Navigator.pop(ctx, 'image'),
                  ),
                  _ShareChoiceButton(
                    icon: Icons.picture_as_pdf_outlined,
                    label: 'PDF',
                    color: const Color(0xFFE53935),
                    onTap: () => Navigator.pop(ctx, 'pdf'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );

    if (choice == null || !mounted) return;

    final dueDate = inv.dueDate != null
        ? DateFormat('dd MMM yyyy').format(inv.dueDate!)
        : null;

    final message = 'Hi $name, your invoice *#${inv.invoiceNumber}* '
        'of *${_currency.format(inv.grandTotal)}* from *$shop*.$upiPart';

    // Prepare the file (native only)
    String? filePath;
    try {
      final pdfBytes = await _ensurePdfBytes();
      final dir = await getTemporaryDirectory();

      if (choice == 'pdf') {
        final fileName = InvoicePdfService().fileNameForInvoice(_liveInvoice);
        final pdfFile = File('${dir.path}/$fileName');
        await pdfFile.writeAsBytes(pdfBytes);
        filePath = pdfFile.path;
      } else {
        // Render PDF page to image with white background
        final pages = await Printing.raster(pdfBytes, pages: [0], dpi: 200).toList();
        if (pages.isNotEmpty) {
          final rasterPage = pages.first;
          final rawImage = await rasterPage.toImage();

          // Draw white background + invoice on top
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          canvas.drawRect(
            Rect.fromLTWH(0, 0, rawImage.width.toDouble(), rawImage.height.toDouble()),
            Paint()..color = Colors.white,
          );
          canvas.drawImage(rawImage, Offset.zero, Paint());
          final picture = recorder.endRecording();
          final composited = await picture.toImage(rawImage.width, rawImage.height);
          final byteData = await composited.toByteData(format: ui.ImageByteFormat.png);
          rawImage.dispose();
          composited.dispose();

          if (byteData != null) {
            final imgFile = File('${dir.path}/Invoice_${_liveInvoice.invoiceNumber}.png');
            await imgFile.writeAsBytes(byteData.buffer.asUint8List());
            filePath = imgFile.path;
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
      return;
    }

    if (filePath == null || !mounted) return;

    // Send file + pre-filled text via WhatsApp native intent
    if (Platform.isAndroid) {
      try {
        const channel = MethodChannel('com.luhit.billeasy/share');
        await channel.invokeMethod('whatsapp', {
          'phone': whatsAppPhone,
          'filePath': filePath,
          'text': message,
        });
        await UsageTrackingService.instance.incrementWhatsAppShareCount();
        return;
      } on PlatformException catch (e) {
        if (e.code != 'NO_WA') return;
      }
    }

    if (!mounted) return;

    // Fallback (iOS / no WhatsApp): open wa.me with message only
    final waUri = Uri.parse('https://wa.me/$whatsAppPhone?text=${Uri.encodeComponent(message)}');
    await launchUrl(waUri, mode: LaunchMode.externalApplication);
    await UsageTrackingService.instance.incrementWhatsAppShareCount();
  }

  /// SMS — open SMS app directly with invoice link
  Future<void> _shareViaSms(BuildContext context) async {
    String? clientPhone;
    String? shareLink;
    try {
      final results = await Future.wait([
        ClientService().getClient(_liveInvoice.clientId),
        InvoiceLinkService.shareLink(invoice: _liveInvoice),
      ]).timeout(const Duration(seconds: 8), onTimeout: () => [null, null]);
      clientPhone = (results[0] as Client?)?.phone;
      shareLink = results[1] as String?;
    } catch (_) {}

    final phone = (clientPhone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    final linkText = shareLink != null ? ' View: $shareLink' : '';
    final message = 'Invoice ${_liveInvoice.invoiceNumber} for ${_currency.format(_liveInvoice.grandTotal)}.$linkText';

    final smsUri = Uri(scheme: 'sms', path: phone, queryParameters: {'body': message});
    try {
      await launchUrl(smsUri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open SMS: $e')));
      }
    }
  }

  void _handleMenuAction(String value, BuildContext context) {
    final invoice = _liveInvoice;
    switch (value) {
      case 'mark_paid':
        HapticFeedback.lightImpact();
        FirebaseService().markAsPaid(invoice.id);
        Navigator.pop(context);
      case 'record_payment':
        _showRecordPaymentSheet(context, invoice);
      case 'payment_history':
        _showPaymentHistory(context, invoice);
      case 'show_qr':
        _showFullScreenQR(context, invoice);
      case 'send_reminder':
        _sendPaymentReminder(context, invoice);
      case 'delete':
        _confirmDelete(context);
    }
  }

  void _showRecordPaymentSheet(BuildContext context, Invoice invoice) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final balance = invoice.balanceDue;
    String selectedMethod = 'Cash';
    final methods = ['Cash', 'UPI', 'Bank Transfer', 'Cheque', 'Other'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Record Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Balance due: \u20b9${balance.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 13, color: kOnSurfaceVariant)),
            const SizedBox(height: 16),
            // Amount field
            TextField(
              controller: amountCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: '\u20b9 ',
                hintText: 'Enter amount received',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: TextButton(
                  onPressed: () => amountCtrl.text = balance.toStringAsFixed(2),
                  child: const Text('Full', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Payment method chips
            Wrap(
              spacing: 8,
              children: methods.map((m) => ChoiceChip(
                label: Text(m, style: const TextStyle(fontSize: 12)),
                selected: selectedMethod == m,
                selectedColor: kPrimary.withValues(alpha: 0.15),
                onSelected: (_) => setSheetState(() => selectedMethod = m),
              )).toList(),
            ),
            const SizedBox(height: 12),
            // Note field
            TextField(
              controller: noteCtrl,
              decoration: InputDecoration(
                hintText: 'Note (optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
              maxLines: 1,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Send UPI payment link with entered amount
                if (_profile != null && _profile!.upiId.isNotEmpty)
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: kPrimary),
                      ),
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Send UPI Link', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      onPressed: () async {
                        final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                        if (amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Enter an amount first')),
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        final payLink = buildUpiWebPaymentLink(
                          upiId: _profile!.upiId,
                          businessName: _profile!.storeName,
                          amount: amount,
                          invoiceNumber: invoice.invoiceNumber,
                        );
                        final name = invoice.clientName.trim().isNotEmpty ? invoice.clientName.trim() : 'Customer';
                        final msg = 'Hi $name, please pay *${_currency.format(amount)}* for invoice *#${invoice.invoiceNumber}*.\n\nPay now: $payLink';

                        // Try to get customer phone
                        String phone = '';
                        try {
                          final client = await ClientService().getClient(invoice.clientId);
                          if (client != null && client.phone.isNotEmpty) {
                            final digits = client.phone.replaceAll(RegExp(r'\D'), '');
                            phone = digits.length == 12 && digits.startsWith('91') ? digits : '91$digits';
                          }
                        } catch (_) {}

                        final waUri = Uri.parse(
                          phone.isNotEmpty
                              ? 'https://wa.me/$phone?text=${Uri.encodeComponent(msg)}'
                              : 'https://wa.me/?text=${Uri.encodeComponent(msg)}',
                        );
                        await launchUrl(waUri, mode: LaunchMode.externalApplication);
                      },
                    ),
                  ),
                if (_profile != null && _profile!.upiId.isNotEmpty)
                  const SizedBox(width: 10),
                // Save payment locally
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: kPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                      if (amount <= 0) return;
                      final newTotalReceived = ((invoice.amountReceived + amount) * 100).roundToDouble() / 100;
                      final capped = newTotalReceived > invoice.grandTotal ? invoice.grandTotal : newTotalReceived;
                      Navigator.pop(ctx);
                      try {
                        await FirebaseService().recordPayment(
                          invoice.id, amount, capped, invoice.grandTotal,
                          method: selectedMethod.toLowerCase(),
                          note: noteCtrl.text.trim(),
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Payment of \u20b9${_currency.format(amount)} recorded'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to record payment: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('Save Payment', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      )),
    );
  }

  void _showPaymentHistory(BuildContext context, Invoice invoice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.history, size: 20, color: kPrimary),
                  const SizedBox(width: 8),
                  const Text('Payment History', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('Total: \u20b9${invoice.amountReceived.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32))),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: FirebaseService().watchPaymentHistory(invoice.id),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final payments = snap.data ?? [];
                  if (payments.isEmpty) {
                    return const Center(child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No payments recorded yet', style: TextStyle(color: kOnSurfaceVariant)),
                    ));
                  }
                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: payments.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final p = payments[i];
                      final amount = (p['amount'] as num? ?? 0).toDouble();
                      final method = (p['method'] as String? ?? 'cash');
                      final note = (p['note'] as String? ?? '');
                      final date = (p['date'] as Timestamp?)?.toDate();
                      final balanceAfter = (p['balanceAfter'] as num? ?? 0).toDouble();

                      final methodIcon = switch (method) {
                        'upi' => Icons.account_balance_wallet,
                        'bank transfer' => Icons.account_balance,
                        'cheque' => Icons.receipt_long,
                        _ => Icons.payments_outlined,
                      };

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(methodIcon, size: 18, color: const Color(0xFF2E7D32)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '\u20b9${amount.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF2E7D32)),
                                  ),
                                  Text(
                                    '${method[0].toUpperCase()}${method.substring(1)}${note.isNotEmpty ? ' \u2022 $note' : ''}',
                                    style: const TextStyle(fontSize: 12, color: kOnSurfaceVariant),
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (date != null)
                                  Text(DateFormat('dd MMM, hh:mm a').format(date),
                                      style: const TextStyle(fontSize: 11, color: kOnSurfaceVariant)),
                                Text('Bal: \u20b9${balanceAfter.toStringAsFixed(2)}',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                        color: balanceAfter > 0 ? const Color(0xFFE65100) : const Color(0xFF2E7D32))),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildMenuItems(Invoice invoice) {
    return [
      if (invoice.effectiveStatus != InvoiceStatus.paid) ...[
        const PopupMenuItem(value: 'record_payment', child: Row(children: [
          Icon(Icons.currency_rupee, size: 18, color: kPrimary),
          SizedBox(width: 10), Text('Record Payment'),
        ])),
        const PopupMenuItem(value: 'mark_paid', child: Row(children: [
          Icon(Icons.check_circle_outline, size: 18, color: kPaid),
          SizedBox(width: 10), Text('Mark as Paid'),
        ])),
      ],
      const PopupMenuItem(value: 'payment_history', child: Row(children: [
        Icon(Icons.history, size: 18, color: Color(0xFF546E7A)),
        SizedBox(width: 10), Text('Payment History'),
      ])),
      if (_profile != null && _profile!.upiId.isNotEmpty && invoice.grandTotal > 0) ...[
        const PopupMenuItem(value: 'show_qr', child: Row(children: [
          Icon(Icons.qr_code_rounded, size: 18, color: Color(0xFF1B7A3D)),
          SizedBox(width: 10), Text('Show Payment QR'),
        ])),
        if (invoice.effectiveStatus != InvoiceStatus.paid)
          const PopupMenuItem(value: 'send_reminder', child: Row(children: [
            Icon(Icons.notifications_active_outlined, size: 18, color: Color(0xFFF57C00)),
            SizedBox(width: 10), Text('Send Reminder'),
          ])),
      ],
      const PopupMenuDivider(),
      const PopupMenuItem(value: 'delete', child: Row(children: [
        Icon(Icons.delete_outline, size: 18, color: kOverdue),
        SizedBox(width: 10), Text('Delete', style: TextStyle(color: kOverdue)),
      ])),
    ];
  }

  // ── Full-Screen Payment QR ────────────────────────────────────────────────

  void _showFullScreenQR(BuildContext context, Invoice invoice) {
    if (_profile == null || _profile!.upiId.isEmpty) return;
    final upiLink = buildUpiPaymentLink(
      upiId: _profile!.upiId,
      businessName: _profile!.storeName,
      amount: invoice.balanceDue > 0 ? invoice.balanceDue : invoice.grandTotal,
      invoiceNumber: invoice.invoiceNumber,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: kSurfaceContainerHigh, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              // Title
              const Text('Scan to Pay', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kOnSurface)),
              const SizedBox(height: 4),
              Text(
                _currency.format(invoice.balanceDue > 0 ? invoice.balanceDue : invoice.grandTotal),
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: kPrimary),
              ),
              const SizedBox(height: 4),
              Text(invoice.invoiceNumber, style: const TextStyle(fontSize: 13, color: kTextTertiary)),
              const SizedBox(height: 20),
              // QR Code
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kSurfaceContainerHigh, width: 1.5),
                ),
                child: QrImageView(
                  data: upiLink,
                  version: QrVersions.auto,
                  size: 240,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF1B7A3D),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'UPI: ${_profile!.upiId}',
                style: const TextStyle(fontSize: 12, color: kTextTertiary),
              ),
              const SizedBox(height: 16),
              // Open UPI app button (mobile only)
              if (!kIsWeb)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse(upiLink);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Open UPI App'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B7A3D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                'Works with GPay, PhonePe, Paytm, BHIM & all UPI apps',
                style: TextStyle(fontSize: 11, color: kTextTertiary.withValues(alpha: 0.7)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Send Payment Reminder ───────────────────────────────────────────────

  Future<void> _sendPaymentReminder(BuildContext context, Invoice invoice) async {
    if (_profile == null || _profile!.upiId.isEmpty) return;

    final payLink = buildUpiWebPaymentLink(
      upiId: _profile!.upiId,
      businessName: _profile!.storeName,
      amount: invoice.balanceDue > 0 ? invoice.balanceDue : invoice.grandTotal,
      invoiceNumber: invoice.invoiceNumber,
    );

    final shopName = _profile!.storeName.isNotEmpty ? _profile!.storeName : 'us';
    final amount = _currency.format(invoice.balanceDue > 0 ? invoice.balanceDue : invoice.grandTotal);
    final name = invoice.clientName.trim().isNotEmpty ? invoice.clientName.trim() : 'Customer';

    final message = 'Hi $name, friendly reminder for invoice *#${invoice.invoiceNumber}* '
        'of *$amount* from *$shopName*.\n\nPay now: $payLink';

    // Try to get customer phone for direct WhatsApp
    String phone = '';
    try {
      final client = await ClientService().getClient(invoice.clientId);
      if (client != null && client.phone.isNotEmpty) {
        final digits = client.phone.replaceAll(RegExp(r'\D'), '');
        phone = digits.length == 12 && digits.startsWith('91') ? digits : '91$digits';
      }
    } catch (_) {}

    final waUri = Uri.parse(
      phone.isNotEmpty
          ? 'https://wa.me/$phone?text=${Uri.encodeComponent(message)}'
          : 'https://wa.me/?text=${Uri.encodeComponent(message)}',
    );

    if (await canLaunchUrl(waUri)) {
      await launchUrl(waUri, mode: LaunchMode.externalApplication);
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp')),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: const Text('This will permanently delete this invoice. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: kOverdue),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      HapticFeedback.heavyImpact();
      await FirebaseService().deleteInvoice(_liveInvoice.id);
      if (context.mounted) Navigator.pop(context);
    }
  }
}

class _ShareIcon extends StatelessWidget {
  const _ShareIcon({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.iconWidget,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final Widget? iconWidget;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(child: iconWidget ?? Icon(icon, color: color, size: 24)),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _TemplateArrowButton extends StatelessWidget {
  const _TemplateArrowButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 8),
          ],
        ),
        child: Icon(icon, size: 26, color: Colors.black87),
      ),
    );
  }
}

class _ShareChoiceButton extends StatelessWidget {
  const _ShareChoiceButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}
