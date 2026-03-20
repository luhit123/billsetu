# CLAUDE.md - BillRaja (billeasy)

## Project Overview

BillRaja is a cross-platform Flutter billing workspace application for managing invoices, customers, GST (Goods and Services Tax), products, purchase orders, and business profiles. It targets Indian small businesses with GST compliance features, PDF invoice generation, and offline-first data persistence.

- **Package name:** billeasy
- **Version:** 1.0.0+1
- **Firebase project:** billeasy-3a6ad

## Tech Stack

- **Frontend:** Flutter (Dart SDK ^3.11.0) with Material Design 3
- **Backend:** Firebase (Firestore, Auth, Cloud Functions, App Check)
- **Authentication:** Firebase Auth with Google Sign-In
- **Database:** Cloud Firestore with offline persistence (100 MB cache)
- **Cloud Functions:** Node.js 20 with Firebase Admin SDK
- **PDF:** `pdf` + `printing` packages for invoice generation and sharing

## Quick Commands

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run                    # Default device
flutter run -d chrome          # Web
flutter run -d android         # Android

# Static analysis
flutter analyze

# Run tests
flutter test

# Build
flutter build apk             # Android
flutter build web             # Web (output: build/web)
flutter build ios              # iOS

# Firebase Cloud Functions
cd functions && npm install
npm run lint                   # Syntax check (node --check index.js)
npm run serve                  # Local emulator
npm run deploy                 # Deploy functions
```

## Project Structure

```
lib/
├── main.dart                  # App entry point, Firebase init, routing
├── firebase_options.dart      # Generated Firebase config
├── l10n/
│   └── app_strings.dart       # Internationalization strings
├── modals/                    # Data models (NOTE: directory named "modals", not "models")
│   ├── analytics_models.dart
│   ├── business_profile.dart
│   ├── client.dart
│   ├── customer_group.dart
│   ├── invoice.dart
│   ├── line_item.dart
│   ├── product.dart
│   ├── purchase_line_item.dart
│   ├── purchase_order.dart
│   └── stock_movement.dart
├── screens/                   # UI screens (20 total)
│   ├── home_screen.dart       # Main dashboard
│   ├── login_screen.dart
│   ├── onboarding_screen.dart
│   ├── create_invoice_screen.dart
│   ├── invoice_details_screen.dart
│   ├── invoices_screen.dart
│   ├── customers_screen.dart
│   ├── customer_details_screen.dart
│   ├── customer_form_screen.dart
│   ├── products_screen.dart
│   ├── product_form_screen.dart
│   ├── product_movements_screen.dart
│   ├── purchase_orders_screen.dart
│   ├── create_purchase_order_screen.dart
│   ├── purchase_order_details_screen.dart
│   ├── gst_report_screen.dart
│   ├── settings_screen.dart
│   ├── profile_setup_screen.dart
│   ├── language_selection_screen.dart
│   └── feature_placeholder_screen.dart
├── services/                  # Business logic & Firebase integration
│   ├── auth_service.dart
│   ├── firebase_service.dart         # Core Firestore queries, invoice CRUD
│   ├── firestore_page.dart           # Pagination helper
│   ├── profile_service.dart
│   ├── client_service.dart
│   ├── product_service.dart
│   ├── inventory_service.dart
│   ├── purchase_order_service.dart
│   ├── invoice_number_service.dart   # Invoice numbering via Cloud Function
│   ├── invoice_pdf_service.dart      # PDF generation
│   ├── analytics_service.dart
│   ├── customer_group_service.dart
│   ├── app_check_service.dart
│   └── background_maintenance_service.dart
├── theme/
│   └── app_colors.dart        # Material 3 color scheme
├── utils/
│   ├── invoice_search.dart    # Search query normalization
│   └── number_utils.dart      # Number formatting
└── widgets/
    ├── invoice_card.dart
    ├── customer_groups_sheet.dart
    └── error_retry_widget.dart

functions/                     # Firebase Cloud Functions (Node.js)
├── index.js                   # 4 functions: reserveInvoiceNumber, syncInvoiceAnalytics,
│                              #   markOverdueInvoices, cleanupInvoicesAfterClientDelete
└── package.json

firestore.rules                # Security rules with strict invoice validation
firestore.indexes.json         # Composite indexes
```

## Architecture

**Pattern:** Service-layer architecture (screens → services → Firebase)

- **Screens** handle UI and user interaction using StatefulWidgets
- **Services** are singleton classes that encapsulate Firestore operations and business logic
- **Modals** (data models) are immutable with `const` constructors, `toMap()`/`fromMap()` serialization
- No state management library — uses `setState`, `StreamBuilder`, and service singletons

## Key Conventions

### Dart/Flutter
- **File naming:** snake_case (`create_invoice_screen.dart`)
- **Class naming:** PascalCase (`CreateInvoiceScreen`)
- **Variable/method naming:** camelCase
- **Models directory** is named `modals/` (not `models/`) — maintain this convention
- **Linting:** `flutter_lints` package (analysis_options.yaml)
- Models use `factory` constructors for deserialization (`fromMap`)
- Models use `toMap()` for Firestore serialization

### Firebase / Firestore
- **Data hierarchy:** `/invoices/{id}` (top-level), `/users/{uid}/clients/{id}`, `/users/{uid}/products/{id}`, etc.
- **Invoice numbers** follow format: `BR-<year>-<5-digit-sequence>` (e.g., `BR-2026-00001`)
- **Invoice numbering** is atomic via Cloud Function `reserveInvoiceNumber`
- **GST rates** are restricted to: 0, 5, 12, 18, 28
- **GST types:** `cgst_sgst` (intra-state) or `igst` (inter-state)
- **Invoice statuses:** `paid`, `pending`, `overdue`
- **Discount types:** `percentage`, `overall`, or `null`
- **Timezone:** Asia/Kolkata (for overdue invoice scheduling)
- **Offline persistence** is enabled with 100 MB cache size

### Security Rules
- All user sub-collections require `isOwner(userId)` — user can only access their own data
- Invoices have strict shape and financial validation at the rules level
- Financial invariants enforced: `grandTotal == taxableAmount + totalTax`, `taxableAmount == subtotal - discountAmount`
- Invoice updates are restricted to status-only changes

### Cloud Functions (functions/index.js)
- `reserveInvoiceNumber` — Atomic invoice number generation with transaction
- `syncInvoiceAnalytics` — Triggered on invoice writes, computes analytics
- `markOverdueInvoices` — Scheduled function (30-day default due date)
- `cleanupInvoicesAfterClientDelete` — Cleans up invoice references when a client is deleted

## Testing

- Test framework: `flutter_test`
- Test files in `test/` directory
- Run with: `flutter test`
- Current coverage: basic widget tests

## Platform Support

Android, iOS, macOS, Linux, Windows, Web — all platform directories are present and configured.

## Important Notes

- Do NOT modify `firebase_options.dart` — it is generated by FlutterFire CLI
- Do NOT modify `lib/l10n/app_strings.dart` manually unless adding/editing translations
- The `modals/` directory name is intentional — do not rename to `models/`
- Firestore security rules enforce strict financial validation — any changes to invoice data shape must be reflected in `firestore.rules`
- Invoice number format `BR-YYYY-NNNNN` is validated in both security rules and Cloud Functions
