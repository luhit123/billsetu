# Production Runbook

## Scope

This runbook covers the production Firebase project `billeasy-3a6ad` for:

- Hosting
- Cloud Functions
- Firestore rules and indexes
- Firebase secrets

## Pre-Deploy Checks

Run these from the repo root before every production deploy:

```bash
node --check functions/index.js
flutter test
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter build web --release
flutter build appbundle --release
cd admin && flutter build web --release
firebase deploy --only firestore:rules,firestore:indexes --project billeasy-3a6ad --dry-run
firebase deploy --only functions --project billeasy-3a6ad --dry-run
```

## Deploy Order

Use this order to minimize user-facing breakage:

```bash
flutter build web --release
flutter build appbundle --release
cd admin && flutter build web --release
firebase deploy --only functions,firestore:rules,firestore:indexes,hosting --project billeasy-3a6ad
```

For client-breaking backend changes, ship the mobile app update before tightening rules that older clients depend on.

## Secrets

Current critical secrets include:

- `RAZORPAY_KEY_ID`
- `RAZORPAY_KEY_SECRET`
- `RAZORPAY_WEBHOOK_SECRET`
- `PAY_LINK_SIGNING_SECRET`

Check that a secret exists:

```bash
firebase functions:secrets:access PAY_LINK_SIGNING_SECRET --project billeasy-3a6ad >/dev/null && echo PRESENT
```

Rotate a secret:

```bash
openssl rand -hex 32 | firebase functions:secrets:set PAY_LINK_SIGNING_SECRET --project billeasy-3a6ad --data-file=-
firebase deploy --only functions --project billeasy-3a6ad
```

## Rollback

### Hosting only

Use the Firebase console to promote the previous Hosting release, or redeploy the previous known-good commit:

```bash
git checkout <known-good-commit>
flutter build web --release
firebase deploy --only hosting --project billeasy-3a6ad
```

### Functions / rules / indexes

Rollback from a known-good git commit:

```bash
git checkout <known-good-commit>
firebase deploy --only functions,firestore:rules,firestore:indexes --project billeasy-3a6ad
```

Do not use `--force` on Firestore indexes during rollback unless you intentionally want to delete indexes that are currently live.

## Backups

### Firestore

Use managed export to a dedicated GCS bucket:

```bash
gcloud firestore export gs://<backup-bucket>/billeasy-$(date +%F-%H%M) --project=billeasy-3a6ad
```

Recommended:

- daily export retention for at least 14 days
- separate bucket with versioning enabled
- restricted restore permissions

### Storage

Recommended:

- bucket versioning enabled
- lifecycle rules for old object versions
- periodic bucket inventory or scheduled copy to a backup bucket

## Incident Triage

### Payment or webhook failures

1. Check Cloud Functions logs for `verifyPayment`, `razorpayWebhook`, and `pay`.
2. Confirm `RAZORPAY_WEBHOOK_SECRET` is present.
3. Verify recent deploy did not change runtime expectations.
4. Check for App Check failures on callable functions if clients suddenly fall back.

### Public invoice or payment-link failures

1. Check logs for `invoicePage`, `downloadSharedInvoice`, `clientBills`, and `saveSharedInvoiceLink`.
2. Confirm `PAY_LINK_SIGNING_SECRET` is present.
3. Verify Hosting rewrite routes still point to the expected functions.

### Auth or deletion failures

1. Check logs for `deleteMyAccount`.
2. Confirm the client build includes the latest fresh-auth messaging.

## Post-Deploy Smoke Test

Verify these in production:

- sign in with OTP
- sign in with Google
- create invoice
- share invoice link
- download invoice PDF from public link
- view purchase history portal
- open signed `/p` payment link
- create team invite and accept it
- membership renew / freeze / unfreeze
- subscription checkout and webhook confirmation

## Known Platform Debt

These are still important follow-ups even after a healthy deploy:

- upgrade Functions runtime from Node.js 20
- upgrade `firebase-functions`
- complete full App Check rollout
- formalize scheduled backups outside local operator memory
