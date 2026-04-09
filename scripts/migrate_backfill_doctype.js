#!/usr/bin/env node
/**
 * Migration: Backfill docType on existing membership member documents.
 *
 * WHY:  Fix S-1 added a `docType: 'membership_member'` field to new members
 *       so that the syncMembershipStates collectionGroup query only touches
 *       membership docs (not team member docs that share the same "members"
 *       collection name). Existing docs created before the fix don't have
 *       this field yet, so they'd be invisible to the scheduled function.
 *
 * WHAT: Reads every doc under users/{uid}/members where docType is missing,
 *       and sets docType = 'membership_member' via batched writes.
 *
 * SAFE: This is purely additive — it only sets a new field. It does NOT
 *       modify any existing fields, delete anything, or change behavior
 *       for documents that already have the field.
 *
 * RUN:  node scripts/migrate_backfill_doctype.js
 *       (from the project root, with GOOGLE_APPLICATION_CREDENTIALS set
 *        or run inside the Firebase emulator shell)
 *
 * IDEMPOTENT: Yes — re-running is safe. It skips docs that already have docType.
 */

const admin = require('firebase-admin');

// Initialize — uses default credentials (ADC / service account / emulator)
if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

const BATCH_LIMIT = 400; // Firestore max is 500; leave headroom

async function main() {
  console.log('=== Backfill docType on membership member docs ===\n');

  // Step 1: Get all user docs (owners who might have members)
  const usersSnap = await db.collection('users').get();
  console.log(`Found ${usersSnap.size} user documents.\n`);

  let totalUpdated = 0;
  let totalSkipped = 0;
  let totalErrors = 0;

  for (const userDoc of usersSnap.docs) {
    const uid = userDoc.id;
    const membersRef = db.collection('users').doc(uid).collection('members');
    const membersSnap = await membersRef.get();

    if (membersSnap.empty) continue;

    let batch = db.batch();
    let batchCount = 0;
    let updatedForUser = 0;

    for (const memberDoc of membersSnap.docs) {
      const data = memberDoc.data();

      // Skip if already backfilled
      if (data.docType === 'membership_member') {
        totalSkipped++;
        continue;
      }

      // Skip if this looks like a team member doc (has 'role' field but no 'planId')
      // Safety check: membership members always have planId; team members have role
      if (data.role && !data.planId) {
        totalSkipped++;
        continue;
      }

      batch.update(memberDoc.ref, { docType: 'membership_member' });
      batchCount++;
      updatedForUser++;

      if (batchCount >= BATCH_LIMIT) {
        await batch.commit();
        console.log(`  [${uid}] Committed batch of ${batchCount}`);
        batch = db.batch();
        batchCount = 0;
      }
    }

    // Commit remaining
    if (batchCount > 0) {
      try {
        await batch.commit();
        totalUpdated += updatedForUser;
        console.log(`  [${uid}] Updated ${updatedForUser} member docs`);
      } catch (err) {
        totalErrors++;
        console.error(`  [${uid}] ERROR committing batch: ${err.message}`);
      }
    } else {
      totalUpdated += updatedForUser;
    }
  }

  console.log('\n=== Migration Complete ===');
  console.log(`  Updated:  ${totalUpdated}`);
  console.log(`  Skipped:  ${totalSkipped} (already had docType or not membership docs)`);
  console.log(`  Errors:   ${totalErrors}`);
  console.log('\nNext step: Deploy indexes, then deploy functions.');
}

main().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
