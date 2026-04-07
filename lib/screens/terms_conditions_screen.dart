import 'package:billeasy/theme/app_colors.dart';
import 'package:flutter/material.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  static const String lastUpdated = 'April 2, 2026';
  static const String appName = 'BillRaja';
  static const String contactEmail = 'contact@billraja.com';
  static const String grievanceEmail = 'contact@billraja.com';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cs.surface,
      appBar: AppBar(
        title: Text(
          'Terms & Conditions',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: context.cs.onSurface,
          ),
        ),
        backgroundColor: context.cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          Text(
            'Last updated: $lastUpdated',
            style: TextStyle(fontSize: 13, color: context.cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          ..._buildSections(context),
        ],
      ),
    );
  }

  List<Widget> _buildSections(BuildContext context) {
    return [
      _section(
        context,
        'Agreement to Terms',
        'These Terms and Conditions ("Terms") govern your use of the $appName mobile '
            'application ("App"). By downloading, installing, or using the App, you agree '
            'to be bound by these Terms. If you do not agree to these Terms, do not use the App.\n\n'
            '$appName is a billing and invoicing platform designed for small businesses in India.',
      ),
      _section(
        context,
        '1. Eligibility',
        '  \u2022 You must be at least 18 years of age to use this App.\n'
            '  \u2022 You must be a legitimate business owner or authorized representative.\n'
            '  \u2022 You must use a valid Google account or a valid phone number to sign in.\n'
            '  \u2022 By using the App, you represent that all information you provide is '
            'accurate, current, and complete.',
      ),
      _section(
        context,
        '2. Account & Authentication',
        '  \u2022 You may sign in using Google Sign-In or phone number verification.\n'
            '  \u2022 You are responsible for maintaining the security of the device, account, and credentials used to access the App.\n'
            '  \u2022 You are responsible for all activities that occur under your account.\n'
            '  \u2022 You must notify us immediately of any unauthorized use of your account.\n'
            '  \u2022 We reserve the right to suspend or terminate accounts that violate these Terms.',
      ),
      _section(
        context,
        '3. Subscription Plans & Payments',
        '$appName offers free and paid plans. Current commercial plans may include Free, Pro, and Enterprise tiers, and the latest pricing, feature set, and billing terms are shown inside the app and on our pricing page.\n\n'
            'Payment Terms:\n\n'
            '  \u2022 Paid subscriptions are billed monthly or annually through Razorpay.\n'
            '  \u2022 Prices are in Indian Rupees (INR) and include applicable GST.\n'
            '  \u2022 Subscriptions auto-renew unless cancelled before the renewal date.\n'
            '  \u2022 You can cancel your subscription at any time from the App settings.\n'
            '  \u2022 Deleting your account may cancel any active subscription associated with it.\n'
            '  \u2022 Upon cancellation, you retain access until the end of the current billing period.\n'
            '  \u2022 No refunds are provided for partial billing periods.\n'
            '  \u2022 We reserve the right to change pricing with reasonable advance notice.',
      ),
      _section(
        context,
        '4. Acceptable Use',
        'You agree NOT to:\n\n'
            '  \u2022 Use the App for any illegal or fraudulent purpose.\n'
            '  \u2022 Generate false, misleading, or fraudulent invoices.\n'
            '  \u2022 Attempt to gain unauthorized access to other users\' data.\n'
            '  \u2022 Reverse engineer, decompile, or disassemble the App.\n'
            '  \u2022 Use automated scripts, bots, or scrapers to access the App.\n'
            '  \u2022 Transmit viruses, malware, or other harmful code.\n'
            '  \u2022 Use the App in any way that could damage, disable, or impair the service.\n'
            '  \u2022 Violate any applicable local, state, national, or international law.',
      ),
      _section(
        context,
        '5. Your Data & Content',
        '  \u2022 You retain full ownership of all business data, invoices, customer '
            'records, and content you create within the App.\n'
            '  \u2022 You grant us a limited license to store, process, and display your '
            'data solely for the purpose of providing the App\'s services.\n'
            '  \u2022 You are solely responsible for the accuracy of your business information, '
            'GST details, invoices, and financial records.\n'
            '  \u2022 You are responsible for complying with all applicable tax laws and '
            'regulations, including GST filing requirements.\n'
            '  \u2022 $appName is a tool to assist with invoicing; it is NOT a substitute '
            'for professional accounting or legal advice.',
      ),
      _section(
        context,
        '6. GST & Tax Compliance',
        '  \u2022 $appName provides GST calculation and reporting features as a convenience tool.\n'
            '  \u2022 We do NOT guarantee the accuracy of GST calculations for your specific '
            'business scenario.\n'
            '  \u2022 You are solely responsible for verifying tax calculations, filing GST '
            'returns, and maintaining compliance with Indian tax authorities.\n'
            '  \u2022 $appName is not a registered tax consultant or chartered accountant service.\n'
            '  \u2022 We recommend consulting a qualified CA/tax professional for tax-related decisions.',
      ),
      _section(
        context,
        '7. Invoice Sharing',
        '  \u2022 When you share invoices via WhatsApp, SMS, email, PDF, or public invoice/payment links, you do so at your own discretion.\n'
            '  \u2022 We are not responsible for the delivery, receipt, or handling of invoices '
            'once shared through third-party platforms.\n'
            '  \u2022 You must ensure that you have proper consent to share business information '
            'with your customers through these channels.',
      ),
      _section(
        context,
        '8. Service Availability',
        '  \u2022 We strive to provide uninterrupted service but do not guarantee 100% uptime.\n'
            '  \u2022 The App includes offline functionality; however, some features require '
            'an internet connection.\n'
            '  \u2022 We may perform maintenance, updates, or upgrades that temporarily '
            'affect availability.\n'
            '  \u2022 We are not liable for any loss arising from service interruptions.',
      ),
      _section(
        context,
        '9. Intellectual Property',
        '  \u2022 The $appName name, logo, design, and all associated intellectual '
            'property are owned by us.\n'
            '  \u2022 You may not copy, modify, distribute, or create derivative works '
            'based on the App without our written permission.\n'
            '  \u2022 All PDF invoice templates and UI designs are our proprietary property.',
      ),
      _section(
        context,
        '10. Limitation of Liability',
        'TO THE MAXIMUM EXTENT PERMITTED BY LAW:\n\n'
            '  \u2022 $appName is provided "AS IS" and "AS AVAILABLE" without warranties '
            'of any kind.\n'
            '  \u2022 We are not liable for any indirect, incidental, special, consequential, '
            'or punitive damages arising from your use of the App.\n'
            '  \u2022 We are not liable for any financial loss, tax penalties, or legal '
            'consequences resulting from inaccurate invoices or GST calculations.\n'
            '  \u2022 Our total liability shall not exceed the amount you paid for the App '
            'in the 12 months preceding the claim.\n'
            '  \u2022 We are not responsible for any loss of data due to device failure, '
            'network issues, or circumstances beyond our control.',
      ),
      _section(
        context,
        '11. Indemnification',
        'You agree to indemnify and hold harmless $appName, its owners, employees, '
            'and affiliates from any claims, losses, damages, liabilities, and expenses '
            '(including legal fees) arising from:\n\n'
            '  \u2022 Your use or misuse of the App.\n'
            '  \u2022 Your violation of these Terms.\n'
            '  \u2022 Inaccurate business information, invoices, or tax filings you generate.\n'
            '  \u2022 Any dispute between you and your customers.',
      ),
      _section(
        context,
        '12. Termination',
        '  \u2022 You may stop using the App and delete your account at any time from the Settings screen.\n'
            '  \u2022 We may suspend or terminate your account if you violate these Terms.\n'
            '  \u2022 Upon termination, your right to use the App ceases immediately.\n'
            '  \u2022 Certain payment, tax, or compliance records may be retained where required by law or by our payment processor.\n'
            '  \u2022 Sections on Limitation of Liability, Indemnification, and Governing '
            'Law survive termination.',
      ),
      _section(
        context,
        '13. Governing Law & Dispute Resolution',
        '  \u2022 These Terms are governed by the laws of India.\n'
            '  \u2022 Any disputes shall be subject to the exclusive jurisdiction of courts '
            'in India.\n'
            '  \u2022 Before initiating legal proceedings, both parties agree to attempt '
            'resolution through good-faith negotiation.',
      ),
      _section(
        context,
        '14. Changes to These Terms',
        'We may update these Terms from time to time. Material changes will be notified '
            'through the App. Continued use after changes constitutes acceptance of the '
            'updated Terms.\n\n'
            'If you disagree with any changes, you must stop using the App.',
      ),
      _section(
        context,
        '15. Contact Us',
        'For questions or concerns regarding these Terms:\n\n'
            '  BillRaja\n'
            '  Email: $contactEmail\n'
            '  Grievance: $grievanceEmail\n\n'
            'We will respond to your inquiry within a reasonable timeframe.',
      ),
      const SizedBox(height: 20),
      Center(
        child: Text(
          '\u00A9 2026 $appName. All rights reserved.',
          style: TextStyle(
            fontSize: 12,
            color: context.cs.onSurfaceVariant.withAlpha(153),
          ),
        ),
      ),
    ];
  }

  Widget _section(BuildContext context, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: context.cs.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: TextStyle(
              fontSize: 14,
              color: context.cs.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
