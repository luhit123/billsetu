const admin = require('firebase-admin');
const logger = require('firebase-functions/logger');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentWritten, onDocumentDeleted } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');

admin.initializeApp();

const db = admin.firestore();
const { FieldValue, Timestamp } = admin.firestore;

const INDIA_TIME_ZONE = 'Asia/Kolkata';
const DEFAULT_DUE_DAYS = 30;
const INVOICE_PREFIX = 'BR';
const COUNTERS_COLLECTION = 'invoiceNumberCounters';

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
// SUBSCRIPTION & PAYMENT MANAGEMENT
// ══════════════════════════════════════════════════════════════════════════════

// Demo Razorpay key for testing - replace with real keys in production
const RAZORPAY_KEY_ID = 'rzp_test_demo';
const RAZORPAY_KEY_SECRET = 'demo_secret';

// Plan pricing in paise (₹1 = 100 paise)
const PLAN_PRICING = {
  raja: {
    monthly: 12000,    // ₹120/mo
    annual: 99900,     // ₹999/yr
  },
  maharaja: {
    monthly: 23900,    // ₹239/mo
    annual: 199900,    // ₹1,999/yr
  },
  king: {
    monthly: 55500,    // ₹555/mo
    annual: 499900,    // ₹4,999/yr
  },
};

/**
 * Creates a subscription for the user.
 * In DEMO mode, this creates a Firestore subscription directly.
 * In production, this would call Razorpay API to create a subscription
 * and return the subscription ID for client-side checkout.
 */
exports.createSubscription = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in required.');
  }

  const { planId, billingCycle } = request.data || {};
  if (!planId || !['raja', 'maharaja', 'king'].includes(planId)) {
    throw new HttpsError('invalid-argument', 'Invalid plan. Choose raja, maharaja, or king.');
  }
  if (!billingCycle || !['monthly', 'annual'].includes(billingCycle)) {
    throw new HttpsError('invalid-argument', 'Invalid billing cycle.');
  }

  // Check for existing active subscription
  const existingDoc = await db.collection('subscriptions').doc(uid).get();
  if (existingDoc.exists) {
    const existing = existingDoc.data();
    if (existing.status === 'active' && existing.plan === planId) {
      throw new HttpsError('already-exists', 'You already have this plan active.');
    }
  }

  const pricing = PLAN_PRICING[planId];
  const priceInPaise = pricing[billingCycle];

  const now = new Date();
  const periodEnd = billingCycle === 'annual'
    ? new Date(now.getFullYear() + 1, now.getMonth(), now.getDate())
    : new Date(now.getFullYear(), now.getMonth() + 1, now.getDate());
  const demoSubId = `demo_sub_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;

  // In DEMO mode, activate immediately
  await db.collection('subscriptions').doc(uid).set({
    id: demoSubId,
    userId: uid,
    plan: planId,
    billingCycle,
    status: 'active',
    razorpaySubscriptionId: demoSubId,
    currentPeriodStart: Timestamp.fromDate(now),
    currentPeriodEnd: Timestamp.fromDate(periodEnd),
    cancelAtPeriodEnd: false,
    createdAt: Timestamp.fromDate(now),
    updatedAt: Timestamp.fromDate(now),
    priceInPaise: priceInPaise,
    demoMode: true,
  });

  // Record payment
  const demoPayId = `demo_pay_${Date.now()}`;
  const gstAmount = Math.round(priceInPaise * 18 / 118);
  await db.collection('subscriptions').doc(uid).collection('payments').doc(demoPayId).set({
    id: demoPayId,
    userId: uid,
    subscriptionId: demoSubId,
    razorpayPaymentId: demoPayId,
    amount: priceInPaise,
    currency: 'INR',
    status: 'captured',
    method: 'demo',
    createdAt: Timestamp.fromDate(now),
    gstAmount,
    baseAmount: priceInPaise - gstAmount,
  });

  logger.info('Subscription created (demo mode)', { uid, planId, billingCycle });

  return {
    success: true,
    subscriptionId: demoSubId,
    plan: planId,
    billingCycle,
    priceInPaise,
    demoMode: true,
  };
});

/**
 * Cancel subscription — sets cancelAtPeriodEnd or immediately cancels.
 */
exports.cancelSubscription = onCall(async (request) => {
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
});

/**
 * Razorpay webhook handler (HTTP endpoint).
 * In production, this verifies the webhook signature and processes events.
 * In DEMO mode, this is a placeholder.
 */
const { onRequest } = require('firebase-functions/v2/https');

exports.razorpayWebhook = onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send('Method not allowed');
    return;
  }

  try {
    const event = req.body;
    const eventType = event && event.event;

    // In production: verify signature with crypto.createHmac('sha256', webhookSecret)
    // const expectedSignature = crypto.createHmac('sha256', RAZORPAY_WEBHOOK_SECRET)
    //   .update(JSON.stringify(req.body))
    //   .digest('hex');
    // if (req.headers['x-razorpay-signature'] !== expectedSignature) {
    //   res.status(401).send('Invalid signature');
    //   return;
    // }

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
      await eventRef.set({ processed: true, processedAt: FieldValue.serverTimestamp() });
    }

    // Handle different event types
    const payload = event && event.payload;
    switch (eventType) {
      case 'subscription.activated':
      case 'subscription.charged': {
        const subscription = payload && payload.subscription && payload.subscription.entity;
        if (subscription) {
          const userId = subscription.notes && subscription.notes.userId;
          if (userId) {
            const periodEnd = subscription.current_end
              ? Timestamp.fromDate(new Date(subscription.current_end * 1000))
              : null;
            await db.collection('subscriptions').doc(userId).update({
              status: 'active',
              currentPeriodEnd: periodEnd,
              updatedAt: FieldValue.serverTimestamp(),
            });
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
      case 'subscription.cancelled': {
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
      case 'payment.captured': {
        const payment = payload && payload.payment && payload.payment.entity;
        if (payment) {
          const userId = payment.notes && payment.notes.userId;
          const subId = payment.notes && payment.notes.subscriptionId;
          if (userId && subId) {
            const gstAmount = Math.round(payment.amount * 18 / 118);
            await db.collection('subscriptions').doc(userId)
              .collection('payments').doc(payment.id).set({
                id: payment.id,
                userId,
                subscriptionId: subId,
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
      default:
        logger.info('Unhandled webhook event', { eventType });
    }

    res.status(200).json({ status: 'ok' });
  } catch (err) {
    logger.error('Webhook error', { error: err && err.message });
    res.status(500).json({ error: 'Internal error' });
  }
});

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
    const now = Timestamp.fromDate(new Date());

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
      if (data.demoMode) return; // Skip demo subscriptions
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
    demoMode: data.demoMode || false,
  };
});
