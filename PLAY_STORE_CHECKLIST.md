# Google Play Store Upload Checklist for BillRaja

## 1. Privacy Policy (REQUIRED)

You MUST provide a publicly accessible privacy policy URL.

**Your hosted privacy policy:** Deploy your Firebase Hosting and use:
```
https://billeasy-3a6ad.web.app/privacy-policy.html
```

Set this URL in:
- Google Play Console → Policy → App content → Privacy policy
- Also in your app's Store Listing description

---

## 2. Data Safety Form (REQUIRED)

Google Play requires you to fill out the Data Safety section. Here's exactly what to declare:

### Data Collected

| Data Type | Collected | Shared | Purpose |
|-----------|-----------|--------|---------|
| **Name** | Yes | No | Account management |
| **Email address** | Yes | No | Account management |
| **Phone number** | Yes (optional) | No | App functionality (business profile) |
| **Address** | Yes (optional) | No | App functionality (invoicing) |
| **Photos** | Yes (optional) | No | App functionality (business logo) |
| **Financial info (purchase history)** | Yes | Yes (Razorpay) | Subscription payments |
| **Other financial info (invoices, GST)** | Yes | No | App functionality |
| **App interactions** | Yes | No | Analytics (usage tracking) |
| **Device identifiers (FCM token)** | Yes | No | Push notifications |

### Data Safety Answers

- **Is data encrypted in transit?** → YES (HTTPS/TLS)
- **Can users request data deletion?** → YES (via email: support@billraja.app)
- **Is data collected from children?** → NO (app is 18+)
- **Does the app share data with third parties?** → YES (Razorpay for payments, Google/Firebase for infrastructure)

---

## 3. Account Deletion Requirement (REQUIRED since Dec 2023)

Google Play requires apps with accounts to offer account deletion. You need:

1. **In-app deletion option** — Add a "Delete Account" button in Settings
2. **Web-based deletion** — A web form or email for users who can't access the app

**Current status:** Users can contact support@billraja.app for deletion.
**Recommended:** Add an in-app "Delete Account" button in Settings that:
  - Shows a confirmation dialog
  - Calls a Cloud Function to delete all user data from Firestore
  - Deletes the Firebase Auth account
  - Signs the user out

---

## 4. Content Rating (REQUIRED)

Fill out the IARC questionnaire in Play Console:
- No violence, sexual content, or gambling → Expected rating: **Everyone / PEGI 3**
- Contains: Financial transactions (in-app purchases for subscriptions)

---

## 5. Target Audience & Content (REQUIRED)

- **Target age group:** 18+ (business professionals)
- **Is this app designed for children?** → NO
- **Does it appeal to children?** → NO

---

## 6. Ads Declaration

- **Does your app contain ads?** → NO

---

## 7. App Access (for Review)

Since BillRaja requires Google Sign-In, provide the review team:
- A test Google account they can use
- Or mark "All or some functionality is restricted" and provide login credentials

---

## 8. Store Listing Requirements

### Required Assets:
- [ ] App icon: 512x512 PNG (32-bit, no alpha)
- [ ] Feature graphic: 1024x500 PNG or JPG
- [ ] Screenshots: Min 2, max 8 per device type
  - Phone: 16:9 or 9:16 (min 320px, max 3840px)
  - Tablet (optional but recommended): 16:9 or 9:16
- [ ] Short description: Max 80 characters
- [ ] Full description: Max 4000 characters

### Suggested Short Description:
```
Create GST invoices, manage inventory & customers. Free billing app.
```

### Suggested Full Description:
```
BillRaja is the simplest billing app for Indian small businesses. Create professional GST invoices, manage your customers, track inventory, and generate tax reports — all from your phone.

KEY FEATURES:
• Create & share professional invoices in seconds
• Automatic GST calculation with per-item tax rates
• Share invoices via WhatsApp, SMS, or PDF
• Customer management with contact details & GSTIN
• Product catalog with inventory tracking
• Stock movement history
• GST reports (monthly & quarterly)
• Purchase order management
• Multiple invoice PDF templates
• Data export to CSV
• Works offline — syncs when connected
• Multi-language support (English, Hindi, Assamese, Gujarati, Tamil)

SUBSCRIPTION PLANS:
• Free — 20 invoices/month, 10 customers, 20 products
• Raja — Unlimited invoices, WhatsApp sharing, data export
• Maharaja — GST reports, e-way bill, advanced templates
• King — Everything unlimited

Built for Indian businesses. GST-compliant. Simple and fast.

Download BillRaja today and start billing like a pro!
```

---

## 9. App Category

- **Category:** Business
- **Tags:** Invoice, Billing, GST, Accounting, Small Business

---

## 10. Firebase Hosting Deployment

To make the privacy policy and terms pages publicly accessible:

```bash
# From the project root
firebase deploy --only hosting
```

This will deploy the web/ directory (including privacy-policy.html and terms-conditions.html) to:
- https://billeasy-3a6ad.web.app/privacy-policy.html
- https://billeasy-3a6ad.web.app/terms-conditions.html

Use the privacy policy URL in your Play Store listing.

---

## 11. Signing & Release

- [ ] Generate upload key (if not done): `keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
- [ ] Configure `android/key.properties` with keystore path and passwords
- [ ] Build release APK/AAB: `flutter build appbundle --release`
- [ ] Upload AAB to Play Console → Production/Internal testing track

---

## Quick Action Items:

1. ✅ Privacy Policy — Created (in-app screen + hosted HTML)
2. ✅ Terms & Conditions — Created (in-app screen + hosted HTML)
3. ✅ Legal consent on login — Added
4. ⬜ Deploy Firebase Hosting (`firebase deploy --only hosting`)
5. ⬜ Fill Data Safety form in Play Console (use table above)
6. ⬜ Add in-app Account Deletion (recommended)
7. ⬜ Complete IARC content rating questionnaire
8. ⬜ Prepare store listing assets (icon, screenshots, feature graphic)
9. ⬜ Create test account for Play Store review team
10. ⬜ Build and sign release AAB
