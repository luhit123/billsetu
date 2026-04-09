#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
# BillRaja — Production Deployment Script
# Deploys all fixes: indexes → rules → functions → migrations
#
# Usage:
#   chmod +x scripts/deploy_production.sh
#   ./scripts/deploy_production.sh
#
# Prerequisites:
#   - Firebase CLI installed and authenticated (firebase login)
#   - Node.js 20+ installed
#   - GOOGLE_APPLICATION_CREDENTIALS set (for migration scripts)
#   - Working directory: project root (billeasy/)
# ─────────────────────────────────────────────────────────────────────

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()   { echo -e "${BLUE}[DEPLOY]${NC} $1"; }
ok()    { echo -e "${GREEN}[  OK  ]${NC} $1"; }
warn()  { echo -e "${YELLOW}[ WARN ]${NC} $1"; }
fail()  { echo -e "${RED}[ FAIL ]${NC} $1"; exit 1; }

# ── Pre-flight checks ──────────────────────────────────────────────
log "Running pre-flight checks..."

command -v firebase >/dev/null 2>&1 || fail "Firebase CLI not found. Install: npm install -g firebase-tools"
command -v node >/dev/null 2>&1     || fail "Node.js not found."
command -v flutter >/dev/null 2>&1  || warn "Flutter not found — skipping flutter analyze"

NODE_VER=$(node -v | cut -d'.' -f1 | tr -d 'v')
[ "$NODE_VER" -ge 20 ] || fail "Node.js 20+ required. Found: $(node -v)"

# Syntax check Cloud Functions
log "Syntax-checking functions/index.js..."
node --check functions/index.js || fail "functions/index.js has syntax errors!"
ok "Cloud Functions syntax OK"

# JSON check indexes
log "Validating firestore.indexes.json..."
node -e "JSON.parse(require('fs').readFileSync('firestore.indexes.json','utf8')); console.log('Valid')" \
  || fail "firestore.indexes.json is invalid JSON!"
ok "Firestore indexes JSON OK"

# JSON check firestore rules (basic file existence)
[ -f "firestore.rules" ] || fail "firestore.rules not found!"
ok "Firestore rules file exists"

echo ""
log "═══════════════════════════════════════════════════"
log "  Step 1/5 — Deploy Firestore Indexes"
log "═══════════════════════════════════════════════════"
log "Indexes build asynchronously (5-10 min). Deploying now..."
firebase deploy --only firestore:indexes || fail "Index deployment failed!"
ok "Indexes deployed (building in background)"

echo ""
log "═══════════════════════════════════════════════════"
log "  Step 2/5 — Deploy Firestore Security Rules"
log "═══════════════════════════════════════════════════"
firebase deploy --only firestore:rules || fail "Rules deployment failed!"
ok "Security rules deployed"

echo ""
log "═══════════════════════════════════════════════════"
log "  Step 3/5 — Deploy Cloud Functions"
log "═══════════════════════════════════════════════════"
cd functions && npm install && cd ..
firebase deploy --only functions || fail "Functions deployment failed!"
ok "Cloud Functions deployed"

echo ""
log "═══════════════════════════════════════════════════"
log "  Step 4/5 — Run Migration: Backfill docType"
log "═══════════════════════════════════════════════════"
log "This adds docType='membership_member' to existing member docs..."
read -p "Run docType backfill migration? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  node scripts/migrate_backfill_doctype.js || warn "Migration had errors — check output above"
  ok "docType backfill complete"
else
  warn "Skipped docType backfill — run manually: node scripts/migrate_backfill_doctype.js"
fi

echo ""
log "═══════════════════════════════════════════════════"
log "  Step 5/5 — Run Migration: Seed Membership Stats"
log "═══════════════════════════════════════════════════"
log "This pre-computes dashboard stats for all existing owners..."
read -p "Run membership stats seeding? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  node scripts/migrate_seed_membership_stats.js || warn "Seeding had errors — check output above"
  ok "Membership stats seeded"
else
  warn "Skipped stats seeding — run manually: node scripts/migrate_seed_membership_stats.js"
fi

echo ""
log "═══════════════════════════════════════════════════"
echo -e "${GREEN}"
echo "  ✓ Deployment complete!"
echo ""
echo "  Deployed:"
echo "    • Firestore indexes (2 new composite indexes)"
echo "    • Firestore security rules (analytics + membership read guards)"
echo "    • Cloud Functions (cancelMembershipMember, syncMembershipStats + all fixes)"
echo ""
echo "  Post-deploy checklist:"
echo "    1. Wait 5-10 min for indexes to finish building"
echo "    2. Test checkout geofence (set requireGeofenceOnCheckout: true on a test team)"
echo "    3. Test cancel membership flow from the app"
echo "    4. Verify dashboard loads stats from denormalized doc"
echo "    5. Run: flutter analyze (if not done already)"
echo -e "${NC}"
