import 'package:billeasy/theme/app_colors.dart';
import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String lastUpdated = 'April 2, 2026';
  static const String appName = 'BillRaja';
  static const String contactEmail = 'contact@billraja.com';
  static const String grievanceEmail = 'contact@billraja.com';
  static const String accountDeletionUrl =
      'https://billraja.com/account-deletion.html';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cs.surface,
      appBar: AppBar(
        title: Text(
          'Privacy Policy',
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
        'Introduction',
        '$appName ("we", "our", or "us") is a mobile application designed to help '
            'small businesses in India create invoices, manage customers, track inventory, '
            'and handle GST compliance. This Privacy Policy explains how we collect, use, '
            'store, share, and protect your information when you use our app.\n\n'
            'By using $appName, you agree to the collection and use of information in '
            'accordance with this policy. If you do not agree, please do not use the app.',
      ),
      _section(
        context,
        '1. Information We Collect',
        null,
        children: [
          _subSection(
            context,
            'a) Account & Sign-In Information',
            'Depending on how you sign in, we may collect:\n'
                '  \u2022 Unique user identifier (UID)\n'
                '  \u2022 Your name, email address, and Google profile photo URL when you use Google Sign-In\n'
                '  \u2022 Your phone number when you use phone number verification',
          ),
          _subSection(
            context,
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
            context,
            'c) Customer Data & Contact Import',
            'You may store information about your customers, including:\n'
                '  \u2022 Customer name, phone number, and email\n'
                '  \u2022 Customer address\n'
                '  \u2022 Customer GSTIN\n'
                '  \u2022 Notes and group classifications\n\n'
                'If you choose to import a customer from your address book, we may access the '
                'selected contact details so you can save them into the app.',
          ),
          _subSection(
            context,
            'd) Invoice & Financial Data',
            'Invoices you create contain:\n'
                '  \u2022 Invoice numbers and dates\n'
                '  \u2022 Item descriptions, quantities, prices, and HSN codes\n'
                '  \u2022 GST rates and tax calculations\n'
                '  \u2022 Discounts and total amounts\n'
                '  \u2022 Payment status (paid, pending, overdue)',
          ),
          _subSection(
            context,
            'e) Product & Inventory Data',
            '  \u2022 Product names, descriptions, categories, and prices\n'
                '  \u2022 Stock levels and stock movement history',
          ),
          _subSection(
            context,
            'f) Subscription & Payment Data',
            '  \u2022 Subscription plan (Free, Pro)\n'
                '  \u2022 Billing cycle and subscription status\n'
                '  \u2022 Razorpay payment and subscription IDs\n\n'
                'Note: We do NOT store your credit/debit card numbers or banking '
                'credentials. All payment processing is handled securely by Razorpay.',
          ),
          _subSection(
            context,
            'g) Device & Usage Data',
            '  \u2022 Device push notification tokens (FCM)\n'
                '  \u2022 Monthly usage metrics (invoice count, WhatsApp shares count)\n'
                '  \u2022 Language preference\n'
                '  \u2022 App crash logs, error diagnostics, and device information (collected automatically by Firebase Crashlytics)\n'
                '  \u2022 App usage events, screen views, session duration, and device identifiers (collected automatically by Firebase Analytics)',
          ),
          _subSection(
            context,
            'h) Location Data',
            'If your team uses the Geo-Attendance feature, we collect:\n\n'
                '  \u2022 Precise GPS location (latitude and longitude) at the time you check in or check out.\n'
                '  \u2022 Your distance from the configured office location to verify you are within the geofence.\n\n'
                'Location is collected only in the foreground when you actively open the Attendance screen and tap Check In or Check Out. '
                'We do not track your location in the background or when the app is closed.\n\n'
                'Your location data is stored alongside your attendance record and is visible to your team owner/manager for attendance verification purposes.',
          ),
          _subSection(
            context,
            'i) Team & Collaboration Data',
            'If you create or join a team workspace, we collect and store:\n\n'
                '  \u2022 Team membership details (your role, permissions, display name)\n'
                '  \u2022 Attendance records (check-in/check-out times, location, duration)\n'
                '  \u2022 Audit logs of team actions (role changes, member additions/removals)\n\n'
                'Team owners and managers can view attendance records and audit logs for all team members. '
                'Your business data (invoices, customers, products) created under a team workspace is accessible to other team members based on their assigned permissions.',
          ),
        ],
      ),
      _section(
        context,
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
        context,
        '3. Data Storage & Security',
        'Your data is stored using Google Firebase services:\n\n'
            '  \u2022 Cloud Firestore: Stores your business profile, invoices, customers, '
            'products, and subscription data in Google\'s secure cloud infrastructure.\n'
            '  \u2022 Firebase Storage: Stores uploaded images (business logos).\n'
            '  \u2022 Local Cache: A copy of your data (up to 100 MB) may be cached on your '
            'device for offline access. This data syncs automatically when you reconnect.\n\n'
            'We implement the following security measures:\n\n'
            '  \u2022 Account ownership, role-based access controls, and backend validation for sensitive operations\n'
            '  \u2022 Firestore and Storage rules to limit access to authorized data paths\n'
            '  \u2022 Server-side payment verification and billing processing via Cloud Functions\n'
            '  \u2022 All data transmitted over encrypted HTTPS connections\n\n'
            'While we take reasonable measures to protect your data, no method of electronic '
            'storage or transmission is 100% secure. We cannot guarantee absolute security.',
      ),
      _section(
        context,
        '4. Third-Party Services',
        'We use the following third-party services that may collect and process your data:\n\n'
            '  \u2022 Google Firebase (Authentication, including Google Sign-In and phone number verification, Firestore, Cloud Functions, Storage, '
            'Messaging, App Check)\n\n'
            '  \u2022 Firebase Analytics (App usage events, screen views, session data, device identifiers)\n\n'
            '  \u2022 Firebase Crashlytics (Crash logs, error diagnostics, device and OS information)\n\n'
            '  \u2022 Firebase Remote Config (Feature flags and configuration; may collect device identifiers)\n\n'
            '  \u2022 Google Sign-In (when you choose it)\n\n'
            '  \u2022 Razorpay (Payment processing)\n\n'
            'These services have their own privacy policies governing how they handle your data.',
      ),
      _section(
        context,
        '5. Data Sharing',
        'We do NOT sell, trade, or rent your personal information to third parties.\n\n'
            'Your data may be shared only in these circumstances:\n\n'
            '  \u2022 With Razorpay: To process subscription payments.\n'
            '  \u2022 With Google/Firebase: For authentication, data storage, and push notifications.\n'
            '  \u2022 Invoice and payment sharing: When YOU choose to share invoices or payment requests via WhatsApp, SMS, email, or public invoice/payment links, '
            'the invoice data you choose to share is made available through those channels.\n'
            '  \u2022 With your team: If you are part of a team workspace, your attendance records, invoices, and business data may be visible to team owners and managers based on role permissions.\n'
            '  \u2022 Legal compliance: If required by law, regulation, or valid legal process.',
      ),
      _section(
        context,
        '6. Data Retention',
        'We retain your data for as long as your account is active. If you delete your '
            'account:\n\n'
            '  \u2022 Your business profile, invoices, customers, products, and analytics '
            'will be deleted from our backend systems, subject to any limited legal retention obligations.\n'
            '  \u2022 Uploaded assets such as your business logo are deleted from our storage.\n'
            '  \u2022 Active subscriptions may be cancelled as part of the deletion flow.\n'
            '  \u2022 Local cached data on your device may continue to exist until app data is cleared, the cache is overwritten, or the app is uninstalled.\n'
            '  \u2022 Payment records maintained by Razorpay are subject to Razorpay\'s '
            'own retention policies.\n\n'
            'We may retain certain data as required by Indian tax and business regulations.',
      ),
      _section(
        context,
        '7. Your Rights',
        'You have the right to:\n\n'
            '  \u2022 Access: View all your data within the app at any time.\n'
            '  \u2022 Export: Export invoice, customer, and product data as CSV files where available.\n'
            '  \u2022 Correction: Update your business profile, customer, and product information.\n'
            '  \u2022 Deletion: Delete your account in the app from Settings > Danger Zone. If you cannot access the app, use $accountDeletionUrl or contact us at $contactEmail.\n'
            '  \u2022 Withdraw Consent: Stop using the app and sign out at any time.',
      ),
      _section(
        context,
        '8. Children\'s Privacy',
        '$appName is not intended for use by anyone under the age of 18. We do not '
            'knowingly collect personal information from children. If you believe we have '
            'inadvertently collected data from a minor, please contact us at $contactEmail '
            'and we will promptly delete it.',
      ),
      _section(
        context,
        '9. Permissions',
        'Depending on your device and how you use the app, we may request or use the following device permissions/capabilities:\n\n'
            '  \u2022 Internet: Required for syncing data, authentication, and processing payments.\n'
            '  \u2022 Notifications: To send invoice reminders and updates.\n'
            '  \u2022 Contacts: If you choose to import customer details from your address book.\n'
            '  \u2022 Photo/Media Picker: If you choose to upload a business logo.\n'
            '  \u2022 Vibration: To support notification delivery on supported devices.\n'
            '  \u2022 Location (ACCESS_FINE_LOCATION): Used only for the Geo-Attendance feature. Collected in the foreground when you actively check in or check out. Not collected in the background.\n\n'
            'Optional permissions are used only when you trigger the related feature. Location permission is requested only when you first open the Attendance screen.',
      ),
      _section(
        context,
        '10. Data Breach Notification',
        'In the event of a data breach that affects your personal or business data, we will:\n\n'
            '  \u2022 Notify affected users via email and/or in-app notification without unreasonable delay.\n'
            '  \u2022 Provide details of the nature of the breach, the data affected, and the steps we are taking to address it.\n'
            '  \u2022 Report the breach to the relevant authorities as required under the Digital Personal Data Protection Act (DPDPA) 2023 and other applicable Indian laws.',
      ),
      _section(
        context,
        '11. Changes to This Policy',
        'We may update this Privacy Policy from time to time. We will notify you of '
            'significant changes through the app or via email. Continued use of the app '
            'after changes constitutes acceptance of the updated policy.\n\n'
            'We encourage you to review this policy periodically.',
      ),
      _section(
        context,
        '12. Grievance Officer',
        'In accordance with the Information Technology Act, 2000 and the rules made thereunder, '
            'the Grievance Officer for the purpose of this Privacy Policy is:\n\n'
            '  Name: Luhit Dhungel\n'
            '  Designation: Founder & Grievance Officer\n'
            '  Email: $grievanceEmail\n\n'
            'The Grievance Officer shall address your concerns and resolve any complaints within 30 days of receiving them.',
      ),
      _section(
        context,
        '13. Contact Us',
        'If you have questions, concerns, or requests regarding this Privacy Policy '
            'or your data, please contact us:\n\n'
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

  Widget _section(
    BuildContext context,
    String title,
    String? body, {
    List<Widget>? children,
  }) {
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
          if (body != null) ...[
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
          if (children != null) ...children,
        ],
      ),
    );
  }

  Widget _subSection(BuildContext context, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: context.cs.onSurface,
            ),
          ),
          const SizedBox(height: 6),
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
