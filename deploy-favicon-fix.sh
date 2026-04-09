#!/bin/bash
# Deploy favicon & SEO fixes to Firebase Hosting
# Run this from the billeasy project root

set -e

echo "🔨 Building Flutter web app..."
flutter build web --release

echo ""
echo "📋 Copying new favicon files to build/web..."
# Copy all the new favicon files that aren't part of Flutter's build
cp web/favicon.ico build/web/
cp web/favicon.svg build/web/
cp web/favicon-16x16.png build/web/
cp web/favicon-32x32.png build/web/
cp web/favicon-48x48.png build/web/
cp web/favicon-96x96.png build/web/
cp web/favicon-144x144.png build/web/
cp web/favicon-180x180.png build/web/
cp web/favicon-384x384.png build/web/
cp web/apple-touch-icon.png build/web/

# Copy new icon sizes
cp web/icons/Icon-48.png build/web/icons/
cp web/icons/Icon-96.png build/web/icons/
cp web/icons/Icon-144.png build/web/icons/
cp web/icons/Icon-384.png build/web/icons/

echo "✅ All favicon files copied to build/web"

echo ""
echo "🚀 Deploying to Firebase Hosting (app target)..."
firebase deploy --only hosting:app

echo ""
echo "🎉 Done! Your favicon fixes are now live."
echo "➡️  Next step: Go to Google Search Console → URL Inspection"
echo "   Enter https://billraja.com/ → Click REQUEST INDEXING"
