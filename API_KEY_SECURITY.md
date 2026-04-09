# API Key Security — BillRaja (billeasy)

Firebase API keys in `firebase_options.dart` are **not secret** — they identify the
project, not authorize it. However, unrestricted keys can be abused for quota
exhaustion, billing fraud, or impersonation attacks. Follow these steps in the
GCP Console to restrict each key before go-live.

## 1. Open the Credentials page

Go to: https://console.cloud.google.com/apis/credentials?project=billeasy-3a6ad

You will see API keys auto-created by Firebase for each platform (Android, iOS, Web).

## 2. Restrict the Android key

1. Click the Android key (e.g. `android key (auto created by Firebase)`).
2. Under **Application restrictions**, select **Android apps**.
3. Add an item:
   - **Package name:** `com.billeasy.app` (match `android/app/build.gradle` `applicationId`)
   - **SHA-1 fingerprint:** get it with:
     ```bash
     keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android
     # For release: use your upload/signing keystore
     ```
4. Under **API restrictions**, select **Restrict key** and allow only:
   - Firebase Installations API
   - Firebase Cloud Messaging API
   - Cloud Firestore API
   - Identity Toolkit API
   - Token Service API
5. Click **Save**.

## 3. Restrict the iOS key

1. Click the iOS key.
2. Under **Application restrictions**, select **iOS apps**.
3. Add your **Bundle ID**: `com.billeasy.app` (match `ios/Runner.xcodeproj` bundle identifier).
4. Apply the same **API restrictions** as the Android key above.
5. Click **Save**.

## 4. Restrict the Web key

1. Click the Web key.
2. Under **Application restrictions**, select **HTTP referrers (web sites)**.
3. Add allowed referrers:
   - `https://billeasy-3a6ad.web.app/*`
   - `https://billeasy-3a6ad.firebaseapp.com/*`
   - `https://yourdomain.com/*` (if using custom domain)
   - `http://localhost:*/*` (for development — remove before production)
4. Apply the same **API restrictions** as above.
5. Click **Save**.

## 5. Enable Firebase App Check

App Check is already enforced on all Cloud Functions (`enforceAppCheck: true`).
Ensure the following are also enabled:

1. Go to: https://console.firebase.google.com/project/billeasy-3a6ad/appcheck
2. For **Android**: Register with **Play Integrity** provider.
3. For **iOS**: Register with **App Attest** (or DeviceCheck for older devices).
4. For **Web**: Register with **reCAPTCHA Enterprise**.
5. Under **APIs**, enforce App Check for:
   - Cloud Firestore
   - Cloud Functions
   - Cloud Storage
   - Firebase Authentication

## 6. Verify restrictions

After restricting keys, test each platform to confirm normal operation:
- Android: Sign in, create an invoice, generate PDF
- iOS: Sign in, create an invoice, generate PDF
- Web: Sign in, create an invoice, generate PDF

If a key restriction is too tight you will see `403 PERMISSION_DENIED` or
`API key not valid` errors in the console.

## 7. Rotate keys if compromised

If a key is exposed (e.g. committed to a public repo):
1. Create a new key with the same restrictions.
2. Update `firebase_options.dart` with the new key.
3. Deploy a new app build.
4. Delete the old key after the new build is live.

## References

- [Firebase API key best practices](https://firebase.google.com/docs/projects/api-keys)
- [GCP API key restrictions](https://cloud.google.com/docs/authentication/api-keys#securing)
- [Firebase App Check](https://firebase.google.com/docs/app-check)
