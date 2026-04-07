# Google Play Store Upload Checklist for BillRaja

## 1. Privacy Policy and Account Deletion URLs

You MUST provide publicly accessible policy and deletion URLs.

**Hosted privacy policy**
```
https://billeasy-3a6ad.web.app/privacy-policy.html
```

**Hosted terms and conditions**
```
https://billeasy-3a6ad.web.app/terms-conditions.html
```

**Hosted account deletion page**
```
https://billeasy-3a6ad.web.app/account-deletion.html
```

Set the privacy policy URL in:
- Google Play Console -> Policy -> App content -> Privacy policy

Set the account deletion URL in:
- Google Play Console -> Policy -> App content -> Account deletion

---

## 2. Data Safety Form

Fill the Data Safety answers from current app behavior, not from old store copy.

### Data collected by the app

| Data Type | Collected | Shared | Purpose |
|-----------|-----------|--------|---------|
| **Name** | Yes | No | Account management and profile setup |
| **Email address** | Yes | No | Account management and communication |
| **Phone number** | Yes | No | Phone sign-in, business profile, customer records |
| **Address** | Yes (optional) | No | Business and customer invoicing details |
| **Contacts** | Yes (optional, user initiated) | No | Importing customer details from address book |
| **Photos / files** | Yes (optional) | No | Uploading a business logo |
| **Financial info (purchase history / subscription IDs)** | Yes | Yes (Razorpay) | Subscription billing and verification |
| **Other financial info (invoice, GST, bank / UPI details)** | Yes | No | App functionality |
| **App interactions / usage metrics** | Yes | No | Plan enforcement and product analytics |
| **Device identifiers (FCM token)** | Yes | No | Push notifications |

### Data Safety answers to review before submission

- **Is data encrypted in transit?** -> YES
- **Can users request data deletion?** -> YES (in-app deletion plus hosted deletion page)
- **Is data collected from children?** -> NO
- **Does the app share data with third parties?** -> YES (Razorpay for payments, Google/Firebase for infrastructure)

Note:
- User-initiated invoice sharing through WhatsApp, SMS, email, or public invoice/payment links should be reviewed carefully when answering Play Console questions. Keep the Console answers aligned with the latest Google guidance at submission time.

---

## 3. Account Deletion Requirement

Google Play requires apps with account creation to support deletion inside the app and from a public web resource.

### Current implementation

1. **In-app deletion** -> Settings -> Danger Zone -> `Erase profile permanently`
2. **Outside-app deletion** -> `https://billeasy-3a6ad.web.app/account-deletion.html`

### What the current flow does

- Deletes the user profile and app data from backend systems
- Deletes uploaded assets such as the logo
- Deletes the Firebase Auth account
- Signs the user out
- Cancels the active subscription as part of deletion flow when applicable

---

## 4. Content Rating

Fill out the IARC questionnaire in Play Console:
- No violence, sexual content, or gambling -> Expected rating: **Everyone / PEGI 3**
- Contains: Financial transactions (in-app subscriptions)

---

## 5. Target Audience & Content

- **Target age group:** 18+ (business professionals)
- **Is this app designed for children?** -> NO
- **Does it appeal to children?** -> NO

---

## 6. Ads Declaration

- **Does your app contain ads?** -> NO

---

## 7. App Access (for Review)

BillRaja supports both Google Sign-In and phone OTP.

**Recommended for Play review**
- Provide a dedicated Google test account because it is the easiest review path
- If any premium feature needs access, include exact steps for the reviewer
- If phone OTP review is required, provide a working review phone flow and instructions

---

## 8. Store Listing Requirements

### Required assets

- [ ] App icon: 512x512 PNG (32-bit, no alpha)
- [ ] Feature graphic: 1024x500 PNG or JPG
- [ ] Screenshots: Min 2, max 8 per device type
- [ ] Short description: Max 80 characters
- [ ] Full description: Max 4000 characters

### Suggested short description

```
Create GST invoices, manage customers and inventory, and share bills fast.
```

### Suggested full description

```
BillRaja helps Indian small businesses create professional invoices, manage customers, track inventory, and collect payments faster.

KEY FEATURES:
- Create GST invoices in seconds
- Share invoices by PDF, WhatsApp, SMS, and payment links
- Manage customers with phone, address, and GSTIN details
- Track products, stock levels, and stock movement
- Upload your business logo for branded invoices
- Export data and GST reports
- Work offline and sync when back online
- Use English, Hindi, Assamese, Gujarati, and Tamil

PLANS:
- Free: Core billing tools to get started
- Pro: Advanced sharing, exports, reports, inventory, analytics, and more

Built for Indian businesses. Simple, fast, and GST-ready.
```

---

## 9. App Category

- **Category:** Business
- **Tags:** Invoice, Billing, GST, Accounting, Small Business

---

## 10. Hosting Deployment

To make the hosted privacy policy, terms, and deletion pages public:

```bash
flutter build web
firebase deploy --only hosting
```

Hosted pages:
- `https://billeasy-3a6ad.web.app/privacy-policy.html`
- `https://billeasy-3a6ad.web.app/terms-conditions.html`
- `https://billeasy-3a6ad.web.app/account-deletion.html`

---

## 11. Signing & Release

- [ ] Generate upload key (if not done): `keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
- [ ] Configure `android/key.properties` with keystore path and passwords
- [ ] Build release AAB: `flutter build appbundle --release`
- [ ] Upload AAB to Play Console -> Internal testing / Production

---

## Quick Action Items

1. ✅ Privacy policy updated
2. ✅ Terms and conditions updated
3. ✅ Hosted account deletion page added
4. ✅ In-app deletion flow present
5. ✅ Permission surface reduced by removing unused boot permission
6. ✅ Hosting deployed with the latest policy and deletion pages
7. ⬜ Recheck Play Data Safety answers in Console before submission
8. ⬜ Complete IARC content rating questionnaire
9. ⬜ Prepare store listing assets and reviewer test account
10. ⬜ Build and sign release AAB
