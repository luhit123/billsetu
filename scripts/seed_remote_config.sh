#!/bin/bash
# Seed all Remote Config parameters for BillRaja (billeasy-3a6ad)
# Usage: bash scripts/seed_remote_config.sh

set -e

PROJECT_ID="billeasy-3a6ad"

echo "Getting access token..."
ACCESS_TOKEN=$(firebase login:ci --no-localhost 2>/dev/null || true)

# Use gcloud if available, otherwise firebase auth
if command -v gcloud &> /dev/null; then
  ACCESS_TOKEN=$(gcloud auth print-access-token 2>/dev/null || true)
fi

if [ -z "$ACCESS_TOKEN" ]; then
  # Try to get token from firebase tools
  ACCESS_TOKEN=$(npx firebase-tools login:ci 2>/dev/null || true)
fi

# Fallback: use the firebase admin approach
echo "Fetching current Remote Config ETag..."
RESPONSE=$(curl -s -D - \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  "https://firebaseremoteconfig.googleapis.com/v1/projects/${PROJECT_ID}/remoteConfig")

ETAG=$(echo "$RESPONSE" | grep -i "etag:" | tr -d '\r' | awk '{print $2}')

if [ -z "$ETAG" ]; then
  echo "Could not fetch ETag. Make sure you're logged in with: gcloud auth login"
  echo "Or: gcloud auth application-default login"
  exit 1
fi

echo "Got ETag: $ETAG"
echo "Publishing 40 Remote Config parameters..."

HTTP_CODE=$(curl -s -o /tmp/rc_response.json -w "%{http_code}" \
  -X PUT \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json; UTF8" \
  -H "If-Match: $ETAG" \
  "https://firebaseremoteconfig.googleapis.com/v1/projects/${PROJECT_ID}/remoteConfig" \
  -d '{
  "parameters": {
    "min_supported_version": {
      "defaultValue": { "value": "1.0.0" },
      "description": "Minimum app version required. Users below this see force-update screen.",
      "valueType": "STRING"
    },
    "force_update_enabled": {
      "defaultValue": { "value": "false" },
      "description": "Enable force-update screen for old app versions.",
      "valueType": "BOOLEAN"
    },
    "force_update_title": {
      "defaultValue": { "value": "Update Required" },
      "description": "Title shown on force-update screen.",
      "valueType": "STRING"
    },
    "force_update_message": {
      "defaultValue": { "value": "A new version of BillRaja is available. Please update to continue using the app." },
      "description": "Message shown on force-update screen.",
      "valueType": "STRING"
    },
    "force_update_store_url": {
      "defaultValue": { "value": "https://play.google.com/store/apps/details?id=com.luhit.billeasy" },
      "description": "Play Store URL for force-update button.",
      "valueType": "STRING"
    },
    "maintenance_enabled": {
      "defaultValue": { "value": "false" },
      "description": "Enable maintenance mode (blocks entire app).",
      "valueType": "BOOLEAN"
    },
    "maintenance_title": {
      "defaultValue": { "value": "Under Maintenance" },
      "description": "Title shown during maintenance.",
      "valueType": "STRING"
    },
    "maintenance_message": {
      "defaultValue": { "value": "We are performing scheduled maintenance. We will be back shortly!" },
      "description": "Message shown during maintenance.",
      "valueType": "STRING"
    },
    "expired_max_invoices": {
      "defaultValue": { "value": "5" },
      "description": "Free plan: max invoices per month.",
      "valueType": "NUMBER"
    },
    "expired_max_customers": {
      "defaultValue": { "value": "5" },
      "description": "Free plan: max total customers.",
      "valueType": "NUMBER"
    },
    "expired_max_products": {
      "defaultValue": { "value": "20" },
      "description": "Free plan: max total products.",
      "valueType": "NUMBER"
    },
    "expired_max_pdf_templates": {
      "defaultValue": { "value": "1" },
      "description": "Free plan: number of unlocked PDF templates.",
      "valueType": "NUMBER"
    },
    "expired_max_whatsapp_shares": {
      "defaultValue": { "value": "0" },
      "description": "Free plan: WhatsApp shares per month (0 = disabled).",
      "valueType": "NUMBER"
    },
    "expired_has_reports": {
      "defaultValue": { "value": "false" },
      "description": "Free plan: access to Reports & Analytics.",
      "valueType": "BOOLEAN"
    },
    "expired_has_purchase_orders": {
      "defaultValue": { "value": "false" },
      "description": "Free plan: access to Purchase Orders.",
      "valueType": "BOOLEAN"
    },
    "expired_has_data_export": {
      "defaultValue": { "value": "false" },
      "description": "Free plan: access to CSV data export.",
      "valueType": "BOOLEAN"
    },
    "pro_max_invoices": {
      "defaultValue": { "value": "-1" },
      "description": "Pro plan: max invoices per month (-1 = unlimited).",
      "valueType": "NUMBER"
    },
    "pro_max_customers": {
      "defaultValue": { "value": "-1" },
      "description": "Pro plan: max total customers (-1 = unlimited).",
      "valueType": "NUMBER"
    },
    "pro_max_products": {
      "defaultValue": { "value": "-1" },
      "description": "Pro plan: max total products (-1 = unlimited).",
      "valueType": "NUMBER"
    },
    "pro_max_pdf_templates": {
      "defaultValue": { "value": "-1" },
      "description": "Pro plan: number of unlocked PDF templates (-1 = all).",
      "valueType": "NUMBER"
    },
    "pro_max_whatsapp_shares": {
      "defaultValue": { "value": "-1" },
      "description": "Pro plan: WhatsApp shares per month (-1 = unlimited).",
      "valueType": "NUMBER"
    },
    "pro_has_reports": {
      "defaultValue": { "value": "true" },
      "description": "Pro plan: access to Reports & Analytics.",
      "valueType": "BOOLEAN"
    },
    "pro_has_purchase_orders": {
      "defaultValue": { "value": "true" },
      "description": "Pro plan: access to Purchase Orders.",
      "valueType": "BOOLEAN"
    },
    "pro_has_data_export": {
      "defaultValue": { "value": "true" },
      "description": "Pro plan: access to CSV data export.",
      "valueType": "BOOLEAN"
    },
    "pro_price_monthly": {
      "defaultValue": { "value": "99" },
      "description": "Pro monthly price in INR (incl 18% GST).",
      "valueType": "NUMBER"
    },
    "pro_price_annual": {
      "defaultValue": { "value": "999" },
      "description": "Pro annual price in INR (incl 18% GST).",
      "valueType": "NUMBER"
    },
    "trial_duration_months": {
      "defaultValue": { "value": "6" },
      "description": "Number of months for the free trial period.",
      "valueType": "NUMBER"
    },
    "grace_period_days": {
      "defaultValue": { "value": "7" },
      "description": "Days of grace period after payment failure before downgrade.",
      "valueType": "NUMBER"
    },
    "review_session_threshold": {
      "defaultValue": { "value": "5" },
      "description": "App sessions before prompting for review.",
      "valueType": "NUMBER"
    },
    "review_invoice_threshold": {
      "defaultValue": { "value": "3" },
      "description": "Invoices created before prompting for review.",
      "valueType": "NUMBER"
    },
    "feature_purchase_orders": {
      "defaultValue": { "value": "true" },
      "description": "GLOBAL KILL SWITCH: Disable Purchase Orders for ALL users.",
      "valueType": "BOOLEAN"
    },
    "feature_reports": {
      "defaultValue": { "value": "true" },
      "description": "GLOBAL KILL SWITCH: Disable Reports for ALL users.",
      "valueType": "BOOLEAN"
    },
    "feature_data_export": {
      "defaultValue": { "value": "true" },
      "description": "GLOBAL KILL SWITCH: Disable Data Export for ALL users.",
      "valueType": "BOOLEAN"
    },
    "feature_whatsapp_share": {
      "defaultValue": { "value": "true" },
      "description": "GLOBAL KILL SWITCH: Disable WhatsApp Sharing for ALL users.",
      "valueType": "BOOLEAN"
    },
    "feature_membership": {
      "defaultValue": { "value": "true" },
      "description": "GLOBAL KILL SWITCH: Disable Membership Management for ALL users.",
      "valueType": "BOOLEAN"
    },
    "feature_qr_attendance": {
      "defaultValue": { "value": "true" },
      "description": "GLOBAL KILL SWITCH: Disable QR Attendance for ALL users.",
      "valueType": "BOOLEAN"
    },
    "upgrade_title": {
      "defaultValue": { "value": "Upgrade to Pro" },
      "description": "Upgrade screen header title.",
      "valueType": "STRING"
    },
    "upgrade_cta_text": {
      "defaultValue": { "value": "Upgrade to Pro" },
      "description": "Upgrade screen CTA button text.",
      "valueType": "STRING"
    },
    "upgrade_features_json": {
      "defaultValue": { "value": "[{\"icon\":\"receipt_long\",\"label\":\"Unlimited Invoices\"},{\"icon\":\"people\",\"label\":\"Unlimited Customers\"},{\"icon\":\"inventory_2\",\"label\":\"Unlimited Products\"},{\"icon\":\"picture_as_pdf\",\"label\":\"20 PDF Templates\"},{\"icon\":\"chat\",\"label\":\"Unlimited WhatsApp Sharing\"},{\"icon\":\"shopping_cart\",\"label\":\"Purchase Orders\"},{\"icon\":\"bar_chart\",\"label\":\"Reports & Analytics\"},{\"icon\":\"download\",\"label\":\"Data Export\"},{\"icon\":\"palette\",\"label\":\"Custom Branding\"}]" },
      "description": "Pro features list (JSON array with icon + label).",
      "valueType": "JSON"
    },
    "plan_comparison_json": {
      "defaultValue": { "value": "[{\"icon\":\"receipt_long\",\"label\":\"Invoices\",\"free\":\"5/month\",\"pro\":\"Unlimited\"},{\"icon\":\"people\",\"label\":\"Customers\",\"free\":\"5\",\"pro\":\"Unlimited\"},{\"icon\":\"inventory_2\",\"label\":\"Products & Inventory\",\"free\":\"20\",\"pro\":\"Unlimited\"},{\"icon\":\"picture_as_pdf\",\"label\":\"PDF Templates\",\"free\":\"1\",\"pro\":\"All 20+\"},{\"icon\":\"currency_rupee\",\"label\":\"GST Invoicing\",\"free\":true,\"pro\":true},{\"icon\":\"qr_code\",\"label\":\"UPI Payment Links & QR\",\"free\":true,\"pro\":true},{\"icon\":\"language\",\"label\":\"Multi-language Support\",\"free\":true,\"pro\":true},{\"icon\":\"cloud_off\",\"label\":\"Offline Mode\",\"free\":true,\"pro\":true},{\"icon\":\"badge\",\"label\":\"Digital Business Card\",\"free\":true,\"pro\":true},{\"icon\":\"chat\",\"label\":\"WhatsApp Sharing\",\"free\":false,\"pro\":true},{\"icon\":\"shopping_cart\",\"label\":\"Purchase Orders\",\"free\":false,\"pro\":true},{\"icon\":\"bar_chart\",\"label\":\"Reports & Analytics\",\"free\":false,\"pro\":true},{\"icon\":\"assessment\",\"label\":\"GST Reports & GSTR-3B\",\"free\":false,\"pro\":true},{\"icon\":\"card_membership\",\"label\":\"Membership Management\",\"free\":false,\"pro\":true},{\"icon\":\"qr_code_scanner\",\"label\":\"QR Attendance\",\"free\":false,\"pro\":true},{\"icon\":\"download\",\"label\":\"Data Export (CSV)\",\"free\":false,\"pro\":true},{\"icon\":\"palette\",\"label\":\"Custom Branding & Logo\",\"free\":false,\"pro\":true}]" },
      "description": "Free vs Pro comparison table (JSON). Each: icon, label, free (string/bool), pro (string/bool).",
      "valueType": "JSON"
    },
    "promo_banner_enabled": {
      "defaultValue": { "value": "false" },
      "description": "Show promotional banner on upgrade screen.",
      "valueType": "BOOLEAN"
    },
    "promo_banner_text": {
      "defaultValue": { "value": "" },
      "description": "Promo banner message text.",
      "valueType": "STRING"
    },
    "promo_banner_color": {
      "defaultValue": { "value": "#0057FF" },
      "description": "Promo banner accent color (hex).",
      "valueType": "STRING"
    },
    "enabled_languages": {
      "defaultValue": { "value": "" },
      "description": "Comma-separated enabled languages (empty = all). e.g. english,hindi,tamil",
      "valueType": "STRING"
    }
  },
  "conditions": []
}')

echo ""
if [ "$HTTP_CODE" = "200" ]; then
  echo "All 40 parameters published to Remote Config!"
  echo "Go to Firebase Console > Remote Config to edit them."
else
  echo "Failed with HTTP $HTTP_CODE:"
  cat /tmp/rc_response.json
  echo ""
  echo ""
  echo "If auth failed, run: gcloud auth application-default login"
fi

rm -f /tmp/rc_response.json
