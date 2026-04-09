#!/usr/bin/env node
/**
 * Migration: Seed the denormalized membershipStats/current doc for each owner.
 *
 * WHY:  Fix P-1 added a syncMembershipStats trigger that maintains a
 *       denormalized stats doc on every member write. But existing owners
 *       won't have this doc until one of their members is next updated.
 *       This script computes stats for every owner and writes the doc
 *       so the dashboard fast-path works immediately after deploy.
 *
 * WHAT: For each user with a 'members' subcollection, counts active/expired/
 *       frozen/cancelled members, sums revenue, counts expiring-this-week,
 *       and writes to users/{uid}/membershipStats/current.
 *
 * SAFE: Purely additive. The Cloud Function trigger will overwrite this doc
 *       on the next member update, so any staleness is temporary.
 *
 * RUN:  node scripts/migrate_seed_membership_stats.js
 *
 * IDEMPOTENT: Yes — re-running overwrites the stats doc with fresh counts.
 */

const admin = require('firebase-admin');

if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();
const { FieldValue } = admin.firestore;

async function main() {
  console.log('=== Seed membershipStats/current for all owners ===\n');

  const usersSnap = await db.collection('users').get();
  console.log(`Found ${usersSnap.size} user documents.\n`);

  let seeded = 0;
  let skipped = 0;

  for (const userDoc of usersSnap.docs) {
    const uid = userDoc.id;
    const membersSnap = await db
      .collection('users').doc(uid).collection('members')
      .where('isDeleted', '==', false)
      .get();

    if (membersSnap.empty) {
      skipped++;
      continue;
    }

    const now = new Date();
    const weekFromNow = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);

    let totalMembers = 0;
    let active = 0;
    let expired = 0;
    let frozen = 0;
    let cancelled = 0;
    let expiringThisWeek = 0;
    let totalRevenue = 0;

    for (const doc of membersSnap.docs) {
      const d = doc.data();
      totalMembers++;

      const status = d.status || 'active';
      const endDate = d.endDate ? d.endDate.toDate() : now;
      const amountPaid = typeof d.amountPaid === 'number' ? d.amountPaid : 0;
      const joiningFeePaid = typeof d.joiningFeePaid === 'number' ? d.joiningFeePaid : 0;

      totalRevenue += amountPaid + joiningFeePaid;

      if (status === 'cancelled') {
        cancelled++;
      } else if (status === 'frozen') {
        frozen++;
      } else if (status === 'expired' || endDate < now) {
        expired++;
      } else {
        active++;
        if (endDate <= weekFromNow) {
          expiringThisWeek++;
        }
      }
    }

    const statsRef = db
      .collection('users').doc(uid)
      .collection('membershipStats').doc('current');

    await statsRef.set({
      totalMembers,
      active,
      expired,
      frozen,
      cancelled,
      expiringThisWeek,
      totalRevenue,
      updatedAt: FieldValue.serverTimestamp(),
    });

    seeded++;
    console.log(`  [${uid}] ${totalMembers} members → active:${active} expired:${expired} frozen:${frozen} cancelled:${cancelled} revenue:${totalRevenue.toFixed(2)}`);
  }

  console.log('\n=== Seeding Complete ===');
  console.log(`  Seeded:  ${seeded} owners`);
  console.log(`  Skipped: ${skipped} (no members)`);
  console.log('\nDashboard fast-path is now active for all existing owners.');
}

main().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
