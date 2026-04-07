# Mobile Release Rollout

## Goal

Ship the client update that matches the hardened backend now live on `billeasy-3a6ad`.

## Android

Before running a publishable release build, provide upload-signing credentials with either:

- `android/key.properties` copied from `android/key.properties.example`
- `BILLRAJA_UPLOAD_STORE_FILE`, `BILLRAJA_UPLOAD_STORE_PASSWORD`, `BILLRAJA_UPLOAD_KEY_ALIAS`, and `BILLRAJA_UPLOAD_KEY_PASSWORD`

Build command:

```bash
flutter build appbundle --release
```

Expected output:

- `build/app/outputs/bundle/release/app-release.aab`

Before uploading to Play Console, validate:

- sign in with OTP
- sign in with Google
- create invoice on mobile and web
- team invite accept / decline
- team member role change
- office location save
- membership renew / freeze / unfreeze
- invoice share link generation
- signed `/p` reminder/payment links
- account deletion fresh-auth flow
- web app release build still succeeds

## iOS

Build and archive from Xcode after confirming:

- Google sign-in configuration is still valid
- associated domains / universal links are unchanged if used
- Firebase config matches production

## Rollout Strategy

Recommended:

1. Internal testing
2. Closed testing / staged rollout
3. Production rollout

Watch production logs for:

- `app-check`
- `permission-denied`
- `failed-precondition`
- `resource-exhausted`
- `unauthenticated`

## Release Notes Focus

Mention these visible changes:

- safer invoice and payment links
- stronger account-deletion security
- team and membership management reliability improvements

## Blocking Reminder

If the mobile client is not published, installed users may still run into older share or reminder behaviors even though the backend is already hardened.
