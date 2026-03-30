import 'package:billeasy/theme/app_colors.dart';
import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String lastUpdated = 'March 21, 2026';
  static const String appName = 'BillRaja';
  static const String developerName = 'BillRaja';
  static const String contactEmail = 'support@billraja.app';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: kOnSurface,
          ),
        ),
        backgroundColor: kSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          Text(
            'Last updated: $lastUpdated',
            style: const TextStyle(
              fontSize: 13,
              color: kOnSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          ..._buildSections(),
        ],
      ),
    );
  }

  List<Widget> _buildSections() {
    return [
      _section(
        'Introduction',
        '$appName ("we", "our", or "us") is a mobile application designed to help '
            'small businesses in India create invoices, manage customers, track inventory, '
            'and handle GST compliance. This Privacy Policy explains how we collect, use, '
            'store, share, and protect your information when you use our app.\n\n'
            'By using $appName, you agree to the collection and use of information in '
            'accordance with this policy. If you do not agree, please do not use the app.',
      ),
      _section(
        '1. Information We Collect',
        null,
        children: [
          _subSection(
            'a) Account Information',
            'When you sign in using Google Sign-In, we collect:\n'
                '  \u2022 Your name\n'
                '  \u2022 Email address\n'
                '  \u2022 Google profile photo URL\n'
                '  \u2022 Unique user identifier (UID)',
          ),
          _subSection(
            'b) Business Profile Information',
            'To generate invoices and comply with GST requirements, you may provide:\n'
                '  \u2022 Business/store name\n'
                '  \u2022 Business address and state\n'
                '  \u2022 Phone number\n'
                '  \u2022 GSTIN (GST Identification Number)\n'
                '  \u2022 Business logo (uploaded image)\n'
                '  \u2022 Bank account details (account holder name, account number, IFSC code, bank name)\n'
                '  \u2022 UPI ID\n'
                '  \u2022 Invoice number prefix and payment terms',
          ),
          _subSection(
            'c) Customer Data',
            'You may store information about your customers, including:\n'
                '  \u2022 Customer name, phone number, and email\n'
                '  \u2022 Customer address\n'
                '  \u2022 Customer GSTIN\n'
                '  \u2022 Notes and group classifications',
          ),
          _subSection(
            'd) Invoice & Financial Data',
            'Invoices you create contain:\n'
                '  \u2022 Invoice numbers and dates\n'
                '  \u2022 Item descriptions, quantities, prices, and HSN codes\n'
                '  \u2022 GST rates and tax calculations\n'
                '  \u2022 Discounts and total amounts\n'
                '  \u2022 Payment status (paid, pending, overdue)',
          ),
          _subSection(
            'e) Product & Inventory Data',
            '  \u2022 Product names, descriptions, categories, and prices\n'
                '  \u2022 Stock levels and stock movement history',
          ),
          _subSection(
            'f) Subscription & Payment Data',
            '  \u2022 Subscription plan (Free, Pro)\n'
                '  \u2022 Billing cycle and subscription status\n'
                '  \u2022 Razorpay payment and subscription IDs\n\n'
                'Note: We do NOT store your credit/debit card numbers or banking '
                'credentials. All payment processing is handled securely by Razorpay.',
          ),
          _subSection(
            'g) Device & Usage Data',
            '  \u2022 Device push notification tokens (FCM)\n'
                '  \u2022 Monthly usage metrics (invoice count, WhatsApp shares count)\n'
                '  \u2022 Language preference',
          ),
        ],
      ),
      _section(
        '2. How We Use Your Information',
        'We use the information collected to:\n\n'
            '  \u2022 Provide and maintain the app\'s core features (invoicing, inventory, GST reports)\n'
            '  \u2022 Authenticate your identity and secure your account\n'
            '  \u2022 Process subscription payments through Razorpay\n'
            '  \u2022 Send push notifications (e.g., overdue invoice reminders)\n'
            '  \u2022 Generate PDF invoices and enable sharing via WhatsApp/SMS\n'
            '  \u2022 Calculate and display GST reports for your business\n'
            '  \u2022 Enforce plan limits and track usage\n'
            '  \u2022 Improve app performance and fix bugs\n'
            '  \u2022 Comply with legal obligations',
      ),
      _section(
        '3. Data Storage & Security',
        'Your data is stored using Google Firebase services:\n\n'
            '  \u2022 Cloud Firestore: Stores your business profile, invoices, customers, '
            'products, and subscription data in Google\'s secure cloud infrastructure.\n'
            '  \u2022 Firebase Storage: Stores uploaded images (business logos).\n'
            '  \u2022 Local Cache: A copy of your data (up to 100 MB) is cached on your '
            'device for offline access. This data syncs automatically when you reconnect.\n\n'
            'We implement the following security measures:\n\n'
            '  \u2022 Firebase App Check to prevent unauthorized API access\n'
            '  \u2022 Firestore security rules ensuring users can only access their own data\n'
            '  \u2022 Server-side payment verification via Cloud Functions\n'
            '  \u2022 All data transmitted over encrypted HTTPS connections\n\n'
            'While we take reasonable measures to protect your data, no method of electronic '
            'storage or transmission is 100% secure. We cannot guarantee absolute security.',
      ),
      _section(
        '4. Third-Party Services',
        'We use the following third-party services that may collect and process your data:\n\n'
            '  \u2022 Google Firebase (Authentication, Firestore, Cloud Functions, Storage, '
            'Messaging, App Check) \u2013 Privacy Policy: https://firebase.google.com/support/privacy\n\n'
            '  \u2022 Google Sign-In \u2013 Privacy Policy: https://policies.google.com/privacy\n\n'
            '  \u2022 Razorpay (Payment processing) \u2013 Privacy Policy: https://razorpay.com/privacy\n\n'
            'These services have their own privacy policies governing how they handle your data.',
      ),
      _section(
        '5. Data Sharing',
        'We do NOT sell, trade, or rent your personal information to third parties.\n\n'
            'Your data may be shared only in these circumstances:\n\n'
            '  \u2022 With Razorpay: To process subscription payments.\n'
            '  \u2022 With Google/Firebase: For authentication, data storage, and push notifications.\n'
            '  \u2022 Invoice sharing: When YOU choose to share invoices via WhatsApp or SMS, '
            'the invoice data is shared through those platforms.\n'
            '  \u2022 Legal compliance: If required by law, regulation, or valid legal process.',
      ),
      _section(
        '6. Data Retention',
        'We retain your data for as long as your account is active. If you delete your '
            'account:\n\n'
            '  \u2022 Your business profile, invoices, customers, products, and analytics '
            'will be permanently deleted from our servers.\n'
            '  \u2022 Locally cached data on your device will be cleared upon signing out.\n'
            '  \u2022 Payment records maintained by Razorpay are subject to Razorpay\'s '
            'own retention policies.\n\n'
            'We may retain certain data as required by Indian tax and business regulations.',
      ),
      _section(
        '7. Your Rights',
        'You have the right to:\n\n'
            '  \u2022 Access: View all your data within the app at any time.\n'
            '  \u2022 Export: Export your invoice and customer data as CSV files.\n'
            '  \u2022 Correction: Update your business profile, customer, and product information.\n'
            '  \u2022 Deletion: Request account and data deletion by contacting us at $contactEmail.\n'
            '  \u2022 Withdraw Consent: Stop using the app and sign out at any time.',
      ),
      _section(
        '8. Children\'s Privacy',
        '$appName is not intended for use by anyone under the age of 18. We do not '
            'knowingly collect personal information from children. If you believe we have '
            'inadvertently collected data from a minor, please contact us at $contactEmail '
            'and we will promptly delete it.',
      ),
      _section(
        '9. Permissions',
        'The app requests the following device permissions:\n\n'
            '  \u2022 Internet: Required for syncing data and processing payments.\n'
            '  \u2022 Camera & Photo Library: To upload your business logo.\n'
            '  \u2022 Push Notifications: To send invoice reminders and updates.\n\n'
            'All permissions are used solely for the stated purposes.',
      ),
      _section(
        '10. Changes to This Policy',
        'We may update this Privacy Policy from time to time. We will notify you of '
            'significant changes through the app or via email. Continued use of the app '
            'after changes constitutes acceptance of the updated policy.\n\n'
            'We encourage you to review this policy periodically.',
      ),
      _section(
        '11. Contact Us',
        'If you have questions, concerns, or requests regarding this Privacy Policy '
            'or your data, please contact us:\n\n'
            '  Email: $contactEmail\n\n'
            'We will respond to your inquiry within a reasonable timeframe.',
      ),
      const SizedBox(height: 20),
      Center(
        child: Text(
          '\u00A9 2026 $appName. All rights reserved.',
          style: const TextStyle(
            fontSize: 12,
            color: kTextTertiary,
          ),
        ),
      ),
    ];
  }

  Widget _section(String title, String? body, {List<Widget>? children}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: kOnSurface,
            ),
          ),
          if (body != null) ...[
            const SizedBox(height: 10),
            Text(
              body,
              style: const TextStyle(
                fontSize: 14,
                color: kOnSurfaceVariant,
                height: 1.6,
              ),
            ),
          ],
          if (children != null) ...children,
        ],
      ),
    );
  }

  Widget _subSection(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: kOnSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              color: kOnSurfaceVariant,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
