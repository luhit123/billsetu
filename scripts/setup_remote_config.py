#!/usr/bin/env python3
"""
One-time script to set all Firebase Remote Config defaults for BillRaja.
Usage:
  1. Download your Firebase service account key from:
     Firebase Console → Project Settings → Service Accounts → Generate new private key
  2. Save it as 'service_account.json' in the same folder as this script
  3. Run: python3 setup_remote_config.py
"""

import json
import sys
import urllib.request
import urllib.error

# ── Config ──────────────────────────────────────────────────────────────────
PROJECT_ID = "billeasy-3a6ad"
SERVICE_ACCOUNT_FILE = "scripts/service_account.json"

# ── Remote Config parameters (mirrors _defaults in remote_config_service.dart)
PARAMETERS = {
    # Force update / maintenance
    "min_supported_version":    {"defaultValue": {"value": "1.0.0"},          "valueType": "STRING"},
    "force_update_enabled":     {"defaultValue": {"value": "false"},          "valueType": "BOOLEAN"},
    "force_update_title":       {"defaultValue": {"value": "Update Required"},"valueType": "STRING"},
    "force_update_message":     {"defaultValue": {"value": "A new version of BillRaja is available. Please update to continue using the app."}, "valueType": "STRING"},
    "force_update_store_url":   {"defaultValue": {"value": "https://play.google.com/store/apps/details?id=com.luhit.billeasy"}, "valueType": "STRING"},
    "maintenance_enabled":      {"defaultValue": {"value": "false"},          "valueType": "BOOLEAN"},
    "maintenance_title":        {"defaultValue": {"value": "Under Maintenance"},"valueType": "STRING"},
    "maintenance_message":      {"defaultValue": {"value": "We're performing scheduled maintenance. We'll be back shortly!"}, "valueType": "STRING"},

    # Plan limits — expired
    "expired_max_invoices":       {"defaultValue": {"value": "5"},   "valueType": "NUMBER"},
    "expired_max_customers":      {"defaultValue": {"value": "5"},   "valueType": "NUMBER"},
    "expired_max_products":       {"defaultValue": {"value": "20"},  "valueType": "NUMBER"},
    "expired_max_pdf_templates":  {"defaultValue": {"value": "1"},   "valueType": "NUMBER"},
    "expired_max_whatsapp_shares":{"defaultValue": {"value": "0"},   "valueType": "NUMBER"},
    "expired_has_reports":        {"defaultValue": {"value": "false"},"valueType": "BOOLEAN"},
    "expired_has_eway_bill":      {"defaultValue": {"value": "false"},"valueType": "BOOLEAN"},
    "expired_has_purchase_orders":{"defaultValue": {"value": "false"},"valueType": "BOOLEAN"},
    "expired_has_data_export":    {"defaultValue": {"value": "false"},"valueType": "BOOLEAN"},

    # Plan limits — pro
    "pro_max_invoices":       {"defaultValue": {"value": "-1"},  "valueType": "NUMBER"},
    "pro_max_customers":      {"defaultValue": {"value": "-1"},  "valueType": "NUMBER"},
    "pro_max_products":       {"defaultValue": {"value": "-1"},  "valueType": "NUMBER"},
    "pro_max_pdf_templates":  {"defaultValue": {"value": "-1"},  "valueType": "NUMBER"},
    "pro_max_whatsapp_shares":{"defaultValue": {"value": "-1"},  "valueType": "NUMBER"},
    "pro_has_reports":        {"defaultValue": {"value": "true"},"valueType": "BOOLEAN"},
    "pro_has_eway_bill":      {"defaultValue": {"value": "true"},"valueType": "BOOLEAN"},
    "pro_has_purchase_orders":{"defaultValue": {"value": "true"},"valueType": "BOOLEAN"},
    "pro_has_data_export":    {"defaultValue": {"value": "true"},"valueType": "BOOLEAN"},

    # Pricing
    "pro_price_monthly": {"defaultValue": {"value": "129.0"}, "valueType": "NUMBER"},
    "pro_price_annual":  {"defaultValue": {"value": "999.0"}, "valueType": "NUMBER"},

    # Review triggers
    "review_session_threshold": {"defaultValue": {"value": "5"}, "valueType": "NUMBER"},
    "review_invoice_threshold": {"defaultValue": {"value": "3"}, "valueType": "NUMBER"},

    # Feature flags
    "feature_eway_bill":       {"defaultValue": {"value": "true"}, "valueType": "BOOLEAN"},
    "feature_purchase_orders": {"defaultValue": {"value": "true"}, "valueType": "BOOLEAN"},
    "feature_reports":         {"defaultValue": {"value": "true"}, "valueType": "BOOLEAN"},
    "feature_data_export":     {"defaultValue": {"value": "true"}, "valueType": "BOOLEAN"},
    "feature_whatsapp_share":  {"defaultValue": {"value": "true"}, "valueType": "BOOLEAN"},
    "feature_membership":      {"defaultValue": {"value": "true"}, "valueType": "BOOLEAN"},
    "feature_qr_attendance":   {"defaultValue": {"value": "true"}, "valueType": "BOOLEAN"},

    # Upgrade screen
    "upgrade_title":    {"defaultValue": {"value": "Upgrade to Pro"}, "valueType": "STRING"},
    "upgrade_cta_text": {"defaultValue": {"value": "Upgrade to Pro"}, "valueType": "STRING"},
    "upgrade_features_json": {
        "defaultValue": {"value": '[{"icon":"receipt_long","label":"Unlimited Invoices"},{"icon":"people","label":"Unlimited Customers"},{"icon":"inventory_2","label":"Unlimited Products"},{"icon":"picture_as_pdf","label":"20 PDF Templates"},{"icon":"chat","label":"Unlimited WhatsApp Sharing"},{"icon":"shopping_cart","label":"Purchase Orders"},{"icon":"bar_chart","label":"Reports & Analytics"},{"icon":"local_shipping","label":"E-Way Bill"},{"icon":"download","label":"Data Export"},{"icon":"palette","label":"Custom Branding"}]'},
        "valueType": "JSON"
    },

    # Promo banner
    "promo_banner_enabled": {"defaultValue": {"value": "false"},   "valueType": "BOOLEAN"},
    "promo_banner_text":    {"defaultValue": {"value": ""},        "valueType": "STRING"},
    "promo_banner_color":   {"defaultValue": {"value": "#0057FF"}, "valueType": "STRING"},

    # Language control (empty = all 23 languages enabled)
    "enabled_languages": {"defaultValue": {"value": ""}, "valueType": "STRING"},
}


def get_access_token(service_account_file):
    """Get OAuth2 access token using service account credentials."""
    try:
        import google.auth
        import google.auth.transport.requests
        from google.oauth2 import service_account

        credentials = service_account.Credentials.from_service_account_file(
            service_account_file,
            scopes=["https://www.googleapis.com/auth/firebase.remoteconfig"]
        )
        request = google.auth.transport.requests.Request()
        credentials.refresh(request)
        return credentials.token

    except ImportError:
        print("❌ Missing dependency. Run: pip install google-auth")
        sys.exit(1)


def get_current_etag(token):
    url = f"https://firebaseremoteconfig.googleapis.com/v1/projects/{PROJECT_ID}/remoteConfig"
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    try:
        with urllib.request.urlopen(req) as resp:
            return resp.headers.get("ETag", "*")
    except:
        return "*"


def push_remote_config(token, etag):
    url = f"https://firebaseremoteconfig.googleapis.com/v1/projects/{PROJECT_ID}/remoteConfig"
    body = json.dumps({"parameters": PARAMETERS}).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=body,
        method="PUT",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json; UTF-8",
            "If-Match": etag,
        }
    )
    try:
        with urllib.request.urlopen(req) as resp:
            return resp.status, resp.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()


def main():
    print(f"🔧 Setting up Firebase Remote Config for project: {PROJECT_ID}")
    print(f"📂 Reading service account from: {SERVICE_ACCOUNT_FILE}\n")

    token = get_access_token(SERVICE_ACCOUNT_FILE)
    print("✅ Got access token")

    etag = get_current_etag(token)
    print(f"✅ Current ETag: {etag}")

    print(f"⬆️  Pushing {len(PARAMETERS)} parameters...")
    status, body = push_remote_config(token, etag)

    if status == 200:
        print(f"\n✅ SUCCESS! All {len(PARAMETERS)} Remote Config parameters set.")
        print("   Go to Firebase Console → Remote Config to verify.")
    else:
        print(f"\n❌ Failed with status {status}")
        print(body)


if __name__ == "__main__":
    main()
