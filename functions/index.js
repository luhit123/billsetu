const admin = require('firebase-admin');
const logger = require('firebase-functions/logger');
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentWritten, onDocumentDeleted, onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');

admin.initializeApp();

const db = admin.firestore();
const { FieldValue, Timestamp } = admin.firestore;

const INDIA_TIME_ZONE = 'Asia/Kolkata';
const DEFAULT_DUE_DAYS = 30;
const INVOICE_PREFIX = 'BR';
const COUNTERS_COLLECTION = 'invoiceNumberCounters';

// ── Trial setup: when a new user doc is created, set trialExpiresAt ──────────
exports.setupUserTrial = onDocumentCreated('users/{uid}', async (event) => {
  const uid = event.params.uid;
  const data = event.data && event.data.data();
  if (!data) return;

  // Only set trialExpiresAt if not already present
  if (data.trialExpiresAt) return;

  const createdAt = data.createdAt ? data.createdAt.toDate() : new Date();
  const trialExpiresAt = new Date(createdAt);
  trialExpiresAt.setMonth(trialExpiresAt.getMonth() + 6);

  await db.collection('users').doc(uid).update({
    trialExpiresAt: Timestamp.fromDate(trialExpiresAt),
  });

  logger.info('Trial set up for new user', { uid, trialExpiresAt: trialExpiresAt.toISOString() });
});

// Keep one warm instance to eliminate cold-start latency for this
// critical user-facing function called on every invoice creation.
exports.reserveInvoiceNumber = onCall({ minInstances: 1 }, async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in is required to reserve invoice numbers.');
  }

  const requestedYear = parseYear(request.data && request.data.year);
  const counterRef = db
    .collection(COUNTERS_COLLECTION)
    .doc(uid)
    .collection('years')
    .doc(String(requestedYear));

  const reservation = await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(counterRef);
    const nextSequence = snapshot.exists && Number.isInteger(snapshot.data().nextSequence)
      ? snapshot.data().nextSequence
      : 1;
    const sequence = nextSequence;
    const invoiceNumber = formatInvoiceNumber(requestedYear, sequence);

    transaction.set(counterRef, {
      ownerId: uid,
      year: requestedYear,
      nextSequence: sequence + 1,
      lastReservedSequence: sequence,
      lastReservedInvoiceNumber: invoiceNumber,
      lastReservedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    return {
      invoiceNumber,
      sequence,
    };
  });

  logger.info('Reserved invoice number', {
    ownerId: uid,
    year: requestedYear,
    sequence: reservation.sequence,
    invoiceNumber: reservation.invoiceNumber,
  });

  return {
    ownerId: uid,
    year: requestedYear,
    prefix: INVOICE_PREFIX,
    sequence: reservation.sequence,
    invoiceNumber: reservation.invoiceNumber,
  };
});

// Fields that materially affect analytics calculations.
// Updates touching only metadata (e.g. updatedAt, searchPrefixes) are skipped
// to avoid running expensive aggregation on every cosmetic write.
const ANALYTICS_FIELDS = ['status', 'grandTotal', 'gstAmount', 'createdAt'];

// Fields written exclusively by this function during normalization.
// If ONLY these fields changed, the trigger is our own write-back — skip to prevent
// an infinite trigger loop.
const SELF_WRITTEN_FIELDS = new Set([
  'clientNameLower', 'searchPrefixes', 'subtotal', 'discountAmount',
  'taxableAmount', 'cgstAmount', 'sgstAmount', 'igstAmount', 'totalTax',
  'grandTotal', 'dueAt', 'financialTotalsVersion', 'derivedTotalsUpdatedAt',
]);

function analyticsFieldsChanged(beforeData, afterData) {
  if (!beforeData || !afterData) {
    // Document created or deleted — always process.
    return true;
  }

  return ANALYTICS_FIELDS.some((field) => {
    const left = beforeData[field];
    const right = afterData[field];
    return !valuesMatch(left, right);
  });
}

exports.syncInvoiceAnalytics = onDocumentWritten('invoices/{invoiceId}', async (event) => {
  try {
    const beforeData = event.data.before.exists ? event.data.before.data() : null;
    const afterData = event.data.after.exists ? event.data.after.data() : null;

    // Early exit: detect our own normalization write-back to prevent an infinite loop.
    // When this function writes derivedPatch back to the invoice, that write triggers this
    // function again. We detect self-writes by checking if ALL changed fields belong to the
    // set of fields we write during normalization — if so, there is nothing new to process.
    if (isSelfWrite(beforeData, afterData)) {
      logger.info('syncInvoiceAnalytics: skipping — self-write detected', {
        invoiceId: event.params.invoiceId,
      });
      return;
    }

    // Early exit: skip expensive aggregation when no analytics-relevant fields changed.
    if (!analyticsFieldsChanged(beforeData, afterData)) {
      logger.info('syncInvoiceAnalytics: skipping — no analytics-relevant fields changed', {
        invoiceId: event.params.invoiceId,
      });
      return;
    }

    const before = beforeData ? buildInvoiceRecord(beforeData, event.params.invoiceId) : null;
    const after = afterData ? buildInvoiceRecord(afterData, event.params.invoiceId) : null;

    if (after && invoiceNeedsNormalization(event.data.after.data(), after.derivedPatch)) {
      await event.data.after.ref.set({
        ...after.derivedPatch,
        derivedTotalsUpdatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    }

    await updateAnalyticsForWrite(before, after, event.params.invoiceId);
  } catch (err) {
    logger.error('syncInvoiceAnalytics: unhandled error', {
      invoiceId: event.params.invoiceId,
      error: err && err.message,
    });
  }
});

exports.cleanupInvoicesAfterClientDelete = onDocumentDeleted(
  'users/{ownerId}/clients/{clientId}',
  async (event) => {
    const ownerId = event.params.ownerId;
    const clientId = event.params.clientId;
    const deletedClient = event.data && event.data.data ? event.data.data() : null;
    const deletedClientName = safeString(
      deletedClient && deletedClient.name,
      deletedClient && deletedClient.fullName,
      clientId,
    );

    const invoicesSnapshot = await db
      .collection('invoices')
      .where('ownerId', '==', ownerId)
      .where('clientId', '==', clientId)
      .get();

    const writer = db.bulkWriter();
    let updatedCount = 0;

    invoicesSnapshot.forEach((doc) => {
      updatedCount += 1;
      writer.set(doc.ref, {
        clientId: '',
        clientDeleted: true,
        clientDeletedAt: FieldValue.serverTimestamp(),
        orphanedClientId: clientId,
        orphanedClientName: deletedClientName,
      }, { merge: true });
    });

    await writer.close();

    logger.info('Cleaned invoices after client delete', {
      ownerId,
      clientId,
      deletedClientName,
      updatedCount,
    });
  },
);

// ══════════════════════════════════════════════════════════════════════════════
// PURCHASE ORDER → INPUT GST ANALYTICS
// When a PO is written (status changed to received, or GST values change),
// recompute Input GST totals for the relevant period.
// ══════════════════════════════════════════════════════════════════════════════

exports.syncPurchaseOrderAnalytics = onDocumentWritten(
  'users/{ownerId}/purchaseOrders/{poId}',
  async (event) => {
    try {
      const ownerId = event.params.ownerId;
      const poId = event.params.poId;
      const beforeData = event.data.before.exists ? event.data.before.data() : null;
      const afterData = event.data.after.exists ? event.data.after.data() : null;

      // Only care about received POs with GST enabled
      const beforeRelevant = beforeData &&
        beforeData.status === 'received' &&
        beforeData.gstEnabled === true;
      const afterRelevant = afterData &&
        afterData.status === 'received' &&
        afterData.gstEnabled === true;

      // Skip if nothing changed from an input-GST perspective
      if (!beforeRelevant && !afterRelevant) {
        return;
      }

      // Build before/after input GST contributions
      const beforeInput = beforeRelevant ? buildPoInputGst(beforeData) : null;
      const afterInput = afterRelevant ? buildPoInputGst(afterData) : null;

      // Determine the date for period bucketing
      const afterDate = afterData ? parseDate(afterData.createdAt) : null;
      const beforeDate = beforeData ? parseDate(beforeData.createdAt) : null;

      const writes = [];

      // Subtract old contribution
      if (beforeInput && beforeDate) {
        const periods = buildInputGstPeriods(beforeDate, beforeInput, -1);
        for (const p of periods) {
          writes.push(writeInputGstPeriod(ownerId, p, poId));
        }
      }

      // Add new contribution
      if (afterInput && afterDate) {
        const periods = buildInputGstPeriods(afterDate, afterInput, 1);
        for (const p of periods) {
          writes.push(writeInputGstPeriod(ownerId, p, poId));
        }
      }

      await Promise.all(writes);

      logger.info('syncPurchaseOrderAnalytics: updated input GST', {
        ownerId,
        poId,
        beforeRelevant,
        afterRelevant,
      });
    } catch (err) {
      logger.error('syncPurchaseOrderAnalytics: error', {
        poId: event.params.poId,
        error: err && err.message,
      });
    }
  },
);

function buildPoInputGst(data) {
  const items = Array.isArray(data.items) ? data.items : [];
  const subtotal = roundMoney(items.reduce((s, i) => s + lineItemTotal(i), 0));
  const discountType = data.discountType || null;
  const discountValue = toNumber(data.discountValue);
  const discountAmount = roundMoney(computeDiscountAmount(subtotal, discountType, discountValue));
  const taxableAmount = roundMoney(Math.max(subtotal - discountAmount, 0));
  const gstType = normalizeGstType(data.gstType);
  const orderGstRate = toNumber(data.gstRate);

  // Per-item GST calculation (mirrors Dart model logic)
  const ratio = subtotal > 0 ? taxableAmount / subtotal : 0;
  let cgstAmount = 0;
  let igstAmount = 0;

  for (const item of items) {
    const itemTotal = lineItemTotal(item);
    // Use per-item rate if available, otherwise fall back to order-level rate
    let itemRate = toNumber(item.gstRate);
    if (itemRate === 0 && orderGstRate > 0) {
      itemRate = orderGstRate;
    }
    if (gstType === 'cgst_sgst') {
      cgstAmount += itemTotal * ratio * itemRate / 200;
    } else {
      igstAmount += itemTotal * ratio * itemRate / 100;
    }
  }

  cgstAmount = roundMoney(cgstAmount);
  const sgstAmount = cgstAmount;
  igstAmount = roundMoney(igstAmount);
  const totalTax = roundMoney(cgstAmount + sgstAmount + igstAmount);
  const grandTotal = roundMoney(taxableAmount + totalTax);

  return {
    taxableAmount,
    discountAmount,
    cgstAmount,
    sgstAmount,
    igstAmount,
    totalTax,
    grandTotal,
  };
}

function buildInputGstPeriods(date, input, sign) {
  const dateParts = getIndianDateParts(date);
  const monthKey = `${dateParts.year}-${padNumber(dateParts.month, 2)}`;
  const quarterNumber = Math.floor((dateParts.month - 1) / 3) + 1;
  const quarterKey = `${dateParts.year}-Q${quarterNumber}`;
  const yearKey = String(dateParts.year);

  const delta = {
    inputPoCount: sign * 1,
    inputTaxableAmount: sign * input.taxableAmount,
    inputDiscountAmount: sign * input.discountAmount,
    inputCgstAmount: sign * input.cgstAmount,
    inputSgstAmount: sign * input.sgstAmount,
    inputIgstAmount: sign * input.igstAmount,
    inputTotalTax: sign * input.totalTax,
    inputGrandTotal: sign * input.grandTotal,
  };

  return [
    { docId: `monthly_${monthKey}`, periodType: 'monthly', periodKey: monthKey, delta },
    { docId: `quarterly_${quarterKey}`, periodType: 'quarterly', periodKey: quarterKey, delta },
    { docId: `yearly_${yearKey}`, periodType: 'yearly', periodKey: yearKey, delta },
  ];
}

function writeInputGstPeriod(ownerId, period, poId) {
  const ref = db
    .collection('users')
    .doc(ownerId)
    .collection('analytics')
    .doc('gstSummaries')
    .collection('periods')
    .doc(period.docId);

  return ref.set({
    ownerId,
    docId: period.docId,
    periodType: period.periodType,
    periodKey: period.periodKey,
    inputPoCount: FieldValue.increment(period.delta.inputPoCount || 0),
    inputTaxableAmount: FieldValue.increment(period.delta.inputTaxableAmount || 0),
    inputDiscountAmount: FieldValue.increment(period.delta.inputDiscountAmount || 0),
    inputCgstAmount: FieldValue.increment(period.delta.inputCgstAmount || 0),
    inputSgstAmount: FieldValue.increment(period.delta.inputSgstAmount || 0),
    inputIgstAmount: FieldValue.increment(period.delta.inputIgstAmount || 0),
    inputTotalTax: FieldValue.increment(period.delta.inputTotalTax || 0),
    inputGrandTotal: FieldValue.increment(period.delta.inputGrandTotal || 0),
    updatedAt: FieldValue.serverTimestamp(),
    lastSyncedPoId: poId,
  }, { merge: true });
}

exports.markOverdueInvoices = onSchedule(
  {
    schedule: 'every day 02:30',
    timeZone: INDIA_TIME_ZONE,
  },
  async () => {
    const now = new Date();

    // Filter by dueDate < today at the query level so Firestore only returns
    // genuinely overdue invoices rather than every pending invoice across all
    // users. This dramatically reduces scan size as the dataset grows.
    // Requires a composite index on (status ASC, dueDate ASC).
    const today = Timestamp.fromDate(now);
    const pendingSnapshot = await db
      .collection('invoices')
      .where('status', '==', 'pending')
      .where('dueDate', '<', today)
      .get();

    const writer = db.bulkWriter();
    let overdueCount = 0;

    pendingSnapshot.forEach((doc) => {
      const data = doc.data();
      const dueAt = resolveDueAt(data);
      if (!dueAt || dueAt.getTime() > now.getTime()) {
        return;
      }

      overdueCount += 1;
      writer.update(doc.ref, {
        status: 'overdue',
        overdueMarkedAt: FieldValue.serverTimestamp(),
        overdueReason: 'scheduled_overdue_job',
      });
    });

    await writer.close();

    logger.info('Overdue scheduler completed', {
      overdueCount,
    });
  },
);

exports.backfillMyInvoiceData = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in is required to backfill invoice data.');
  }

  const invoicesSnapshot = await db
    .collection('invoices')
    .where('ownerId', '==', uid)
    .get();

  const invoiceWriter = db.bulkWriter();
  const records = [];
  let normalizedInvoices = 0;

  invoicesSnapshot.forEach((doc) => {
    const raw = doc.data();
    const record = buildInvoiceRecord(raw, doc.id);
    records.push(record);

    if (!invoiceNeedsNormalization(raw, record.derivedPatch)) {
      return;
    }

    normalizedInvoices += 1;
    invoiceWriter.set(doc.ref, {
      ...record.derivedPatch,
      derivedTotalsUpdatedAt: FieldValue.serverTimestamp(),
      financialTotalsBackfilledAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  });

  await invoiceWriter.close();

  const analyticsSnapshot = buildOwnerAnalyticsSnapshot(records);
  await replaceOwnerAnalytics(uid, analyticsSnapshot);

  logger.info('Completed invoice backfill', {
    ownerId: uid,
    invoiceCount: records.length,
    normalizedInvoices,
    gstSummaryCount: analyticsSnapshot.gstPeriods.length,
  });

  return {
    ownerId: uid,
    invoiceCount: records.length,
    normalizedInvoices,
    gstSummaryCount: analyticsSnapshot.gstPeriods.length,
  };
});

function updateAnalyticsForWrite(before, after, invoiceId) {
  const ownerChanges = new Map();

  if (before && before.ownerId) {
    accumulateOwnerChange(ownerChanges, before.ownerId, before, -1);
  }

  if (after && after.ownerId) {
    accumulateOwnerChange(ownerChanges, after.ownerId, after, 1);
  }

  const writes = [];
  for (const [ownerId, change] of ownerChanges.entries()) {
    if (isZeroChange(change.dashboard)) {
      continue;
    }

    writes.push(writeOwnerAnalytics(ownerId, change, invoiceId));
  }

  return Promise.all(writes);
}

function buildOwnerAnalyticsSnapshot(records) {
  const dashboard = emptyDashboardDelta();
  const gstPeriods = [];

  for (const record of records) {
    if (!record || !record.ownerId) {
      continue;
    }

    const contribution = buildContribution(record);
    addDashboardDelta(dashboard, contribution.dashboard, 1);
    for (const period of contribution.gstPeriods) {
      addGstPeriodDelta(gstPeriods, period, 1);
    }
  }

  return {
    dashboard: materializeDashboardSnapshot(dashboard),
    gstPeriods: gstPeriods.map(materializeGstPeriodSnapshot),
  };
}

async function replaceOwnerAnalytics(ownerId, analyticsSnapshot) {
  const analyticsRootRef = db.collection('users').doc(ownerId).collection('analytics');
  const dashboardRef = analyticsRootRef.doc('dashboard');
  const gstSummaryRef = analyticsRootRef.doc('gstSummaries');
  const periodsRef = gstSummaryRef.collection('periods');
  const existingPeriodsSnapshot = await periodsRef.get();
  const writer = db.bulkWriter();

  existingPeriodsSnapshot.forEach((doc) => {
    writer.delete(doc.ref);
  });

  writer.set(dashboardRef, {
    ownerId,
    ...analyticsSnapshot.dashboard,
    updatedAt: FieldValue.serverTimestamp(),
    rebuiltAt: FieldValue.serverTimestamp(),
  });

  writer.set(gstSummaryRef, {
    ownerId,
    updatedAt: FieldValue.serverTimestamp(),
    rebuiltAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  for (const period of analyticsSnapshot.gstPeriods) {
    writer.set(periodsRef.doc(period.docId), {
      ownerId,
      docId: period.docId,
      periodType: period.periodType,
      periodKey: period.periodKey,
      ...period.delta,
      updatedAt: FieldValue.serverTimestamp(),
      rebuiltAt: FieldValue.serverTimestamp(),
    });
  }

  await writer.close();
}

function writeOwnerAnalytics(ownerId, change, invoiceId) {
  const dashboardRef = db.collection('users').doc(ownerId).collection('analytics').doc('dashboard');
  const gstWrites = [];

  const dashboardPatch = {
    totalInvoices: FieldValue.increment(change.dashboard.totalInvoices || 0),
    paidInvoices: FieldValue.increment(change.dashboard.paidInvoices || 0),
    pendingInvoices: FieldValue.increment(change.dashboard.pendingInvoices || 0),
    overdueInvoices: FieldValue.increment(change.dashboard.overdueInvoices || 0),
    totalBilled: FieldValue.increment(change.dashboard.totalBilled || 0),
    totalCollected: FieldValue.increment(change.dashboard.totalCollected || 0),
    totalOutstanding: FieldValue.increment(change.dashboard.totalOutstanding || 0),
    totalDiscounts: FieldValue.increment(change.dashboard.totalDiscounts || 0),
    totalTaxableAmount: FieldValue.increment(change.dashboard.totalTaxableAmount || 0),
    totalCgst: FieldValue.increment(change.dashboard.totalCgst || 0),
    totalSgst: FieldValue.increment(change.dashboard.totalSgst || 0),
    totalIgst: FieldValue.increment(change.dashboard.totalIgst || 0),
    totalTax: FieldValue.increment(change.dashboard.totalTax || 0),
    gstInvoices: FieldValue.increment(change.dashboard.gstInvoices || 0),
    updatedAt: FieldValue.serverTimestamp(),
    lastSyncedInvoiceId: invoiceId,
  };

  gstWrites.push(
    dashboardRef.set(dashboardPatch, { merge: true }),
  );

  for (const periodPatch of change.gstPeriods) {
    if (isZeroChange(periodPatch.delta)) {
      continue;
    }

    const periodRef = db
      .collection('users')
      .doc(ownerId)
      .collection('analytics')
      .doc('gstSummaries')
      .collection('periods')
      .doc(periodPatch.docId);

    gstWrites.push(periodRef.set({
      ownerId,
      docId: periodPatch.docId,
      periodType: periodPatch.periodType,
      periodKey: periodPatch.periodKey,
      invoiceCount: FieldValue.increment(periodPatch.delta.invoiceCount || 0),
      taxableAmount: FieldValue.increment(periodPatch.delta.taxableAmount || 0),
      discountAmount: FieldValue.increment(periodPatch.delta.discountAmount || 0),
      cgstAmount: FieldValue.increment(periodPatch.delta.cgstAmount || 0),
      sgstAmount: FieldValue.increment(periodPatch.delta.sgstAmount || 0),
      igstAmount: FieldValue.increment(periodPatch.delta.igstAmount || 0),
      totalTax: FieldValue.increment(periodPatch.delta.totalTax || 0),
      grandTotal: FieldValue.increment(periodPatch.delta.grandTotal || 0),
      updatedAt: FieldValue.serverTimestamp(),
      lastSyncedInvoiceId: invoiceId,
    }, { merge: true }));
  }

  return Promise.all(gstWrites);
}

function accumulateOwnerChange(ownerChanges, ownerId, record, sign) {
  const existing = ownerChanges.get(ownerId) || {
    dashboard: emptyDashboardDelta(),
    gstPeriods: [],
  };

  const contribution = buildContribution(record);

  addDashboardDelta(existing.dashboard, contribution.dashboard, sign);
  for (const period of contribution.gstPeriods) {
    addGstPeriodDelta(existing.gstPeriods, period, sign);
  }

  ownerChanges.set(ownerId, existing);
}

function buildContribution(record) {
  const dashboard = {
    totalInvoices: 1,
    paidInvoices: record.status === 'paid' ? 1 : 0,
    pendingInvoices: record.status === 'pending' ? 1 : 0,
    overdueInvoices: record.status === 'overdue' ? 1 : 0,
    totalBilled: record.metrics.grandTotal,
    totalCollected: record.status === 'paid' ? record.metrics.grandTotal : 0,
    totalOutstanding: record.status === 'paid' ? 0 : record.metrics.grandTotal,
    totalDiscounts: record.metrics.discountAmount,
    totalTaxableAmount: record.metrics.taxableAmount,
    totalCgst: record.metrics.cgstAmount,
    totalSgst: record.metrics.sgstAmount,
    totalIgst: record.metrics.igstAmount,
    totalTax: record.metrics.totalTax,
    gstInvoices: record.metrics.hasGst ? 1 : 0,
  };

  const gstPeriods = record.metrics.hasGst
    ? buildGstPeriods(record)
    : [];

  return {
    dashboard,
    gstPeriods,
  };
}

function buildGstPeriods(record) {
  const dateParts = getIndianDateParts(record.createdAt);
  const monthKey = `${dateParts.year}-${padNumber(dateParts.month, 2)}`;
  const quarterNumber = Math.floor((dateParts.month - 1) / 3) + 1;
  const quarterKey = `${dateParts.year}-Q${quarterNumber}`;
  const yearKey = String(dateParts.year);

  return [
    buildGstPeriodContribution('monthly', monthKey, {
      invoiceCount: 1,
      taxableAmount: record.metrics.taxableAmount,
      discountAmount: record.metrics.discountAmount,
      cgstAmount: record.metrics.cgstAmount,
      sgstAmount: record.metrics.sgstAmount,
      igstAmount: record.metrics.igstAmount,
      totalTax: record.metrics.totalTax,
      grandTotal: record.metrics.grandTotal,
    }),
    buildGstPeriodContribution('quarterly', quarterKey, {
      invoiceCount: 1,
      taxableAmount: record.metrics.taxableAmount,
      discountAmount: record.metrics.discountAmount,
      cgstAmount: record.metrics.cgstAmount,
      sgstAmount: record.metrics.sgstAmount,
      igstAmount: record.metrics.igstAmount,
      totalTax: record.metrics.totalTax,
      grandTotal: record.metrics.grandTotal,
    }),
    buildGstPeriodContribution('yearly', yearKey, {
      invoiceCount: 1,
      taxableAmount: record.metrics.taxableAmount,
      discountAmount: record.metrics.discountAmount,
      cgstAmount: record.metrics.cgstAmount,
      sgstAmount: record.metrics.sgstAmount,
      igstAmount: record.metrics.igstAmount,
      totalTax: record.metrics.totalTax,
      grandTotal: record.metrics.grandTotal,
    }),
  ];
}

function buildGstPeriodContribution(periodType, periodKey, delta) {
  return {
    docId: `${periodType}_${periodKey}`,
    periodType,
    periodKey,
    delta,
  };
}

function addDashboardDelta(target, delta, sign) {
  target.totalInvoices += sign * (delta.totalInvoices || 0);
  target.paidInvoices += sign * (delta.paidInvoices || 0);
  target.pendingInvoices += sign * (delta.pendingInvoices || 0);
  target.overdueInvoices += sign * (delta.overdueInvoices || 0);
  target.totalBilled += sign * (delta.totalBilled || 0);
  target.totalCollected += sign * (delta.totalCollected || 0);
  target.totalOutstanding += sign * (delta.totalOutstanding || 0);
  target.totalDiscounts += sign * (delta.totalDiscounts || 0);
  target.totalTaxableAmount += sign * (delta.totalTaxableAmount || 0);
  target.totalCgst += sign * (delta.totalCgst || 0);
  target.totalSgst += sign * (delta.totalSgst || 0);
  target.totalIgst += sign * (delta.totalIgst || 0);
  target.totalTax += sign * (delta.totalTax || 0);
  target.gstInvoices += sign * (delta.gstInvoices || 0);
}

function addGstPeriodDelta(periods, period, sign) {
  const existing = periods.find((entry) => entry.docId === period.docId);
  if (existing) {
    addNumericDelta(existing.delta, period.delta, sign);
    return;
  }

  periods.push({
    docId: period.docId,
    periodType: period.periodType,
    periodKey: period.periodKey,
    delta: scaleDelta(period.delta, sign),
  });
}

function scaleDelta(delta, sign) {
  return {
    invoiceCount: sign * (delta.invoiceCount || 0),
    taxableAmount: sign * (delta.taxableAmount || 0),
    discountAmount: sign * (delta.discountAmount || 0),
    cgstAmount: sign * (delta.cgstAmount || 0),
    sgstAmount: sign * (delta.sgstAmount || 0),
    igstAmount: sign * (delta.igstAmount || 0),
    totalTax: sign * (delta.totalTax || 0),
    grandTotal: sign * (delta.grandTotal || 0),
  };
}

function addNumericDelta(target, source, sign) {
  target.invoiceCount = (target.invoiceCount || 0) + sign * (source.invoiceCount || 0);
  target.taxableAmount = (target.taxableAmount || 0) + sign * (source.taxableAmount || 0);
  target.discountAmount = (target.discountAmount || 0) + sign * (source.discountAmount || 0);
  target.cgstAmount = (target.cgstAmount || 0) + sign * (source.cgstAmount || 0);
  target.sgstAmount = (target.sgstAmount || 0) + sign * (source.sgstAmount || 0);
  target.igstAmount = (target.igstAmount || 0) + sign * (source.igstAmount || 0);
  target.totalTax = (target.totalTax || 0) + sign * (source.totalTax || 0);
  target.grandTotal = (target.grandTotal || 0) + sign * (source.grandTotal || 0);
}

function materializeDashboardSnapshot(dashboard) {
  return {
    totalInvoices: dashboard.totalInvoices || 0,
    paidInvoices: dashboard.paidInvoices || 0,
    pendingInvoices: dashboard.pendingInvoices || 0,
    overdueInvoices: dashboard.overdueInvoices || 0,
    totalBilled: roundMoney(dashboard.totalBilled || 0),
    totalCollected: roundMoney(dashboard.totalCollected || 0),
    totalOutstanding: roundMoney(dashboard.totalOutstanding || 0),
    totalDiscounts: roundMoney(dashboard.totalDiscounts || 0),
    totalTaxableAmount: roundMoney(dashboard.totalTaxableAmount || 0),
    totalCgst: roundMoney(dashboard.totalCgst || 0),
    totalSgst: roundMoney(dashboard.totalSgst || 0),
    totalIgst: roundMoney(dashboard.totalIgst || 0),
    totalTax: roundMoney(dashboard.totalTax || 0),
    gstInvoices: dashboard.gstInvoices || 0,
  };
}

function materializeGstPeriodSnapshot(period) {
  return {
    docId: period.docId,
    periodType: period.periodType,
    periodKey: period.periodKey,
    delta: {
      invoiceCount: period.delta.invoiceCount || 0,
      taxableAmount: roundMoney(period.delta.taxableAmount || 0),
      discountAmount: roundMoney(period.delta.discountAmount || 0),
      cgstAmount: roundMoney(period.delta.cgstAmount || 0),
      sgstAmount: roundMoney(period.delta.sgstAmount || 0),
      igstAmount: roundMoney(period.delta.igstAmount || 0),
      totalTax: roundMoney(period.delta.totalTax || 0),
      grandTotal: roundMoney(period.delta.grandTotal || 0),
    },
  };
}

function emptyDashboardDelta() {
  return {
    totalInvoices: 0,
    paidInvoices: 0,
    pendingInvoices: 0,
    overdueInvoices: 0,
    totalBilled: 0,
    totalCollected: 0,
    totalOutstanding: 0,
    totalDiscounts: 0,
    totalTaxableAmount: 0,
    totalCgst: 0,
    totalSgst: 0,
    totalIgst: 0,
    totalTax: 0,
    gstInvoices: 0,
  };
}

function isZeroChange(change) {
  const dashboard = change.dashboard || change;
  const numericValues = [
    dashboard.totalInvoices,
    dashboard.paidInvoices,
    dashboard.pendingInvoices,
    dashboard.overdueInvoices,
    dashboard.totalBilled,
    dashboard.totalCollected,
    dashboard.totalOutstanding,
    dashboard.totalDiscounts,
    dashboard.totalTaxableAmount,
    dashboard.totalCgst,
    dashboard.totalSgst,
    dashboard.totalIgst,
    dashboard.totalTax,
    dashboard.gstInvoices,
  ];

  if (numericValues.some((value) => value !== 0)) {
    return false;
  }

  if (!change.gstPeriods || change.gstPeriods.length === 0) {
    return true;
  }

  return change.gstPeriods.every((period) => isZeroPeriodDelta(period.delta));
}

function isZeroPeriodDelta(delta) {
  return !delta
    || (
      (delta.invoiceCount || 0) === 0 &&
      (delta.taxableAmount || 0) === 0 &&
      (delta.discountAmount || 0) === 0 &&
      (delta.cgstAmount || 0) === 0 &&
      (delta.sgstAmount || 0) === 0 &&
      (delta.igstAmount || 0) === 0 &&
      (delta.totalTax || 0) === 0 &&
      (delta.grandTotal || 0) === 0
    );
}

function invoiceNeedsNormalization(raw, derivedPatch) {
  return Object.keys(derivedPatch).some((key) => !valuesMatch(raw[key], derivedPatch[key]));
}

function valuesMatch(left, right) {
  if (left && typeof left.toDate === 'function' && right instanceof Date) {
    return left.toMillis() === right.getTime();
  }

  if (left && typeof left.toMillis === 'function' && right && typeof right.toMillis === 'function') {
    return left.toMillis() === right.toMillis();
  }

  if (left instanceof Date && right instanceof Date) {
    return left.getTime() === right.getTime();
  }

  if (Number.isFinite(left) && Number.isFinite(right)) {
    return roundMoney(left) === roundMoney(right);
  }

  // FIX: Arrays were always compared with === (reference equality), which is always false
  // for two separate array instances even with identical content. This caused
  // invoiceNeedsNormalization() to return true on every invocation because derivedPatch
  // includes searchPrefixes (an array), triggering an infinite write-back loop.
  if (Array.isArray(left) && Array.isArray(right)) {
    if (left.length !== right.length) return false;
    const sortedLeft = [...left].sort();
    const sortedRight = [...right].sort();
    return sortedLeft.every((v, i) => v === sortedRight[i]);
  }

  // Treat both-null / both-undefined as matching.
  if (left == null && right == null) return true;

  return left === right;
}

// Returns true if ALL changed fields between before and after are fields that
// this function writes during normalization — meaning this event is our own
// write-back and there is nothing new to process.
function isSelfWrite(beforeData, afterData) {
  if (!beforeData || !afterData) return false; // creation / deletion — always process

  const allKeys = new Set([...Object.keys(beforeData), ...Object.keys(afterData)]);
  const changedKeys = [...allKeys].filter((key) => !valuesMatch(beforeData[key], afterData[key]));

  return changedKeys.length > 0 && changedKeys.every((key) => SELF_WRITTEN_FIELDS.has(key));
}

function buildInvoiceRecord(raw, invoiceId) {
  const createdAt = parseDate(
    raw.createdAt,
    raw.createdAtAt,
    raw.createdAtTimestamp,
    raw.issuedAt,
  ) || new Date();
  const ownerId = safeString(raw.ownerId);
  const status = normalizeStatus(raw.status);
  const items = Array.isArray(raw.items) ? raw.items : [];
  const subtotal = roundMoney(items.reduce((sum, item) => sum + lineItemTotal(item), 0));
  const discountType = normalizeDiscountType(raw.discountType);
  const discountValue = toNumber(raw.discountValue);
  const discountAmount = roundMoney(computeDiscountAmount(subtotal, discountType, discountValue));
  const taxableAmount = roundMoney(Math.max(subtotal - discountAmount, 0));
  const gstEnabled = Boolean(raw.gstEnabled);
  const gstRate = toNumber(raw.gstRate) > 0 ? toNumber(raw.gstRate) : 18;
  const gstType = normalizeGstType(raw.gstType);
  const cgstAmount = roundMoney(gstEnabled && gstType === 'cgst_sgst' ? taxableAmount * gstRate / 200 : 0);
  const sgstAmount = roundMoney(cgstAmount);
  const igstAmount = roundMoney(gstEnabled && gstType === 'igst' ? taxableAmount * gstRate / 100 : 0);
  const totalTax = roundMoney(cgstAmount + sgstAmount + igstAmount);
  const grandTotal = roundMoney(taxableAmount + totalTax);
  const dueAt = resolveDueAt(raw, createdAt);
  const invoiceNumber = safeString(raw.invoiceNumber);
  const clientName = safeString(raw.clientName, raw.clientId);

  return {
    invoiceId,
    ownerId,
    invoiceNumber,
    clientName,
    status,
    createdAt,
    raw,
    metrics: {
      subtotal,
      discountAmount,
      taxableAmount,
      gstEnabled,
      gstRate,
      gstType,
      cgstAmount,
      sgstAmount,
      igstAmount,
      totalTax,
      grandTotal,
      hasGst: gstEnabled && totalTax > 0,
      dueAt,
    },
    derivedPatch: {
      clientNameLower: clientName.toLowerCase(),
      searchPrefixes: buildSearchPrefixes(clientName, invoiceNumber),
      subtotal,
      discountAmount,
      taxableAmount,
      cgstAmount,
      sgstAmount,
      igstAmount,
      totalTax,
      grandTotal,
      dueAt: Timestamp.fromDate(dueAt),
      financialTotalsVersion: 1,
    },
  };
}

function resolveDueAt(raw, createdAt) {
  const explicitDueDate = parseDate(
    raw.dueAt,
    raw.dueDate,
    raw.paymentDueAt,
    raw.dueTimestamp,
  );

  if (explicitDueDate) {
    return explicitDueDate;
  }

  const termsDays = toPositiveInteger(raw.paymentTermsDays, raw.dueDays, raw.netDays);
  const effectiveDays = termsDays || DEFAULT_DUE_DAYS;
  return addDays(createdAt, effectiveDays);
}

function parseDate() {
  for (let i = 0; i < arguments.length; i += 1) {
    const value = arguments[i];
    if (!value) {
      continue;
    }

    if (typeof value.toDate === 'function') {
      const date = value.toDate();
      if (!Number.isNaN(date.getTime())) {
        return date;
      }
    }

    if (value instanceof Date && !Number.isNaN(value.getTime())) {
      return value;
    }

    if (typeof value === 'string') {
      const parsed = new Date(value);
      if (!Number.isNaN(parsed.getTime())) {
        return parsed;
      }
    }

    if (typeof value === 'number') {
      const parsed = new Date(value);
      if (!Number.isNaN(parsed.getTime())) {
        return parsed;
      }
    }
  }

  return null;
}

function lineItemTotal(item) {
  if (!item) {
    return 0;
  }

  return roundMoney(toNumber(item.quantity) * toNumber(item.unitPrice));
}

function computeDiscountAmount(subtotal, discountType, discountValue) {
  if (!discountType || discountValue <= 0 || subtotal <= 0) {
    return 0;
  }

  if (discountType === 'percentage') {
    return Math.min(subtotal * (discountValue / 100), subtotal);
  }

  return Math.min(discountValue, subtotal);
}

function normalizeStatus(value) {
  const status = safeString(value).toLowerCase();
  if (status === 'paid' || status === 'pending' || status === 'overdue') {
    return status;
  }

  return 'pending';
}

function normalizeDiscountType(value) {
  const normalized = safeString(value).toLowerCase();
  if (normalized === 'percentage' || normalized === 'overall') {
    return normalized;
  }

  return null;
}

function normalizeGstType(value) {
  const normalized = safeString(value).toLowerCase();
  if (normalized === 'igst') {
    return 'igst';
  }

  return 'cgst_sgst';
}

function toNumber() {
  for (let i = 0; i < arguments.length; i += 1) {
    const value = arguments[i];
    if (typeof value === 'number' && Number.isFinite(value)) {
      return value;
    }

    if (typeof value === 'string' && value.trim() !== '') {
      const parsed = Number(value);
      if (Number.isFinite(parsed)) {
        return parsed;
      }
    }
  }

  return 0;
}

function toPositiveInteger() {
  for (let i = 0; i < arguments.length; i += 1) {
    const value = arguments[i];
    const numeric = toNumber(value);
    if (Number.isInteger(numeric) && numeric > 0) {
      return numeric;
    }
  }

  return 0;
}

function roundMoney(value) {
  return Math.round((toNumber(value) + Number.EPSILON) * 100) / 100;
}

function addDays(date, days) {
  const result = new Date(date.getTime());
  result.setDate(result.getDate() + days);
  return result;
}

function safeString() {
  for (let i = 0; i < arguments.length; i += 1) {
    const value = arguments[i];
    if (typeof value === 'string' && value.trim()) {
      return value.trim();
    }

    if (typeof value === 'number' && Number.isFinite(value)) {
      return String(value);
    }
  }

  return '';
}

function formatInvoiceNumber(year, sequence) {
  return `${INVOICE_PREFIX}-${year}-${padNumber(sequence, 5)}`;
}

function buildSearchPrefixes(clientName, invoiceNumber) {
  const prefixes = new Set();
  addSearchPrefixes(prefixes, clientName);
  addSearchPrefixes(prefixes, invoiceNumber);
  return Array.from(prefixes).sort().slice(0, 60);
}

function addSearchPrefixes(prefixes, rawValue) {
  const normalized = normalizeSearchValue(rawValue);
  if (!normalized) {
    return;
  }

  addPrefixesForValue(prefixes, normalized);

  const tokens = normalized.split(/[^a-z0-9]+/);
  for (const token of tokens) {
    if (!token) {
      continue;
    }

    addPrefixesForValue(prefixes, token);
  }
}

function addPrefixesForValue(prefixes, normalizedValue) {
  const maxLength = Math.min(normalizedValue.length, 20);
  for (let i = 1; i <= maxLength; i += 1) {
    prefixes.add(normalizedValue.slice(0, i));
  }
}

function normalizeSearchValue(value) {
  return safeString(value).toLowerCase().replace(/\s+/g, ' ');
}

function padNumber(value, length) {
  return String(value).padStart(length, '0');
}

function parseYear(value) {
  const numeric = toNumber(value);
  if (Number.isInteger(numeric) && numeric >= 2000 && numeric <= 3000) {
    return numeric;
  }

  return getIndianDateParts(new Date()).year;
}

function getIndianDateParts(date) {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: INDIA_TIME_ZONE,
    year: 'numeric',
    month: 'numeric',
    day: 'numeric',
  }).formatToParts(date);

  const lookup = {};
  for (const part of parts) {
    if (part.type === 'year' || part.type === 'month' || part.type === 'day') {
      lookup[part.type] = Number(part.value);
    }
  }

  return {
    year: lookup.year || date.getFullYear(),
    month: lookup.month || (date.getMonth() + 1),
    day: lookup.day || date.getDate(),
  };
}

// ══════════════════════════════════════════════════════════════════════════════
// SUBSCRIPTION & PAYMENT MANAGEMENT (Razorpay)
// ══════════════════════════════════════════════════════════════════════════════

const crypto = require('crypto');
const Razorpay = require('razorpay');

// Razorpay credentials — set via: firebase functions:secrets:set RAZORPAY_KEY_ID etc.
// Falls back to env vars or hardcoded test keys for local dev.
// Razorpay credentials are injected at runtime via Cloud Functions secrets.
// Create a fresh client each time to ensure secrets are loaded.
function getRazorpay() {
  const keyId = process.env.RAZORPAY_KEY_ID;
  const keySecret = process.env.RAZORPAY_KEY_SECRET;
  logger.info('Razorpay init', { keyPresent: !!keyId, secretPresent: !!keySecret });
  return new Razorpay({ key_id: keyId, key_secret: keySecret });
}
const RAZORPAY_WEBHOOK_SECRET = process.env.RAZORPAY_WEBHOOK_SECRET;
if (!RAZORPAY_WEBHOOK_SECRET) {
  logger.warn('RAZORPAY_WEBHOOK_SECRET is not set — webhook signature verification will reject all requests');
}

// Plan pricing in paise (₹1 = 100 paise)
const PLAN_PRICING = {
  pro: {
    monthly: 12900,    // ₹129/mo
    annual: 99900,     // ₹999/yr
  },
};

// Razorpay Plan IDs — cached from Firestore config/razorpay_plans.
// Only 'pro_monthly' and 'pro_annual' are valid now.
let RAZORPAY_PLAN_IDS = null;

async function getRazorpayPlanIds() {
  if (RAZORPAY_PLAN_IDS) return RAZORPAY_PLAN_IDS;
  const doc = await db.collection('config').doc('razorpay_plans').get();
  if (doc.exists) {
    RAZORPAY_PLAN_IDS = doc.data();
    return RAZORPAY_PLAN_IDS;
  }
  // Fallback — return null; createSubscription will create plans on-the-fly
  return null;
}

/**
 * Helper: ensure a Razorpay Plan exists for the given planId + billingCycle.
 * Creates it via API if not found in config, then caches the ID.
 */
async function ensureRazorpayPlan(planId, billingCycle) {
  const planIds = await getRazorpayPlanIds();
  const key = `${planId}_${billingCycle}`;

  if (planIds && planIds[key]) {
    return planIds[key];
  }

  // Create plan via Razorpay API
  const pricing = PLAN_PRICING[planId];
  const displayName = planId.charAt(0).toUpperCase() + planId.slice(1);
  const period = billingCycle === 'annual' ? 'yearly' : 'monthly';

  const rzpPlan = await getRazorpay().plans.create({
    period,
    interval: 1,
    item: {
      name: `${displayName} ${billingCycle === 'annual' ? 'Annual' : 'Monthly'}`,
      amount: pricing[billingCycle],
      currency: 'INR',
      description: `BillEasy ${displayName} plan — ${billingCycle} billing`,
    },
  });

  // Cache in Firestore
  await db.collection('config').doc('razorpay_plans').set(
    { [key]: rzpPlan.id },
    { merge: true }
  );

  // Update in-memory cache
  if (!RAZORPAY_PLAN_IDS) RAZORPAY_PLAN_IDS = {};
  RAZORPAY_PLAN_IDS[key] = rzpPlan.id;

  logger.info('Created Razorpay plan', { key, rzpPlanId: rzpPlan.id });
  return rzpPlan.id;
}

/**
 * Creates a Razorpay subscription for the user.
 * Returns the subscription ID for client-side checkout.
 */
exports.createSubscription = onCall(
  { secrets: ['RAZORPAY_KEY_ID', 'RAZORPAY_KEY_SECRET'] },
  async (request) => {
    const uid = request.auth && request.auth.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Sign in required.');
    }

    const { planId, billingCycle } = request.data || {};
    if (!planId || planId !== 'pro') {
      throw new HttpsError('invalid-argument', 'Invalid plan. Only "pro" is available.');
    }
    if (!billingCycle || !['monthly', 'annual'].includes(billingCycle)) {
      throw new HttpsError('invalid-argument', 'Invalid billing cycle.');
    }

    // Check for existing active subscription on the same plan
    const existingDoc = await db.collection('subscriptions').doc(uid).get();
    if (existingDoc.exists) {
      const existing = existingDoc.data();
      if (existing.status === 'active' && existing.plan === planId) {
        throw new HttpsError('already-exists', 'You already have this plan active.');
      }
      // If upgrading/downgrading, cancel old Razorpay subscription first
      if (existing.status === 'active' && existing.razorpaySubscriptionId) {
        try {
          await getRazorpay().subscriptions.cancel(existing.razorpaySubscriptionId, { cancel_at_cycle_end: false });
          logger.info('Cancelled old Razorpay subscription for plan change', {
            uid, oldPlan: existing.plan, newPlan: planId,
          });
        } catch (cancelErr) {
          logger.warn('Failed to cancel old Razorpay sub (may be already cancelled)', {
            error: cancelErr.message,
          });
        }
      }
    }

    // Ensure the Razorpay Plan exists
    let rzpPlanId;
    try {
      rzpPlanId = await ensureRazorpayPlan(planId, billingCycle);
      logger.info('Got Razorpay plan', { rzpPlanId });
    } catch (planErr) {
      const errDetail = planErr.error || planErr;
      logger.error('ensureRazorpayPlan failed', { error: JSON.stringify(errDetail), statusCode: planErr.statusCode, stack: planErr.stack });
      throw new HttpsError('internal', 'Failed to create billing plan. Please try again later.');
    }
    const pricing = PLAN_PRICING[planId];
    const priceInPaise = pricing[billingCycle];

    // Total billing cycles: 12 for monthly (1 year), 1 for annual
    const totalCount = billingCycle === 'annual' ? 5 : 12;

    // Create Razorpay Subscription
    let rzpSub;
    try {
      rzpSub = await getRazorpay().subscriptions.create({
      plan_id: rzpPlanId,
      total_count: totalCount,
      quantity: 1,
      customer_notify: 1,
      notes: {
        userId: uid,
        planId,
        billingCycle,
      },
    });
    logger.info('Razorpay subscription created via API', { rzpSubId: rzpSub.id });
    } catch (subErr) {
      logger.error('subscriptions.create failed', { error: subErr.message, statusCode: subErr.statusCode, rzpPlanId });
      throw new HttpsError('internal', 'Failed to create subscription: ' + subErr.message);
    }

    // Write pending subscription to Firestore (webhook will activate it)
    const now = new Date();
    await db.collection('subscriptions').doc(uid).set({
      id: rzpSub.id,
      userId: uid,
      plan: planId,
      billingCycle,
      status: 'created',
      razorpaySubscriptionId: rzpSub.id,
      razorpayPlanId: rzpPlanId,
      currentPeriodStart: Timestamp.fromDate(now),
      cancelAtPeriodEnd: false,
      createdAt: Timestamp.fromDate(now),
      updatedAt: Timestamp.fromDate(now),
      priceInPaise,
    });

    logger.info('Razorpay subscription created', {
      uid, planId, billingCycle, rzpSubId: rzpSub.id,
    });

    return {
      success: true,
      subscriptionId: rzpSub.id,
      plan: planId,
      billingCycle,
      priceInPaise,
    };
  }
);

/**
 * Cancel subscription — cancels on Razorpay and updates Firestore.
 */
exports.cancelSubscription = onCall(
  { secrets: ['RAZORPAY_KEY_ID', 'RAZORPAY_KEY_SECRET'] },
  async (request) => {
    const uid = request.auth && request.auth.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Sign in required.');
    }

    const cancelImmediately = request.data && request.data.immediate === true;
    const subRef = db.collection('subscriptions').doc(uid);
    const subDoc = await subRef.get();

    if (!subDoc.exists) {
      throw new HttpsError('not-found', 'No active subscription found.');
    }

    const sub = subDoc.data();
    if (sub.status !== 'active' && sub.status !== 'pending') {
      throw new HttpsError('failed-precondition', 'Subscription is not active.');
    }

    // Cancel on Razorpay
    const rzpSubId = sub.razorpaySubscriptionId;
    if (rzpSubId) {
      try {
        await getRazorpay().subscriptions.cancel(rzpSubId, {
          cancel_at_cycle_end: cancelImmediately ? false : true,
        });
      } catch (rzpErr) {
        logger.warn('Razorpay cancel failed (may already be cancelled)', {
          error: rzpErr.message, rzpSubId,
        });
      }
    }

    // Update Firestore
    if (cancelImmediately) {
      await subRef.update({
        status: 'cancelled',
        cancelledAt: Timestamp.fromDate(new Date()),
        updatedAt: Timestamp.fromDate(new Date()),
      });
    } else {
      await subRef.update({
        cancelAtPeriodEnd: true,
        updatedAt: Timestamp.fromDate(new Date()),
      });
    }

    logger.info('Subscription cancelled', { uid, immediate: cancelImmediately });
    return { success: true, cancelledImmediately: cancelImmediately };
  }
);

/**
 * Reactivate a subscription that was set to cancel at period end.
 * Reverses the cancelAtPeriodEnd flag so the subscription continues.
 */
exports.reactivateSubscription = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in required.');
  }

  const subRef = db.collection('subscriptions').doc(uid);
  const subDoc = await subRef.get();

  if (!subDoc.exists) {
    throw new HttpsError('not-found', 'No subscription found.');
  }

  const sub = subDoc.data();
  if (sub.status !== 'active') {
    throw new HttpsError('failed-precondition', 'Subscription is not active.');
  }
  if (!sub.cancelAtPeriodEnd) {
    return { success: true, message: 'Subscription is already active.' };
  }

  await subRef.update({
    cancelAtPeriodEnd: false,
    updatedAt: FieldValue.serverTimestamp(),
  });

  logger.info('Subscription reactivated', { uid });
  return { success: true };
});

/**
 * Verify payment signature after Razorpay checkout success.
 * Called by Flutter client to confirm payment is genuine.
 */
exports.verifyPayment = onCall(
  { secrets: ['RAZORPAY_KEY_SECRET'] },
  async (request) => {
    const uid = request.auth && request.auth.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Sign in required.');
    }

    const { razorpayPaymentId, razorpaySubscriptionId, razorpaySignature } = request.data || {};
    if (!razorpayPaymentId || !razorpaySubscriptionId || !razorpaySignature) {
      throw new HttpsError('invalid-argument', 'Missing payment verification parameters.');
    }

    // Verify signature: HMAC-SHA256(razorpayPaymentId + "|" + razorpaySubscriptionId, key_secret)
    const expectedSignature = crypto
      .createHmac('sha256', process.env.RAZORPAY_KEY_SECRET)
      .update(`${razorpayPaymentId}|${razorpaySubscriptionId}`)
      .digest('hex');

    if (expectedSignature !== razorpaySignature) {
      logger.warn('Payment signature mismatch', { uid, razorpayPaymentId });
      return { verified: false, message: 'Invalid payment signature.' };
    }

    // Activate the subscription in Firestore
    const subRef = db.collection('subscriptions').doc(uid);
    const subDoc = await subRef.get();
    if (subDoc.exists) {
      const sub = subDoc.data();
      if (sub.status !== 'active') {
        const now = new Date();
        const periodEnd = new Date(now);
        if (sub.billingCycle === 'annual') {
          periodEnd.setFullYear(periodEnd.getFullYear() + 1);
        } else {
          periodEnd.setMonth(periodEnd.getMonth() + 1);
        }
        await subRef.update({
          status: 'active',
          currentPeriodStart: Timestamp.fromDate(now),
          currentPeriodEnd: Timestamp.fromDate(periodEnd),
          lastPaymentId: razorpayPaymentId,
          updatedAt: Timestamp.fromDate(now),
        });
        logger.info('Plan activated via verifyPayment', { uid, plan: sub.plan });
      }
    }

    logger.info('Payment verified', { uid, razorpayPaymentId, razorpaySubscriptionId });
    return { verified: true };
  }
);

/**
 * Razorpay webhook handler (HTTP endpoint).
 * Verifies signature and processes subscription/payment events.
 */
exports.razorpayWebhook = onRequest(
  { secrets: ['RAZORPAY_WEBHOOK_SECRET'] },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).send('Method not allowed');
      return;
    }

    try {
      const event = req.body;
      const eventType = event && event.event;

      // Verify webhook signature (mandatory — reject unsigned requests)
      const webhookSignature = req.headers['x-razorpay-signature'];
      const webhookSecret = process.env.RAZORPAY_WEBHOOK_SECRET || RAZORPAY_WEBHOOK_SECRET;
      if (!webhookSignature || !webhookSecret) {
        logger.warn('Webhook rejected: missing signature or secret not configured', { eventType });
        res.status(401).send('Unauthorized');
        return;
      }
      const expectedSignature = crypto
        .createHmac('sha256', webhookSecret)
        .update(JSON.stringify(req.body))
        .digest('hex');
      if (webhookSignature !== expectedSignature) {
        logger.warn('Webhook signature mismatch', { eventType });
        res.status(401).send('Invalid signature');
        return;
      }

      logger.info('Razorpay webhook received', { eventType });

      // Idempotency check
      const eventId = event && event.id;
      if (eventId) {
        const eventRef = db.collection('razorpayEvents').doc(eventId);
        const eventDoc = await eventRef.get();
        if (eventDoc.exists && eventDoc.data().processed) {
          res.status(200).json({ status: 'already_processed' });
          return;
        }
        await eventRef.set({
          processed: true,
          eventType,
          processedAt: FieldValue.serverTimestamp(),
        });
      }

      // Handle different event types
      const payload = event && event.payload;
      switch (eventType) {
        case 'subscription.activated':
        case 'subscription.charged': {
          const subscription = payload && payload.subscription && payload.subscription.entity;
          if (subscription) {
            const userId = subscription.notes && subscription.notes.userId;
            const planId = subscription.notes && subscription.notes.planId;
            const billingCycle = subscription.notes && subscription.notes.billingCycle;
            if (userId) {
              const periodStart = subscription.current_start
                ? Timestamp.fromDate(new Date(subscription.current_start * 1000))
                : null;
              const periodEnd = subscription.current_end
                ? Timestamp.fromDate(new Date(subscription.current_end * 1000))
                : null;
              const updateData = {
                status: 'active',
                updatedAt: FieldValue.serverTimestamp(),
              };
              if (periodStart) updateData.currentPeriodStart = periodStart;
              if (periodEnd) updateData.currentPeriodEnd = periodEnd;
              if (planId) updateData.plan = planId;
              if (billingCycle) updateData.billingCycle = billingCycle;
              await db.collection('subscriptions').doc(userId).update(updateData);
            }
          }
          break;
        }
        case 'subscription.pending': {
          const subscription = payload && payload.subscription && payload.subscription.entity;
          if (subscription) {
            const userId = subscription.notes && subscription.notes.userId;
            if (userId) {
              await db.collection('subscriptions').doc(userId).update({
                status: 'pending',
                updatedAt: FieldValue.serverTimestamp(),
              });
            }
          }
          break;
        }
        case 'subscription.halted': {
          const subscription = payload && payload.subscription && payload.subscription.entity;
          if (subscription) {
            const userId = subscription.notes && subscription.notes.userId;
            if (userId) {
              const graceDate = new Date();
              graceDate.setDate(graceDate.getDate() + 7);
              await db.collection('subscriptions').doc(userId).update({
                status: 'halted',
                graceExpiresAt: Timestamp.fromDate(graceDate),
                updatedAt: FieldValue.serverTimestamp(),
              });
            }
          }
          break;
        }
        case 'subscription.cancelled':
        case 'subscription.completed': {
          const subscription = payload && payload.subscription && payload.subscription.entity;
          if (subscription) {
            const userId = subscription.notes && subscription.notes.userId;
            if (userId) {
              await db.collection('subscriptions').doc(userId).update({
                status: 'cancelled',
                cancelledAt: FieldValue.serverTimestamp(),
                updatedAt: FieldValue.serverTimestamp(),
              });
            }
          }
          break;
        }
        case 'subscription.paused': {
          const subscription = payload && payload.subscription && payload.subscription.entity;
          if (subscription) {
            const userId = subscription.notes && subscription.notes.userId;
            if (userId) {
              await db.collection('subscriptions').doc(userId).update({
                status: 'paused',
                updatedAt: FieldValue.serverTimestamp(),
              });
            }
          }
          break;
        }
        case 'subscription.resumed': {
          const subscription = payload && payload.subscription && payload.subscription.entity;
          if (subscription) {
            const userId = subscription.notes && subscription.notes.userId;
            if (userId) {
              await db.collection('subscriptions').doc(userId).update({
                status: 'active',
                updatedAt: FieldValue.serverTimestamp(),
              });
            }
          }
          break;
        }
        case 'payment.captured': {
          const payment = payload && payload.payment && payload.payment.entity;
          if (payment) {
            const userId = payment.notes && payment.notes.userId;
            // For subscription payments, get subId from the subscription entity or notes
            const subEntity = payload && payload.subscription && payload.subscription.entity;
            const subId = (subEntity && subEntity.id) || (payment.notes && payment.notes.subscriptionId);
            if (userId) {
              const gstAmount = Math.round(payment.amount * 18 / 118);
              await db.collection('subscriptions').doc(userId)
                .collection('payments').doc(payment.id).set({
                  id: payment.id,
                  userId,
                  subscriptionId: subId || '',
                  razorpayPaymentId: payment.id,
                  amount: payment.amount,
                  currency: payment.currency || 'INR',
                  status: 'captured',
                  method: payment.method,
                  createdAt: FieldValue.serverTimestamp(),
                  gstAmount,
                  baseAmount: payment.amount - gstAmount,
                });
            }
          }
          break;
        }
        case 'payment.failed': {
          const payment = payload && payload.payment && payload.payment.entity;
          if (payment) {
            const userId = payment.notes && payment.notes.userId;
            if (userId) {
              await db.collection('subscriptions').doc(userId)
                .collection('payments').doc(payment.id).set({
                  id: payment.id,
                  userId,
                  razorpayPaymentId: payment.id,
                  amount: payment.amount,
                  currency: payment.currency || 'INR',
                  status: 'failed',
                  method: payment.method,
                  errorCode: payment.error_code,
                  errorDescription: payment.error_description,
                  createdAt: FieldValue.serverTimestamp(),
                });
            }
          }
          break;
        }
        default:
          logger.info('Unhandled webhook event', { eventType });
      }

      res.status(200).json({ status: 'ok' });
    } catch (err) {
      logger.error('Webhook error', { error: err && err.message });
      res.status(500).json({ error: 'Internal error' });
    }
  }
);

/**
 * Daily job: check for expired grace periods and downgrade to free.
 * Also catches missed webhooks where subscription period has ended.
 */
exports.checkSubscriptionExpiry = onSchedule(
  {
    schedule: 'every day 03:00',
    timeZone: INDIA_TIME_ZONE,
  },
  async () => {
    // 1. Expired grace periods → downgrade to free
    const haltedSnapshot = await db.collection('subscriptions')
      .where('status', '==', 'halted')
      .get();

    const writer = db.bulkWriter();
    let expiredCount = 0;

    haltedSnapshot.forEach((doc) => {
      const data = doc.data();
      const graceExpires = data.graceExpiresAt;
      if (graceExpires && graceExpires.toDate() < new Date()) {
        expiredCount++;
        writer.update(doc.ref, {
          status: 'expired',
          plan: 'free',
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    });

    // 2. Active subs past currentPeriodEnd with no recent webhook → mark halted
    const activeSnapshot = await db.collection('subscriptions')
      .where('status', '==', 'active')
      .get();

    let haltedCount = 0;

    activeSnapshot.forEach((doc) => {
      const data = doc.data();
      const periodEnd = data.currentPeriodEnd;
      if (periodEnd && periodEnd.toDate() < new Date()) {
        haltedCount++;
        const graceDate = new Date();
        graceDate.setDate(graceDate.getDate() + 7);
        writer.update(doc.ref, {
          status: 'halted',
          graceExpiresAt: Timestamp.fromDate(graceDate),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    });

    // 3. Handle cancelAtPeriodEnd
    activeSnapshot.forEach((doc) => {
      const data = doc.data();
      if (!data.cancelAtPeriodEnd) return;
      const periodEnd = data.currentPeriodEnd;
      if (periodEnd && periodEnd.toDate() < new Date()) {
        writer.update(doc.ref, {
          status: 'cancelled',
          plan: 'free',
          cancelledAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    });

    await writer.close();

    logger.info('Subscription expiry check completed', { expiredCount, haltedCount });
  }
);

/**
 * Get subscription status for current user.
 */
exports.getSubscriptionStatus = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in required.');
  }

  const subDoc = await db.collection('subscriptions').doc(uid).get();
  if (!subDoc.exists) {
    return { plan: 'free', status: 'none', features: PLAN_PRICING };
  }

  const data = subDoc.data();

  return {
    plan: data.plan,
    status: data.status,
    billingCycle: data.billingCycle,
    currentPeriodEnd: data.currentPeriodEnd,
    cancelAtPeriodEnd: data.cancelAtPeriodEnd || false,
    priceInPaise: data.priceInPaise,
  };
});

// ── Send Invoice via SMS (future-ready) ──────────────────────────────────
// This function is scaffolded for backend SMS delivery via Twilio or MSG91.
// To activate:
// 1. Complete DLT registration (required for India)
// 2. Set secrets: firebase functions:secrets:set TWILIO_SID TWILIO_AUTH_TOKEN TWILIO_PHONE
// 3. Uncomment the Twilio send block below
//
// Usage from Flutter:
//   final result = await FirebaseFunctions.instance
//       .httpsCallable('sendInvoiceSms')
//       .call({ invoiceId: '...', phoneNumber: '+91...', downloadUrl: 'https://...' });
exports.sendInvoiceSms = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in required.');
  }

  const { invoiceId, phoneNumber, downloadUrl } = request.data || {};
  if (!invoiceId || !phoneNumber || !downloadUrl) {
    throw new HttpsError(
      'invalid-argument',
      'invoiceId, phoneNumber, and downloadUrl are required.'
    );
  }

  // Verify the invoice belongs to this user
  const invoiceDoc = await db.collection('invoices').doc(invoiceId).get();
  if (!invoiceDoc.exists || invoiceDoc.data().ownerId !== uid) {
    throw new HttpsError('permission-denied', 'Invoice not found or not owned by you.');
  }

  const invoice = invoiceDoc.data();
  const clientName = invoice.clientName || 'Customer';
  const invoiceNumber = invoice.invoiceNumber || invoiceId;
  const grandTotal = invoice.storedGrandTotal || 0;

  const message = `Hi ${clientName}, here is your invoice #${invoiceNumber} for ₹${grandTotal}. Download: ${downloadUrl}`;

  // TODO: Uncomment and configure when DLT registration is complete.
  // ──────────────────────────────────────────────────────────────────────
  // const twilio = require('twilio');
  // const client = twilio(process.env.TWILIO_SID, process.env.TWILIO_AUTH_TOKEN);
  // const result = await client.messages.create({
  //   body: message,
  //   from: process.env.TWILIO_PHONE,  // Your DLT-registered sender ID
  //   to: phoneNumber,
  // });
  // logger.info(`SMS sent to ${phoneNumber}: ${result.sid}`);
  // return { success: true, messageId: result.sid };
  // ──────────────────────────────────────────────────────────────────────

  logger.info(`[sendInvoiceSms] Ready to send to ${phoneNumber}: ${message}`);
  return {
    success: false,
    reason: 'Backend SMS not yet configured. Complete DLT registration and set Twilio secrets.',
    message,
  };
});

// ════════════════════════════════════════════════════════════════════════════
// INVOICE LANDING PAGE — serves a branded HTML page for shared invoices
// ════════════════════════════════════════════════════════════════════════════

exports.invoicePage = onRequest(async (req, res) => {
  const pathParts = req.path.split('/').filter(Boolean);
  const shortCode = pathParts.length >= 2 ? pathParts[1] : null;

  if (!shortCode) {
    res.status(404).send(notFoundPage());
    return;
  }

  try {
    const doc = await db.collection('shared_invoices').doc(shortCode).get();

    if (!doc.exists) {
      res.status(404).send(notFoundPage());
      return;
    }

    const data = doc.data();
    const amount = fmtCur(data.amount || 0);
    const date = data.date || '';
    const invoiceNumber = data.invoiceNumber || shortCode;
    const clientName = data.clientName || 'Customer';
    const downloadUrl = data.downloadUrl || '';
    const items = data.items || [];
    const subtotal = data.subtotal || 0;
    const discountAmount = data.discountAmount || 0;
    const gstEnabled = data.gstEnabled || false;
    const gstType = data.gstType || 'cgst_sgst';
    const cgstAmount = data.cgstAmount || 0;
    const sgstAmount = data.sgstAmount || 0;
    const igstAmount = data.igstAmount || 0;
    const status = data.status || 'pending';

    // UPI payment details
    const upiId = data.upiId || '';
    const upiNumber = data.upiNumber || '';
    const upiQrUrl = data.upiQrUrl || '';
    const storeName = data.storeName || '';
    const hasPayment = upiId || upiNumber || upiQrUrl;

    // Client phone for bill history OTP verification
    // Only show history portal for repeat customers (more than 1 invoice)
    const clientPhone = data.clientPhone || '';
    let isRepeatCustomer = false;
    if (clientPhone.length > 0 && data.clientName && data.ownerId) {
      try {
        const repeatCheck = await db.collection('shared_invoices')
          .where('ownerId', '==', data.ownerId)
          .where('clientName', '==', data.clientName)
          .limit(2)
          .get();
        isRepeatCustomer = repeatCheck.size > 1;
      } catch (e) {
        logger.warn('[invoicePage] Repeat customer check failed:', e);
      }
    }
    const hasClientPhone = clientPhone.length > 0 && isRepeatCustomer;

    // Build UPI deep link (both upi:// and intent:// for Android Chrome)
    const upiParams = upiId
      ? `pa=${encodeURIComponent(upiId)}&pn=${encodeURIComponent(storeName)}&am=${data.amount || 0}&cu=INR`
      : '';
    const upiDeepLink = upiParams ? `upi://pay?${upiParams}` : '';
    const intentLink = upiParams
      ? `intent://pay?${upiParams}#Intent;scheme=upi;package=com.google.android.apps.nbu.paisa.user;end`
      : '';

    // Build item rows HTML
    const itemRowsHtml = items.map((item, idx) => {
      const qty = fmtQty(item.quantity || 0);
      const unit = item.unit || '';
      const qtyLabel = unit ? `${qty} ${esc(unit)}` : qty;
      return `<tr>
        <td class="item-idx">${idx + 1}</td>
        <td class="item-desc">
          <div class="item-name">${esc(item.description)}</div>
          ${item.hsnCode ? `<div class="item-hsn">HSN: ${esc(item.hsnCode)}</div>` : ''}
        </td>
        <td class="item-qty">${qtyLabel}</td>
        <td class="item-price">${fmtCur(item.unitPrice || 0)}</td>
        <td class="item-total">${fmtCur(item.total || 0)}</td>
      </tr>`;
    }).join('');

    // Status badge
    const statusColors = {
      paid: { bg: '#dcfce7', text: '#15803d', label: 'Paid' },
      pending: { bg: '#fef3c7', text: '#b45309', label: 'Pending' },
      overdue: { bg: '#fee2e2', text: '#b91c1c', label: 'Overdue' },
    };
    const sc = statusColors[status] || statusColors.pending;

    // Build summary rows
    let summaryHtml = `<div class="sum-row">
      <span>Subtotal</span><span>${fmtCur(subtotal)}</span>
    </div>`;
    if (discountAmount > 0) {
      summaryHtml += `<div class="sum-row discount">
        <span>Discount</span><span>-${fmtCur(discountAmount)}</span>
      </div>`;
    }
    if (gstEnabled) {
      if (gstType === 'cgst_sgst') {
        summaryHtml += `<div class="sum-row tax">
          <span>CGST</span><span>+${fmtCur(cgstAmount)}</span>
        </div>`;
        summaryHtml += `<div class="sum-row tax">
          <span>SGST</span><span>+${fmtCur(sgstAmount)}</span>
        </div>`;
      } else {
        summaryHtml += `<div class="sum-row tax">
          <span>IGST</span><span>+${fmtCur(igstAmount)}</span>
        </div>`;
      }
    }

    res.status(200).send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Invoice ${esc(invoiceNumber)} — BillRaja</title>
  <meta property="og:title" content="Invoice ${esc(invoiceNumber)} — ${amount}">
  <meta property="og:description" content="Invoice for ${esc(clientName)} dated ${esc(date)}. ${items.length} item${items.length !== 1 ? 's' : ''} — Tap to view and download.">
  <meta property="og:type" content="website">
  <meta name="description" content="Invoice ${esc(invoiceNumber)} for ${esc(clientName)} — ${amount}">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  <style>
    *{margin:0;padding:0;box-sizing:border-box}
    body{font-family:'Inter',system-ui,-apple-system,sans-serif;background:#eef2f7;min-height:100vh;display:flex;align-items:flex-start;justify-content:center;padding:24px 16px}
    .card{background:#fff;border-radius:24px;box-shadow:0 8px 40px rgba(0,0,0,0.07);max-width:480px;width:100%;overflow:hidden}
    /* Header */
    .header{background:linear-gradient(135deg,#1e3a8a,#3b82f6);padding:32px 28px 28px;position:relative;overflow:hidden}
    .header::after{content:'';position:absolute;top:-40px;right:-40px;width:120px;height:120px;border-radius:50%;background:rgba(255,255,255,0.06)}
    .header-top{display:flex;justify-content:space-between;align-items:flex-start}
    .logo{font-size:24px;font-weight:800;color:#fff;letter-spacing:-0.5px}
    .logo span{color:#fbbf24}
    .status-badge{padding:5px 14px;border-radius:20px;font-size:11px;font-weight:700;letter-spacing:0.3px;text-transform:uppercase;background:${sc.bg};color:${sc.text}}
    .inv-number{color:rgba(255,255,255,0.6);font-size:13px;font-weight:600;margin-top:16px;letter-spacing:0.5px}
    .inv-amount{color:#fff;font-size:34px;font-weight:800;margin-top:4px}
    .inv-meta{display:flex;gap:24px;margin-top:14px}
    .inv-meta-item{color:rgba(255,255,255,0.7);font-size:12px}
    .inv-meta-item strong{color:#fff;display:block;font-size:14px;margin-top:2px}
    /* Body */
    .body{padding:24px}
    .section-title{font-size:11px;font-weight:700;color:#9ca3af;text-transform:uppercase;letter-spacing:0.8px;margin-bottom:10px}
    /* Items table */
    .items-table{width:100%;border-collapse:collapse;font-size:13px}
    .items-table thead th{text-align:left;padding:8px 6px;color:#9ca3af;font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:0.5px;border-bottom:2px solid #f3f4f6}
    .items-table thead th:last-child,.items-table thead th:nth-child(4){text-align:right}
    .items-table tbody td{padding:10px 6px;border-bottom:1px solid #f3f4f6;vertical-align:top}
    .item-idx{color:#d1d5db;font-weight:600;width:24px}
    .item-desc{color:#374151}
    .item-name{font-weight:600}
    .item-hsn{font-size:11px;color:#9ca3af;margin-top:2px}
    .item-qty{color:#6b7280;white-space:nowrap;text-align:center}
    .item-price{color:#6b7280;text-align:right;white-space:nowrap}
    .item-total{color:#111827;font-weight:700;text-align:right;white-space:nowrap}
    /* Summary */
    .summary{background:#f9fafb;border-radius:14px;padding:16px;margin-top:20px}
    .sum-row{display:flex;justify-content:space-between;padding:6px 0;font-size:13px;color:#6b7280}
    .sum-row span:last-child{font-weight:600;color:#374151}
    .sum-row.discount span:last-child{color:#ef4444}
    .sum-row.tax span:last-child{color:#16a34a}
    .sum-divider{height:1px;background:#e5e7eb;margin:8px 0}
    .sum-total{display:flex;justify-content:space-between;padding:8px 0 0;font-size:18px;font-weight:800;color:#111827}
    /* Payment */
    .payment-section{margin-top:24px;border:1.5px solid #e5e7eb;border-radius:16px;overflow:hidden}
    .payment-header{display:flex;align-items:center;gap:8px;padding:14px 16px;background:#f0fdf4;font-size:15px;font-weight:700;color:#15803d;border-bottom:1px solid #dcfce7}
    .payment-icon{font-size:20px}
    .payment-body{padding:16px;display:flex;gap:20px;align-items:flex-start;flex-wrap:wrap}
    .qr-container{text-align:center}
    .qr-img{width:140px;height:140px;border-radius:12px;border:1px solid #e5e7eb;object-fit:contain}
    .qr-label{font-size:11px;color:#9ca3af;margin-top:6px;font-weight:500}
    .upi-details{flex:1;min-width:140px}
    .upi-row{margin-bottom:12px}
    .upi-label{font-size:11px;color:#9ca3af;font-weight:600;text-transform:uppercase;letter-spacing:0.5px}
    .upi-value-row{display:flex;align-items:center;gap:8px;margin-top:4px}
    .upi-value{font-size:15px;font-weight:700;color:#111827;word-break:break-all}
    .copy-btn{padding:4px 12px;border:1px solid #d1d5db;border-radius:8px;background:#fff;font-size:11px;font-weight:600;color:#6b7280;cursor:pointer;transition:all .15s}
    .copy-btn:hover{background:#f3f4f6;color:#111827}
    .pay-now-btn{display:block;text-align:center;padding:14px;margin:0 16px 16px;background:linear-gradient(135deg,#15803d,#22c55e);color:#fff;border-radius:12px;font-size:15px;font-weight:700;text-decoration:none;transition:transform .15s;box-shadow:0 4px 14px rgba(34,197,94,0.3)}
    .pay-now-btn:hover{transform:translateY(-1px);box-shadow:0 6px 20px rgba(34,197,94,0.4)}
    .pay-now-btn:active{transform:translateY(0)}
    /* Button */
    .download-btn{display:block;width:100%;padding:16px;margin-top:24px;background:linear-gradient(135deg,#1e3a8a,#3b82f6);color:#fff;border:none;border-radius:14px;font-size:16px;font-weight:700;cursor:pointer;text-align:center;text-decoration:none;transition:transform .15s,box-shadow .15s;box-shadow:0 4px 14px rgba(59,130,246,0.3)}
    .download-btn:hover{transform:translateY(-1px);box-shadow:0 6px 20px rgba(59,130,246,0.4)}
    .download-btn:active{transform:translateY(0)}
    .footer{text-align:center;padding:16px 24px 24px;color:#d1d5db;font-size:11px}
    .footer a{color:#93c5fd;text-decoration:none}
    /* Bill History / Customer Portal Section */
    .history-section{margin-top:28px;border-top:2px solid #f3f4f6;padding-top:24px}
    .history-title{font-size:17px;font-weight:800;color:#111827;margin-bottom:4px}
    .history-subtitle{font-size:12px;color:#9ca3af;margin-bottom:16px}
    .phone-input-group{display:flex;gap:8px;margin-bottom:12px}
    .phone-prefix{padding:12px 14px;background:#f3f4f6;border:1.5px solid #e5e7eb;border-radius:12px;font-size:15px;font-weight:600;color:#374151;flex-shrink:0}
    .phone-input{flex:1;padding:12px 14px;border:1.5px solid #e5e7eb;border-radius:12px;font-size:15px;font-weight:500;color:#111827;outline:none;transition:border-color .2s}
    .phone-input:focus{border-color:#3b82f6}
    .otp-input{width:100%;padding:14px;border:1.5px solid #e5e7eb;border-radius:12px;font-size:18px;font-weight:700;color:#111827;text-align:center;letter-spacing:8px;outline:none;transition:border-color .2s;margin-bottom:12px}
    .otp-input:focus{border-color:#3b82f6}
    .otp-btn{display:block;width:100%;padding:14px;background:linear-gradient(135deg,#1e3a8a,#3b82f6);color:#fff;border:none;border-radius:12px;font-size:15px;font-weight:700;cursor:pointer;transition:transform .15s,opacity .15s}
    .otp-btn:hover{transform:translateY(-1px)}
    .otp-btn:disabled{opacity:0.5;cursor:not-allowed;transform:none}
    .otp-error{color:#ef4444;font-size:13px;font-weight:500;margin-top:8px;display:none}
    .otp-step{display:none}
    .otp-step.active{display:block}
    /* Portal Header */
    .portal-header{background:linear-gradient(135deg,#1e3a8a,#3b82f6);border-radius:16px;padding:20px;margin-bottom:16px;color:#fff}
    .portal-welcome{font-size:11px;font-weight:500;color:rgba(255,255,255,0.6);text-transform:uppercase;letter-spacing:0.5px}
    .portal-name{font-size:20px;font-weight:800;margin-top:4px}
    .portal-store{font-size:12px;color:rgba(255,255,255,0.7);margin-top:2px}
    /* Summary Stats Grid */
    .stats-grid{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-bottom:16px}
    .stat-card{padding:14px;border-radius:12px;border:1.5px solid #f3f4f6}
    .stat-label{font-size:10px;font-weight:600;text-transform:uppercase;letter-spacing:0.5px;color:#9ca3af}
    .stat-value{font-size:18px;font-weight:800;margin-top:4px}
    .stat-count{font-size:11px;color:#9ca3af;margin-top:2px}
    .stat-total{border-color:#e0e7ff;background:#f5f7ff}
    .stat-total .stat-value{color:#1e3a8a}
    .stat-paid{border-color:#dcfce7;background:#f0fdf4}
    .stat-paid .stat-value{color:#15803d}
    .stat-pending{border-color:#fef3c7;background:#fffbeb}
    .stat-pending .stat-value{color:#b45309}
    .stat-overdue{border-color:#fee2e2;background:#fef2f2}
    .stat-overdue .stat-value{color:#b91c1c}
    /* Filter Tabs */
    .filter-tabs{display:flex;gap:6px;margin-bottom:14px;overflow-x:auto;-webkit-overflow-scrolling:touch}
    .filter-tab{padding:8px 16px;border-radius:20px;font-size:12px;font-weight:600;border:1.5px solid #e5e7eb;background:#fff;color:#6b7280;cursor:pointer;white-space:nowrap;transition:all .2s}
    .filter-tab.active{background:#1e3a8a;color:#fff;border-color:#1e3a8a}
    .filter-tab .tab-count{display:inline-block;margin-left:4px;padding:1px 6px;border-radius:10px;font-size:10px;font-weight:700;background:rgba(0,0,0,0.08)}
    .filter-tab.active .tab-count{background:rgba(255,255,255,0.2)}
    /* Bills List */
    .bills-list{margin-top:8px}
    .bills-empty{text-align:center;color:#9ca3af;font-size:13px;padding:32px 0}
    .bill-card{display:flex;justify-content:space-between;align-items:center;padding:14px 16px;background:#fff;border:1.5px solid #f3f4f6;border-radius:12px;margin-bottom:8px;cursor:pointer;transition:border-color .2s,box-shadow .2s}
    .bill-card:hover{border-color:#3b82f6;box-shadow:0 2px 8px rgba(59,130,246,0.1)}
    .bill-left{flex:1}
    .bill-inv-no{font-size:14px;font-weight:700;color:#111827}
    .bill-date{font-size:12px;color:#9ca3af;margin-top:2px}
    .bill-items-count{font-size:11px;color:#6b7280;margin-top:2px}
    .bill-right{text-align:right}
    .bill-amount{font-size:15px;font-weight:800;color:#111827}
    .bill-status{display:inline-block;padding:3px 10px;border-radius:20px;font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:0.3px;margin-top:4px}
    .bill-status.paid{background:#dcfce7;color:#15803d}
    .bill-status.pending{background:#fef3c7;color:#b45309}
    .bill-status.overdue{background:#fee2e2;color:#b91c1c}
    .bill-chevron{color:#d1d5db;margin-left:8px;font-size:16px}
    /* Modal Overlay */
    .modal-overlay{display:none;position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,0.5);z-index:1000;align-items:flex-end;justify-content:center;padding:0}
    .modal-overlay.open{display:flex}
    .modal-sheet{background:#fff;border-radius:24px 24px 0 0;width:100%;max-width:480px;max-height:90vh;overflow-y:auto;animation:slideUp .3s ease}
    @keyframes slideUp{from{transform:translateY(100%)}to{transform:translateY(0)}}
    .modal-handle{width:40px;height:4px;background:#d1d5db;border-radius:2px;margin:12px auto}
    .modal-header{display:flex;justify-content:space-between;align-items:flex-start;padding:0 20px 16px;border-bottom:1px solid #f3f4f6}
    .modal-title{font-size:16px;font-weight:800;color:#111827}
    .modal-meta{font-size:12px;color:#9ca3af;margin-top:4px}
    .modal-close{width:32px;height:32px;border-radius:50%;border:none;background:#f3f4f6;font-size:18px;color:#6b7280;cursor:pointer;display:flex;align-items:center;justify-content:center;flex-shrink:0}
    .modal-body{padding:16px 20px 20px}
    .modal-status-bar{display:flex;justify-content:space-between;align-items:center;padding:12px 16px;border-radius:12px;margin-bottom:16px}
    .modal-status-bar.paid{background:#f0fdf4;border:1px solid #dcfce7}
    .modal-status-bar.pending{background:#fffbeb;border:1px solid #fef3c7}
    .modal-status-bar.overdue{background:#fef2f2;border:1px solid #fee2e2}
    .modal-total{font-size:22px;font-weight:800;color:#111827}
    /* Modal Items Table */
    .modal-section-title{font-size:10px;font-weight:700;color:#9ca3af;text-transform:uppercase;letter-spacing:0.8px;margin-bottom:8px}
    .modal-items{width:100%;border-collapse:collapse;font-size:13px;margin-bottom:16px}
    .modal-items thead th{text-align:left;padding:8px 6px;color:#9ca3af;font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:0.4px;border-bottom:2px solid #f3f4f6}
    .modal-items thead th:last-child{text-align:right}
    .modal-items tbody td{padding:10px 6px;border-bottom:1px solid #f9fafb;vertical-align:top}
    .modal-items .mi-desc{font-weight:600;color:#374151}
    .modal-items .mi-hsn{font-size:10px;color:#9ca3af;margin-top:2px}
    .modal-items .mi-qty{color:#6b7280;text-align:center}
    .modal-items .mi-total{text-align:right;font-weight:700;color:#111827}
    .modal-summary{background:#f9fafb;border-radius:12px;padding:14px;margin-bottom:16px}
    .modal-sum-row{display:flex;justify-content:space-between;padding:5px 0;font-size:13px;color:#6b7280}
    .modal-sum-row span:last-child{font-weight:600;color:#374151}
    .modal-sum-row.discount span:last-child{color:#ef4444}
    .modal-sum-row.tax span:last-child{color:#16a34a}
    .modal-sum-divider{height:1px;background:#e5e7eb;margin:6px 0}
    .modal-sum-total{display:flex;justify-content:space-between;padding:6px 0 0;font-size:17px;font-weight:800;color:#111827}
    .modal-download{display:block;width:100%;padding:14px;background:linear-gradient(135deg,#1e3a8a,#3b82f6);color:#fff;border:none;border-radius:12px;font-size:15px;font-weight:700;cursor:pointer;text-align:center;text-decoration:none;transition:transform .15s;box-shadow:0 4px 14px rgba(59,130,246,0.3)}
    .modal-download:hover{transform:translateY(-1px)}
    @media(max-width:400px){
      .inv-amount{font-size:28px}
      .inv-meta{gap:16px}
      .items-table{font-size:12px}
      .item-price{display:none}
      .items-table thead th:nth-child(4){display:none}
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <div class="header-top">
        <div class="logo">Bill<span>Raja</span></div>
        <span class="status-badge">${esc(sc.label)}</span>
      </div>
      <div class="inv-number">${esc(invoiceNumber)}</div>
      <div class="inv-amount">${amount}</div>
      <div class="inv-meta">
        <div class="inv-meta-item">Billed to<strong>${esc(clientName)}</strong></div>
        <div class="inv-meta-item">Date<strong>${esc(date)}</strong></div>
      </div>
    </div>
    <div class="body">
      <div class="section-title">Items (${items.length})</div>
      <table class="items-table">
        <thead>
          <tr><th>#</th><th>Description</th><th>Qty</th><th>Rate</th><th>Amount</th></tr>
        </thead>
        <tbody>
          ${itemRowsHtml}
        </tbody>
      </table>
      <div class="summary">
        ${summaryHtml}
        <div class="sum-divider"></div>
        <div class="sum-total">
          <span>Total</span><span>${amount}</span>
        </div>
      </div>
      ${hasPayment ? `
      <div class="payment-section">
        <div class="payment-header">
          <span class="payment-icon">&#128179;</span>
          <span>Pay via UPI</span>
        </div>
        <div class="payment-body">
          ${upiQrUrl ? `
          <div class="qr-container">
            <img src="${esc(upiQrUrl)}" alt="UPI QR Code" class="qr-img">
            <div class="qr-label">Scan to Pay</div>
          </div>` : ''}
          <div class="upi-details">
            ${upiId ? `
            <div class="upi-row">
              <span class="upi-label">UPI ID</span>
              <div class="upi-value-row">
                <span class="upi-value">${esc(upiId)}</span>
                <button class="copy-btn" onclick="navigator.clipboard.writeText('${esc(upiId)}').then(()=>{this.textContent='Copied!';;setTimeout(()=>this.textContent='Copy',1500)})">Copy</button>
              </div>
            </div>` : ''}
            ${upiNumber ? `
            <div class="upi-row">
              <span class="upi-label">UPI Number</span>
              <span class="upi-value">${esc(upiNumber)}</span>
            </div>` : ''}
          </div>
        </div>
        ${upiDeepLink ? `
        <a class="pay-now-btn" id="payNowBtn" href="${upiDeepLink}" onclick="return handleUpiPay(event)">
          Pay Now &#8594;
        </a>
        <script>
        function handleUpiPay(e) {
          e.preventDefault();
          var ua = navigator.userAgent || '';
          var isAndroid = /android/i.test(ua);
          var isIOS = /iphone|ipad|ipod/i.test(ua);
          var upiUrl = '${upiDeepLink}';
          var intentUrl = '${intentLink}';

          if (isAndroid) {
            // Try intent:// first (works in Chrome on Android)
            window.location.href = intentUrl;
            // Fallback to upi:// after short delay
            setTimeout(function() { window.location.href = upiUrl; }, 500);
          } else if (isIOS) {
            // iOS uses upi:// directly
            window.location.href = upiUrl;
          } else {
            // Desktop — just try upi://, show message if it fails
            window.location.href = upiUrl;
            setTimeout(function() {
              var btn = document.getElementById('payNowBtn');
              btn.textContent = 'Open your UPI app to pay';
              btn.style.background = '#6b7280';
            }, 2000);
          }
          return false;
        }
        </script>` : ''}
      </div>` : ''}
      <a class="download-btn" href="${esc(downloadUrl)}" target="_blank" rel="noopener">
        Download PDF
      </a>
      ${hasClientPhone ? `
      <div class="history-section">
        <div class="history-title">&#128203; Your Purchase History</div>
        <div class="history-subtitle">Verify your phone number to view all your bills, filter by status, and re-download anytime</div>

        <!-- Step 1: Phone number input -->
        <div id="phoneStep" class="otp-step active">
          <div class="phone-input-group">
            <span class="phone-prefix">+91</span>
            <input type="tel" id="phoneInput" class="phone-input" placeholder="Enter your phone number" maxlength="10" inputmode="numeric" pattern="[0-9]*">
          </div>
          <button type="button" id="sendOtpBtn" class="otp-btn" onclick="sendOtp()">Send OTP</button>
          <div id="phoneError" class="otp-error"></div>
        </div>

        <!-- Step 2: OTP input -->
        <div id="otpStep" class="otp-step">
          <p style="font-size:13px;color:#6b7280;margin-bottom:12px">Enter the 6-digit code sent to your phone</p>
          <input type="tel" id="otpInput" class="otp-input" placeholder="------" maxlength="6" inputmode="numeric" pattern="[0-9]*">
          <button type="button" id="verifyOtpBtn" class="otp-btn" onclick="verifyOtp()">Verify &amp; View Bills</button>
          <div id="otpError" class="otp-error"></div>
          <p style="font-size:12px;color:#9ca3af;margin-top:12px;text-align:center;cursor:pointer" onclick="showPhoneStep()">&#8592; Change number</p>
        </div>

        <!-- Step 3: Full Customer Portal -->
        <div id="billsStep" class="otp-step">
          <div id="portalHeader"></div>
          <div id="statsGrid"></div>
          <div id="filterTabs"></div>
          <div id="billsList" class="bills-list"></div>
        </div>
      </div>

      <!-- Bill Detail Modal -->
      <div id="billModal" class="modal-overlay" onclick="if(event.target===this)closeModal()">
        <div class="modal-sheet">
          <div class="modal-handle"></div>
          <div class="modal-header">
            <div>
              <div id="modalTitle" class="modal-title"></div>
              <div id="modalMeta" class="modal-meta"></div>
            </div>
            <button class="modal-close" onclick="closeModal()">&#10005;</button>
          </div>
          <div class="modal-body" id="modalBody"></div>
        </div>
      </div>

      <!-- Firebase Auth SDK -->
      <script src="https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js"></script>
      <script src="https://www.gstatic.com/firebasejs/10.12.0/firebase-auth-compat.js"></script>
      <div id="recaptcha-container"></div>
      <script>
      firebase.initializeApp({
        apiKey: 'AIzaSyAQwciiy95IZmhNumtPLgqDHXF1ypiEMbc',
        authDomain: 'billeasy-3a6ad.firebaseapp.com',
        projectId: 'billeasy-3a6ad',
      });

      var confirmationResult = null;
      var currentShortCode = '${esc(shortCode)}';
      var allBills = [];
      var portalData = {};
      var activeFilter = 'all';

      function showError(elId, msg) {
        var el = document.getElementById(elId);
        el.textContent = msg;
        el.style.display = msg ? 'block' : 'none';
      }

      function showPhoneStep() {
        document.getElementById('phoneStep').className = 'otp-step active';
        document.getElementById('otpStep').className = 'otp-step';
        document.getElementById('billsStep').className = 'otp-step';
        showError('phoneError', '');
      }

      function sendOtp() {
        try {
          var phone = document.getElementById('phoneInput').value.replace(/\\D/g, '');
          if (phone.length !== 10) {
            showError('phoneError', 'Please enter a valid 10-digit phone number');
            return;
          }

          var btn = document.getElementById('sendOtpBtn');
          btn.disabled = true;
          btn.textContent = 'Sending...';
          showError('phoneError', '');

          // Always recreate reCAPTCHA to avoid stale state
          if (window.recaptchaVerifier) {
            try { window.recaptchaVerifier.clear(); } catch(e) {}
            window.recaptchaVerifier = null;
          }

          window.recaptchaVerifier = new firebase.auth.RecaptchaVerifier('recaptcha-container', {
            size: 'invisible',
            callback: function() { /* reCAPTCHA solved */ },
            'expired-callback': function() {
              showError('phoneError', 'Verification expired. Please try again.');
              btn.disabled = false;
              btn.textContent = 'Send OTP';
            }
          });

          window.recaptchaVerifier.render().then(function() {
            return firebase.auth().signInWithPhoneNumber('+91' + phone, window.recaptchaVerifier);
          })
            .then(function(result) {
              confirmationResult = result;
              document.getElementById('phoneStep').className = 'otp-step';
              document.getElementById('otpStep').className = 'otp-step active';
              btn.disabled = false;
              btn.textContent = 'Send OTP';
            })
            .catch(function(err) {
              console.error('OTP error:', err);
              var msg = 'Failed to send OTP. Please try again.';
              if (err.code === 'auth/too-many-requests') msg = 'Too many attempts. Please try again later.';
              else if (err.code === 'auth/invalid-phone-number') msg = 'Invalid phone number.';
              else if (err.code === 'auth/quota-exceeded') msg = 'SMS quota exceeded. Try later.';
              showError('phoneError', msg);
              btn.disabled = false;
              btn.textContent = 'Send OTP';
              try { window.recaptchaVerifier.clear(); } catch(e) {}
              window.recaptchaVerifier = null;
            });
        } catch(e) {
          console.error('sendOtp exception:', e);
          showError('phoneError', 'Something went wrong. Please refresh and try again.');
          var btn = document.getElementById('sendOtpBtn');
          if (btn) { btn.disabled = false; btn.textContent = 'Send OTP'; }
        }
      }

      function verifyOtp() {
        var otp = document.getElementById('otpInput').value.replace(/\\D/g, '');
        if (otp.length !== 6) {
          showError('otpError', 'Please enter a valid 6-digit OTP');
          return;
        }

        var btn = document.getElementById('verifyOtpBtn');
        btn.disabled = true;
        btn.textContent = 'Verifying...';
        showError('otpError', '');

        confirmationResult.confirm(otp)
          .then(function(result) {
            return result.user.getIdToken();
          })
          .then(function(idToken) {
            return fetch('/api/client-bills', {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ' + idToken,
              },
              body: JSON.stringify({ shortCode: currentShortCode }),
            });
          })
          .then(function(resp) {
            if (!resp.ok) throw new Error('Phone number does not match our records');
            return resp.json();
          })
          .then(function(data) {
            allBills = data.bills || [];
            portalData = data;
            renderPortal();
            document.getElementById('otpStep').className = 'otp-step';
            document.getElementById('billsStep').className = 'otp-step active';
          })
          .catch(function(err) {
            console.error('Verify error:', err);
            var msg = err.code === 'auth/invalid-verification-code'
              ? 'Invalid OTP. Please try again.'
              : (err.message || 'Verification failed. Please try again.');
            showError('otpError', msg);
            btn.disabled = false;
            btn.textContent = 'Verify & View Bills';
          });
      }

      function renderPortal() {
        var s = portalData.summary || {};
        var clientName = portalData.clientName || 'Customer';
        var store = portalData.storeName || '';

        // Portal header
        document.getElementById('portalHeader').innerHTML =
          '<div class="portal-header">'
          + '<div class="portal-welcome">Customer Portal</div>'
          + '<div class="portal-name">' + escJs(clientName) + '</div>'
          + (store ? '<div class="portal-store">' + escJs(store) + '</div>' : '')
          + '</div>';

        // Stats grid
        document.getElementById('statsGrid').innerHTML =
          '<div class="stats-grid">'
          + statCard('stat-total', 'Total Spent', s.totalSpent, s.totalBills + ' bill' + (s.totalBills !== 1 ? 's' : ''))
          + statCard('stat-paid', 'Paid', s.paidAmount, s.paidCount + ' bill' + (s.paidCount !== 1 ? 's' : ''))
          + statCard('stat-pending', 'Pending', s.pendingAmount, s.pendingCount + ' bill' + (s.pendingCount !== 1 ? 's' : ''))
          + statCard('stat-overdue', 'Overdue', s.overdueAmount, s.overdueCount + ' bill' + (s.overdueCount !== 1 ? 's' : ''))
          + '</div>';

        // Filter tabs
        renderFilters(s);

        // Render bills with active filter
        renderBills();
      }

      function statCard(cls, label, amount, count) {
        return '<div class="stat-card ' + cls + '">'
          + '<div class="stat-label">' + label + '</div>'
          + '<div class="stat-value">' + fmtCurJs(amount || 0) + '</div>'
          + '<div class="stat-count">' + count + '</div>'
          + '</div>';
      }

      function renderFilters(s) {
        var filters = [
          { key: 'all', label: 'All', count: s.totalBills || 0 },
          { key: 'paid', label: 'Paid', count: s.paidCount || 0 },
          { key: 'pending', label: 'Pending', count: s.pendingCount || 0 },
          { key: 'overdue', label: 'Overdue', count: s.overdueCount || 0 },
        ];
        var html = '<div class="filter-tabs">';
        filters.forEach(function(f) {
          html += '<div class="filter-tab' + (activeFilter === f.key ? ' active' : '') + '" onclick="setFilter(\\'' + f.key + '\\')">'
            + f.label + '<span class="tab-count">' + f.count + '</span></div>';
        });
        html += '</div>';
        document.getElementById('filterTabs').innerHTML = html;
      }

      function setFilter(key) {
        activeFilter = key;
        renderFilters(portalData.summary || {});
        renderBills();
      }

      function renderBills() {
        var container = document.getElementById('billsList');
        var filtered = activeFilter === 'all'
          ? allBills
          : allBills.filter(function(b) { return b.status === activeFilter; });

        if (!filtered.length) {
          container.innerHTML = '<div class="bills-empty">No ' + (activeFilter === 'all' ? '' : activeFilter + ' ') + 'bills found</div>';
          return;
        }

        var html = '';
        filtered.forEach(function(b, idx) {
          var statusCls = b.status || 'pending';
          var statusLabel = statusCls.charAt(0).toUpperCase() + statusCls.slice(1);
          var itemCount = (b.items || []).length;
          html += '<div class="bill-card" onclick="openBillDetail(' + idx + ',' + JSON.stringify(activeFilter === 'all').replace(/"/g, '') + ')">'
            + '<div class="bill-left">'
            + '<div class="bill-inv-no">' + escJs(b.invoiceNumber) + '</div>'
            + '<div class="bill-date">' + escJs(b.date) + '</div>'
            + '<div class="bill-items-count">' + itemCount + ' item' + (itemCount !== 1 ? 's' : '') + '</div>'
            + '</div>'
            + '<div class="bill-right">'
            + '<div class="bill-amount">' + fmtCurJs(b.amount) + '</div>'
            + '<span class="bill-status ' + statusCls + '">' + statusLabel + '</span>'
            + '</div>'
            + '<span class="bill-chevron">&#8250;</span>'
            + '</div>';
        });

        container.innerHTML = html;
      }

      function openBillDetail(filteredIdx, isAll) {
        var filtered = isAll
          ? allBills
          : allBills.filter(function(b) { return b.status === activeFilter; });
        var bill = filtered[filteredIdx];
        if (!bill) return;

        var statusCls = bill.status || 'pending';
        var statusLabel = statusCls.charAt(0).toUpperCase() + statusCls.slice(1);

        document.getElementById('modalTitle').textContent = bill.invoiceNumber;
        document.getElementById('modalMeta').textContent = bill.date;

        // Build modal body
        var html = '';

        // Status bar
        html += '<div class="modal-status-bar ' + statusCls + '">'
          + '<span class="bill-status ' + statusCls + '">' + statusLabel + '</span>'
          + '<span class="modal-total">' + fmtCurJs(bill.amount) + '</span>'
          + '</div>';

        // Items table
        var items = bill.items || [];
        if (items.length) {
          html += '<div class="modal-section-title">Items (' + items.length + ')</div>'
            + '<table class="modal-items"><thead><tr>'
            + '<th>#</th><th>Description</th><th style="text-align:center">Qty</th><th style="text-align:right">Amount</th>'
            + '</tr></thead><tbody>';

          items.forEach(function(item, i) {
            var qty = item.quantity;
            if (qty === Math.floor(qty)) qty = Math.floor(qty);
            else qty = Number(qty).toFixed(2);
            var qtyLabel = item.unit ? qty + ' ' + escJs(item.unit) : qty;
            html += '<tr>'
              + '<td style="color:#d1d5db;font-weight:600">' + (i + 1) + '</td>'
              + '<td><div class="mi-desc">' + escJs(item.description) + '</div>'
              + (item.hsnCode ? '<div class="mi-hsn">HSN: ' + escJs(item.hsnCode) + '</div>' : '')
              + (item.gstRate ? '<div class="mi-hsn">GST: ' + item.gstRate + '%</div>' : '')
              + '</td>'
              + '<td class="mi-qty">' + qtyLabel + '</td>'
              + '<td class="mi-total">' + fmtCurJs(item.total) + '</td>'
              + '</tr>';
          });
          html += '</tbody></table>';
        }

        // Summary section
        html += '<div class="modal-summary">';
        html += '<div class="modal-sum-row"><span>Subtotal</span><span>' + fmtCurJs(bill.subtotal) + '</span></div>';
        if (bill.discountAmount > 0) {
          html += '<div class="modal-sum-row discount"><span>Discount</span><span>-' + fmtCurJs(bill.discountAmount) + '</span></div>';
        }
        if (bill.gstEnabled) {
          if (bill.gstType === 'cgst_sgst') {
            html += '<div class="modal-sum-row tax"><span>CGST</span><span>+' + fmtCurJs(bill.cgstAmount) + '</span></div>';
            html += '<div class="modal-sum-row tax"><span>SGST</span><span>+' + fmtCurJs(bill.sgstAmount) + '</span></div>';
          } else {
            html += '<div class="modal-sum-row tax"><span>IGST</span><span>+' + fmtCurJs(bill.igstAmount) + '</span></div>';
          }
        }
        html += '<div class="modal-sum-divider"></div>';
        html += '<div class="modal-sum-total"><span>Total</span><span>' + fmtCurJs(bill.amount) + '</span></div>';
        html += '</div>';

        // Download button
        if (bill.downloadUrl) {
          html += '<a class="modal-download" href="' + escJs(bill.downloadUrl) + '" onclick="return forceDownload(this.href, \'Invoice_' + escJs(bill.invoiceNumber || '') + '.pdf\')">&#128196; Download PDF</a>';
        }

        document.getElementById('modalBody').innerHTML = html;
        document.getElementById('billModal').className = 'modal-overlay open';
        document.body.style.overflow = 'hidden';
      }

      function closeModal() {
        document.getElementById('billModal').className = 'modal-overlay';
        document.body.style.overflow = '';
      }

      function fmtCurJs(num) {
        if (!num && num !== 0) return '\\u20B90';
        return '\\u20B9' + Number(num).toLocaleString('en-IN', { maximumFractionDigits: 0 });
      }

      function escJs(str) {
        var d = document.createElement('div');
        d.appendChild(document.createTextNode(str || ''));
        return d.innerHTML;
      }

      // Close modal on back button
      window.addEventListener('popstate', function() { closeModal(); });
      </script>` : ''}
    </div>
    <div class="footer">
      Powered by <a href="https://billraja.com">BillRaja</a>
    </div>
  </div>
</body>
</html>`);
  } catch (err) {
    logger.error('[invoicePage] Error:', err);
    res.status(500).send(notFoundPage('Something went wrong. Please try again later.'));
  }
});

// ════════════════════════════════════════════════════════════════════════════
// CLIENT BILLS API — returns previous invoices for a verified client
// ════════════════════════════════════════════════════════════════════════════

exports.clientBills = onRequest(async (req, res) => {
  // CORS headers
  res.set('Access-Control-Allow-Origin', 'https://invoice.billraja.online');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const { shortCode } = req.body || {};
    if (!shortCode) {
      res.status(400).json({ error: 'shortCode is required' });
      return;
    }

    // Verify Firebase Auth ID token from Authorization header
    const authHeader = req.headers.authorization || '';
    const idToken = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : '';
    if (!idToken) {
      res.status(401).json({ error: 'Missing auth token' });
      return;
    }

    let decodedToken;
    try {
      decodedToken = await admin.auth().verifyIdToken(idToken);
    } catch (authErr) {
      res.status(401).json({ error: 'Invalid auth token' });
      return;
    }

    // Get the phone number from the verified token
    const verifiedPhone = decodedToken.phone_number || '';
    if (!verifiedPhone) {
      res.status(403).json({ error: 'Phone number not verified' });
      return;
    }

    // Load current invoice metadata
    const invoiceDoc = await db.collection('shared_invoices').doc(shortCode).get();
    if (!invoiceDoc.exists) {
      res.status(404).json({ error: 'Invoice not found' });
      return;
    }

    const invoiceData = invoiceDoc.data();
    const storedPhone = invoiceData.clientPhone || '';

    // Normalize phone numbers for comparison (strip leading +91, spaces, dashes)
    const normalizePhone = (p) => p.replace(/[\s\-+]/g, '').replace(/^91/, '');
    const normalizedVerified = normalizePhone(verifiedPhone);
    const normalizedStored = normalizePhone(storedPhone);

    if (!normalizedStored || normalizedVerified !== normalizedStored) {
      res.status(403).json({ error: 'Phone number does not match' });
      return;
    }

    // Query all shared invoices for the same client from the same owner
    const ownerId = invoiceData.ownerId;
    const clientName = invoiceData.clientName;

    const billsSnapshot = await db.collection('shared_invoices')
      .where('ownerId', '==', ownerId)
      .where('clientName', '==', clientName)
      .orderBy('createdAt', 'desc')
      .limit(50)
      .get();

    const bills = [];
    billsSnapshot.forEach((doc) => {
      const d = doc.data();
      bills.push({
        shortCode: doc.id,
        invoiceNumber: d.invoiceNumber || doc.id,
        date: d.date || '',
        amount: d.amount || 0,
        subtotal: d.subtotal || 0,
        status: d.status || 'pending',
        downloadUrl: d.downloadUrl || '',
        items: (d.items || []).map((item) => ({
          description: item.description || '',
          quantity: item.quantity || 0,
          unitPrice: item.unitPrice || 0,
          unit: item.unit || '',
          hsnCode: item.hsnCode || '',
          gstRate: item.gstRate || 0,
          total: item.total || 0,
        })),
        discountAmount: d.discountAmount || 0,
        gstEnabled: d.gstEnabled || false,
        gstType: d.gstType || 'cgst_sgst',
        cgstAmount: d.cgstAmount || 0,
        sgstAmount: d.sgstAmount || 0,
        igstAmount: d.igstAmount || 0,
        totalTax: d.totalTax || 0,
      });
    });

    // Compute summary stats
    let totalSpent = 0, paidAmount = 0, pendingAmount = 0, overdueAmount = 0;
    let paidCount = 0, pendingCount = 0, overdueCount = 0;
    bills.forEach((b) => {
      totalSpent += b.amount;
      if (b.status === 'paid') { paidAmount += b.amount; paidCount++; }
      else if (b.status === 'overdue') { overdueAmount += b.amount; overdueCount++; }
      else { pendingAmount += b.amount; pendingCount++; }
    });

    res.status(200).json({
      bills,
      summary: {
        totalBills: bills.length,
        totalSpent,
        paidAmount, paidCount,
        pendingAmount, pendingCount,
        overdueAmount, overdueCount,
      },
      clientName: clientName,
      storeName: invoiceData.storeName || '',
    });
  } catch (err) {
    logger.error('[clientBills] Error:', err);
    res.status(500).json({ error: 'Internal error' });
  }
});

function notFoundPage(msg) {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Not Found — BillRaja</title>
  <style>
    body{font-family:system-ui,sans-serif;background:#eef2f7;display:flex;align-items:center;justify-content:center;min-height:100vh;padding:20px}
    .card{background:#fff;border-radius:20px;padding:40px 32px;box-shadow:0 4px 24px rgba(0,0,0,0.08);text-align:center;max-width:380px;width:100%}
    h1{font-size:20px;color:#111827;margin-bottom:8px}
    p{color:#6b7280;font-size:14px}
  </style>
</head>
<body>
  <div class="card">
    <h1>Invoice Not Found</h1>
    <p>${msg || 'This invoice link is invalid or has expired.'}</p>
  </div>
</body>
</html>`;
}

function esc(str) {
  return String(str || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function fmtCur(num) {
  if (!num && num !== 0) return '\u20B90';
  return '\u20B9' + Number(num).toLocaleString('en-IN', { maximumFractionDigits: 0 });
}

function fmtQty(val) {
  if (val === Math.floor(val)) return String(Math.floor(val));
  return Number(val).toFixed(2).replace(/0+$/, '').replace(/\.$/, '');
}
