const admin = require('firebase-admin');
const logger = require('firebase-functions/logger');
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentWritten, onDocumentDeleted, onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');

admin.initializeApp();

const db = admin.firestore();
const { FieldValue, Timestamp, FieldPath } = admin.firestore;

const INDIA_TIME_ZONE = 'Asia/Kolkata';
const RECENT_AUTH_MAX_AGE_SECONDS = 10 * 60;
const PAYMENT_LINK_MAX_AGE_SECONDS = 45 * 24 * 60 * 60;
const PAYMENT_LINK_DEFAULT_AGE_SECONDS = 30 * 24 * 60 * 60;

/** Normalise a phone number to E.164-ish format for matching.
 *  Strips spaces/dashes, adds +91 prefix if missing country code. */
function normalizePhone(raw) {
  if (!raw) return '';
  let digits = raw.replace(/[\s\-().]/g, '');
  // Reject inputs that contain non-phone characters after stripping whitespace/punctuation
  if (!/^[+\d]+$/.test(digits)) return '';
  // Already has +, keep as-is
  if (digits.startsWith('+')) return digits;
  // 10-digit Indian number → add +91
  if (/^\d{10}$/.test(digits)) return '+91' + digits;
  // Starts with 91 and 12 digits total → add +
  if (/^91\d{10}$/.test(digits)) return '+' + digits;
  return digits;
}

function normalizeEmail(raw) {
  return String(raw || '').trim().toLowerCase();
}

const DEFAULT_DUE_DAYS = 30;
const INVOICE_PREFIX = 'BR';
const COUNTERS_COLLECTION = 'invoiceNumberCounters';

/**
 * Reusable rate limiter. Checks and increments a counter in rate_limits/{key}.
 * @param {string} key  Unique key for the rate limit bucket (e.g. 'team_invite_{uid}')
 * @param {number} maxCount  Maximum allowed operations in the window
 * @param {number} windowMs  Time window in milliseconds
 * @param {string} message  Error message when limit exceeded
 */
/** Sets standard security headers on public HTTP responses. */
function setSecurityHeaders(res) {
  res.set('X-Content-Type-Options', 'nosniff');
  res.set('X-Frame-Options', 'DENY');
  res.set('Strict-Transport-Security', 'max-age=63072000; includeSubDomains; preload');
  res.set('Content-Security-Policy', [
    "default-src 'self'",
    "script-src 'self' 'unsafe-inline' https://www.gstatic.com https://cdn.jsdelivr.net https://cdnjs.cloudflare.com",
    "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
    "font-src 'self' https://fonts.gstatic.com",
    "img-src 'self' data: https: blob:",
    "connect-src 'self' https://*.googleapis.com https://*.firebaseio.com",
    "frame-ancestors 'none'",
  ].join('; '));
  res.set('Referrer-Policy', 'strict-origin-when-cross-origin');
}

function getRequestIp(req) {
  const forwarded = String(req.headers['x-forwarded-for'] || '').split(',')[0].trim();
  return forwarded || req.ip || (req.socket && req.socket.remoteAddress) || 'unknown';
}

function sanitizeRateLimitKeyPart(value) {
  const sanitized = String(value || 'unknown')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9:_-]/g, '_')
    .slice(0, 120);
  return sanitized || 'unknown';
}

/**
 * Writes an audit log entry to teams/{teamId}/auditLogs subcollection.
 * Fire-and-forget — errors are logged but don't block the caller.
 */
async function writeAuditLog(teamId, action, actorUid, details = {}) {
  try {
    await db.collection('teams').doc(teamId).collection('auditLogs').add({
      action,
      actorUid,
      ...details,
      timestamp: FieldValue.serverTimestamp(),
    });
  } catch (e) {
    logger.warn('Audit log write failed', { teamId, action, error: e.message });
  }
}

async function enforceRateLimit(key, maxCount, windowMs, message) {
  const ref = db.collection('rate_limits').doc(key);
  const now = Date.now();
  const windowStart = now - windowMs;
  await db.runTransaction(async (txn) => {
    const snap = await txn.get(ref);
    if (snap.exists) {
      const data = snap.data();
      if (data.windowStart > windowStart && data.count >= maxCount) {
        throw new HttpsError('resource-exhausted', message);
      }
    }
    const inWindow = snap.exists && snap.data().windowStart > windowStart;
    txn.set(ref, {
      windowStart: inWindow ? snap.data().windowStart : now,
      count: inWindow ? (snap.data().count || 0) + 1 : 1,
    }, { merge: true });
  });
}

function addMonthsClamped(baseDate, months) {
  const rawExpiry = new Date(
    baseDate.getFullYear(),
    baseDate.getMonth() + months,
    baseDate.getDate(),
    baseDate.getHours(),
    baseDate.getMinutes(),
    baseDate.getSeconds(),
    baseDate.getMilliseconds(),
  );
  const targetMonth = ((baseDate.getMonth() + months) % 12 + 12) % 12;
  if (rawExpiry.getMonth() === targetMonth) {
    return rawExpiry;
  }
  return new Date(
    rawExpiry.getFullYear(),
    rawExpiry.getMonth(),
    0,
    baseDate.getHours(),
    baseDate.getMinutes(),
    baseDate.getSeconds(),
    baseDate.getMilliseconds(),
  );
}

async function getResolvedOwnerPlan(ownerId) {
  const [subDoc, userDoc, billingConfig] = await Promise.all([
    db.collection('subscriptions').doc(ownerId).get(),
    db.collection('users').doc(ownerId).get(),
    getRcBillingConfig(),
  ]);

  const subData = subDoc.exists ? (subDoc.data() || {}) : {};
  const subStatus = normalizeSubscriptionStatus(subData.status);
  const subPlan = safeString(subData.plan);

  if (hasPaidAppAccessStatus(subStatus) && subPlan === 'enterprise') {
    return 'enterprise';
  }
  if (hasPaidAppAccessStatus(subStatus) && subPlan === 'pro') {
    return 'pro';
  }

  if (!userDoc.exists) {
    return 'expired';
  }

  const userData = userDoc.data() || {};
  const createdAt = userData.createdAt && typeof userData.createdAt.toDate === 'function'
    ? userData.createdAt.toDate()
    : null;
  const storedTrialEnd = userData.trialExpiresAt && typeof userData.trialExpiresAt.toDate === 'function'
    ? userData.trialExpiresAt.toDate()
    : null;

  let trialEnd = storedTrialEnd;
  if (createdAt) {
    trialEnd = addMonthsClamped(
      createdAt,
      billingConfig.trial_duration_months ?? DEFAULT_DURATIONS.trial_duration_months,
    );
  }

  return trialEnd && trialEnd > new Date() ? 'trial' : 'expired';
}

async function getRemoteConfigIntParam(key, fallback) {
  try {
    const template = await getCachedRemoteConfigTemplate();
    const raw = template.parameters[key] &&
      template.parameters[key].defaultValue &&
      template.parameters[key].defaultValue.value;
    const parsed = raw !== undefined ? Number(raw) : NaN;
    return Number.isFinite(parsed) ? Math.trunc(parsed) : fallback;
  } catch (e) {
    logger.warn(`Failed to read RC key ${key}, using fallback`, { error: e.message });
    return fallback;
  }
}

/**
 * Returns the max team members allowed for a given owner, driven by Remote Config.
 * -1 = unlimited. Mirrors the app's resolved plan model:
 *   trial -> enterprise team limits
 *   pro -> pro team limits
 *   enterprise -> enterprise team limits
 *   expired/free -> no team access
 */
async function getMaxTeamMembersForOwner(ownerId) {
  const plan = await getResolvedOwnerPlan(ownerId);
  switch (plan) {
    case 'trial':
    case 'enterprise':
      return getRemoteConfigIntParam('enterprise_max_team_members', -1);
    case 'pro':
      return getRemoteConfigIntParam('pro_max_team_members', 3);
    default:
      return 0;
  }
}

// ── Permission defaults & override helper ────────────────────────────────────

/** Default permissions by role. Owner always gets all true. */
const ROLE_DEFAULTS = {
  owner:   { canCreateInvoice: true,  canEditInvoice: true,  canDeleteInvoice: true,  canRecordPayment: true,  canAddCustomer: true,  canEditCustomer: true,  canDeleteCustomer: true,  canAddProduct: true,  canEditProduct: true,  canDeleteProduct: true,  canAdjustStock: true,  canManagePurchaseOrders: true,  canViewReports: true,  canViewRevenue: true,  canExportData: true,  canInviteMembers: true,  canAddMembers: true,  canMarkAttendance: true,  canViewOthersInvoices: true },
  coOwner: { canCreateInvoice: true,  canEditInvoice: true,  canDeleteInvoice: true,  canRecordPayment: true,  canAddCustomer: true,  canEditCustomer: true,  canDeleteCustomer: true,  canAddProduct: true,  canEditProduct: true,  canDeleteProduct: true,  canAdjustStock: true,  canManagePurchaseOrders: true,  canViewReports: true,  canViewRevenue: true,  canExportData: true,  canInviteMembers: true,  canAddMembers: true,  canMarkAttendance: true,  canViewOthersInvoices: true },
  manager: { canCreateInvoice: true,  canEditInvoice: true,  canDeleteInvoice: true,  canRecordPayment: true,  canAddCustomer: true,  canEditCustomer: true,  canDeleteCustomer: true,  canAddProduct: true,  canEditProduct: true,  canDeleteProduct: true,  canAdjustStock: true,  canManagePurchaseOrders: true,  canViewReports: true,  canViewRevenue: true,  canExportData: true,  canInviteMembers: true,  canAddMembers: true,  canMarkAttendance: true,  canViewOthersInvoices: true },
  sales:   { canCreateInvoice: true,  canEditInvoice: false, canDeleteInvoice: false, canRecordPayment: true,  canAddCustomer: true,  canEditCustomer: true,  canDeleteCustomer: false, canAddProduct: true,  canEditProduct: true,  canDeleteProduct: false, canAdjustStock: false, canManagePurchaseOrders: false, canViewReports: false, canViewRevenue: false, canExportData: false, canInviteMembers: false, canAddMembers: false, canMarkAttendance: true,  canViewOthersInvoices: false },
  viewer:  { canCreateInvoice: false, canEditInvoice: false, canDeleteInvoice: false, canRecordPayment: false, canAddCustomer: false, canEditCustomer: false, canDeleteCustomer: false, canAddProduct: false, canEditProduct: false, canDeleteProduct: false, canAdjustStock: false, canManagePurchaseOrders: false, canViewReports: false, canViewRevenue: false, canExportData: false, canInviteMembers: false, canAddMembers: false, canMarkAttendance: false, canViewOthersInvoices: false },
};

const OWNER_LEVEL_ROLES = new Set(['owner', 'coOwner']);
const CONFIGURABLE_ROLES = new Set(['coOwner', 'manager', 'sales', 'viewer']);
const CONFIGURABLE_PERMISSION_KEYS = new Set(Object.keys(ROLE_DEFAULTS.owner));

/**
 * Checks whether a team member has a specific permission,
 * taking into account per-role overrides stored on the team doc.
 * @param {string} teamId  The team document ID (owner's UID)
 * @param {string} role    The member's role string
 * @param {string} perm    Permission key (e.g. 'canCreateInvoice')
 * @param {object} [teamData] Optional pre-fetched team doc data
 * @returns {Promise<boolean>}
 */
async function hasPermission(teamId, role, perm, teamData) {
  const defaults = ROLE_DEFAULTS[role] || ROLE_DEFAULTS.viewer;
  const defaultVal = defaults[perm] ?? false;

  // Check for overrides on the team doc
  let data = teamData;
  if (!data) {
    const teamDoc = await db.collection('teams').doc(teamId).get();
    data = teamDoc.exists ? teamDoc.data() : {};
  }
  const overrides = data.rolePermissions && data.rolePermissions[role];
  if (overrides && perm in overrides) return overrides[perm];
  return defaultVal;
}

async function getUserIdentity(uid) {
  const user = await admin.auth().getUser(uid);
  return {
    user,
    phone: normalizePhone(user.phoneNumber || ''),
    email: normalizeEmail(user.email || ''),
  };
}

function inviteIsExpired(inviteData) {
  return !!(inviteData.expiresAt && inviteData.expiresAt.toDate() < new Date());
}

function inviteMatchesIdentity(inviteData, phone, email) {
  const invitePhone = normalizePhone(inviteData.invitedPhone || '');
  const inviteEmail = normalizeEmail(inviteData.invitedEmail || '');
  return (invitePhone && invitePhone === phone) ||
    (inviteEmail && inviteEmail === email);
}

function toMillis(value) {
  return value && typeof value.toMillis === 'function'
    ? value.toMillis()
    : null;
}

function mapInviteForClient(doc) {
  const data = doc.data();
  return {
    id: doc.id,
    ...data,
    createdAt: toMillis(data.createdAt),
    expiresAt: toMillis(data.expiresAt),
    acceptedAt: toMillis(data.acceptedAt),
  };
}

async function getValidatedTeamContext(uid) {
  const mapSnap = await db.collection('userTeamMap').doc(uid).get();
  if (!mapSnap.exists) return null;

  const mapData = mapSnap.data() || {};
  const teamId = mapData.teamId;
  if (!teamId || typeof teamId !== 'string') return null;

  const memberRef = db.collection('teams').doc(teamId).collection('members').doc(uid);
  const memberSnap = await memberRef.get();
  if (!memberSnap.exists) return null;

  const memberData = memberSnap.data() || {};
  if (memberData.status !== 'active') return null;

  return {
    teamId,
    mapData,
    memberRef,
    memberData,
    teamRef: db.collection('teams').doc(teamId),
  };
}

async function getInvoiceShareAccessContext(uid, ownerId) {
  if (uid === ownerId) {
    return {
      ownerId,
      actorUid: uid,
      role: 'owner',
      teamContext: null,
    };
  }

  const teamContext = await getValidatedTeamContext(uid);
  if (!teamContext || teamContext.teamId !== ownerId) {
    throw new HttpsError('permission-denied', 'You do not have access to share invoices for this workspace.');
  }

  const role = String(teamContext.memberData.role || '');
  const canCreate = await hasPermission(ownerId, role, 'canCreateInvoice');
  if (!canCreate) {
    throw new HttpsError('permission-denied', 'You do not have permission to share invoices.');
  }

  return {
    ownerId,
    actorUid: uid,
    role,
    teamContext,
  };
}

async function getPaymentLinkAccessContext(uid) {
  const teamContext = await getValidatedTeamContext(uid);
  if (!teamContext) {
    return {
      ownerId: uid,
      actorUid: uid,
      role: 'owner',
      teamContext: null,
    };
  }

  const role = String(teamContext.memberData.role || '');
  const [canRecordPayment, canCreateInvoice] = await Promise.all([
    hasPermission(teamContext.teamId, role, 'canRecordPayment'),
    hasPermission(teamContext.teamId, role, 'canCreateInvoice'),
  ]);

  if (!canRecordPayment && !canCreateInvoice) {
    throw new HttpsError('permission-denied', 'You do not have permission to create payment links.');
  }

  return {
    ownerId: teamContext.teamId,
    actorUid: uid,
    role,
    teamContext,
  };
}

async function getPendingInviteMatches({ teamId, phone = '', email = '' }) {
  const queries = [];
  if (phone) {
    queries.push(
      db.collection('teamInvites')
        .where('teamId', '==', teamId)
        .where('status', '==', 'pending')
        .where('invitedPhone', '==', phone)
        .get(),
    );
  }
  if (email) {
    queries.push(
      db.collection('teamInvites')
        .where('teamId', '==', teamId)
        .where('status', '==', 'pending')
        .where('invitedEmail', '==', email)
        .get(),
    );
  }

  if (queries.length === 0) return [];

  const snapshots = await Promise.all(queries);
  const docs = new Map();
  for (const snapshot of snapshots) {
    for (const doc of snapshot.docs) {
      docs.set(doc.id, doc);
    }
  }
  return Array.from(docs.values());
}

function buildOwnerMap(teamId, teamData, joinedAt) {
  return {
    teamId,
    role: 'owner',
    teamBusinessName: teamData.businessName || '',
    isOwner: true,
    joinedAt: joinedAt || FieldValue.serverTimestamp(),
  };
}

function isOwnerLevelRole(role) {
  return OWNER_LEVEL_ROLES.has(role);
}

function sanitizeRoleOverrides(role, overrides) {
  if (!CONFIGURABLE_ROLES.has(role)) {
    throw new HttpsError('invalid-argument', 'Invalid role for permission overrides.');
  }

  if (!overrides || typeof overrides !== 'object' || Array.isArray(overrides)) {
    throw new HttpsError('invalid-argument', 'Permission overrides must be a map.');
  }

  const defaults = ROLE_DEFAULTS[role] || {};
  const cleaned = {};

  for (const [permKey, rawValue] of Object.entries(overrides)) {
    if (!CONFIGURABLE_PERMISSION_KEYS.has(permKey)) {
      throw new HttpsError('invalid-argument', `Unknown permission: ${permKey}`);
    }
    if (typeof rawValue !== 'boolean') {
      throw new HttpsError('invalid-argument', `Permission ${permKey} must be boolean.`);
    }
    if (rawValue !== defaults[permKey]) {
      cleaned[permKey] = rawValue;
    }
  }

  return cleaned;
}

const MEMBERSHIP_PLAN_DURATIONS = new Set([
  'weekly',
  'monthly',
  'quarterly',
  'halfYearly',
  'yearly',
  'custom',
]);
const MEMBERSHIP_PLAN_TYPES = new Set(['recurring', 'package']);
const MEMBERSHIP_MEMBER_STATUSES = new Set(['active', 'expired', 'frozen', 'cancelled']);
const MEMBERSHIP_MAX_MONEY = 10000000;
const MEMBERSHIP_MAX_DURATION_DAYS = 3660;
const MEMBERSHIP_MS_PER_DAY = 24 * 60 * 60 * 1000;

function trimOptionalString(value, maxLength, fieldName, required = false) {
  const trimmed = String(value || '').trim();
  if (required && !trimmed) {
    throw new HttpsError('invalid-argument', `${fieldName} is required.`);
  }
  if (trimmed.length > maxLength) {
    throw new HttpsError('invalid-argument', `${fieldName} must be at most ${maxLength} characters.`);
  }
  return trimmed;
}

function requireFiniteCurrency(value, fieldName) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < 0 || parsed > MEMBERSHIP_MAX_MONEY) {
    throw new HttpsError('invalid-argument', `${fieldName} must be between 0 and ${MEMBERSHIP_MAX_MONEY}.`);
  }
  return Math.round(parsed * 100) / 100;
}

function requireFinitePercent(value, fieldName) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < 0 || parsed > 100) {
    throw new HttpsError('invalid-argument', `${fieldName} must be between 0 and 100.`);
  }
  return Math.round(parsed * 100) / 100;
}

function requireFiniteInteger(value, fieldName, min, max) {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < min || parsed > max) {
    throw new HttpsError('invalid-argument', `${fieldName} must be between ${min} and ${max}.`);
  }
  return parsed;
}

function isValidHexColor(value) {
  return /^#[0-9A-Fa-f]{6}$/.test(value);
}

function requireTimestampFromMillis(value, fieldName) {
  const millis = Number(value);
  if (!Number.isFinite(millis) || millis <= 0) {
    throw new HttpsError('invalid-argument', `${fieldName} must be a valid timestamp.`);
  }
  return Timestamp.fromMillis(Math.trunc(millis));
}

function computeMembershipDurationDays(planData) {
  switch (planData.duration) {
    case 'weekly':
      return 7;
    case 'monthly':
      return 30;
    case 'quarterly':
      return 90;
    case 'halfYearly':
      return 180;
    case 'yearly':
      return 365;
    case 'custom':
      return requireFiniteInteger(
        planData.customDays,
        'customDays',
        1,
        MEMBERSHIP_MAX_DURATION_DAYS,
      );
    default:
      throw new HttpsError('invalid-argument', 'Invalid membership duration.');
  }
}

function computePlanEffectivePrice(planData) {
  const price = Number(planData.price || 0);
  const discountPercent = Number(planData.discountPercent || 0);
  const effective = discountPercent > 0
    ? price - (price * discountPercent / 100)
    : price;
  return Math.round(effective * 100) / 100;
}

function sanitizeMembershipBenefits(benefits) {
  if (benefits == null) return [];
  if (!Array.isArray(benefits)) {
    throw new HttpsError('invalid-argument', 'benefits must be a list.');
  }
  if (benefits.length > 20) {
    throw new HttpsError('invalid-argument', 'A plan can have at most 20 benefits.');
  }
  return benefits.map((entry) => trimOptionalString(entry, 80, 'Benefit'))
    .filter(Boolean);
}

function sanitizeMembershipPlanPayload(data) {
  const duration = String(data.duration || 'monthly');
  if (!MEMBERSHIP_PLAN_DURATIONS.has(duration)) {
    throw new HttpsError('invalid-argument', 'Invalid membership duration.');
  }

  const planType = String(data.planType || 'recurring');
  if (!MEMBERSHIP_PLAN_TYPES.has(planType)) {
    throw new HttpsError('invalid-argument', 'Invalid membership plan type.');
  }

  const colorHex = String(data.colorHex || '#1E3A8A').trim();
  if (!isValidHexColor(colorHex)) {
    throw new HttpsError('invalid-argument', 'colorHex must be a valid 6-digit hex color.');
  }

  const gstEnabled = data.gstEnabled === true;
  const gstRate = Number(data.gstRate ?? 18);
  if (![5, 12, 18, 28].includes(gstRate)) {
    throw new HttpsError('invalid-argument', 'gstRate must be one of 5, 12, 18, or 28.');
  }
  const gstType = data.gstType === 'igst' ? 'igst' : 'cgst_sgst';

  return {
    name: trimOptionalString(data.name, 80, 'Plan name', true),
    description: trimOptionalString(data.description, 500, 'Description'),
    benefits: sanitizeMembershipBenefits(data.benefits),
    duration,
    customDays: duration === 'custom'
      ? requireFiniteInteger(data.customDays, 'customDays', 1, MEMBERSHIP_MAX_DURATION_DAYS)
      : duration === 'weekly'
          ? 7
          : duration === 'monthly'
              ? 30
              : duration === 'quarterly'
                  ? 90
                  : duration === 'halfYearly'
                      ? 180
                      : 365,
    price: requireFiniteCurrency(data.price ?? 0, 'price'),
    joiningFee: planType === 'package'
      ? 0
      : requireFiniteCurrency(data.joiningFee ?? 0, 'joiningFee'),
    discountPercent: requireFinitePercent(data.discountPercent ?? 0, 'discountPercent'),
    gracePeriodDays: requireFiniteInteger(data.gracePeriodDays ?? 3, 'gracePeriodDays', 0, 90),
    planType,
    autoRenew: planType === 'package' ? false : data.autoRenew === true,
    isActive: data.isActive !== false,
    colorHex: colorHex.toUpperCase(),
    gstEnabled,
    gstRate,
    gstType,
    isDeleted: false,
  };
}

function sanitizeMembershipMemberPayload(data) {
  const startDate = requireTimestampFromMillis(data.startDateMs, 'startDateMs');
  const endDate = requireTimestampFromMillis(data.endDateMs, 'endDateMs');
  const durationMs = endDate.toMillis() - startDate.toMillis();
  if (durationMs <= 0 || durationMs > MEMBERSHIP_MAX_DURATION_DAYS * MEMBERSHIP_MS_PER_DAY) {
    throw new HttpsError('invalid-argument', 'Membership duration is invalid.');
  }

  return {
    name: trimOptionalString(data.name, 80, 'Member name', true),
    phone: trimOptionalString(data.phone, 32, 'Phone'),
    email: trimOptionalString(data.email, 160, 'Email'),
    notes: trimOptionalString(data.notes, 1000, 'Notes'),
    planId: trimOptionalString(data.planId, 120, 'planId', true),
    startDate,
    endDate,
    autoRenew: data.autoRenew === true,
    amountPaid: requireFiniteCurrency(data.amountPaid ?? 0, 'amountPaid'),
    joiningFeePaid: requireFiniteCurrency(data.joiningFeePaid ?? 0, 'joiningFeePaid'),
  };
}

async function getMembershipAccessContext(uid, { requireOwnerLevel = false } = {}) {
  const mapSnap = await db.collection('userTeamMap').doc(uid).get();
  if (!mapSnap.exists) {
    return {
      actorUid: uid,
      ownerId: uid,
      role: 'owner',
      teamId: null,
      teamContext: null,
      ownerRef: db.collection('users').doc(uid),
    };
  }

  const teamContext = await getValidatedTeamContext(uid);
  if (!teamContext) {
    throw new HttpsError('failed-precondition', 'Your team access is not active.');
  }

  const role = teamContext.memberData.role || 'viewer';
  if (requireOwnerLevel && !isOwnerLevelRole(role)) {
    throw new HttpsError('permission-denied', 'Only owners and co-owners can manage memberships.');
  }

  return {
    actorUid: uid,
    ownerId: teamContext.teamId,
    role,
    teamId: teamContext.teamId,
    teamContext,
    ownerRef: db.collection('users').doc(teamContext.teamId),
  };
}

async function getAppBillingAccessContext(uid) {
  return getMembershipAccessContext(uid, { requireOwnerLevel: true });
}

function buildMembershipPlanSnapshot(planId, planData) {
  return {
    planId,
    planName: planData.name || '',
    planDuration: planData.duration || 'monthly',
    planDurationDays: computeMembershipDurationDays(planData),
    planTypeSnapshot: planData.planType || 'recurring',
    planGracePeriodDays: Number.isInteger(planData.gracePeriodDays)
      ? planData.gracePeriodDays
      : 0,
    planGstEnabled: planData.gstEnabled === true,
    planGstRate: Number(planData.gstRate || 18),
    planGstType: planData.gstType === 'igst' ? 'igst' : 'cgst_sgst',
    planEffectivePrice: computePlanEffectivePrice(planData),
  };
}

async function writeMembershipAuditIfNeeded(context, action, details = {}) {
  if (!context || !context.teamId) return;
  await writeAuditLog(context.teamId, action, context.actorUid, details);
}

function computeFrozenExtensionDays(memberData, referenceDate = new Date()) {
  const frozenUntilMs = memberData.frozenUntil && typeof memberData.frozenUntil.toMillis === 'function'
    ? memberData.frozenUntil.toMillis()
    : 0;
  if (!frozenUntilMs) return 0;

  const freezeStartedAtMs = memberData.freezeStartedAt && typeof memberData.freezeStartedAt.toMillis === 'function'
    ? memberData.freezeStartedAt.toMillis()
    : referenceDate.getTime();
  const resumeAtMs = Math.min(referenceDate.getTime(), frozenUntilMs);
  if (resumeAtMs <= freezeStartedAtMs) return 0;

  return Math.max(
    0,
    Math.ceil((resumeAtMs - freezeStartedAtMs) / MEMBERSHIP_MS_PER_DAY),
  );
}

function isFiniteCoordinate(value, min, max) {
  return Number.isFinite(value) && value >= min && value <= max;
}

function distanceMeters(lat1, lon1, lat2, lon2) {
  const toRadians = (degrees) => degrees * Math.PI / 180;
  const radius = 6371000.0;
  const dLat = toRadians(lat2 - lat1);
  const dLon = toRadians(lon2 - lon1);
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRadians(lat1)) *
      Math.cos(toRadians(lat2)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return radius * c;
}

// ── Trial-used tracking ───────────────────────────────────────────────────────
// Stores phone numbers and emails of users who have already used a trial.
// Survives account deletion so re-signups don't get another free trial.

/**
 * Before deleting an account, record the user's phone/email in `usedTrials`
 * so they can't get a fresh trial by re-signing up.
 */
async function markTrialUsed(uid) {
  try {
    const authUser = await admin.auth().getUser(uid);
    const writes = [];

    if (authUser.phoneNumber) {
      writes.push(
        db.collection('usedTrials').doc(authUser.phoneNumber).set({
          markedAt: FieldValue.serverTimestamp(),
          originalUid: uid,
        })
      );
    }
    if (authUser.email) {
      // Use a sanitised key (Firestore doc IDs can't contain '/')
      const emailKey = authUser.email.toLowerCase().replace(/[/]/g, '_');
      writes.push(
        db.collection('usedTrials').doc(emailKey).set({
          markedAt: FieldValue.serverTimestamp(),
          originalUid: uid,
        })
      );
    }

    if (writes.length > 0) {
      await Promise.all(writes);
      logger.info('Marked trial as used before account deletion', {
        uid,
        phone: authUser.phoneNumber || null,
        email: authUser.email || null,
      });
    }
  } catch (e) {
    // Don't block deletion if this fails
    logger.warn('Failed to mark trial as used', { uid, error: e.message });
  }
}

/**
 * Check if this user's phone number or email has already used a trial.
 * Returns true if the user is a returning user (no trial allowed).
 */
async function hasUsedTrial(uid) {
  try {
    const authUser = await admin.auth().getUser(uid);
    const checks = [];

    if (authUser.phoneNumber) {
      checks.push(db.collection('usedTrials').doc(authUser.phoneNumber).get());
    }
    if (authUser.email) {
      const emailKey = authUser.email.toLowerCase().replace(/[/]/g, '_');
      checks.push(db.collection('usedTrials').doc(emailKey).get());
    }

    if (checks.length === 0) return false;

    const results = await Promise.all(checks);
    return results.some((snap) => snap.exists);
  } catch (e) {
    logger.warn('Failed to check usedTrials', { uid, error: e.message });
    return false; // fail open — don't block new users
  }
}

// ── Trial setup: when a new user doc is created, set trialExpiresAt ──────────
exports.setupUserTrial = onDocumentCreated('users/{uid}', async (event) => {
  const uid = event.params.uid;
  const data = event.data && event.data.data();
  if (!data) return;

  // Only set trialExpiresAt if not already present
  if (data.trialExpiresAt) return;

  const config = await getPricingConfig();
  const trialMonths = config.trial_duration_months ?? 6;

  // If trial duration is 0, no trial — skip writing trialExpiresAt entirely.
  if (trialMonths <= 0) {
    logger.info('Trial duration is 0 — skipping trial setup for user', { uid });
    return;
  }

  // Check if this user previously had an account and already used their trial.
  // Returning users (deleted account + re-signed up) don't get another trial.
  const alreadyUsed = await hasUsedTrial(uid);
  if (alreadyUsed) {
    logger.info('Returning user detected — no trial granted', { uid });
    // Write trialExpiresAt in the past so PlanService resolves to expired/free
    await db.collection('users').doc(uid).update({
      trialExpiresAt: Timestamp.fromDate(new Date(0)),
      returningUser: true,
    });
    return;
  }

  const createdAt = data.createdAt ? data.createdAt.toDate() : new Date();
  const trialExpiresAt = new Date(createdAt);
  trialExpiresAt.setMonth(trialExpiresAt.getMonth() + trialMonths);

  await db.collection('users').doc(uid).update({
    trialExpiresAt: Timestamp.fromDate(trialExpiresAt),
  });

  logger.info('Trial set up for new user', { uid, trialMonths, trialExpiresAt: trialExpiresAt.toISOString() });
});

// Keep one warm instance to eliminate cold-start latency for this
// critical user-facing function called on every invoice creation.
exports.reserveInvoiceNumber = onCall(
  { enforceAppCheck: true, minInstances: 1, memory: '256MiB', timeoutSeconds: 30 },
  async (request) => {
    const uid = request.auth && request.auth.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Sign in is required to reserve invoice numbers.');
    }

    // Team support: if ownerId is provided and differs from caller's uid,
    // validate the caller is an active team member with write permissions.
    let effectiveOwnerId = uid;
    const requestedOwnerId = request.data && request.data.ownerId;
    if (requestedOwnerId && requestedOwnerId !== uid) {
      const memberDoc = await db
        .collection('teams').doc(requestedOwnerId)
        .collection('members').doc(uid)
        .get();
      if (!memberDoc.exists || memberDoc.data().status !== 'active') {
        throw new HttpsError('permission-denied', 'You are not an active member of this team.');
      }
      const memberRole = memberDoc.data().role;
      const canCreate = await hasPermission(requestedOwnerId, memberRole, 'canCreateInvoice');
      if (!canCreate) {
        throw new HttpsError('permission-denied', 'You do not have permission to create invoices.');
      }
      effectiveOwnerId = requestedOwnerId;
    }

    // Rate limiting: max 100 invoices per hour per user.
    // Runs inside its own transaction so concurrent requests can't all pass the
    // check before any one of them increments the counter (race condition fix).
    const rateLimitRef = db.collection('rate_limits').doc(`invoice_${uid}`);
    const now = Date.now();
    const oneHourAgo = now - 3600000;
    await db.runTransaction(async (txn) => {
      const snap = await txn.get(rateLimitRef);
      if (snap.exists) {
        const data = snap.data();
        if (data.windowStart > oneHourAgo && data.count >= 100) {
          throw new HttpsError('resource-exhausted', 'Rate limit exceeded: max 100 invoices per hour.');
        }
      }
      const inWindow = snap.exists && snap.data().windowStart > oneHourAgo;
      txn.set(rateLimitRef, {
        windowStart: inWindow ? snap.data().windowStart : now,
        count: inWindow ? (snap.data().count || 0) + 1 : 1,
        uid,
      }, { merge: true });
    });

    // ── Server-side plan limit enforcement (RC-driven) ──────────────────────
    // Mirrors the app's resolved plan model so trial, paid, and expired users
    // see the same limits client-side and server-side.
    {
      const resolvedPlan = await getResolvedOwnerPlan(effectiveOwnerId);
      const rcKey = resolvedPlan === 'enterprise' || resolvedPlan === 'trial'
        ? 'enterprise_max_invoices'
        : resolvedPlan === 'pro'
          ? 'pro_max_invoices'
          : 'expired_max_invoices';

      // Read limit from Remote Config
      let maxInvoices = resolvedPlan === 'expired' ? 5 : -1;
      try {
        const rcTemplate = await getCachedRemoteConfigTemplate();
        const param = rcTemplate.parameters[rcKey];
        if (param && param.defaultValue && param.defaultValue.value) {
          const parsed = parseInt(param.defaultValue.value, 10);
          if (!isNaN(parsed)) maxInvoices = parsed;
        }
      } catch (_) { /* use default */ }

      // Enforce limit if not unlimited
      if (maxInvoices !== -1) {
        const nowDate = new Date();
        const periodKey = `${nowDate.getFullYear()}-${String(nowDate.getMonth() + 1).padStart(2, '0')}`;
        const usageDoc = await db.collection('users').doc(effectiveOwnerId)
          .collection('usage').doc(periodKey).get();
        const invoicesCreated = usageDoc.exists
          ? (usageDoc.data().invoicesCreated || 0)
          : 0;

        if (invoicesCreated >= maxInvoices) {
          throw new HttpsError(
            'resource-exhausted',
            `Monthly invoice limit reached (${maxInvoices}). Please upgrade for more invoices.`,
          );
        }
      }
    }

    const requestedYear = parseYear(request.data && request.data.year);
    const counterRef = db
      .collection(COUNTERS_COLLECTION)
      .doc(effectiveOwnerId)
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
        ownerId: effectiveOwnerId,
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
      ownerId: effectiveOwnerId,
      callerUid: uid,
      year: requestedYear,
      sequence: reservation.sequence,
      invoiceNumber: reservation.invoiceNumber,
    });

    return {
      ownerId: effectiveOwnerId,
      year: requestedYear,
      prefix: INVOICE_PREFIX,
      sequence: reservation.sequence,
      invoiceNumber: reservation.invoiceNumber,
    };
  },
);

// Fields that materially affect analytics calculations.
// Updates touching only metadata (e.g. updatedAt, searchPrefixes) are skipped
// to avoid running expensive aggregation on every cosmetic write.
// 'gstAmount' was the wrong field name — the actual fields are cgstAmount,
// sgstAmount, igstAmount, totalTax.
const ANALYTICS_FIELDS = ['status', 'grandTotal', 'cgstAmount', 'sgstAmount', 'igstAmount', 'totalTax', 'createdAt'];

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

exports.syncInvoiceAnalytics = onDocumentWritten(
  { document: 'invoices/{invoiceId}', memory: '512MiB', timeoutSeconds: 120 },
  async (event) => {
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
    console.error('syncInvoiceAnalytics CRASH:', err);
    console.error('invoiceId:', event.params.invoiceId, 'message:', err?.message, 'stack:', err?.stack);
  }
});

exports.reconcileInvoiceCreate = onDocumentCreated(
  { document: 'invoices/{invoiceId}', memory: '256MiB', timeoutSeconds: 60 },
  async (event) => {
    const invoiceId = event.params.invoiceId;
    const data = event.data && event.data.data ? event.data.data() : null;
    if (!data) {
      return;
    }

    const ownerId = safeString(data.ownerId);
    if (!ownerId) {
      logger.warn('reconcileInvoiceCreate: missing ownerId', { invoiceId });
      return;
    }

    const createdAt = parseDate(data.createdAt, data.issuedAt) || new Date();
    const reservation = await claimCanonicalInvoiceNumber({
      ownerId,
      invoiceId,
      rawInvoiceNumber: data.invoiceNumber,
      createdAt,
    });

    if (reservation.changed) {
      const clientName = safeString(data.clientName, data.clientId);
      await event.data.ref.set({
        invoiceNumber: reservation.invoiceNumber,
        searchPrefixes: buildSearchPrefixes(clientName, reservation.invoiceNumber),
      }, { merge: true });
    }

    logger.info('Invoice reconciled after create', {
      ownerId,
      invoiceId,
      invoiceNumber: reservation.invoiceNumber,
      changed: reservation.changed,
    });
  },
);

exports.cleanupInvoicesAfterClientDelete = onDocumentDeleted(
  { document: 'users/{ownerId}/clients/{clientId}', memory: '512MiB', timeoutSeconds: 300 },
  async (event) => {
    const ownerId = event.params.ownerId;
    const clientId = event.params.clientId;
    const deletedClient = event.data && event.data.data ? event.data.data() : null;
    const deletedClientName = safeString(
      deletedClient && deletedClient.name,
      deletedClient && deletedClient.fullName,
      clientId,
    );

    // Paginate: process 500 invoices at a time to avoid timeouts
    const CLEANUP_PAGE_SIZE = 500;
    let lastCleanupDoc = null;
    let updatedCount = 0;

    while (true) {
      let query = db.collection('invoices')
        .where('ownerId', '==', ownerId)
        .where('clientId', '==', clientId)
        .limit(CLEANUP_PAGE_SIZE);

      if (lastCleanupDoc) {
        query = query.startAfter(lastCleanupDoc);
      }

      const pageSnapshot = await query.get();
      if (pageSnapshot.empty) break;

      const writer = db.bulkWriter();
      pageSnapshot.forEach((doc) => {
        updatedCount += 1;
        writer.set(doc.ref, {
          clientId: '',
          clientName: `${deletedClientName} (Deleted)`,
        }, { merge: true });
      });
      await writer.close();

      lastCleanupDoc = pageSnapshot.docs[pageSnapshot.docs.length - 1];
      if (pageSnapshot.size < CLEANUP_PAGE_SIZE) break;
    }

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
  { document: 'users/{ownerId}/purchaseOrders/{poId}', memory: '512MiB', timeoutSeconds: 120 },
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
    let overdueCount = 0;

    // Paginated overdue marking for both 'pending' and 'partiallyPaid'
    const OVERDUE_PAGE_SIZE = 500;

    for (const status of ['pending', 'partiallyPaid']) {
      let lastOverdueDoc = null;

      while (true) {
        let query = db.collection('invoices')
          .where('status', '==', status)
          .where('dueDate', '<', today)
          .limit(OVERDUE_PAGE_SIZE);

        if (lastOverdueDoc) {
          query = query.startAfter(lastOverdueDoc);
        }

        const pageSnapshot = await query.get();
        if (pageSnapshot.empty) break;

        const writer = db.bulkWriter();

        pageSnapshot.forEach((doc) => {
          const data = doc.data();
          const dueAt = resolveDueAt(data);
          if (!dueAt || dueAt.getTime() > now.getTime()) return;

          overdueCount += 1;
          writer.update(doc.ref, {
            status: 'overdue',
            overdueMarkedAt: FieldValue.serverTimestamp(),
            overdueReason: 'scheduled_overdue_job',
          });
        });

        await writer.close();
        lastOverdueDoc = pageSnapshot.docs[pageSnapshot.docs.length - 1];
        if (pageSnapshot.size < OVERDUE_PAGE_SIZE) break;
      }
    }

    logger.info('Overdue scheduler completed', {
      overdueCount,
    });
  },
);

exports.backfillMyInvoiceData = onCall(
  { enforceAppCheck: true, memory: '512MiB', timeoutSeconds: 300 },
  async (request) => {
    const uid = request.auth && request.auth.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Sign in is required to backfill invoice data.');
    }

    // Rate-limit: allow backfill at most once per hour
    const backfillRef = db.collection('rate_limits').doc(`backfill_${uid}`);
    const backfillSnap = await backfillRef.get();
    if (backfillSnap.exists) {
      const lastRun = backfillSnap.data().lastRunAt;
      if (lastRun && Date.now() - lastRun < 3600000) {
        throw new HttpsError('resource-exhausted', 'Backfill can only be run once per hour.');
      }
    }
    await backfillRef.set({ lastRunAt: Date.now(), uid }, { merge: true });

  // Paginate: process 500 invoices at a time to avoid timeouts
  const PAGE_SIZE = 500;
  let lastDoc = null;
  const records = [];
  let normalizedInvoices = 0;

  while (true) {
    let query = db.collection('invoices')
      .where('ownerId', '==', uid)
      .orderBy('createdAt')
      .limit(PAGE_SIZE);

    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const pageSnapshot = await query.get();
    if (pageSnapshot.empty) break;

    const invoiceWriter = db.bulkWriter();

    pageSnapshot.forEach((doc) => {
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
    lastDoc = pageSnapshot.docs[pageSnapshot.docs.length - 1];

    if (pageSnapshot.size < PAGE_SIZE) break;
  }

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

// ══════════════════════════════════════════════════════════════════════════════
// TEAM MANAGEMENT — Callable Cloud Functions
// ══════════════════════════════════════════════════════════════════════════════

/**
 * Creates a team invite. Caller must be the team owner or a manager.
 * Input: { phone: string, email?: string, role: 'manager'|'sales'|'viewer' }
 */
exports.createTeamInvite = onCall({ memory: '256MiB', timeoutSeconds: 30 }, async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required.');

  await enforceRateLimit(`team_invite_${uid}`, 20, 3600000, 'Rate limit exceeded: max 20 invites per hour.');

  const { name, phone: rawPhone, email, role } = request.data || {};
  const phone = normalizePhone(rawPhone);
  const normalizedEmail = normalizeEmail(email);
  if (!name || !name.trim()) throw new HttpsError('invalid-argument', 'Member name is required.');
  if (!phone && !normalizedEmail) throw new HttpsError('invalid-argument', 'Phone or email is required.');
  if (!['coOwner', 'manager', 'sales', 'viewer'].includes(role)) {
    throw new HttpsError('invalid-argument', 'Invalid role.');
  }

  const context = await getValidatedTeamContext(uid);
  if (!context) {
    throw new HttpsError('not-found', 'You must create or join a team first.');
  }

  const canInvite = await hasPermission(
    context.teamId,
    context.memberData.role,
    'canInviteMembers',
  );
  if (!canInvite) {
    throw new HttpsError('permission-denied', 'You do not have permission to invite members.');
  }
  if (role === 'coOwner' && !isOwnerLevelRole(context.memberData.role)) {
    throw new HttpsError('permission-denied', 'Only owners and co-owners can invite co-owners.');
  }

  const teamDoc = await context.teamRef.get();
  if (!teamDoc.exists) throw new HttpsError('not-found', 'Team not found.');
  const teamData = teamDoc.data();
  if (teamData.isActive === false) {
    throw new HttpsError('failed-precondition', 'This team is not active.');
  }

  // Check member limit based on subscription plan (RC-driven)
  const planMaxMembers = await getMaxTeamMembersForOwner(context.teamId);
  const effectiveMax = planMaxMembers === -1 ? Infinity : planMaxMembers;
  if (teamData.memberCount >= effectiveMax) {
    if (planMaxMembers === 0) {
      throw new HttpsError('resource-exhausted', 'Team member limit reached. Please contact support.');
    }
    throw new HttpsError('resource-exhausted',
      `Team member limit reached (${planMaxMembers}). Please contact support to increase your limit.`);
  }

  const expiresAt = new Date();
  expiresAt.setDate(expiresAt.getDate() + 7);
  const duplicateDocs = await getPendingInviteMatches({
    teamId: context.teamId,
    phone,
    email: normalizedEmail,
  });

  const activeDuplicates = duplicateDocs.filter((doc) => !inviteIsExpired(doc.data()));

  const invitePayload = {
    teamId: context.teamId,
    teamBusinessName: teamData.businessName || '',
    invitedName: name.trim(),
    invitedPhone: phone || '',
    invitedEmail: normalizedEmail,
    role,
    status: 'pending',
    invitedBy: uid,
    invitedByName: context.memberData.displayName || teamData.ownerName || '',
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
    expiresAt: Timestamp.fromDate(expiresAt),
  };

  if (activeDuplicates.length > 0) {
    const primary = activeDuplicates[0];
    const batch = db.batch();
    batch.set(primary.ref, invitePayload, { merge: true });
    for (const staleDoc of activeDuplicates.slice(1)) {
      batch.update(staleDoc.ref, {
        status: 'expired',
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    logger.info('Team invite refreshed', { teamId: context.teamId, inviteId: primary.id, role });
    return { inviteId: primary.id, reused: true };
  }

  const inviteRef = db.collection('teamInvites').doc();
  await inviteRef.set(invitePayload);

  logger.info('Team invite created', { teamId: context.teamId, inviteId: inviteRef.id, role });
  return { inviteId: inviteRef.id, reused: false };
});

/**
 * Checks for pending invites matching the caller's phone or email.
 * Returns: { invites: [...] }
 */
exports.checkPendingInvites = onCall({ memory: '256MiB', timeoutSeconds: 15 }, async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required.');

  const { phone, email } = await getUserIdentity(uid);

  const invites = [];

  if (phone) {
    // Query with normalized phone (matches E.164 stored format)
    const byPhone = await db.collection('teamInvites')
      .where('invitedPhone', '==', phone)
      .where('status', '==', 'pending')
      .get();
    byPhone.forEach(doc => {
      const data = doc.data();
      if (!inviteIsExpired(data)) {
        invites.push(mapInviteForClient(doc));
      }
    });
  }

  if (email) {
    const byEmail = await db.collection('teamInvites')
      .where('invitedEmail', '==', email)
      .where('status', '==', 'pending')
      .get();
    byEmail.forEach(doc => {
      const data = doc.data();
      // Avoid duplicates (same invite found by phone AND email)
      if (!invites.some(i => i.id === doc.id)) {
        if (!inviteIsExpired(data)) {
          invites.push(mapInviteForClient(doc));
        }
      }
    });
  }

  invites.sort((a, b) => (b.createdAt || 0) - (a.createdAt || 0));
  return { invites };
});

/**
 * Accepts a team invite. Creates the member doc and userTeamMap atomically.
 * Input: { inviteId: string }
 */
exports.acceptTeamInvite = onCall({ memory: '256MiB', timeoutSeconds: 30 }, async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required.');

  await enforceRateLimit(`team_accept_${uid}`, 10, 3600000, 'Rate limit exceeded: max 10 invite accepts per hour.');

  const { inviteId } = request.data || {};
  if (!inviteId) throw new HttpsError('invalid-argument', 'inviteId is required.');

  const inviteRef = db.collection('teamInvites').doc(inviteId);
  const { user, phone, email } = await getUserIdentity(uid);
  let teamId = '';
  let memberName = '';
  let acceptedRole = '';

  await db.runTransaction(async (txn) => {
    const invite = await txn.get(inviteRef);
    if (!invite.exists) throw new HttpsError('not-found', 'Invite not found.');

    const inviteData = invite.data() || {};
    if (inviteData.status !== 'pending') {
      throw new HttpsError('failed-precondition', 'This invite is no longer pending.');
    }
    if (inviteIsExpired(inviteData)) {
      txn.update(inviteRef, {
        status: 'expired',
        updatedAt: FieldValue.serverTimestamp(),
      });
      throw new HttpsError('failed-precondition', 'This invite has expired.');
    }
    if (!inviteMatchesIdentity(inviteData, phone, email)) {
      throw new HttpsError('permission-denied', 'This invite is not for your account.');
    }

    teamId = inviteData.teamId || '';
    if (!teamId) throw new HttpsError('failed-precondition', 'Invite is missing a team.');

    const teamRef = db.collection('teams').doc(teamId);
    const teamDoc = await txn.get(teamRef);
    if (!teamDoc.exists) throw new HttpsError('not-found', 'Team not found.');
    const teamData = teamDoc.data() || {};
    if (teamData.isActive === false) {
      throw new HttpsError('failed-precondition', 'This team is no longer active.');
    }

    const currentCount = Number.isInteger(teamData.memberCount) ? teamData.memberCount : 0;
    // Plan-based limit: read owner subscription outside transaction (acceptable for limit check)
    const planMaxMembers = await getMaxTeamMembersForOwner(teamId);
    const effectiveMax = planMaxMembers === -1 ? Infinity : planMaxMembers;
    if (currentCount >= effectiveMax) {
      throw new HttpsError('resource-exhausted',
        'This team is full. Ask the team owner to contact support to increase the member limit.');
    }

    const memberRef = teamRef.collection('members').doc(uid);
    const currentMember = await txn.get(memberRef);
    if (currentMember.exists && currentMember.data().status === 'active') {
      throw new HttpsError('already-exists', 'You are already on this team.');
    }

    const mapRef = db.collection('userTeamMap').doc(uid);
    const existingMap = await txn.get(mapRef);
    let previousOwnerTeamId = '';
    if (existingMap.exists) {
      const mapData = existingMap.data() || {};
      const existingTeamId = mapData.teamId || '';
      if (mapData.isOwner === true && existingTeamId && existingTeamId !== teamId) {
        previousOwnerTeamId = existingTeamId;
      } else if (existingTeamId) {
        const oldMemberRef = db.collection('teams').doc(existingTeamId)
          .collection('members').doc(uid);
        const oldMemberDoc = existingTeamId === teamId
          ? currentMember
          : await txn.get(oldMemberRef);
        const isActiveOnOldTeam = oldMemberDoc.exists && oldMemberDoc.data().status === 'active';
        if (isActiveOnOldTeam) {
          throw new HttpsError(
            'already-exists',
            existingTeamId === teamId
              ? 'You are already on this team.'
              : 'You are already on a team. Leave your current team first.',
          );
        }
      }
    }

    acceptedRole = inviteData.role;
    memberName = inviteData.invitedName || user.displayName || user.phoneNumber || '';

    txn.set(memberRef, {
      uid,
      role: acceptedRole,
      displayName: memberName,
      phone: user.phoneNumber || '',
      email,
      status: 'active',
      invitedBy: inviteData.invitedBy || '',
      invitedAt: inviteData.createdAt || FieldValue.serverTimestamp(),
      joinedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    const nextMap = {
      teamId,
      role: acceptedRole,
      teamBusinessName: inviteData.teamBusinessName || teamData.businessName || '',
      isOwner: false,
      joinedAt: FieldValue.serverTimestamp(),
    };
    if (previousOwnerTeamId && previousOwnerTeamId !== teamId) {
      nextMap.previousOwnerTeamId = previousOwnerTeamId;
    }
    txn.set(mapRef, nextMap);

    txn.update(inviteRef, {
      status: 'accepted',
      acceptedBy: uid,
      acceptedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    txn.update(teamRef, {
      memberCount: FieldValue.increment(1),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  const duplicateInvites = await getPendingInviteMatches({ teamId, phone, email });
  if (duplicateInvites.length > 0) {
    const batch = db.batch();
    for (const duplicateInvite of duplicateInvites) {
      if (duplicateInvite.id === inviteId) continue;
      batch.update(duplicateInvite.ref, {
        status: 'expired',
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  // Notify team owner and managers that a new member joined
  try {
    const roleName = acceptedRole === 'coOwner' ? 'Co-Owner'
      : acceptedRole.charAt(0).toUpperCase() + acceptedRole.slice(1);
    const notifTitle = 'New team member joined';
    const notifBody = `${memberName} has joined as ${roleName}`;
    const notifData = {
      type: 'member_joined',
      title: notifTitle,
      body: notifBody,
      memberUid: uid,
      memberName,
      memberRole: acceptedRole,
      teamId,
      createdAt: FieldValue.serverTimestamp(),
      read: false,
    };

    // Collect all UIDs to notify: owner + active managers/co-owners
    const notifyUids = [teamId]; // owner
    const managers = await db.collection('teams').doc(teamId).collection('members')
      .where('status', '==', 'active')
      .where('role', 'in', ['manager', 'coOwner'])
      .get();
    for (const doc of managers.docs) {
      if (doc.id !== teamId) notifyUids.push(doc.id);
    }

    // Store Firestore notification docs + send FCM push
    const promises = [];
    for (const targetUid of notifyUids) {
      // Store in Firestore
      promises.push(
        db.collection('users').doc(targetUid).collection('notifications').add(notifData)
      );

      // Send FCM push notification
      promises.push(
        (async () => {
          try {
            const userDoc = await db.collection('users').doc(targetUid).get();
            const fcmToken = userDoc.exists && userDoc.data().fcmToken;
            if (fcmToken) {
              await admin.messaging().send({
                token: fcmToken,
                notification: { title: notifTitle, body: notifBody },
                data: { type: 'member_joined', teamId, memberName, memberRole: acceptedRole },
                android: { priority: 'high' },
              });
            }
          } catch (fcmErr) {
            logger.warn('FCM send failed for ' + targetUid, { error: fcmErr.message });
          }
        })()
      );
    }
    await Promise.all(promises);
  } catch (notifErr) {
    logger.warn('Failed to send join notification', { error: notifErr.message });
    // Non-critical — don't fail the join
  }

  logger.info('Team invite accepted', { teamId, uid, role: acceptedRole });
  writeAuditLog(teamId, 'member_joined', uid, { memberName, role: acceptedRole });
  return { teamId, role: acceptedRole, memberName };
});

/**
 * Declines a team invite.
 * Input: { inviteId: string }
 */
exports.declineTeamInvite = onCall({ memory: '256MiB', timeoutSeconds: 15 }, async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required.');

  const { inviteId } = request.data || {};
  if (!inviteId) throw new HttpsError('invalid-argument', 'inviteId is required.');

  const { phone, email } = await getUserIdentity(uid);
  const inviteRef = db.collection('teamInvites').doc(inviteId);
  const invite = await inviteRef.get();
  if (!invite.exists) throw new HttpsError('not-found', 'Invite not found.');
  const inviteData = invite.data() || {};
  if (inviteData.status !== 'pending') {
    throw new HttpsError('failed-precondition', 'This invite is no longer pending.');
  }
  if (inviteIsExpired(inviteData)) {
    await inviteRef.update({
      status: 'expired',
      updatedAt: FieldValue.serverTimestamp(),
    });
    throw new HttpsError('failed-precondition', 'This invite has expired.');
  }
  if (!inviteMatchesIdentity(inviteData, phone, email)) {
    throw new HttpsError('permission-denied', 'This invite is not for your account.');
  }

  await inviteRef.update({
    status: 'declined',
    declinedBy: uid,
    declinedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  return { success: true };
});

/**
 * Removes a team member (owner-only).
 * Input: { memberUid: string }
 */
exports.removeTeamMember = onCall({ memory: '256MiB', timeoutSeconds: 30 }, async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required.');

  await enforceRateLimit(`team_remove_${uid}`, 10, 3600000, 'Rate limit exceeded: max 10 removals per hour.');

  const { memberUid } = request.data || {};
  if (!memberUid) throw new HttpsError('invalid-argument', 'memberUid is required.');

  const context = await getValidatedTeamContext(uid);
  if (!context || !isOwnerLevelRole(context.memberData.role)) {
    throw new HttpsError('permission-denied', 'Only owners and co-owners can remove members.');
  }

  const teamId = context.teamId;
  if (memberUid === uid || memberUid === teamId) {
    throw new HttpsError('invalid-argument', 'Cannot remove yourself. Transfer ownership first.');
  }

  await db.runTransaction(async (txn) => {
    const teamRef = db.collection('teams').doc(teamId);
    const memberRef = teamRef.collection('members').doc(memberUid);
    const mapRef = db.collection('userTeamMap').doc(memberUid);

    // All reads must come before any writes in a Firestore transaction.
    const [memberDoc, mapDoc] = await Promise.all([
      txn.get(memberRef),
      txn.get(mapRef),
    ]);
    const isActiveMember = memberDoc.exists && memberDoc.data().status === 'active';

    // Pre-read previousTeam doc if needed (before any writes).
    let previousTeamDoc = null;
    const mapData = mapDoc.exists ? (mapDoc.data() || {}) : {};
    const previousOwnerTeamId = mapData.previousOwnerTeamId || '';
    if (mapDoc.exists && mapData.teamId === teamId && previousOwnerTeamId) {
      const previousTeamRef = db.collection('teams').doc(previousOwnerTeamId);
      previousTeamDoc = await txn.get(previousTeamRef);
    }

    if (!isActiveMember && !mapDoc.exists) {
      throw new HttpsError('not-found', 'Member not found.');
    }

    // Now perform all writes.
    if (isActiveMember) {
      txn.update(memberRef, {
        status: 'removed',
        updatedAt: FieldValue.serverTimestamp(),
        removedAt: FieldValue.serverTimestamp(),
        removedBy: uid,
      });
      txn.update(teamRef, {
        memberCount: FieldValue.increment(-1),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    if (mapDoc.exists && mapData.teamId === teamId) {
      if (previousOwnerTeamId && previousTeamDoc && previousTeamDoc.exists) {
        txn.set(mapRef, buildOwnerMap(
          previousOwnerTeamId,
          previousTeamDoc.data() || {},
          mapData.joinedAt || FieldValue.serverTimestamp(),
        ));
      } else {
        txn.delete(mapRef);
      }
    }
  });

  logger.info('Team member removed', { teamId, memberUid, removedBy: uid });
  writeAuditLog(teamId, 'member_removed', uid, { memberUid });
  return { success: true };
});

/**
 * Changes a team member's role.
 * Input: { memberUid: string, role: 'coOwner'|'manager'|'sales'|'viewer' }
 */
exports.changeTeamMemberRole = onCall({ memory: '256MiB', timeoutSeconds: 30 }, async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required.');

  const { memberUid, role } = request.data || {};
  if (!memberUid) throw new HttpsError('invalid-argument', 'memberUid is required.');
  if (!CONFIGURABLE_ROLES.has(role)) {
    throw new HttpsError('invalid-argument', 'Invalid role.');
  }

  const context = await getValidatedTeamContext(uid);
  if (!context || !isOwnerLevelRole(context.memberData.role)) {
    throw new HttpsError('permission-denied', 'Only owners and co-owners can change roles.');
  }

  const teamId = context.teamId;
  if (memberUid === uid) {
    throw new HttpsError('invalid-argument', 'You cannot change your own role.');
  }
  if (memberUid === teamId) {
    throw new HttpsError('failed-precondition', 'The owner role cannot be changed here.');
  }

  await db.runTransaction(async (txn) => {
    const teamRef = db.collection('teams').doc(teamId);
    const memberRef = teamRef.collection('members').doc(memberUid);
    const mapRef = db.collection('userTeamMap').doc(memberUid);

    // All reads must come before any writes in a Firestore transaction.
    const [memberDoc, mapDoc] = await Promise.all([
      txn.get(memberRef),
      txn.get(mapRef),
    ]);

    if (!memberDoc.exists) throw new HttpsError('not-found', 'Member not found.');

    const memberData = memberDoc.data() || {};
    if (memberData.status !== 'active') {
      throw new HttpsError('failed-precondition', 'Only active members can be updated.');
    }
    if ((memberData.role || '') === 'owner') {
      throw new HttpsError('failed-precondition', 'The owner role cannot be changed here.');
    }
    if ((memberData.role || '') === role) {
      return;
    }

    txn.update(memberRef, {
      role,
      updatedAt: FieldValue.serverTimestamp(),
    });

    if (mapDoc.exists && (mapDoc.data() || {}).teamId === teamId) {
      txn.set(mapRef, { role }, { merge: true });
    }
  });

  logger.info('Team member role changed', { teamId, memberUid, role, updatedBy: uid });
  writeAuditLog(teamId, 'role_changed', uid, { memberUid, newRole: role });
  return { success: true };
});

/**
 * Cancels a pending invite.
 * Input: { inviteId: string }
 */
exports.cancelTeamInvite = onCall({ memory: '256MiB', timeoutSeconds: 15 }, async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required.');

  const { inviteId } = request.data || {};
  if (!inviteId) throw new HttpsError('invalid-argument', 'inviteId is required.');

  const context = await getValidatedTeamContext(uid);
  if (!context) throw new HttpsError('failed-precondition', 'You are not on an active team.');

  const canInvite = await hasPermission(
    context.teamId,
    context.memberData.role,
    'canInviteMembers',
  );
  if (!canInvite) {
    throw new HttpsError('permission-denied', 'You do not have permission to manage invites.');
  }

  const inviteRef = db.collection('teamInvites').doc(inviteId);
  await db.runTransaction(async (txn) => {
    const inviteDoc = await txn.get(inviteRef);
    if (!inviteDoc.exists) throw new HttpsError('not-found', 'Invite not found.');

    const inviteData = inviteDoc.data() || {};
    if ((inviteData.teamId || '') !== context.teamId) {
      throw new HttpsError('permission-denied', 'This invite does not belong to your team.');
    }
    if (inviteData.status !== 'pending') {
      throw new HttpsError('failed-precondition', 'Only pending invites can be cancelled.');
    }

    txn.update(inviteRef, {
      status: 'expired',
      cancelledBy: uid,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  return { success: true };
});

/**
 * Updates permission overrides for a team role.
 * Input: { role: string, overrides: { ... } }
 */
exports.updateTeamRolePermissions = onCall({ memory: '256MiB', timeoutSeconds: 30 }, async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required.');

  const { role, overrides } = request.data || {};
  if (!role) throw new HttpsError('invalid-argument', 'role is required.');

  const context = await getValidatedTeamContext(uid);
  if (!context || !isOwnerLevelRole(context.memberData.role)) {
    throw new HttpsError('permission-denied', 'Only owners and co-owners can update role permissions.');
  }

  const cleaned = sanitizeRoleOverrides(role, overrides);
  await context.teamRef.set({
    rolePermissions: {
      [role]: cleaned,
    },
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  writeAuditLog(context.teamId, 'permissions_updated', uid, { role, overrides: cleaned });
  return { success: true, role };
});

/**
 * Updates the team office geofence.
 * Input: { latitude: number, longitude: number, radius: number, address?: string }
 */
exports.updateTeamOfficeLocation = onCall({ memory: '256MiB', timeoutSeconds: 30 }, async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required.');

  const { latitude, longitude, radius, address } = request.data || {};
  if (!isFiniteCoordinate(latitude, -90, 90) || !isFiniteCoordinate(longitude, -180, 180)) {
    throw new HttpsError('invalid-argument', 'Valid coordinates are required.');
  }
  if (!Number.isFinite(radius) || radius < 50 || radius > 500) {
    throw new HttpsError('invalid-argument', 'Radius must be between 50m and 500m.');
  }

  const context = await getValidatedTeamContext(uid);
  if (!context || !isOwnerLevelRole(context.memberData.role)) {
    throw new HttpsError('permission-denied', 'Only owners and co-owners can update the office location.');
  }

  await context.teamRef.set({
    officeLatitude: latitude,
    officeLongitude: longitude,
    officeRadius: radius,
    officeAddress: String(address || '').trim(),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  return { success: true };
});

/**
 * Current user leaves their team voluntarily.
 */
exports.leaveTeam = onCall({ memory: '256MiB', timeoutSeconds: 30 }, async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required.');

  await enforceRateLimit(`team_leave_${uid}`, 5, 3600000, 'Rate limit exceeded: max 5 leave attempts per hour.');

  const mapRef = db.collection('userTeamMap').doc(uid);
  let teamId = '';

  await db.runTransaction(async (txn) => {
    const callerMap = await txn.get(mapRef);
    if (!callerMap.exists) {
      throw new HttpsError('not-found', 'You are not on any team.');
    }

    const mapData = callerMap.data() || {};
    if (mapData.isOwner) {
      throw new HttpsError('failed-precondition', 'Team owner cannot leave. Delete or transfer the team instead.');
    }

    teamId = mapData.teamId || '';
    if (!teamId) {
      txn.delete(mapRef);
      return;
    }

    const teamRef = db.collection('teams').doc(teamId);
    const memberRef = teamRef.collection('members').doc(uid);
    const memberDoc = await txn.get(memberRef);
    const isActiveMember = memberDoc.exists && memberDoc.data().status === 'active';

    if (isActiveMember) {
      txn.update(memberRef, {
        status: 'removed',
        updatedAt: FieldValue.serverTimestamp(),
        removedAt: FieldValue.serverTimestamp(),
      });
      txn.update(teamRef, {
        memberCount: FieldValue.increment(-1),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    const previousOwnerTeamId = mapData.previousOwnerTeamId || '';
    if (previousOwnerTeamId) {
      const previousTeamRef = db.collection('teams').doc(previousOwnerTeamId);
      const previousTeamDoc = await txn.get(previousTeamRef);
      if (previousTeamDoc.exists) {
        txn.set(mapRef, buildOwnerMap(
          previousOwnerTeamId,
          previousTeamDoc.data() || {},
          mapData.joinedAt || FieldValue.serverTimestamp(),
        ));
      } else {
        txn.delete(mapRef);
      }
    } else {
      txn.delete(mapRef);
    }
  });

  logger.info('Team member left', { teamId, uid });
  writeAuditLog(teamId, 'member_left', uid, {});
  return { success: true };
});

/**
 * Geo check-in for a team member.
 * Input: { latitude: number, longitude: number }
 */
exports.teamGeoCheckIn = onCall({ memory: '256MiB', timeoutSeconds: 30 }, async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required.');

  const { latitude, longitude } = request.data || {};
  if (!isFiniteCoordinate(latitude, -90, 90) || !isFiniteCoordinate(longitude, -180, 180)) {
    throw new HttpsError('invalid-argument', 'Valid coordinates are required.');
  }

  const context = await getValidatedTeamContext(uid);
  if (!context) throw new HttpsError('failed-precondition', 'You are not on an active team.');

  const canMarkAttendance = await hasPermission(
    context.teamId,
    context.memberData.role,
    'canMarkAttendance',
  );
  if (!canMarkAttendance) {
    throw new HttpsError('permission-denied', 'You do not have permission to mark attendance.');
  }

  const teamDoc = await context.teamRef.get();
  if (!teamDoc.exists) throw new HttpsError('not-found', 'Team not found.');
  const teamData = teamDoc.data() || {};
  if (!Number.isFinite(teamData.officeLatitude) || !Number.isFinite(teamData.officeLongitude)) {
    throw new HttpsError('failed-precondition', 'Office location is not configured.');
  }

  const distance = distanceMeters(
    latitude,
    longitude,
    teamData.officeLatitude,
    teamData.officeLongitude,
  );
  const officeRadius = Number.isFinite(teamData.officeRadius) ? teamData.officeRadius : 200;
  if (distance > officeRadius) {
    throw new HttpsError('permission-denied', 'You must be inside the office geofence to check in.');
  }

  const startOfDay = Timestamp.fromDate(
    new Date(new Date().getFullYear(), new Date().getMonth(), new Date().getDate()),
  );
  const attendanceRef = context.memberRef.collection('attendance');
  const existingSnap = await attendanceRef
    .where('checkInTime', '>=', startOfDay)
    .orderBy('checkInTime', 'desc')
    .limit(1)
    .get();
  if (!existingSnap.empty && !existingSnap.docs[0].data().checkOutTime) {
    throw new HttpsError('failed-precondition', 'You are already checked in.');
  }

  const now = Timestamp.now();
  const docRef = attendanceRef.doc();
  await docRef.set({
    memberId: uid,
    memberName: context.memberData.displayName || '',
    checkInTime: now,
    method: 'geo',
    attendanceDomain: 'team',
    markedBy: uid,
    latitude,
    longitude,
  });

  return { logId: docRef.id, checkInTime: now.toMillis() };
});

/**
 * Geo check-out for a team member.
 * Input: { logId: string }
 */
exports.teamGeoCheckOut = onCall({ memory: '256MiB', timeoutSeconds: 30 }, async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required.');

  const { logId } = request.data || {};
  if (!logId) throw new HttpsError('invalid-argument', 'logId is required.');

  const context = await getValidatedTeamContext(uid);
  if (!context) throw new HttpsError('failed-precondition', 'You are not on an active team.');

  const canMarkAttendance = await hasPermission(
    context.teamId,
    context.memberData.role,
    'canMarkAttendance',
  );
  if (!canMarkAttendance) {
    throw new HttpsError('permission-denied', 'You do not have permission to mark attendance.');
  }

  const attendanceRef = context.memberRef.collection('attendance').doc(logId);
  const attendanceDoc = await attendanceRef.get();
  if (!attendanceDoc.exists) throw new HttpsError('not-found', 'Attendance log not found.');

  const attendanceData = attendanceDoc.data() || {};
  if ((attendanceData.memberId || '') !== uid) {
    throw new HttpsError('permission-denied', 'This attendance log does not belong to you.');
  }
  if (attendanceData.checkOutTime) {
    throw new HttpsError('failed-precondition', 'You are already checked out.');
  }

  await attendanceRef.update({
    checkOutTime: Timestamp.now(),
  });

  return { success: true };
});

// ══════════════════════════════════════════════════════════════════════════════
// MEMBERSHIP MANAGEMENT — Callable Cloud Functions
// ══════════════════════════════════════════════════════════════════════════════

exports.saveMembershipPlan = onCall({ memory: '256MiB', timeoutSeconds: 30 }, async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required.');

  const { planId = '', plan = {} } = request.data || {};
  const context = await getMembershipAccessContext(uid, { requireOwnerLevel: true });
  const plansCol = context.ownerRef.collection('subscription_plans');
  const ref = planId ? plansCol.doc(String(planId)) : plansCol.doc();
  const cleaned = sanitizeMembershipPlanPayload(plan);
  const now = FieldValue.serverTimestamp();

  if (planId) {
    const existingDoc = await ref.get();
    if (!existingDoc.exists) {
      throw new HttpsError('not-found', 'Membership plan not found.');
    }
    const existingData = existingDoc.data() || {};
    if (existingData.isDeleted === true) {
      throw new HttpsError('failed-precondition', 'Deleted plans cannot be edited.');
    }

    await ref.set({
      ownerId: context.ownerId,
      name: cleaned.name,
      nameLower: cleaned.name.toLowerCase(),
      description: cleaned.description,
      benefits: cleaned.benefits,
      duration: cleaned.duration,
      customDays: cleaned.customDays,
      price: cleaned.price,
      joiningFee: cleaned.joiningFee,
      discountPercent: cleaned.discountPercent,
      gracePeriodDays: cleaned.gracePeriodDays,
      planType: cleaned.planType,
      autoRenew: cleaned.autoRenew,
      isActive: cleaned.isActive,
      isDeleted: false,
      memberCount: Number.isInteger(existingData.memberCount) ? existingData.memberCount : 0,
      colorHex: cleaned.colorHex,
      gstEnabled: cleaned.gstEnabled,
      gstRate: cleaned.gstRate,
      gstType: cleaned.gstType,
      createdAt: existingData.createdAt || now,
      updatedAt: now,
    }, { merge: false });
  } else {
    await ref.set({
      ownerId: context.ownerId,
      name: cleaned.name,
      nameLower: cleaned.name.toLowerCase(),
      description: cleaned.description,
      benefits: cleaned.benefits,
      duration: cleaned.duration,
      customDays: cleaned.customDays,
      price: cleaned.price,
      joiningFee: cleaned.joiningFee,
      discountPercent: cleaned.discountPercent,
      gracePeriodDays: cleaned.gracePeriodDays,
      planType: cleaned.planType,
      autoRenew: cleaned.autoRenew,
      isActive: cleaned.isActive,
      isDeleted: false,
      memberCount: 0,
      colorHex: cleaned.colorHex,
      gstEnabled: cleaned.gstEnabled,
      gstRate: cleaned.gstRate,
      gstType: cleaned.gstType,
      createdAt: now,
      updatedAt: now,
    });
  }

  await writeMembershipAuditIfNeeded(context, 'membership_plan_saved', {
    planId: ref.id,
    created: !planId,
  });
  return { planId: ref.id };
});

exports.deleteMembershipPlan = onCall({ memory: '256MiB', timeoutSeconds: 30 }, async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required.');

  const { planId } = request.data || {};
  if (!planId) throw new HttpsError('invalid-argument', 'planId is required.');

  const context = await getMembershipAccessContext(uid, { requireOwnerLevel: true });
  const ref = context.ownerRef.collection('subscription_plans').doc(String(planId));
  const doc = await ref.get();
  if (!doc.exists) throw new HttpsError('not-found', 'Membership plan not found.');

  await ref.set({
    isDeleted: true,
    isActive: false,
    deletedAt: FieldValue.serverTimestamp(),
    deletedBy: uid,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  await writeMembershipAuditIfNeeded(context, 'membership_plan_deleted', { planId: ref.id });
  return { success: true };
});

exports.setMembershipPlanActive = onCall({ memory: '256MiB', timeoutSeconds: 15 }, async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required.');

  const { planId, isActive } = request.data || {};
  if (!planId || typeof isActive !== 'boolean') {
    throw new HttpsError('invalid-argument', 'planId and isActive are required.');
  }

  const context = await getMembershipAccessContext(uid, { requireOwnerLevel: true });
  const ref = context.ownerRef.collection('subscription_plans').doc(String(planId));
  const doc = await ref.get();
  if (!doc.exists) throw new HttpsError('not-found', 'Membership plan not found.');
  if ((doc.data() || {}).isDeleted === true) {
    throw new HttpsError('failed-precondition', 'Deleted plans cannot be activated.');
  }

  await ref.set({
    isActive,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  await writeMembershipAuditIfNeeded(context, 'membership_plan_visibility_changed', {
    planId: ref.id,
    isActive,
  });
  return { success: true };
});

exports.saveMembershipMember = onCall({ memory: '256MiB', timeoutSeconds: 30 }, async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required.');

  const { memberId = '', member = {} } = request.data || {};
  const context = await getMembershipAccessContext(uid, { requireOwnerLevel: true });
  const cleaned = sanitizeMembershipMemberPayload(member);
  const membersCol = context.ownerRef.collection('members');
  const plansCol = context.ownerRef.collection('subscription_plans');
  const memberRef = memberId ? membersCol.doc(String(memberId)) : membersCol.doc();

  await db.runTransaction(async (txn) => {
    const nextPlanRef = plansCol.doc(cleaned.planId);
    const nextPlanDoc = await txn.get(nextPlanRef);
    if (!nextPlanDoc.exists) {
      throw new HttpsError('not-found', 'Selected membership plan was not found.');
    }
    const nextPlanData = nextPlanDoc.data() || {};

    let existingData = null;
    let changingPlan = false;
    if (memberId) {
      const existingDoc = await txn.get(memberRef);
      if (!existingDoc.exists) {
        throw new HttpsError('not-found', 'Membership member not found.');
      }
      existingData = existingDoc.data() || {};
      if (existingData.isDeleted === true) {
        throw new HttpsError('failed-precondition', 'Deleted members cannot be edited.');
      }
      changingPlan = (existingData.planId || '') !== cleaned.planId;
    }

    if ((nextPlanData.isDeleted === true || nextPlanData.isActive === false) && (!existingData || changingPlan)) {
      throw new HttpsError('failed-precondition', 'The selected membership plan is not active.');
    }

    const snapshot = buildMembershipPlanSnapshot(cleaned.planId, nextPlanData);
    let status = existingData && MEMBERSHIP_MEMBER_STATUSES.has(existingData.status)
      ? existingData.status
      : 'active';
    if (!memberId) {
      status = 'active';
    } else if (status !== 'cancelled' && status !== 'frozen') {
      status = cleaned.endDate.toMillis() < Date.now() ? 'expired' : 'active';
    }

    txn.set(memberRef, {
      ownerId: context.ownerId,
      name: cleaned.name,
      nameLower: cleaned.name.toLowerCase(),
      phone: cleaned.phone,
      email: cleaned.email,
      photoUrl: existingData && typeof existingData.photoUrl === 'string' ? existingData.photoUrl : '',
      notes: cleaned.notes,
      planId: cleaned.planId,
      planName: nextPlanData.name || '',
      status,
      startDate: cleaned.startDate,
      endDate: cleaned.endDate,
      frozenUntil: status === 'frozen' && existingData ? existingData.frozenUntil || null : null,
      freezeStartedAt: status === 'frozen' && existingData ? existingData.freezeStartedAt || null : null,
      autoRenew: nextPlanData.planType === 'package' ? false : cleaned.autoRenew,
      amountPaid: cleaned.amountPaid,
      joiningFeePaid: cleaned.joiningFeePaid,
      attendanceCount: existingData && Number.isInteger(existingData.attendanceCount)
        ? existingData.attendanceCount
        : 0,
      lastCheckIn: existingData ? existingData.lastCheckIn || null : null,
      isDeleted: false,
      ...snapshot,
      createdAt: existingData ? existingData.createdAt || FieldValue.serverTimestamp() : FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: false });

    if (!existingData) {
      txn.set(nextPlanRef, {
        memberCount: FieldValue.increment(1),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      return;
    }

    if (changingPlan) {
      const oldPlanId = String(existingData.planId || '').trim();
      if (oldPlanId) {
        txn.set(plansCol.doc(oldPlanId), {
          memberCount: FieldValue.increment(-1),
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      }
      txn.set(nextPlanRef, {
        memberCount: FieldValue.increment(1),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    }
  });

  await writeMembershipAuditIfNeeded(context, 'membership_member_saved', {
    memberId: memberRef.id,
    created: !memberId,
  });
  return { memberId: memberRef.id };
});

exports.deleteMembershipMember = onCall({ memory: '256MiB', timeoutSeconds: 30 }, async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required.');

  const { memberId } = request.data || {};
  if (!memberId) throw new HttpsError('invalid-argument', 'memberId is required.');

  const context = await getMembershipAccessContext(uid, { requireOwnerLevel: true });
  const memberRef = context.ownerRef.collection('members').doc(String(memberId));
  const plansCol = context.ownerRef.collection('subscription_plans');

  await db.runTransaction(async (txn) => {
    const memberDoc = await txn.get(memberRef);
    if (!memberDoc.exists) throw new HttpsError('not-found', 'Membership member not found.');

    const memberData = memberDoc.data() || {};
    if (memberData.isDeleted === true) {
      return;
    }

    txn.set(memberRef, {
      isDeleted: true,
      status: 'cancelled',
      deletedAt: FieldValue.serverTimestamp(),
      deletedBy: uid,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    const planId = String(memberData.planId || '').trim();
    if (planId) {
      txn.set(plansCol.doc(planId), {
        memberCount: FieldValue.increment(-1),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    }
  });

  await writeMembershipAuditIfNeeded(context, 'membership_member_deleted', { memberId });
  return { success: true };
});

exports.freezeMembershipMember = onCall({ memory: '256MiB', timeoutSeconds: 30 }, async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required.');

  const { memberId, freezeUntilMs } = request.data || {};
  if (!memberId) throw new HttpsError('invalid-argument', 'memberId is required.');

  const freezeUntil = requireTimestampFromMillis(freezeUntilMs, 'freezeUntilMs');
  const context = await getMembershipAccessContext(uid, { requireOwnerLevel: true });
  const memberRef = context.ownerRef.collection('members').doc(String(memberId));
  const memberDoc = await memberRef.get();
  if (!memberDoc.exists) throw new HttpsError('not-found', 'Membership member not found.');

  const memberData = memberDoc.data() || {};
  if (memberData.isDeleted === true) {
    throw new HttpsError('failed-precondition', 'Deleted members cannot be frozen.');
  }
  if (freezeUntil.toMillis() <= Date.now()) {
    throw new HttpsError('invalid-argument', 'freezeUntilMs must be in the future.');
  }

  const endDate = memberData.endDate && typeof memberData.endDate.toMillis === 'function'
    ? memberData.endDate.toMillis()
    : 0;
  if (endDate > 0 && freezeUntil.toMillis() > endDate + (90 * MEMBERSHIP_MS_PER_DAY)) {
    throw new HttpsError('invalid-argument', 'Freeze date cannot be more than 90 days beyond the membership end date.');
  }

  await memberRef.set({
    status: 'frozen',
    frozenUntil: freezeUntil,
    freezeStartedAt: memberData.status === 'frozen' && memberData.freezeStartedAt
      ? memberData.freezeStartedAt
      : FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  await writeMembershipAuditIfNeeded(context, 'membership_member_frozen', { memberId });
  return { freezeUntil: freezeUntil.toMillis() };
});

exports.unfreezeMembershipMember = onCall({ memory: '256MiB', timeoutSeconds: 30 }, async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required.');

  const { memberId } = request.data || {};
  if (!memberId) throw new HttpsError('invalid-argument', 'memberId is required.');

  const context = await getMembershipAccessContext(uid, { requireOwnerLevel: true });
  const memberRef = context.ownerRef.collection('members').doc(String(memberId));
  const memberDoc = await memberRef.get();
  if (!memberDoc.exists) throw new HttpsError('not-found', 'Membership member not found.');

  const memberData = memberDoc.data() || {};
  if (memberData.isDeleted === true) {
    throw new HttpsError('failed-precondition', 'Deleted members cannot be unfrozen.');
  }
  if (memberData.status !== 'frozen' || !memberData.frozenUntil) {
    throw new HttpsError('failed-precondition', 'Membership is not currently frozen.');
  }

  const extensionDays = computeFrozenExtensionDays(memberData, new Date());
  const newEndDate = memberData.endDate && typeof memberData.endDate.toDate === 'function'
    ? memberData.endDate.toDate()
    : new Date();
  newEndDate.setDate(newEndDate.getDate() + extensionDays);
  const nextStatus = newEndDate.getTime() < Date.now() ? 'expired' : 'active';

  await memberRef.set({
    status: nextStatus,
    frozenUntil: FieldValue.delete(),
    freezeStartedAt: FieldValue.delete(),
    endDate: Timestamp.fromDate(newEndDate),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  await writeMembershipAuditIfNeeded(context, 'membership_member_unfrozen', { memberId });
  return { newEndDate: newEndDate.getTime() };
});

exports.renewMembershipMember = onCall({ memory: '256MiB', timeoutSeconds: 30 }, async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required.');

  const { memberId } = request.data || {};
  if (!memberId) throw new HttpsError('invalid-argument', 'memberId is required.');

  const context = await getMembershipAccessContext(uid, { requireOwnerLevel: true });
  const memberRef = context.ownerRef.collection('members').doc(String(memberId));
  const memberDoc = await memberRef.get();
  if (!memberDoc.exists) throw new HttpsError('not-found', 'Membership member not found.');

  const memberData = memberDoc.data() || {};
  if (memberData.isDeleted === true) {
    throw new HttpsError('failed-precondition', 'Deleted members cannot be renewed.');
  }

  let renewalAmount = requireFiniteCurrency(memberData.planEffectivePrice || memberData.amountPaid || 0, 'renewalAmount');
  let durationDays = requireFiniteInteger(
    memberData.planDurationDays || 30,
    'planDurationDays',
    1,
    MEMBERSHIP_MAX_DURATION_DAYS,
  );

  const planId = String(memberData.planId || '').trim();
  if (planId) {
    const planDoc = await context.ownerRef.collection('subscription_plans').doc(planId).get();
    if (planDoc.exists && (planDoc.data() || {}).isDeleted !== true) {
      const planData = planDoc.data() || {};
      renewalAmount = computePlanEffectivePrice(planData);
      durationDays = computeMembershipDurationDays(planData);
      await memberRef.set({
        planName: planData.name || memberData.planName || '',
        ...buildMembershipPlanSnapshot(planId, planData),
      }, { merge: true });
    }
  }

  const now = new Date();
  const baseDate = memberData.endDate && typeof memberData.endDate.toDate === 'function'
    ? memberData.endDate.toDate()
    : now;
  const renewalBase = baseDate.getTime() > now.getTime() ? baseDate : now;
  const newEndDate = new Date(renewalBase);
  newEndDate.setDate(newEndDate.getDate() + durationDays);

  await memberRef.set({
    status: 'active',
    frozenUntil: FieldValue.delete(),
    freezeStartedAt: FieldValue.delete(),
    endDate: Timestamp.fromDate(newEndDate),
    amountPaid: FieldValue.increment(renewalAmount),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  await writeMembershipAuditIfNeeded(context, 'membership_member_renewed', {
    memberId,
    renewalAmount,
  });
  return {
    success: true,
    memberId,
    renewalAmount,
    newEndDate: newEndDate.getTime(),
  };
});

exports.markMembershipAttendance = onCall({ memory: '256MiB', timeoutSeconds: 30 }, async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in required.');

  const { memberId, method } = request.data || {};
  if (!memberId) throw new HttpsError('invalid-argument', 'memberId is required.');
  const attendanceMethod = ['manual', 'qr', 'code'].includes(String(method || 'manual'))
    ? String(method || 'manual')
    : 'manual';

  const context = await getMembershipAccessContext(uid, { requireOwnerLevel: true });

  const memberRef = context.ownerRef.collection('members').doc(String(memberId));
  const dayKey = new Intl.DateTimeFormat('en-CA', {
    timeZone: INDIA_TIME_ZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date());
  const attendanceRef = memberRef.collection('attendance').doc(dayKey);
  const now = Timestamp.now();

  await db.runTransaction(async (txn) => {
    const memberDoc = await txn.get(memberRef);
    if (!memberDoc.exists) throw new HttpsError('not-found', 'Membership member not found.');

    const memberData = memberDoc.data() || {};
    if (memberData.isDeleted === true) {
      throw new HttpsError('failed-precondition', 'Deleted members cannot be checked in.');
    }
    if ((memberData.status || 'active') !== 'active') {
      throw new HttpsError('failed-precondition', 'Only active members can be checked in.');
    }
    const endDate = memberData.endDate && typeof memberData.endDate.toMillis === 'function'
      ? memberData.endDate.toMillis()
      : 0;
    if (endDate > 0 && endDate < Date.now()) {
      throw new HttpsError('failed-precondition', 'Membership has already expired.');
    }

    const attendanceDoc = await txn.get(attendanceRef);
    if (attendanceDoc.exists) {
      throw new HttpsError('failed-precondition', 'Attendance has already been recorded for today.');
    }

    txn.set(attendanceRef, {
      memberId: memberRef.id,
      memberName: memberData.name || '',
      checkInTime: now,
      method: attendanceMethod,
      attendanceDomain: 'membership',
      markedBy: context.ownerId,
      actorUid: uid,
    });
    txn.set(memberRef, {
      attendanceCount: FieldValue.increment(1),
      lastCheckIn: now,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  });

  await writeMembershipAuditIfNeeded(context, 'membership_attendance_marked', {
    memberId,
    method: attendanceMethod,
  });
  return {
    success: true,
    logId: dayKey,
    checkInTime: now.toMillis(),
  };
});

/**
 * Periodically synchronizes membership status transitions that depend on time.
 */
exports.syncMembershipStates = onSchedule(
  { schedule: 'every 6 hours', timeZone: INDIA_TIME_ZONE },
  async () => {
    const now = Timestamp.now();
    const nowDate = now.toDate();
    const PAGE_SIZE = 500;
    let updatedExpired = 0;
    let resumedFrozen = 0;

    let lastExpiredDoc = null;
    while (true) {
      let query = db.collectionGroup('members')
        .where('status', '==', 'active')
        .where('endDate', '<', now)
        .orderBy('endDate')
        .orderBy(FieldPath.documentId())
        .limit(PAGE_SIZE);

      if (lastExpiredDoc) query = query.startAfter(lastExpiredDoc);

      const snap = await query.get();
      if (snap.empty) break;

      const writer = db.bulkWriter();
      snap.docs.forEach((doc) => {
        writer.set(doc.ref, {
          status: 'expired',
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
        updatedExpired += 1;
      });
      await writer.close();

      if (snap.size < PAGE_SIZE) break;
      lastExpiredDoc = snap.docs[snap.docs.length - 1];
    }

    let lastFrozenDoc = null;
    while (true) {
      let query = db.collectionGroup('members')
        .where('status', '==', 'frozen')
        .where('frozenUntil', '<=', now)
        .orderBy('frozenUntil')
        .orderBy(FieldPath.documentId())
        .limit(PAGE_SIZE);

      if (lastFrozenDoc) query = query.startAfter(lastFrozenDoc);

      const snap = await query.get();
      if (snap.empty) break;

      const writer = db.bulkWriter();
      snap.docs.forEach((doc) => {
        const data = doc.data() || {};
        const extensionDays = computeFrozenExtensionDays(data, nowDate);
        const newEndDate = data.endDate && typeof data.endDate.toDate === 'function'
          ? data.endDate.toDate()
          : nowDate;
        newEndDate.setDate(newEndDate.getDate() + extensionDays);
        writer.set(doc.ref, {
          status: newEndDate.getTime() < nowDate.getTime() ? 'expired' : 'active',
          frozenUntil: FieldValue.delete(),
          freezeStartedAt: FieldValue.delete(),
          endDate: Timestamp.fromDate(newEndDate),
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
        resumedFrozen += 1;
      });
      await writer.close();

      if (snap.size < PAGE_SIZE) break;
      lastFrozenDoc = snap.docs[snap.docs.length - 1];
    }

    logger.info('Membership states synchronized', {
      updatedExpired,
      resumedFrozen,
    });
  },
);

/**
 * Daily cleanup of expired team invites.
 */
exports.cleanupExpiredTeamInvites = onSchedule(
  { schedule: 'every day 03:00', timeZone: INDIA_TIME_ZONE },
  async () => {
    const now = Timestamp.now();
    const PAGE_SIZE = 500;
    let lastDoc = null;
    let expiredCount = 0;

    while (true) {
      let query = db.collection('teamInvites')
        .where('status', '==', 'pending')
        .where('expiresAt', '<', now)
        .orderBy('expiresAt')
        .orderBy(FieldPath.documentId())
        .limit(PAGE_SIZE);

      if (lastDoc) query = query.startAfter(lastDoc);

      const snap = await query.get();
      if (snap.empty) break;

      const writer = db.bulkWriter();
      snap.forEach(doc => {
        expiredCount++;
        writer.update(doc.ref, { status: 'expired' });
      });
      await writer.close();

      lastDoc = snap.docs[snap.docs.length - 1];
      if (snap.size < PAGE_SIZE) break;
    }

    logger.info('Cleaned up expired team invites', { expiredCount });
  }
);

/**
 * Scheduled cleanup for expired shared invoice links.
 * Runs daily, deletes shared_invoices docs past their expiresAt date
 * and their associated Storage PDFs.
 */
exports.cleanupExpiredSharedInvoices = onSchedule(
  { schedule: 'every day 04:00', timeZone: INDIA_TIME_ZONE },
  async () => {
    const now = Timestamp.now();
    const PAGE_SIZE = 200;
    let lastDoc = null;
    let deletedCount = 0;

    while (true) {
      let query = db.collection('shared_invoices')
        .where('expiresAt', '<', now)
        .orderBy('expiresAt')
        .orderBy(FieldPath.documentId())
        .limit(PAGE_SIZE);

      if (lastDoc) query = query.startAfter(lastDoc);

      const snap = await query.get();
      if (snap.empty) break;

      const writer = db.bulkWriter();
      for (const doc of snap.docs) {
        deletedCount++;
        // Delete the Storage PDF if a downloadUrl exists
        const data = doc.data();
        const storagePath = resolveSharedInvoiceStoragePath(data);
        if (storagePath) {
          try {
            await admin.storage().bucket().file(storagePath).delete().catch(() => {});
          } catch (_) { /* ignore deletion failures */ }
        }
        writer.delete(doc.ref);
      }
      await writer.close();

      lastDoc = snap.docs[snap.docs.length - 1];
      if (snap.size < PAGE_SIZE) break;
    }

    logger.info('Cleaned up expired shared invoices', { deletedCount });
  }
);

// ══════════════════════════════════════════════════════════════════════════════
// END TEAM MANAGEMENT
// ══════════════════════════════════════════════════════════════════════════════

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
  // If client already wrote financial totals that satisfy the invariant, skip overwriting them.
  // This prevents the server from corrupting correct client-side calculations.
  const clientGrand = toNumber(raw.grandTotal);
  const clientTaxable = toNumber(raw.taxableAmount);
  const clientTax = toNumber(raw.totalTax);
  const clientSub = toNumber(raw.subtotal);
  const clientDisc = toNumber(raw.discountAmount);
  if (clientGrand > 0 &&
      roundMoney(clientGrand) === roundMoney(clientTaxable + clientTax) &&
      roundMoney(clientTaxable) === roundMoney(clientSub - clientDisc)) {
    // Client totals are internally consistent — only normalize non-financial fields
    const financialKeys = new Set([
      'subtotal', 'discountAmount', 'taxableAmount',
      'cgstAmount', 'sgstAmount', 'igstAmount', 'totalTax', 'grandTotal',
    ]);
    return Object.keys(derivedPatch)
      .filter((key) => !financialKeys.has(key))
      .some((key) => !valuesMatch(raw[key], derivedPatch[key]));
  }
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
  const gstRate = toNumber(raw.gstRate) > 0 ? toNumber(raw.gstRate) : 18.0;
  const gstType = normalizeGstType(raw.gstType);

  // Per-item GST calculation: each item can have its own gstRate
  let totalItemTax = 0;
  if (gstEnabled) {
    for (const item of items) {
      const itemTotal = lineItemTotal(item);
      // Apply discount proportionally to get per-item taxable amount
      const itemTaxable = subtotal > 0 ? itemTotal * (taxableAmount / subtotal) : 0;
      const itemGstRate = toNumber(item.gstRate || item.gstPercent || raw.gstRate || 18);
      totalItemTax += itemTaxable * itemGstRate / 100;
    }
  }
  totalItemTax = roundMoney(totalItemTax);

  const cgstAmount = roundMoney(gstEnabled && gstType === 'cgst_sgst' ? totalItemTax / 2 : 0);
  const sgstAmount = roundMoney(cgstAmount);
  const igstAmount = roundMoney(gstEnabled && gstType === 'igst' ? totalItemTax : 0);
  const totalTax = roundMoney(cgstAmount + sgstAmount + igstAmount);
  const grandTotal = roundMoney(taxableAmount + totalTax);
  const dueAt = resolveDueAt(raw, createdAt);
  const invoiceNumber = safeString(raw.invoiceNumber);
  const clientName = safeString(raw.clientName, raw.clientId);
  const customerGstin = safeString(raw.customerGstin);
  const placeOfSupply = safeString(raw.placeOfSupply);

  // GSTR-1 classification: B2B if customer has valid GSTIN, else B2C
  const gstTransactionType = customerGstin.length >= 15 ? 'B2B' : 'B2C';

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
      gstTransactionType,
      customerGstin,
      placeOfSupply,
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
      gstTransactionType,
      schemaVersion: 3,
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

  const qty = toNumber(item.quantity);
  const unitPrice = toNumber(item.unitPrice);
  const discountPercent = toNumber(item.discountPercent || item.discount);
  const base = qty * unitPrice;
  return roundMoney(discountPercent > 0 ? base * (1 - discountPercent / 100) : base);
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
  // Firestore rules allow 'partiallyPaid' — preserve it (don't collapse to 'pending')
  if (status === 'partiallypaid') {
    return 'partiallyPaid';
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

function parseInvoiceNumber(rawInvoiceNumber) {
  const normalized = safeString(rawInvoiceNumber).toUpperCase();
  const match = new RegExp(`^${INVOICE_PREFIX}-(\\d{4})-(\\d{1,9})$`).exec(normalized);
  if (!match) {
    return null;
  }

  const year = parseYear(match[1]);
  const sequence = Number.parseInt(match[2], 10);
  if (!Number.isInteger(sequence) || sequence <= 0) {
    return null;
  }

  return {
    year,
    sequence,
    invoiceNumber: formatInvoiceNumber(year, sequence),
  };
}

async function claimCanonicalInvoiceNumber({
  ownerId,
  invoiceId,
  rawInvoiceNumber,
  createdAt,
}) {
  const preferred = parseInvoiceNumber(rawInvoiceNumber);
  const fallbackYear = preferred && preferred.year
    ? preferred.year
    : getIndianDateParts(createdAt || new Date()).year;
  const counterRef = db
    .collection(COUNTERS_COLLECTION)
    .doc(ownerId)
    .collection('years')
    .doc(String(fallbackYear));

  return db.runTransaction(async (transaction) => {
    const counterSnap = await transaction.get(counterRef);
    const currentNextSequence =
      counterSnap.exists && Number.isInteger(counterSnap.data().nextSequence)
        ? counterSnap.data().nextSequence
        : 1;

    if (preferred && preferred.year === fallbackYear) {
      const preferredClaimRef = counterRef.collection('claims').doc(preferred.invoiceNumber);
      const preferredClaimSnap = await transaction.get(preferredClaimRef);

      if (!preferredClaimSnap.exists) {
        transaction.set(preferredClaimRef, {
          ownerId,
          invoiceId,
          invoiceNumber: preferred.invoiceNumber,
          year: preferred.year,
          sequence: preferred.sequence,
          claimedAt: FieldValue.serverTimestamp(),
        });
        transaction.set(counterRef, {
          ownerId,
          year: preferred.year,
          nextSequence: Math.max(currentNextSequence, preferred.sequence + 1),
          lastIssuedSequence: preferred.sequence,
          lastIssuedInvoiceNumber: preferred.invoiceNumber,
          lastIssuedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
        return {
          invoiceNumber: preferred.invoiceNumber,
          sequence: preferred.sequence,
          year: preferred.year,
          changed: preferred.invoiceNumber !== safeString(rawInvoiceNumber),
        };
      }

      const preferredClaimData = preferredClaimSnap.data() || {};
      if (safeString(preferredClaimData.invoiceId) === invoiceId) {
        return {
          invoiceNumber: preferred.invoiceNumber,
          sequence: preferred.sequence,
          year: preferred.year,
          changed: preferred.invoiceNumber !== safeString(rawInvoiceNumber),
        };
      }
    }

    const sequence = currentNextSequence;
    const canonicalInvoiceNumber = formatInvoiceNumber(fallbackYear, sequence);
    const claimRef = counterRef.collection('claims').doc(canonicalInvoiceNumber);
    transaction.set(claimRef, {
      ownerId,
      invoiceId,
      invoiceNumber: canonicalInvoiceNumber,
      year: fallbackYear,
      sequence,
      claimedAt: FieldValue.serverTimestamp(),
    });
    transaction.set(counterRef, {
      ownerId,
      year: fallbackYear,
      nextSequence: sequence + 1,
      lastIssuedSequence: sequence,
      lastIssuedInvoiceNumber: canonicalInvoiceNumber,
      lastIssuedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    return {
      invoiceNumber: canonicalInvoiceNumber,
      sequence,
      year: fallbackYear,
      changed: canonicalInvoiceNumber !== safeString(rawInvoiceNumber),
    };
  });
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
const {
  getSubscriptionTotalCount,
  hasPaidAppAccessStatus,
  isOpenSubscriptionStatus,
  isTerminalRazorpayCancellationError,
  normalizeSubscriptionStatus,
} = require('./subscription_logic');

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

// ── Pricing & config ──────────────────────────────────────────────────────────
//
// Source of truth:
//   • Firebase Remote Config    → display prices and billing durations
//                                  Change in RC console updates both app and server.
//   • Firestore config/pricing  → backward-compatible fallback for old operators.
//
// Defaults are used only when both sources are unavailable.
const DEFAULT_PRICING = {
  pro_monthly_paise: 5900,        // ₹59/mo
  pro_annual_paise: 49900,        // ₹499/yr
  enterprise_monthly_paise: 9900, // ₹99/mo
  enterprise_annual_paise: 99900, // ₹999/yr
};
const DEFAULT_DURATIONS = {
  trial_duration_months: 6,
  grace_period_days: 7,
};

let _rcTemplateCache = null;
let _rcTemplateCacheTime = 0;

// ── Remote Config cache (billing values) ──────────────────────────────────────
let _rcBillingCache = null;
let _rcBillingCacheTime = 0;

// ── Firestore pricing cache (payment amounts) ─────────────────────────────────
let _pricingCache = null;
let _pricingCacheTime = 0;

const PRICING_CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes

async function getCachedRemoteConfigTemplate() {
  const now = Date.now();
  if (_rcTemplateCache && (now - _rcTemplateCacheTime) < PRICING_CACHE_TTL_MS) {
    return _rcTemplateCache;
  }

  try {
    _rcTemplateCache = await admin.remoteConfig().getTemplate();
    _rcTemplateCacheTime = now;
    return _rcTemplateCache;
  } catch (e) {
    if (_rcTemplateCache) {
      logger.warn('[RC] Failed to refresh Remote Config template, reusing cached copy', {
        error: e.message,
      });
      return _rcTemplateCache;
    }
    throw e;
  }
}

/**
 * Read authoritative billing config from Firebase Remote Config via the Admin SDK.
 * Prices are stored in rupees in RC and converted to paise here so the client
 * display values and the backend-charged values stay aligned.
 */
async function getRcBillingConfig() {
  const now = Date.now();
  if (_rcBillingCache && (now - _rcBillingCacheTime) < PRICING_CACHE_TTL_MS) {
    return _rcBillingCache;
  }
  try {
    const template = await getCachedRemoteConfigTemplate();
    const getPositiveInt = (key, fallback) => {
      const raw = template.parameters[key] && template.parameters[key].defaultValue && template.parameters[key].defaultValue.value;
      const parsed = raw !== undefined ? Number(raw) : NaN;
      return Number.isFinite(parsed) && parsed >= 0 ? parsed : fallback;
    };
    const getCurrencyPaise = (key, fallback) => {
      const raw = template.parameters[key] && template.parameters[key].defaultValue && template.parameters[key].defaultValue.value;
      const parsed = raw !== undefined ? Number(raw) : NaN;
      return Number.isFinite(parsed) && parsed >= 0
        ? Math.round(parsed * 100)
        : fallback;
    };
    _rcBillingCache = {
      pro_monthly_paise: getCurrencyPaise('pro_price_monthly', DEFAULT_PRICING.pro_monthly_paise),
      pro_annual_paise: getCurrencyPaise('pro_price_annual', DEFAULT_PRICING.pro_annual_paise),
      enterprise_monthly_paise: getCurrencyPaise('enterprise_price_monthly', DEFAULT_PRICING.enterprise_monthly_paise),
      enterprise_annual_paise: getCurrencyPaise('enterprise_price_annual', DEFAULT_PRICING.enterprise_annual_paise),
      trial_duration_months: getPositiveInt('trial_duration_months', DEFAULT_DURATIONS.trial_duration_months),
      grace_period_days: getPositiveInt('grace_period_days', DEFAULT_DURATIONS.grace_period_days),
    };
    logger.info('[RC] Billing config loaded', _rcBillingCache);
  } catch (e) {
    logger.warn('[RC] Failed to read Remote Config billing config, using defaults', { error: e.message });
    _rcBillingCache = { ...DEFAULT_PRICING, ...DEFAULT_DURATIONS };
  }
  _rcBillingCacheTime = now;
  return _rcBillingCache;
}

/**
 * Returns merged config for prices and billing durations.
 * Remote Config is the primary source so the purchase UI and charged amount stay
 * aligned. Firestore pricing remains as a backward-compatible fallback.
 */
async function getPricingConfig() {
  const now = Date.now();
  if (_pricingCache && (now - _pricingCacheTime) < PRICING_CACHE_TTL_MS) {
    return _pricingCache;
  }

  // Fetch Firestore fallback values and authoritative RC values in parallel.
  const [fsResult, rcResult] = await Promise.allSettled([
    db.collection('config').doc('pricing').get(),
    getRcBillingConfig(),
  ]);

  // Build payment amounts from Firestore
  let paymentConfig = { ...DEFAULT_PRICING };
  if (fsResult.status === 'fulfilled') {
    const doc = fsResult.value;
    if (doc.exists) {
      paymentConfig = { ...paymentConfig, ...doc.data() };
    } else {
      // Seed defaults on first access (fire-and-forget)
      db.collection('config').doc('pricing').set(DEFAULT_PRICING).catch(() => {});
    }
  } else {
    logger.warn('Failed to read config/pricing, using defaults', { error: fsResult.reason && fsResult.reason.message });
  }

  const rcBillingConfig = rcResult.status === 'fulfilled'
    ? rcResult.value
    : { ...DEFAULT_PRICING, ...DEFAULT_DURATIONS };

  _pricingCache = { ...paymentConfig, ...rcBillingConfig };
  _pricingCacheTime = now;
  return _pricingCache;
}

function getPriceInPaise(config, billingCycle, planId = 'pro') {
  if (planId === 'enterprise') {
    return billingCycle === 'annual' ? config.enterprise_annual_paise : config.enterprise_monthly_paise;
  }
  return billingCycle === 'annual' ? config.pro_annual_paise : config.pro_monthly_paise;
}

async function getOwnedSubscriptionSnapshot(ownerId, razorpaySubscriptionId = '') {
  const ref = db.collection('subscriptions').doc(ownerId);
  const doc = await ref.get();
  if (!doc.exists) return null;

  const data = doc.data() || {};
  if (razorpaySubscriptionId && data.razorpaySubscriptionId !== razorpaySubscriptionId) {
    return null;
  }

  return { ref, doc, data };
}

const BILLING_LOCK_TTL_MS = 2 * 60 * 1000;

async function acquireOwnerBillingLock(ownerId, actorUid, purpose) {
  const token = crypto.randomUUID();
  const ref = db.collection('billingLocks').doc(ownerId);
  const now = Date.now();
  const expiresAt = now + BILLING_LOCK_TTL_MS;

  await db.runTransaction(async (txn) => {
    const snap = await txn.get(ref);
    if (snap.exists) {
      const data = snap.data() || {};
      if (Number(data.expiresAt || 0) > now) {
        throw new HttpsError(
          'resource-exhausted',
          'Another billing update is already in progress. Please wait a moment and try again.',
        );
      }
    }

    txn.set(ref, {
      ownerId,
      actorUid,
      purpose,
      token,
      acquiredAt: now,
      expiresAt,
    });
  });

  return { ref, token };
}

async function releaseOwnerBillingLock(lock) {
  if (!lock) return;
  try {
    await db.runTransaction(async (txn) => {
      const snap = await txn.get(lock.ref);
      if (!snap.exists) return;
      const data = snap.data() || {};
      if (data.token !== lock.token) return;
      txn.delete(lock.ref);
    });
  } catch (error) {
    logger.warn('Failed to release billing lock', {
      error: error && error.message,
      lockRef: lock.ref && lock.ref.path,
    });
  }
}

function buildSubscriptionStateUpdate(subscription, fallback = {}) {
  const status = normalizeSubscriptionStatus(
    (subscription && subscription.status) || fallback.status,
  );
  const notes = subscription && subscription.notes ? subscription.notes : {};
  const updateData = {
    updatedAt: FieldValue.serverTimestamp(),
  };

  if (status) {
    updateData.status = status;
  }

  const planId = safeString(notes.planId, fallback.planId);
  if (planId) updateData.plan = planId;

  const billingCycle = safeString(notes.billingCycle, fallback.billingCycle);
  if (billingCycle) updateData.billingCycle = billingCycle;

  const userId = safeString(notes.userId, fallback.userId);
  if (userId) updateData.userId = userId;

  if (subscription && subscription.id) {
    updateData.razorpaySubscriptionId = subscription.id;
  }
  if (subscription && subscription.plan_id) {
    updateData.razorpayPlanId = subscription.plan_id;
  }
  if (subscription && subscription.customer_id) {
    updateData.razorpayCustomerId = subscription.customer_id;
  }
  if (subscription && subscription.current_start) {
    updateData.currentPeriodStart = Timestamp.fromDate(
      new Date(subscription.current_start * 1000),
    );
  }
  if (subscription && subscription.current_end) {
    updateData.currentPeriodEnd = Timestamp.fromDate(
      new Date(subscription.current_end * 1000),
    );
  }
  if (subscription && subscription.ended_at) {
    updateData.cancelledAt = Timestamp.fromDate(
      new Date(subscription.ended_at * 1000),
    );
  }

  if (status === 'active') {
    updateData.graceExpiresAt = FieldValue.delete();
    if (!(subscription && subscription.ended_at)) {
      updateData.cancelledAt = FieldValue.delete();
    }
  } else if (status === 'pending') {
    updateData.graceExpiresAt = FieldValue.delete();
  } else if (['cancelled', 'completed', 'expired'].includes(status)) {
    updateData.cancelAtPeriodEnd = false;
    updateData.graceExpiresAt = FieldValue.delete();
  }

  return { status, updateData };
}

async function syncTeamMemberLimitForOwner(ownerId) {
  const teamRef = db.collection('teams').doc(ownerId);
  const teamDoc = await teamRef.get();
  if (!teamDoc.exists) return;

  const newMax = await getMaxTeamMembersForOwner(ownerId);
  await teamRef.update({
    maxMembers: newMax === -1 ? 999999 : newMax,
    updatedAt: FieldValue.serverTimestamp(),
  });
}

// Razorpay Plan IDs — cached from Firestore config/razorpay_plans.
// Valid keys: pro_monthly, pro_annual, enterprise_monthly, enterprise_annual
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
  const amountKey = `${key}_amount`;

  // Create plan via Razorpay API using Firestore pricing config
  const config = await getPricingConfig();
  const amount = getPriceInPaise(config, billingCycle, planId);

  // Reuse cached plan only if pricing hasn't changed
  if (planIds && planIds[key] && planIds[amountKey] === amount) {
    return planIds[key];
  }
  const displayName = planId.charAt(0).toUpperCase() + planId.slice(1);
  const period = billingCycle === 'annual' ? 'yearly' : 'monthly';

  const rzpPlan = await getRazorpay().plans.create({
    period,
    interval: 1,
    item: {
      name: `${displayName} ${billingCycle === 'annual' ? 'Annual' : 'Monthly'}`,
      amount,
      currency: 'INR',
      description: `BillRaja ${displayName} plan — ${billingCycle} billing`,
    },
  });

  // Cache plan ID + amount in Firestore (amount lets us detect pricing changes)
  await db.collection('config').doc('razorpay_plans').set(
    { [key]: rzpPlan.id, [amountKey]: amount },
    { merge: true }
  );

  // Update in-memory cache
  if (!RAZORPAY_PLAN_IDS) RAZORPAY_PLAN_IDS = {};
  RAZORPAY_PLAN_IDS[key] = rzpPlan.id;
  RAZORPAY_PLAN_IDS[amountKey] = amount;

  logger.info('Created Razorpay plan', { key, rzpPlanId: rzpPlan.id, amount });
  return rzpPlan.id;
}

/**
 * Creates a Razorpay subscription for the user.
 * Returns the subscription ID for client-side checkout.
 */
exports.createSubscription = onCall(
  { secrets: ['RAZORPAY_KEY_ID', 'RAZORPAY_KEY_SECRET'], memory: '256MiB', timeoutSeconds: 60 },
  async (request) => {
    const uid = request.auth && request.auth.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Sign in required.');
    }

    const { planId, billingCycle } = request.data || {};
    if (!planId || !['pro', 'enterprise'].includes(planId)) {
      throw new HttpsError('invalid-argument', 'Invalid plan. Choose "pro" or "enterprise".');
    }
    if (!billingCycle || !['monthly', 'annual'].includes(billingCycle)) {
      throw new HttpsError('invalid-argument', 'Invalid billing cycle.');
    }

    const context = await getAppBillingAccessContext(uid);
    const ownerId = context.ownerId;
    await enforceRateLimit(
      `create_subscription_${ownerId}_${uid}`,
      5,
      10 * 60 * 1000,
      'Too many checkout attempts. Please wait a few minutes and try again.',
    );

    let billingLock = null;
    try {
      billingLock = await acquireOwnerBillingLock(ownerId, uid, 'create_subscription');

      const PLAN_RANK = { pro: 1, enterprise: 2 };
      const existingDoc = await db.collection('subscriptions').doc(ownerId).get();
      if (existingDoc.exists) {
        const existing = existingDoc.data() || {};
        if (existing.status === 'active' && existing.plan === planId && existing.billingCycle === billingCycle) {
          throw new HttpsError('already-exists', 'You already have this plan active.');
        }

        const existingStatus = normalizeSubscriptionStatus(existing.status);
        const isActiveSub = ['active', 'halted'].includes(existingStatus);
        const existingRank = PLAN_RANK[existing.plan] || 0;
        const newRank = PLAN_RANK[planId] || 0;
        const isDowngrade = isActiveSub && newRank < existingRank;

        // ── DOWNGRADE: schedule for end of billing period ──────────────────
        // Enterprise → Pro: don't cancel now. Let Enterprise run until period
        // end, then the user can subscribe to Pro.
        if (isDowngrade && existing.razorpaySubscriptionId) {
          logger.info('Downgrade detected — scheduling cancel at period end', {
            ownerId, actorUid: uid,
            currentPlan: existing.plan, newPlan: planId,
          });
          try {
            await getRazorpay().subscriptions.cancel(existing.razorpaySubscriptionId, {
              cancel_at_cycle_end: true,
            });
          } catch (cancelErr) {
            if (!isTerminalRazorpayCancellationError(cancelErr)) {
              logger.error('Failed to schedule downgrade cancellation', {
                error: cancelErr.message, ownerId, actorUid: uid,
              });
              throw new HttpsError('internal', 'Could not schedule downgrade. Please try again later.');
            }
          }
          // Store the pending downgrade info in Firestore
          const now = new Date();
          await db.collection('subscriptions').doc(ownerId).set({
            cancelAtPeriodEnd: true,
            pendingDowngrade: {
              plan: planId,
              billingCycle,
              scheduledByUid: uid,
              scheduledAt: Timestamp.fromDate(now),
            },
            updatedAt: Timestamp.fromDate(now),
          }, { merge: true });

          // Calculate when the current period ends for display
          const currentPeriodEnd = existing.currentPeriodEnd
            ? (existing.currentPeriodEnd.toDate ? existing.currentPeriodEnd.toDate() : new Date(existing.currentPeriodEnd))
            : null;

          return {
            success: true,
            downgradeScheduled: true,
            currentPlan: existing.plan,
            newPlan: planId,
            billingCycle,
            currentPeriodEnd: currentPeriodEnd ? currentPeriodEnd.toISOString() : null,
            message: `Your ${existing.plan === 'enterprise' ? 'Enterprise' : 'Pro'} plan will continue until the end of your current billing period. After that, you can subscribe to the ${planId === 'pro' ? 'Pro' : 'Enterprise'} plan.`,
          };
        }

        // ── Stale checkout subscriptions: discard and create fresh ──────────
        if (
          existing.razorpaySubscriptionId &&
          ['created', 'authenticated', 'pending'].includes(existingStatus)
        ) {
          logger.info('Discarding stale checkout subscription, creating fresh one', {
            ownerId, actorUid: uid,
            previousSubscriptionId: existing.razorpaySubscriptionId,
            previousStatus: existing.status,
          });
        }

        // ── UPGRADE or same-tier billing change: cancel old immediately ─────
        const needsRazorpayCancel = existing.razorpaySubscriptionId &&
          ['active', 'halted'].includes(existingStatus);
        if (needsRazorpayCancel) {
          try {
            await getRazorpay().subscriptions.cancel(existing.razorpaySubscriptionId, {
              cancel_at_cycle_end: false,
            });
            logger.info('Cancelled old Razorpay subscription for upgrade', {
              ownerId, actorUid: uid, oldPlan: existing.plan, newPlan: planId,
            });
          } catch (cancelErr) {
            if (isTerminalRazorpayCancellationError(cancelErr)) {
              logger.warn('Old Razorpay sub already cancelled/not found, continuing', {
                ownerId,
                actorUid: uid,
                previousSubscriptionId: existing.razorpaySubscriptionId,
              });
            } else {
              let shouldAbort = true;
              try {
                const remoteSub = await getRazorpay().subscriptions.fetch(existing.razorpaySubscriptionId);
                const remoteStatus = normalizeSubscriptionStatus(remoteSub.status);
                if (['cancelled', 'completed', 'expired'].includes(remoteStatus)) {
                  logger.warn('Old Razorpay sub is already terminal on remote, continuing', {
                    ownerId, actorUid: uid, remoteStatus,
                    previousSubscriptionId: existing.razorpaySubscriptionId,
                  });
                  shouldAbort = false;
                } else {
                  logger.error('Failed to cancel old Razorpay sub — aborting to prevent double-billing', {
                    error: cancelErr.message, ownerId, actorUid: uid, remoteStatus,
                  });
                }
              } catch (fetchErr) {
                logger.warn('Could not fetch old Razorpay sub (likely deleted), continuing', {
                  ownerId, actorUid: uid, fetchError: fetchErr.message,
                  previousSubscriptionId: existing.razorpaySubscriptionId,
                });
                shouldAbort = false;
              }
              if (shouldAbort) {
                throw new HttpsError('internal', 'Could not cancel existing subscription. Please try again later.');
              }
            }
          }
          // Clear any pending downgrade since we're doing a new subscription
          await db.collection('subscriptions').doc(ownerId).set({
            cancelAtPeriodEnd: false,
            pendingDowngrade: null,
          }, { merge: true });
        } else if (existing.razorpaySubscriptionId && !needsRazorpayCancel) {
          logger.info('Skipping Razorpay cancel — old sub was never activated (status: ' + existingStatus + ')', {
            ownerId, actorUid: uid, previousSubscriptionId: existing.razorpaySubscriptionId,
          });
        }
      }

      let rzpPlanId;
      try {
        rzpPlanId = await ensureRazorpayPlan(planId, billingCycle);
        logger.info('Got Razorpay plan', { rzpPlanId });
      } catch (planErr) {
        const errDetail = planErr.error || planErr;
        logger.error('ensureRazorpayPlan failed', { error: JSON.stringify(errDetail), statusCode: planErr.statusCode, stack: planErr.stack });
        throw new HttpsError('internal', 'Failed to create billing plan. Please try again later.');
      }
      const pricingConfig = await getPricingConfig();
      const priceInPaise = getPriceInPaise(pricingConfig, billingCycle, planId);
      const totalCount = getSubscriptionTotalCount(billingCycle);

      let rzpSub;
      try {
        rzpSub = await getRazorpay().subscriptions.create({
          plan_id: rzpPlanId,
          total_count: totalCount,
          quantity: 1,
          customer_notify: 1,
          notes: {
            userId: ownerId,
            actorUid: uid,
            planId,
            billingCycle,
          },
        });
        logger.info('Razorpay subscription created via API', { rzpSubId: rzpSub.id });
      } catch (subErr) {
        logger.error('subscriptions.create failed', { error: subErr.message, statusCode: subErr.statusCode, rzpPlanId });
        throw new HttpsError('internal', 'Failed to create subscription: ' + subErr.message);
      }

      const now = new Date();
      await db.collection('subscriptions').doc(ownerId).set({
        id: rzpSub.id,
        userId: ownerId,
        plan: planId,
        billingCycle,
        status: normalizeSubscriptionStatus(rzpSub.status) || 'created',
        razorpaySubscriptionId: rzpSub.id,
        razorpayPlanId: rzpPlanId,
        createdByUid: uid,
        cancelAtPeriodEnd: false,
        createdAt: Timestamp.fromDate(now),
        updatedAt: Timestamp.fromDate(now),
        priceInPaise,
      }, { merge: true });

      logger.info('Razorpay subscription created', {
        ownerId, actorUid: uid, planId, billingCycle, rzpSubId: rzpSub.id,
      });

      return {
        success: true,
        subscriptionId: rzpSub.id,
        plan: planId,
        billingCycle,
        priceInPaise,
      };
    } finally {
      await releaseOwnerBillingLock(billingLock);
    }
  }
);

/**
 * Cancel subscription — cancels on Razorpay and updates Firestore.
 */
exports.cancelSubscription = onCall(
  { secrets: ['RAZORPAY_KEY_ID', 'RAZORPAY_KEY_SECRET'], memory: '256MiB', timeoutSeconds: 60 },
  async (request) => {
    const uid = request.auth && request.auth.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Sign in required.');
    }

    const context = await getAppBillingAccessContext(uid);
    const ownerId = context.ownerId;
    const cancelImmediately = request.data && request.data.immediate === true;
    let billingLock = null;
    try {
      billingLock = await acquireOwnerBillingLock(ownerId, uid, 'cancel_subscription');

      const subRef = db.collection('subscriptions').doc(ownerId);
      const subDoc = await subRef.get();

      if (!subDoc.exists) {
        throw new HttpsError('not-found', 'No active subscription found.');
      }

      const sub = subDoc.data() || {};
      const normalizedStatus = normalizeSubscriptionStatus(sub.status);
      if (!isOpenSubscriptionStatus(normalizedStatus) && normalizedStatus !== 'halted') {
        throw new HttpsError('failed-precondition', 'Subscription is not active.');
      }

      const rzpSubId = sub.razorpaySubscriptionId;
      let remotelyCancelled = false;
      if (rzpSubId) {
        try {
          await getRazorpay().subscriptions.cancel(rzpSubId, {
            cancel_at_cycle_end: cancelImmediately ? false : true,
          });
          remotelyCancelled = cancelImmediately;
        } catch (rzpErr) {
          if (isTerminalRazorpayCancellationError(rzpErr)) {
            remotelyCancelled = true;
            logger.warn('Razorpay cancel reported subscription already cancelled/not found', {
              ownerId,
              actorUid: uid,
              rzpSubId,
              error: rzpErr.message,
            });
          } else {
            logger.error('Razorpay cancel failed; leaving Firestore unchanged', {
              ownerId,
              actorUid: uid,
              rzpSubId,
              error: rzpErr.message,
            });
            throw new HttpsError(
              'internal',
              'Could not cancel the subscription with Razorpay. Please try again in a moment.',
            );
          }
        }
      }

      if (cancelImmediately || remotelyCancelled) {
        await subRef.update({
          status: 'cancelled',
          cancelAtPeriodEnd: false,
          cancelledAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        await syncTeamMemberLimitForOwner(ownerId);
      } else {
        await subRef.update({
          cancelAtPeriodEnd: true,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }

      logger.info('Subscription cancelled', { ownerId, actorUid: uid, immediate: cancelImmediately });
      return { success: true, cancelledImmediately: cancelImmediately || remotelyCancelled };
    } finally {
      await releaseOwnerBillingLock(billingLock);
    }
  }
);

/**
 * Reactivate a subscription that was set to cancel at period end.
 * Reverses the cancelAtPeriodEnd flag so the subscription continues.
 */
exports.reactivateSubscription = onCall({ memory: '256MiB', timeoutSeconds: 60 }, async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in required.');
  }

  const context = await getAppBillingAccessContext(uid);
  const ownerId = context.ownerId;
  const subRef = db.collection('subscriptions').doc(ownerId);
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

  logger.warn('Reactivate subscription requested but unsupported by Razorpay once cancellation is scheduled', {
    ownerId,
    actorUid: uid,
    razorpaySubscriptionId: sub.razorpaySubscriptionId || null,
  });
  throw new HttpsError(
    'failed-precondition',
    'Scheduled cancellation cannot be undone with Razorpay. You can purchase again after the current period ends.',
  );
});

/**
 * Permanently delete the signed-in user's account and data.
 *
 * Order matters:
 * 1. Cancel any live Razorpay subscription to prevent future billing.
 * 2. Delete user-owned Firestore + Storage data.
 * 3. Delete the Firebase Auth user only after cleanup succeeds.
 */
exports.deleteMyAccount = onCall(
  { secrets: ['RAZORPAY_KEY_ID', 'RAZORPAY_KEY_SECRET'], memory: '1GiB', timeoutSeconds: 540 },
  async (request) => {
    const uid = request.auth && request.auth.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Sign in required.');
    }
    const authTimeSeconds = Number(request.auth.token && request.auth.token.auth_time);
    if (!authTimeSeconds || ((Date.now() / 1000) - authTimeSeconds) > RECENT_AUTH_MAX_AGE_SECONDS) {
      throw new HttpsError(
        'failed-precondition',
        'For security, please sign in again and retry account deletion.',
      );
    }

    // Mark this user's identifiers as "trial used" BEFORE deleting anything.
    // This prevents re-signup abuse where someone deletes and re-creates
    // an account to get another free trial.
    await markTrialUsed(uid);

    await cancelSubscriptionForAccountDeletion(uid);
    await deleteOwnedFirestoreData(uid);
    await deleteOwnedStorageData(uid);
    await admin.auth().deleteUser(uid);

    logger.info('Account deleted permanently', { uid });
    return { success: true };
  }
);

async function cancelSubscriptionForAccountDeletion(uid) {
  const subRef = db.collection('subscriptions').doc(uid);
  const subDoc = await subRef.get();
  if (!subDoc.exists) return;

  const sub = subDoc.data() || {};
  const rzpSubId = sub.razorpaySubscriptionId;
  const status = String(sub.status || '').toLowerCase();
  if (!rzpSubId || ['cancelled', 'completed', 'expired'].includes(status)) {
    return;
  }

  try {
    await getRazorpay().subscriptions.cancel(rzpSubId, {
      cancel_at_cycle_end: false,
    });
    logger.info('Cancelled Razorpay subscription before account deletion', {
      uid,
      rzpSubId,
      status,
    });
  } catch (cancelErr) {
    if (isTerminalRazorpayCancellationError(cancelErr)) {
      logger.warn('Razorpay subscription already cancelled before deletion', {
        uid,
        rzpSubId,
      });
      return;
    }

    logger.error('Failed to cancel Razorpay subscription during account deletion', {
      uid,
      rzpSubId,
      error: cancelErr && cancelErr.message,
    });
    throw new HttpsError(
      'internal',
      'Could not cancel your active subscription. Please try again in a moment.',
    );
  }
}

async function deleteOwnedFirestoreData(uid) {
  await deleteDocsByQuery(
    db.collection('invoices').where('ownerId', '==', uid),
    { recursive: true },
  );
  await deleteDocsByQuery(
    db.collection('shared_invoices').where('ownerId', '==', uid),
  );

  // Clean up team data if user was a team owner
  const teamDoc = await db.collection('teams').doc(uid).get();
  if (teamDoc.exists) {
    // Remove all team members' userTeamMap entries pointing to this team
    const membersSnap = await db.collection('teams').doc(uid)
      .collection('members').get();
    const memberBatch = db.batch();
    for (const memberDoc of membersSnap.docs) {
      const memberUid = memberDoc.id;
      if (memberUid !== uid) {
        memberBatch.delete(db.collection('userTeamMap').doc(memberUid));
      }
    }
    await memberBatch.commit();

    // Delete the team document and all subcollections
    await db.recursiveDelete(db.collection('teams').doc(uid));

    // Expire pending invites for this team
    const inviteSnap = await db.collection('teamInvites')
      .where('teamId', '==', uid)
      .where('status', '==', 'pending')
      .get();
    if (!inviteSnap.empty) {
      const inviteBatch = db.batch();
      inviteSnap.forEach((doc) => {
        inviteBatch.update(doc.ref, {
          status: 'expired',
          updatedAt: FieldValue.serverTimestamp(),
        });
      });
      await inviteBatch.commit();
    }
  }

  // Clean up the user's own userTeamMap entry
  await db.collection('userTeamMap').doc(uid).delete().catch(() => {});

  // Clean up rate limit docs (keyed by pattern, not by uid field)
  const rateLimitPatterns = [
    `team_invite_${uid}`,
    `accept_invite_${uid}`,
    `remove_member_${uid}`,
    `leave_team_${uid}`,
    `invoice_${uid}`,
    `create_subscription_${uid}_${uid}`,
    `cancel_subscription_${uid}_${uid}`,
  ];
  for (const key of rateLimitPatterns) {
    await db.collection('rate_limits').doc(key).delete().catch(() => {});
  }

  await deleteDocTreeIfExists(db.collection('subscriptions').doc(uid));
  await deleteDocTreeIfExists(db.collection(COUNTERS_COLLECTION).doc(uid));
  await db.collection('billingLocks').doc(uid).delete().catch(() => {});
  await deleteDocTreeIfExists(db.collection('users').doc(uid));
}

async function deleteOwnedStorageData(uid) {
  await deleteStoragePrefix(`users/${uid}/`);
  await deleteStoragePrefix(`signatures/${uid}/`);
  await deleteStoragePrefix(`invoices/${uid}/`);
}

async function deleteDocTreeIfExists(ref) {
  const snap = await ref.get();
  if (!snap.exists) return;
  await db.recursiveDelete(ref);
}

async function deleteDocsByQuery(query, options = {}) {
  const recursive = options.recursive === true;
  const pageSize = options.pageSize || 50;

  while (true) {
    const snapshot = await query.limit(pageSize).get();
    if (snapshot.empty) return;

    for (const doc of snapshot.docs) {
      if (recursive) {
        await db.recursiveDelete(doc.ref);
      } else {
        await doc.ref.delete();
      }
    }
  }
}

async function deleteStoragePrefix(prefix) {
  try {
    await admin.storage().bucket().deleteFiles({
      prefix,
      force: true,
    });
  } catch (err) {
    const code = err && err.code;
    if (code === 404 || code === '404') {
      return;
    }
    logger.error('Failed to delete storage prefix during account deletion', {
      prefix,
      error: err && err.message,
    });
    throw err;
  }
}

/**
 * Verify payment signature after Razorpay checkout success.
 * Called by Flutter client to confirm payment is genuine.
 */
exports.verifyPayment = onCall(
  { secrets: ['RAZORPAY_KEY_ID', 'RAZORPAY_KEY_SECRET'], memory: '256MiB', timeoutSeconds: 60 },
  async (request) => {
    const uid = request.auth && request.auth.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Sign in required.');
    }

    const context = await getAppBillingAccessContext(uid);
    const ownerId = context.ownerId;

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
      logger.warn('Payment signature mismatch', { ownerId, actorUid: uid, razorpayPaymentId });
      return { verified: false, message: 'Invalid payment signature.' };
    }

    // Resolve the authoritative subscription state from Razorpay instead of
    // inventing local billing dates/status.
    const ownedSubscription = await getOwnedSubscriptionSnapshot(ownerId, razorpaySubscriptionId);
    if (!ownedSubscription) {
      logger.warn('verifyPayment ownership mismatch', {
        ownerId,
        actorUid: uid,
        razorpayPaymentId,
        razorpaySubscriptionId,
      });
      return { verified: false, message: 'Payment does not match this subscription.' };
    }

    const existingData = ownedSubscription.data || {};
    const previousStatus = normalizeSubscriptionStatus(existingData.status);

    let remoteSubscription = null;
    try {
      remoteSubscription = await getRazorpay().subscriptions.fetch(razorpaySubscriptionId);
    } catch (fetchErr) {
      logger.warn('verifyPayment: failed to fetch Razorpay subscription after signature verification', {
        ownerId,
        actorUid: uid,
        razorpaySubscriptionId,
        error: fetchErr && fetchErr.message,
      });
    }

    const { status, updateData } = buildSubscriptionStateUpdate(
      remoteSubscription || {},
      {
        billingCycle: existingData.billingCycle,
        planId: existingData.plan,
        status: existingData.status,
        userId: ownerId,
      },
    );

    updateData.lastPaymentId = razorpayPaymentId;
    await ownedSubscription.ref.update(updateData);

    if (status === 'active') {
      await syncTeamMemberLimitForOwner(ownerId);
    }

    const resolvedStatus = status || previousStatus || 'created';
    const activationPending = resolvedStatus !== 'active';
    const alreadyActive = previousStatus === 'active' && resolvedStatus === 'active';

    logger.info('Payment verified', {
      ownerId,
      actorUid: uid,
      razorpayPaymentId,
      razorpaySubscriptionId,
      resolvedStatus,
    });
    return {
      verified: true,
      alreadyActive,
      activationPending,
      status: resolvedStatus,
      message: activationPending
        ? 'Payment verified. Subscription activation is still processing.'
        : 'Plan activated successfully.',
    };
  }
);

/**
 * Razorpay webhook handler (HTTP endpoint).
 * Verifies signature and processes subscription/payment events.
 */
exports.razorpayWebhook = onRequest(
  { secrets: ['RAZORPAY_WEBHOOK_SECRET'] },
  async (req, res) => {
    let eventRef = null;
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
      const rawBody = req.rawBody && req.rawBody.length
        ? req.rawBody
        : Buffer.from(JSON.stringify(req.body || {}));
      const expectedSignature = crypto
        .createHmac('sha256', webhookSecret)
        .update(rawBody)
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
        eventRef = db.collection('razorpayEvents').doc(eventId);
        const eventDoc = await eventRef.get();
        if (eventDoc.exists && eventDoc.data().processed) {
          res.status(200).json({ status: 'already_processed' });
          return;
        }
        await eventRef.set({
          eventType,
          processed: false,
          receivedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
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
            if (userId && subscription.id) {
              const ownedSubscription = await getOwnedSubscriptionSnapshot(userId, subscription.id);
              if (!ownedSubscription) {
                logger.warn('subscription webhook ownership mismatch', {
                  eventType,
                  userId,
                  razorpaySubscriptionId: subscription.id,
                });
                break;
              }
              const { updateData } = buildSubscriptionStateUpdate(subscription, {
                planId,
                billingCycle,
                userId,
              });
              await ownedSubscription.ref.update(updateData);
              await syncTeamMemberLimitForOwner(userId);
            }
          }
          break;
        }
        case 'subscription.pending': {
          const subscription = payload && payload.subscription && payload.subscription.entity;
          if (subscription) {
            const userId = subscription.notes && subscription.notes.userId;
            if (userId && subscription.id) {
              const ownedSubscription = await getOwnedSubscriptionSnapshot(userId, subscription.id);
              if (!ownedSubscription) {
                logger.warn('subscription.pending ownership mismatch', {
                  userId,
                  razorpaySubscriptionId: subscription.id,
                });
                break;
              }
              const { updateData } = buildSubscriptionStateUpdate(subscription, {
                userId,
                status: 'pending',
              });
              await ownedSubscription.ref.update(updateData);
            }
          }
          break;
        }
        case 'subscription.halted': {
          const subscription = payload && payload.subscription && payload.subscription.entity;
          if (subscription) {
            const userId = subscription.notes && subscription.notes.userId;
            if (userId && subscription.id) {
              const ownedSubscription = await getOwnedSubscriptionSnapshot(userId, subscription.id);
              if (!ownedSubscription) {
                logger.warn('subscription.halted ownership mismatch', {
                  userId,
                  razorpaySubscriptionId: subscription.id,
                });
                break;
              }
              const graceCfg = await getPricingConfig();
              const graceDays = graceCfg.grace_period_days || 7;
              const graceDate = new Date();
              graceDate.setDate(graceDate.getDate() + graceDays);
              await ownedSubscription.ref.update({
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
            if (userId && subscription.id) {
              const ownedSubscription = await getOwnedSubscriptionSnapshot(userId, subscription.id);
              if (!ownedSubscription) {
                logger.warn('subscription completion ownership mismatch', {
                  eventType,
                  userId,
                  razorpaySubscriptionId: subscription.id,
                });
                break;
              }
              const { updateData } = buildSubscriptionStateUpdate(subscription, {
                userId,
                status: eventType === 'subscription.completed' ? 'completed' : 'cancelled',
              });
              if (!updateData.cancelledAt) {
                updateData.cancelledAt = FieldValue.serverTimestamp();
              }
              await ownedSubscription.ref.update(updateData);
              await syncTeamMemberLimitForOwner(userId);
            }
          }
          break;
        }
        case 'subscription.paused': {
          const subscription = payload && payload.subscription && payload.subscription.entity;
          if (subscription) {
            const userId = subscription.notes && subscription.notes.userId;
            if (userId && subscription.id) {
              const ownedSubscription = await getOwnedSubscriptionSnapshot(userId, subscription.id);
              if (!ownedSubscription) {
                logger.warn('subscription.paused ownership mismatch', {
                  userId,
                  razorpaySubscriptionId: subscription.id,
                });
                break;
              }
              const { updateData } = buildSubscriptionStateUpdate(subscription, {
                userId,
                status: 'paused',
              });
              await ownedSubscription.ref.update(updateData);
            }
          }
          break;
        }
        case 'subscription.resumed': {
          const subscription = payload && payload.subscription && payload.subscription.entity;
          if (subscription) {
            const userId = subscription.notes && subscription.notes.userId;
            if (userId && subscription.id) {
              const ownedSubscription = await getOwnedSubscriptionSnapshot(userId, subscription.id);
              if (!ownedSubscription) {
                logger.warn('subscription.resumed ownership mismatch', {
                  userId,
                  razorpaySubscriptionId: subscription.id,
                });
                break;
              }
              const { updateData } = buildSubscriptionStateUpdate(subscription, {
                userId,
                status: 'active',
              });
              await ownedSubscription.ref.update(updateData);
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
            const subId =
              (subEntity && subEntity.id) ||
              payment.subscription_id ||
              (payment.notes && payment.notes.subscriptionId);
            if (userId) {
              // Ownership validation: verify userId actually owns the razorpay subscription
              // referenced in this payment to prevent notes spoofing.
              const ownedSubscription = subId
                ? await getOwnedSubscriptionSnapshot(userId, subId)
                : await getOwnedSubscriptionSnapshot(userId);
              if (subId && !ownedSubscription) {
                logger.warn('payment.captured: userId/subscriptionId ownership mismatch — ignoring', {
                  userId, subId, paymentId: payment.id,
                });
                break;
              }
              if (!ownedSubscription) {
                logger.warn('payment.captured: subscription document not found — ignoring', {
                  userId,
                  paymentId: payment.id,
                });
                break;
              }
              const gstAmount = Math.round(payment.amount * 18 / 118);
              if (subEntity) {
                const { updateData } = buildSubscriptionStateUpdate(subEntity, {
                  userId,
                });
                if (Object.keys(updateData).length > 1) {
                  await ownedSubscription.ref.update(updateData);
                }
              }
              await ownedSubscription.ref
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
            const subEntity = payload && payload.subscription && payload.subscription.entity;
            const subId =
              (subEntity && subEntity.id) ||
              payment.subscription_id ||
              (payment.notes && payment.notes.subscriptionId);
            if (userId) {
              const ownedSubscription = subId
                ? await getOwnedSubscriptionSnapshot(userId, subId)
                : await getOwnedSubscriptionSnapshot(userId);
              if (subId && !ownedSubscription) {
                logger.warn('payment.failed: userId/subscriptionId ownership mismatch — ignoring', {
                  userId, subId, paymentId: payment.id,
                });
                break;
              }
              if (!ownedSubscription) {
                logger.warn('payment.failed: subscription document not found — ignoring', {
                  userId,
                  paymentId: payment.id,
                });
                break;
              }
              if (subEntity) {
                const { updateData } = buildSubscriptionStateUpdate(subEntity, {
                  userId,
                });
                if (Object.keys(updateData).length > 1) {
                  await ownedSubscription.ref.update(updateData);
                }
              }
              await ownedSubscription.ref
                .collection('payments').doc(payment.id).set({
                  id: payment.id,
                  userId,
                  subscriptionId: subId || '',
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

      if (eventRef) {
        await eventRef.set({
          processed: true,
          processedAt: FieldValue.serverTimestamp(),
          lastError: FieldValue.delete(),
        }, { merge: true });
      }

      res.status(200).json({ status: 'ok' });
    } catch (err) {
      if (eventRef) {
        await eventRef.set({
          processed: false,
          lastError: err && err.message ? String(err.message) : 'unknown',
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      }
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
    let expiredCount = 0;
    let haltedCount = 0;
    let cancelledCount = 0;
    const now = Timestamp.now();
    const PAGE_SIZE = 500;

    const cronConfig = await getPricingConfig();
    const cronGraceDays = cronConfig.grace_period_days || 7;

    let lastHaltedDoc = null;
    while (true) {
      let query = db.collection('subscriptions')
        .where('status', '==', 'halted')
        .where('graceExpiresAt', '<=', now)
        .orderBy('graceExpiresAt')
        .orderBy(FieldPath.documentId())
        .limit(PAGE_SIZE);

      if (lastHaltedDoc) query = query.startAfter(lastHaltedDoc);

      const snap = await query.get();
      if (snap.empty) break;

      const writer = db.bulkWriter();
      snap.docs.forEach((doc) => {
        expiredCount++;
        writer.update(doc.ref, {
          status: 'expired',
          plan: 'free',
          updatedAt: FieldValue.serverTimestamp(),
        });
      });
      await writer.close();

      if (snap.size < PAGE_SIZE) break;
      lastHaltedDoc = snap.docs[snap.docs.length - 1];
    }

    let lastActiveDoc = null;
    while (true) {
      let query = db.collection('subscriptions')
        .where('status', '==', 'active')
        .where('cancelAtPeriodEnd', '==', false)
        .where('currentPeriodEnd', '<=', now)
        .orderBy('currentPeriodEnd')
        .orderBy(FieldPath.documentId())
        .limit(PAGE_SIZE);

      if (lastActiveDoc) query = query.startAfter(lastActiveDoc);

      const snap = await query.get();
      if (snap.empty) break;

      const writer = db.bulkWriter();
      snap.docs.forEach((doc) => {
        haltedCount++;
        const graceDate = new Date();
        graceDate.setDate(graceDate.getDate() + cronGraceDays);
        writer.update(doc.ref, {
          status: 'halted',
          graceExpiresAt: Timestamp.fromDate(graceDate),
          updatedAt: FieldValue.serverTimestamp(),
        });
      });
      await writer.close();

      if (snap.size < PAGE_SIZE) break;
      lastActiveDoc = snap.docs[snap.docs.length - 1];
    }

    let lastCancelDoc = null;
    while (true) {
      let query = db.collection('subscriptions')
        .where('status', '==', 'active')
        .where('cancelAtPeriodEnd', '==', true)
        .where('currentPeriodEnd', '<=', now)
        .orderBy('currentPeriodEnd')
        .orderBy(FieldPath.documentId())
        .limit(PAGE_SIZE);

      if (lastCancelDoc) query = query.startAfter(lastCancelDoc);

      const snap = await query.get();
      if (snap.empty) break;

      const writer = db.bulkWriter();
      snap.docs.forEach((doc) => {
        cancelledCount++;
        writer.update(doc.ref, {
          status: 'cancelled',
          plan: 'free',
          cancelledAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      });
      await writer.close();

      if (snap.size < PAGE_SIZE) break;
      lastCancelDoc = snap.docs[snap.docs.length - 1];
    }

    logger.info('Subscription expiry check completed', {
      expiredCount,
      haltedCount,
      cancelledCount,
    });
  }
);

/**
 * Get subscription status for current user.
 */
exports.getSubscriptionStatus = onCall({ memory: '256MiB', timeoutSeconds: 30 }, async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in required.');
  }

  const context = await getAppBillingAccessContext(uid);
  const subDoc = await db.collection('subscriptions').doc(context.ownerId).get();
  if (!subDoc.exists) {
    return { plan: 'free', status: 'none' };
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
exports.sendInvoiceSms = onCall({ memory: '256MiB', timeoutSeconds: 60 }, async (request) => {
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

exports.saveSharedInvoiceLink = onCall({ memory: '256MiB', timeoutSeconds: 30 }, async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in required.');
  }

  const { shortCode, invoiceId, templateName = '', downloadUrl = '' } = request.data || {};
  const sanitizedShortCode = String(shortCode || '').trim();
  const sanitizedInvoiceId = String(invoiceId || '').trim();

  if (!isValidSharedInvoiceShortCode(sanitizedShortCode)) {
    throw new HttpsError('invalid-argument', 'shortCode is invalid.');
  }
  if (!sanitizedInvoiceId) {
    throw new HttpsError('invalid-argument', 'invoiceId is required.');
  }

  await enforceRateLimit(
    `share_link_${uid}`,
    240,
    60 * 60 * 1000,
    'Too many share link requests. Please try again in a bit.',
  );

  const invoiceRef = db.collection('invoices').doc(sanitizedInvoiceId);
  const invoiceDoc = await invoiceRef.get();
  if (!invoiceDoc.exists) {
    throw new HttpsError('not-found', 'Invoice not found.');
  }

  const invoiceData = invoiceDoc.data() || {};
  const ownerId = safeString(invoiceData.ownerId);
  if (!ownerId) {
    throw new HttpsError('failed-precondition', 'Invoice is missing its owner.');
  }

  await getInvoiceShareAccessContext(uid, ownerId);

  const invoiceRecord = buildInvoiceRecord(invoiceData, sanitizedInvoiceId);
  const ownerRef = db.collection('users').doc(ownerId);
  const [ownerDoc, existingSharedDoc] = await Promise.all([
    ownerRef.get(),
    db.collection('shared_invoices').doc(sanitizedShortCode).get(),
  ]);
  const ownerData = ownerDoc.exists ? ownerDoc.data() || {} : {};
  const existingSharedData = existingSharedDoc.exists ? existingSharedDoc.data() || {} : {};

  if (existingSharedDoc.exists && safeString(existingSharedData.ownerId) && existingSharedData.ownerId !== ownerId) {
    throw new HttpsError('already-exists', 'This share code is already in use.');
  }
  if (existingSharedDoc.exists && safeString(existingSharedData.invoiceId) !== sanitizedInvoiceId) {
    throw new HttpsError('already-exists', 'This share code is already linked to another invoice.');
  }

  let clientPhoneNormalized = '';
  const clientId = safeString(invoiceData.clientId);
  if (clientId) {
    const clientDoc = await ownerRef.collection('clients').doc(clientId).get();
    if (clientDoc.exists) {
      clientPhoneNormalized = normalizePhone(clientDoc.data().phone || '');
    }
  }
  if (!clientPhoneNormalized && existingSharedData.clientPhoneNormalized) {
    clientPhoneNormalized = normalizePhone(existingSharedData.clientPhoneNormalized);
  }

  const amountReceived = roundMoney(toNumber(invoiceData.amountReceived));
  const grandTotal = roundMoney(invoiceRecord.metrics.grandTotal);
  const sharedStatus = computeSharedInvoiceStatus(invoiceData.status, grandTotal, amountReceived);
  const sanitizedTemplate = sanitizeSharedTemplateName(templateName);
  const trustedDownloadUrl = isTrustedSharedDownloadUrl(downloadUrl)
    ? String(downloadUrl)
    : safeString(existingSharedData.downloadUrl);
  const downloadStoragePath = resolveSharedInvoiceStoragePath({
    downloadStoragePath: existingSharedData.downloadStoragePath,
    downloadUrl: trustedDownloadUrl,
  });

  const sharedData = {
    invoiceId: sanitizedInvoiceId,
    invoiceNumber: safeString(invoiceData.invoiceNumber, sanitizedInvoiceId),
    clientId,
    clientName: safeString(invoiceData.clientName, clientId, 'Customer'),
    clientPhoneNormalized,
    amount: grandTotal,
    subtotal: roundMoney(invoiceRecord.metrics.subtotal),
    date: invoiceRecord.createdAt.toLocaleDateString('en-IN', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
      timeZone: INDIA_TIME_ZONE,
    }),
    status: sharedStatus,
    amountReceived,
    balanceDue: roundMoney(Math.max(grandTotal - amountReceived, 0)),
    ownerId,
    createdAt: invoiceData.createdAt || existingSharedData.createdAt || FieldValue.serverTimestamp(),
    sharedAt: FieldValue.serverTimestamp(),
    expiresAt: Timestamp.fromDate(new Date(Date.now() + 90 * 24 * 60 * 60 * 1000)),
    items: sanitizeSharedInvoiceItems(invoiceData.items),
    discountAmount: roundMoney(invoiceRecord.metrics.discountAmount),
    discountType: safeString(invoiceData.discountType),
    discountValue: roundMoney(toNumber(invoiceData.discountValue)),
    gstEnabled: !!invoiceData.gstEnabled,
    gstType: safeString(invoiceData.gstType, 'cgst_sgst'),
    cgstAmount: roundMoney(invoiceRecord.metrics.cgstAmount),
    sgstAmount: roundMoney(invoiceRecord.metrics.sgstAmount),
    igstAmount: roundMoney(invoiceRecord.metrics.igstAmount),
    totalTax: roundMoney(invoiceRecord.metrics.totalTax),
    customerGstin: safeString(invoiceData.customerGstin),
    storeName: safeString(ownerData.storeName),
    sellerPhone: safeString(ownerData.phoneNumber),
    sellerAddress: safeString(ownerData.address),
    sellerGstin: safeString(ownerData.gstin),
    upiId: safeString(ownerData.upiId),
    upiNumber: safeString(ownerData.upiNumber),
    upiQrUrl: sanitizeSharedAssetUrl(ownerData.upiQrUrl),
    signatureUrl: sanitizeSharedAssetUrl(safeString(invoiceData.createdBySignatureUrl, ownerData.signatureUrl)),
    logoUrl: sanitizeSharedAssetUrl(ownerData.logoUrl),
    updatedAt: FieldValue.serverTimestamp(),
  };

  if (trustedDownloadUrl) {
    sharedData.downloadUrl = trustedDownloadUrl;
  }
  if (downloadStoragePath) {
    sharedData.downloadStoragePath = downloadStoragePath;
  }
  if (invoiceData.dueDate || invoiceData.dueAt) {
    const dueDate = parseDate(invoiceData.dueDate, invoiceData.dueAt);
    if (dueDate) {
      sharedData.dueDate = dueDate.toLocaleDateString('en-IN', {
        day: '2-digit',
        month: 'short',
        year: 'numeric',
        timeZone: INDIA_TIME_ZONE,
      });
    }
  }
  if (sanitizedTemplate) {
    sharedData.templateName = sanitizedTemplate;
  }

  await db.collection('shared_invoices').doc(sanitizedShortCode).set(sharedData, { merge: true });

  return {
    shortCode: sanitizedShortCode,
    url: `https://invoice.billraja.online/i/${sanitizedShortCode}`,
  };
});

// ════════════════════════════════════════════════════════════════════════════
// INVOICE LANDING PAGE — serves a branded HTML page for shared invoices
// ════════════════════════════════════════════════════════════════════════════

exports.invoicePage = onRequest(async (req, res) => {
  setSecurityHeaders(res);
  res.set('X-Robots-Tag', 'noindex, nofollow, noarchive, nosnippet, noimageindex');
  const pathParts = req.path.split('/').filter(Boolean);
  const shortCode = pathParts.length >= 2 ? pathParts[1] : null;

  if (!shortCode || !isValidSharedInvoiceShortCode(shortCode)) {
    res.status(404).send(notFoundPage());
    return;
  }

  try {
    try {
      await enforceRateLimit(
        `invoice_page_${sanitizeRateLimitKeyPart(getRequestIp(req))}_${shortCode}`,
        180,
        60 * 60 * 1000,
        'Too many invoice page requests. Please try again later.',
      );
    } catch (rateLimitErr) {
      if (rateLimitErr instanceof HttpsError && rateLimitErr.code === 'resource-exhausted') {
        res.status(429).send(notFoundPage('Too many requests. Please try again in a few minutes.'));
        return;
      }
      throw rateLimitErr;
    }

    const doc = await db.collection('shared_invoices').doc(shortCode).get();

    if (!doc.exists) {
      res.status(404).send(notFoundPage());
      return;
    }

    const data = doc.data();
    if (isSharedInvoiceExpired(data)) {
      res.status(404).send(notFoundPage('This invoice link has expired.'));
      return;
    }
    const amount = fmtCur(data.amount || 0);
    const date = data.date || '';
    const invoiceNumber = data.invoiceNumber || shortCode;
    const clientName = data.clientName || 'Customer';
    const downloadUrl = resolveSharedInvoiceStoragePath(data)
      ? buildSharedInvoiceDownloadUrl(shortCode)
      : '';
    const items = data.items || [];
    const subtotal = data.subtotal || 0;
    const discountAmount = data.discountAmount || 0;
    const gstEnabled = data.gstEnabled || false;
    const gstType = data.gstType || 'cgst_sgst';
    const cgstAmount = data.cgstAmount || 0;
    const sgstAmount = data.sgstAmount || 0;
    const igstAmount = data.igstAmount || 0;
    const totalTax = (data.totalTax != null) ? data.totalTax : (cgstAmount + sgstAmount + igstAmount);
    const discountType = data.discountType || null;
    const taxableAmount = subtotal - discountAmount;
    const status = data.status || 'pending';

    // Seller details
    const storeName = data.storeName || '';
    const sellerPhone = data.sellerPhone || '';
    const sellerAddress = data.sellerAddress || '';
    const sellerGstin = data.sellerGstin || '';

    // UPI payment details
    const upiId = data.upiId || '';
    const upiNumber = data.upiNumber || '';
    const upiQrUrl = sanitizeSharedAssetUrl(data.upiQrUrl);
    const hasPayment = upiId || upiNumber || upiQrUrl;

    // Signature & logo
    const signatureUrl = sanitizeSharedAssetUrl(data.signatureUrl);
    const logoUrl = sanitizeSharedAssetUrl(data.logoUrl);

    // Only show the history portal when we can actually identify a repeat
    // customer using a private client record or a private phone snapshot.
    const clientId = safeString(data.clientId);
    const clientPhoneNormalized = normalizePhone(data.clientPhoneNormalized || '');
    let hasHistoryIdentity = !!clientPhoneNormalized;
    if (!hasHistoryIdentity && clientId && data.ownerId) {
      try {
        const clientDoc = await db.collection('users').doc(String(data.ownerId)).collection('clients').doc(clientId).get();
        if (clientDoc.exists) {
          hasHistoryIdentity = !!normalizePhone(clientDoc.data().phone || '');
        }
      } catch (e) {
        logger.warn('[invoicePage] Client lookup failed:', e);
      }
    }
    let hasHistoryPortal = false;
    if (hasHistoryIdentity && data.ownerId && (clientId || clientPhoneNormalized)) {
      try {
        let repeatQuery = db.collection('shared_invoices')
          .where('ownerId', '==', data.ownerId)
          .orderBy('createdAt', 'desc');
        repeatQuery = clientId
          ? repeatQuery.where('clientId', '==', clientId)
          : repeatQuery.where('clientPhoneNormalized', '==', clientPhoneNormalized);
        const repeatCheck = await repeatQuery.limit(2).get();
        hasHistoryPortal = repeatCheck.size > 1;
      } catch (e) {
        logger.warn('[invoicePage] Repeat customer check failed:', e);
      }
    }

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
      partiallyPaid: { bg: '#dbeafe', text: '#1d4ed8', label: 'Partially Paid' },
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
  <title>BillRaja Invoice</title>
  <meta name="description" content="Secure invoice link from BillRaja. Open to view details, download a PDF, or pay online if enabled.">
  <link rel="canonical" href="https://invoice.billraja.online/i/${esc(shortCode)}">

  <!-- Open Graph -->
  <meta property="og:title" content="BillRaja Invoice">
  <meta property="og:description" content="Secure invoice link from BillRaja. Open to view details, download a PDF, or pay online if enabled.">
  <meta property="og:type" content="website">
  <meta property="og:url" content="https://invoice.billraja.online/i/${esc(shortCode)}">
  <meta property="og:site_name" content="BillRaja">
  <meta property="og:locale" content="en_IN">

  <!-- Twitter Card -->
  <meta name="twitter:card" content="summary">
  <meta name="twitter:title" content="BillRaja Invoice">
  <meta name="twitter:description" content="Secure invoice link from BillRaja. Open to view details, download a PDF, or pay online if enabled.">

  <!-- Structured Data -->
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "WebPage",
    "name": "BillRaja Invoice",
    "isPartOf": {
      "@type": "WebSite",
      "name": "BillRaja"
    }
  }
  </script>

  <meta name="robots" content="noindex,nofollow,noarchive,nosnippet,noimageindex">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  <style>
    *{margin:0;padding:0;box-sizing:border-box}
    body{font-family:'Inter',system-ui,-apple-system,sans-serif;background:#f0f0f0;min-height:100vh;display:flex;flex-direction:column;align-items:center;padding:24px 12px}

    /* ── Invoice Document ── */
    .invoice-page{background:#fff;max-width:700px;width:100%;padding:clamp(12px,3vw,28px);box-shadow:0 2px 24px rgba(0,0,0,0.08);border-radius:4px}
    .inv-title{text-align:center;font-size:clamp(16px,3vw,22px);font-weight:800;color:#0B57D0;padding:clamp(6px,1.5vw,12px) 0;border-bottom:2px solid #7CACF8}
    .seller-box{border:1px solid #7CACF8;padding:clamp(6px,1.5vw,12px);margin-top:clamp(6px,1vw,10px)}
    .seller-name{font-size:clamp(12px,2vw,16px);font-weight:700;color:#000}
    .seller-detail{font-size:clamp(9px,1.5vw,12px);color:#1D1D1F;margin-top:2px}
    .bill-details{display:flex;border:1px solid #7CACF8;margin-top:clamp(6px,1vw,10px)}
    .bill-left,.bill-right{flex:1}
    .bill-right{border-left:1px solid #7CACF8}
    .bd-header{background:#D3E3FD;padding:clamp(4px,0.8vw,8px) clamp(6px,1vw,12px);font-size:clamp(9px,1.5vw,12px);font-weight:700;color:#000}
    .bd-content{padding:clamp(4px,1vw,10px) clamp(6px,1vw,12px)}
    .bd-content div{font-size:clamp(9px,1.5vw,12px);color:#1D1D1F;margin-bottom:2px}
    .bd-content .bd-name{font-size:clamp(10px,1.8vw,14px);font-weight:700;color:#000}
    .items-table{width:100%;border-collapse:collapse;margin-top:clamp(6px,1vw,10px);font-size:clamp(9px,1.5vw,13px)}
    .items-table th,.items-table td{border:1px solid #7CACF8;padding:clamp(3px,0.6vw,6px) clamp(4px,0.8vw,8px)}
    .items-table thead th{background:#D3E3FD;font-weight:700;color:#000;text-align:center}
    .items-table tbody td{color:#000;vertical-align:top}
    .items-table .col-idx{text-align:center;width:clamp(20px,4vw,32px)}
    .items-table .col-name{text-align:left;font-weight:600}
    .items-table .col-num{text-align:right;white-space:nowrap}
    .items-table .col-center{text-align:center;white-space:nowrap}
    .items-table tfoot td{font-weight:700}
    .totals-row{display:flex;margin-top:0}
    .totals-left{flex:1;border:1px solid #7CACF8;border-top:none;padding:clamp(4px,1vw,10px)}
    .totals-right{width:clamp(160px,35vw,240px);border:1px solid #7CACF8;border-top:none;border-left:none}
    .tot-line{display:flex;justify-content:space-between;padding:clamp(2px,0.5vw,5px) clamp(6px,1vw,10px);font-size:clamp(9px,1.5vw,12px);color:#000;border-top:1px solid #7CACF8}
    .tot-line:first-child{border-top:none}
    .tot-line.highlight{background:#0B57D0;color:#fff}
    .tot-line.bold{font-weight:700}
    .words-label{font-size:clamp(8px,1.3vw,11px);font-weight:700;color:#000}
    .words-text{font-size:clamp(8px,1.3vw,11px);color:#1D1D1F;margin-top:2px}
    .terms-sig{display:flex;border:1px solid #7CACF8;margin-top:clamp(6px,1vw,10px)}
    .terms-left{flex:1}
    .sig-right{width:clamp(140px,30vw,200px);border-left:1px solid #7CACF8}
    .ts-header{background:#D3E3FD;padding:clamp(3px,0.6vw,6px) clamp(6px,1vw,10px);font-size:clamp(9px,1.5vw,12px);font-weight:700;color:#000}
    .ts-content{padding:clamp(4px,1vw,8px);font-size:clamp(8px,1.3vw,11px);color:#1D1D1F}
    .sig-area{height:clamp(30px,6vw,50px);margin:4px 8px}
    .sig-label{text-align:center;font-size:clamp(8px,1.3vw,11px);color:#1D1D1F;padding-bottom:4px}
    .inv-footer{font-size:clamp(7px,1vw,9px);color:#6B6B6B;margin-top:clamp(6px,1vw,10px)}
    .status-badge{display:inline-block;padding:3px 10px;border-radius:20px;font-size:clamp(8px,1.3vw,11px);font-weight:700;text-transform:uppercase;letter-spacing:0.3px;background:${sc.bg};color:${sc.text}}

    /* ── Action Buttons ── */
    .actions{max-width:700px;width:100%;margin-top:16px;display:flex;gap:10px;flex-wrap:wrap}
    .action-btn{flex:1;min-width:140px;padding:14px 20px;border:none;border-radius:12px;font-size:15px;font-weight:700;cursor:pointer;text-align:center;text-decoration:none;transition:transform .15s;color:#fff}
    .action-btn:hover{transform:translateY(-1px)}
    .action-btn.primary{background:linear-gradient(135deg,#0B57D0,#4A90E2);box-shadow:0 4px 14px rgba(11,87,208,0.3)}
    .action-btn.green{background:linear-gradient(135deg,#15803d,#22c55e);box-shadow:0 4px 14px rgba(34,197,94,0.3)}

    /* ── Payment ── */
    .payment-section{border:1.5px solid #e5e7eb;border-radius:16px;overflow:hidden}
    .payment-header{display:flex;align-items:center;gap:8px;padding:14px 16px;background:#f0fdf4;font-size:15px;font-weight:700;color:#15803d;border-bottom:1px solid #dcfce7}
    .payment-icon{font-size:20px}
    .payment-body{padding:16px;display:flex;gap:20px;align-items:flex-start;flex-wrap:wrap}
    .qr-container{text-align:center}
    .qr-img{width:clamp(100px,20vw,140px);height:clamp(100px,20vw,140px);border-radius:12px;border:1px solid #e5e7eb;object-fit:contain}
    .qr-label{font-size:11px;color:#9ca3af;margin-top:6px}
    .upi-details{flex:1;min-width:140px}
    .upi-row{margin-bottom:12px}
    .upi-label{font-size:11px;color:#9ca3af;font-weight:600;text-transform:uppercase;letter-spacing:0.5px}
    .upi-value-row{display:flex;align-items:center;gap:8px;margin-top:4px}
    .upi-value{font-size:15px;font-weight:700;color:#111827;word-break:break-all}
    .copy-btn{padding:4px 12px;border:1px solid #d1d5db;border-radius:8px;background:#fff;font-size:11px;font-weight:600;color:#6b7280;cursor:pointer}
    .pay-now-btn{display:block;text-align:center;padding:14px;margin:0 16px 16px;background:linear-gradient(135deg,#15803d,#22c55e);color:#fff;border-radius:12px;font-size:15px;font-weight:700;text-decoration:none}

    /* ── History Portal ── */
    .history-section{margin-top:20px}
    .history-title{font-size:17px;font-weight:800;color:#111827;margin-bottom:4px}
    .history-subtitle{font-size:12px;color:#9ca3af;margin-bottom:16px}
    .phone-input-group{display:flex;gap:8px;margin-bottom:12px}
    .phone-prefix{padding:12px 14px;background:#f3f4f6;border:1.5px solid #e5e7eb;border-radius:12px;font-size:15px;font-weight:600;color:#374151;flex-shrink:0}
    .phone-input{flex:1;padding:12px 14px;border:1.5px solid #e5e7eb;border-radius:12px;font-size:15px;outline:none}
    .phone-input:focus{border-color:#3b82f6}
    .otp-input{width:100%;padding:14px;border:1.5px solid #e5e7eb;border-radius:12px;font-size:18px;font-weight:700;text-align:center;letter-spacing:8px;outline:none;margin-bottom:12px}
    .otp-input:focus{border-color:#3b82f6}
    .otp-btn{display:block;width:100%;padding:14px;background:linear-gradient(135deg,#1e3a8a,#3b82f6);color:#fff;border:none;border-radius:12px;font-size:15px;font-weight:700;cursor:pointer}
    .otp-btn:disabled{opacity:0.5;cursor:not-allowed}
    .otp-error{color:#ef4444;font-size:13px;margin-top:8px;display:none}
    .otp-step{display:none}
    .otp-step.active{display:block}
    .portal-header{background:linear-gradient(135deg,#1e3a8a,#3b82f6);border-radius:16px;padding:20px;margin-bottom:16px;color:#fff}
    .portal-welcome{font-size:11px;color:rgba(255,255,255,0.6);text-transform:uppercase;letter-spacing:0.5px}
    .portal-name{font-size:20px;font-weight:800;margin-top:4px}
    .portal-store{font-size:12px;color:rgba(255,255,255,0.7);margin-top:2px}
    .stats-grid{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-bottom:16px}
    .stat-card{padding:14px;border-radius:12px;border:1.5px solid #f3f4f6}
    .stat-label{font-size:10px;font-weight:600;text-transform:uppercase;letter-spacing:0.5px;color:#9ca3af}
    .stat-value{font-size:18px;font-weight:800;margin-top:4px}
    .stat-count{font-size:11px;color:#9ca3af;margin-top:2px}
    .stat-total{border-color:#e0e7ff;background:#f5f7ff}.stat-total .stat-value{color:#1e3a8a}
    .stat-paid{border-color:#dcfce7;background:#f0fdf4}.stat-paid .stat-value{color:#15803d}
    .stat-pending{border-color:#fef3c7;background:#fffbeb}.stat-pending .stat-value{color:#b45309}
    .stat-overdue{border-color:#fee2e2;background:#fef2f2}.stat-overdue .stat-value{color:#b91c1c}
    .filter-tabs{display:flex;gap:6px;margin-bottom:14px;overflow-x:auto}
    .filter-tab{padding:8px 16px;border-radius:20px;font-size:12px;font-weight:600;border:1.5px solid #e5e7eb;background:#fff;color:#6b7280;cursor:pointer;white-space:nowrap}
    .filter-tab.active{background:#1e3a8a;color:#fff;border-color:#1e3a8a}
    .filter-tab .tab-count{display:inline-block;margin-left:4px;padding:1px 6px;border-radius:10px;font-size:10px;font-weight:700;background:rgba(0,0,0,0.08)}
    .filter-tab.active .tab-count{background:rgba(255,255,255,0.2)}
    .bills-list{margin-top:8px}
    .bills-empty{text-align:center;color:#9ca3af;font-size:13px;padding:32px 0}
    .bill-card{display:flex;justify-content:space-between;align-items:center;padding:14px 16px;background:#fff;border:1.5px solid #f3f4f6;border-radius:12px;margin-bottom:8px;cursor:pointer}
    .bill-card:hover{border-color:#3b82f6;box-shadow:0 2px 8px rgba(59,130,246,0.1)}
    .bill-left{flex:1}.bill-inv-no{font-size:14px;font-weight:700;color:#111827}.bill-date{font-size:12px;color:#9ca3af;margin-top:2px}
    .bill-items-count{font-size:11px;color:#6b7280;margin-top:2px}
    .bill-right{text-align:right}.bill-amount{font-size:15px;font-weight:800;color:#111827}
    .bill-status{display:inline-block;padding:3px 10px;border-radius:20px;font-size:10px;font-weight:700;text-transform:uppercase;margin-top:4px}
    .bill-status.paid{background:#dcfce7;color:#15803d}.bill-status.pending{background:#fef3c7;color:#b45309}.bill-status.overdue{background:#fee2e2;color:#b91c1c}
    .bill-chevron{color:#d1d5db;margin-left:8px}
    .modal-overlay{display:none;position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,0.5);z-index:1000;align-items:flex-end;justify-content:center}
    .modal-overlay.open{display:flex}
    .modal-sheet{background:#fff;border-radius:24px 24px 0 0;width:100%;max-width:480px;max-height:90vh;overflow-y:auto;animation:slideUp .3s ease}
    @keyframes slideUp{from{transform:translateY(100%)}to{transform:translateY(0)}}
    .modal-handle{width:40px;height:4px;background:#d1d5db;border-radius:2px;margin:12px auto}
    .modal-header{display:flex;justify-content:space-between;align-items:flex-start;padding:0 20px 16px;border-bottom:1px solid #f3f4f6}
    .modal-title{font-size:16px;font-weight:800;color:#111827}.modal-meta{font-size:12px;color:#9ca3af;margin-top:4px}
    .modal-close{width:32px;height:32px;border-radius:50%;border:none;background:#f3f4f6;font-size:18px;color:#6b7280;cursor:pointer;display:flex;align-items:center;justify-content:center}
    .modal-body{padding:16px 20px 20px}
    .modal-status-bar{display:flex;justify-content:space-between;align-items:center;padding:12px 16px;border-radius:12px;margin-bottom:16px}
    .modal-status-bar.paid{background:#f0fdf4;border:1px solid #dcfce7}.modal-status-bar.pending{background:#fffbeb;border:1px solid #fef3c7}.modal-status-bar.overdue{background:#fef2f2;border:1px solid #fee2e2}
    .modal-total{font-size:22px;font-weight:800;color:#111827}
    .modal-section-title{font-size:10px;font-weight:700;color:#9ca3af;text-transform:uppercase;letter-spacing:0.8px;margin-bottom:8px}
    .modal-items{width:100%;border-collapse:collapse;font-size:13px;margin-bottom:16px}
    .modal-items thead th{text-align:left;padding:8px 6px;color:#9ca3af;font-size:10px;font-weight:700;border-bottom:2px solid #f3f4f6}
    .modal-items thead th:last-child{text-align:right}
    .modal-items tbody td{padding:10px 6px;border-bottom:1px solid #f9fafb;vertical-align:top}
    .modal-items .mi-desc{font-weight:600;color:#374151}.modal-items .mi-hsn{font-size:10px;color:#9ca3af;margin-top:2px}
    .modal-items .mi-qty{color:#6b7280;text-align:center}.modal-items .mi-total{text-align:right;font-weight:700;color:#111827}
    .modal-summary{background:#f9fafb;border-radius:12px;padding:14px;margin-bottom:16px}
    .modal-sum-row{display:flex;justify-content:space-between;padding:5px 0;font-size:13px;color:#6b7280}
    .modal-sum-row span:last-child{font-weight:600;color:#374151}
    .modal-sum-row.discount span:last-child{color:#ef4444}.modal-sum-row.tax span:last-child{color:#16a34a}
    .modal-sum-divider{height:1px;background:#e5e7eb;margin:6px 0}
    .modal-sum-total{display:flex;justify-content:space-between;padding:6px 0 0;font-size:17px;font-weight:800;color:#111827}
    .modal-download{display:block;width:100%;padding:14px;background:linear-gradient(135deg,#1e3a8a,#3b82f6);color:#fff;border:none;border-radius:12px;font-size:15px;font-weight:700;cursor:pointer;text-align:center;text-decoration:none}

    /* ── Mobile ── */
    @media(max-width:480px){
      body{padding:8px 4px}
      .invoice-page{padding:10px;border-radius:0}
      .bill-details{flex-direction:column}
      .bill-right{border-left:none;border-top:1px solid #7CACF8}
      .totals-row{flex-direction:column}
      .totals-right{width:100%;border-left:1px solid #7CACF8;border-top:none}
      .terms-sig{flex-direction:column}
      .sig-right{width:100%;border-left:none;border-top:1px solid #7CACF8}
      .items-table .col-center:nth-child(4),.items-table thead th:nth-child(4){display:none}
    }
    /* ── Tablet ── */
    @media(min-width:481px) and (max-width:768px){
      body{padding:16px 8px}
    }
    /* ── Desktop ── */
    @media(min-width:769px){
      body{padding:32px 16px}
      .invoice-page{border-radius:8px}
    }
    /* ── Print ── */
    @media print{
      body{background:#fff;padding:0;display:block}
      .invoice-page{box-shadow:none;max-width:100%;border-radius:0}
      .actions,.payment-section,.history-section,.action-btn{display:none!important}
      .inv-title,.bd-header,.ts-header,.items-table thead th,.tot-line.highlight,.status-badge{-webkit-print-color-adjust:exact;print-color-adjust:exact}
    }
  </style>
</head>
<body>
  <!-- Invoice document — matches the Flutter InvoicePreviewWidget exactly -->
  <div class="invoice-page">
    <div class="inv-title">Tax Invoice</div>

    <!-- Seller -->
    <div class="seller-box">
      ${logoUrl ? `<img src="${esc(logoUrl)}" alt="Logo" style="max-height:48px;max-width:120px;object-fit:contain;margin-bottom:4px;display:block">` : ''}
      <div class="seller-name">${esc(storeName || 'Your Store')}</div>
      ${sellerPhone ? `<div class="seller-detail">Phone no.: ${esc(sellerPhone)}</div>` : ''}
      ${sellerAddress ? `<div class="seller-detail">${esc(sellerAddress)}</div>` : ''}
      ${sellerGstin ? `<div class="seller-detail">GSTIN: ${esc(sellerGstin)}</div>` : ''}
    </div>

    <!-- Bill To + Invoice Details -->
    <div class="bill-details">
      <div class="bill-left">
        <div class="bd-header">Bill To:</div>
        <div class="bd-content">
          <div class="bd-name">${esc(clientName)}</div>
          ${data.customerGstin ? `<div>GSTIN: ${esc(data.customerGstin)}</div>` : ''}
        </div>
      </div>
      <div class="bill-right">
        <div class="bd-header">Invoice Details:</div>
        <div class="bd-content">
          <div>No: ${esc(invoiceNumber)}</div>
          <div>Date: <strong>${esc(date)}</strong></div>
          ${data.dueDate ? `<div>Due: ${esc(data.dueDate)}</div>` : ''}
          <div><span class="status-badge">${esc(sc.label)}</span></div>
        </div>
      </div>
    </div>

    <!-- Items Table -->
    <table class="items-table">
      <thead>
        <tr>
          <th class="col-idx">#</th>
          <th>Item Name</th>
          ${items.some(i => i.hsnCode) ? '<th class="col-center">HSN/SAC</th>' : ''}
          <th class="col-center">Qty</th>
          <th class="col-center">Unit</th>
          <th class="col-num">Price/Unit</th>
          <th class="col-num">Amount</th>
          ${gstEnabled ? '<th class="col-center">GST%</th>' : ''}
        </tr>
      </thead>
      <tbody>
        ${items.map((item, idx) => {
          const qty = fmtQty(item.quantity || 0);
          return `<tr>
            <td class="col-idx">${idx + 1}</td>
            <td class="col-name">${esc(item.description)}</td>
            ${items.some(i => i.hsnCode) ? `<td class="col-center">${esc(item.hsnCode || '')}</td>` : ''}
            <td class="col-center">${qty}</td>
            <td class="col-center">${esc(item.unit || '')}</td>
            <td class="col-num">${fmtCur(item.unitPrice || 0)}</td>
            <td class="col-num" style="font-weight:700">${fmtCur(item.total || 0)}</td>
            ${gstEnabled ? `<td class="col-center">${(item.gstRate || 0).toFixed(0)}%</td>` : ''}
          </tr>`;
        }).join('')}
      </tbody>
      <tfoot>
        <tr>
          <td class="col-idx"></td>
          <td class="col-name">Total</td>
          ${items.some(i => i.hsnCode) ? '<td></td>' : ''}
          <td class="col-center">${fmtQty(items.reduce((s, i) => s + (i.quantity || 0), 0))}</td>
          <td></td>
          <td></td>
          <td class="col-num">${fmtCur(subtotal)}</td>
          ${gstEnabled ? '<td></td>' : ''}
        </tr>
      </tfoot>
    </table>

    <!-- Totals -->
    <div class="totals-row">
      <div class="totals-left">
        <div class="words-label">Invoice Amount In Words:</div>
        <div class="words-text">${amount}</div>
      </div>
      <div class="totals-right">
        <div class="tot-line"><span>Sub Total</span><span>${fmtCur(subtotal)}</span></div>
        ${discountAmount > 0 ? `
          <div class="tot-line"><span>Discount${discountType === 'percentage' ? ` (${toNumber(data.discountValue)}%)` : ''}</span><span>- ${fmtCur(discountAmount)}</span></div>
          <div class="tot-line"><span>Taxable Amount</span><span>${fmtCur(taxableAmount)}</span></div>` : ''}
        ${gstEnabled && gstType === 'cgst_sgst' ? `
          <div class="tot-line"><span>CGST</span><span>${fmtCur(cgstAmount)}</span></div>
          <div class="tot-line"><span>SGST</span><span>${fmtCur(sgstAmount)}</span></div>` : ''}
        ${gstEnabled && gstType !== 'cgst_sgst' ? `
          <div class="tot-line"><span>IGST</span><span>${fmtCur(igstAmount)}</span></div>` : ''}
        ${gstEnabled && totalTax > 0 ? `<div class="tot-line"><span>Total Tax</span><span>${fmtCur(totalTax)}</span></div>` : ''}
        <div class="tot-line bold highlight"><span>Grand Total</span><span>${amount}</span></div>
        <div class="tot-line"><span>Received</span><span>${fmtCur(data.amountReceived != null ? data.amountReceived : (status === 'paid' ? data.amount : 0))}</span></div>
        <div class="tot-line bold"><span>Balance</span><span>${fmtCur(data.balanceDue != null ? data.balanceDue : (status === 'paid' ? 0 : data.amount))}</span></div>
      </div>
    </div>

    <!-- Terms + Signature side by side -->
    <div class="terms-sig">
      <div class="terms-left">
        <div class="ts-header">Terms and conditions</div>
        <div class="ts-content">Thank you for doing business with us.</div>
      </div>
      <div class="sig-right">
        <div class="ts-header">For ${esc(storeName || 'Store')}:</div>
        <div class="sig-area">${signatureUrl ? `<img src="${esc(signatureUrl)}" alt="Signature" style="max-height:60px;max-width:160px;object-fit:contain">` : ''}</div>
        <div class="sig-label">Authorized Signatory</div>
      </div>
    </div>

    <div class="inv-footer">Generated by BillRaja</div>
  </div>

  <!-- Action buttons below the invoice -->
  <div class="actions">
    ${downloadUrl ? `
      <a class="action-btn primary" href="${esc(downloadUrl)}" target="_blank" rel="noopener">&#128196; Download PDF</a>` : `
      <button class="action-btn primary" onclick="window.print()">&#128196; Download / Print</button>`}
    <button class="action-btn primary" style="background:linear-gradient(135deg,#6B21A8,#A855F7)" id="imgDlBtn" onclick="downloadAsImage(this)">&#128247; Download Image</button>
    ${hasPayment && upiDeepLink ? `
      <a class="action-btn green" id="payNowBtn" href="${upiDeepLink}" onclick="return handleUpiPay(event)">&#128179; Pay Now</a>` : ''}
  </div>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js"></script>
  <script>
    function downloadAsImage(btn){
      var el=document.querySelector('.invoice-page');
      if(!el)return;
      if(!btn)btn=document.getElementById('imgDlBtn');
      btn.textContent='Generating...';btn.disabled=true;
      // Wait for html2canvas to load if it hasn't yet
      if(typeof html2canvas==='undefined'){
        var s=document.createElement('script');
        s.src='https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js';
        s.onload=function(){doCapture(el,btn)};
        s.onerror=function(){btn.innerHTML='&#128247; Download Image';btn.disabled=false;alert('Could not load image generator. Check your internet connection.')};
        document.head.appendChild(s);
      }else{doCapture(el,btn)}
    }
    function doCapture(el,btn){
      html2canvas(el,{scale:2,useCORS:true,backgroundColor:'#ffffff',logging:false,allowTaint:true}).then(function(canvas){
        var link=document.createElement('a');
        link.download='Invoice_${esc(invoiceNumber)}.png';
        link.href=canvas.toDataURL('image/png');
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        btn.innerHTML='&#128247; Download Image';btn.disabled=false;
      }).catch(function(err){
        console.error('Image capture error:',err);
        btn.innerHTML='&#128247; Download Image';btn.disabled=false;
        alert('Could not generate image. Try Download PDF instead.');
      });
    }
  </script>

  ${hasPayment ? `
  <div style="max-width:600px;width:100%;margin-top:12px;background:#fff;border-radius:16px;box-shadow:0 2px 12px rgba(0,0,0,0.06);overflow:hidden">
      <div class="payment-section" style="border:none;margin:0">
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
      </div>
  </div>` : ''}

  ${hasHistoryPortal ? `
  <div style="max-width:600px;width:100%;margin-top:12px;background:#fff;border-radius:16px;box-shadow:0 2px 12px rgba(0,0,0,0.06);padding:24px">
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
  </div>` : ''}

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
          html += '<a class="modal-download" href="' + escJs(bill.downloadUrl) + '" onclick="return forceDownload(this.href, \\'Invoice_' + escJs(bill.invoiceNumber || '') + '.pdf\\')">&#128196; Download PDF</a>';
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

      function forceDownload(url, filename) {
        fetch(url, { mode: 'cors' })
          .then(function(r) { return r.blob(); })
          .then(function(blob) {
            var a = document.createElement('a');
            a.href = URL.createObjectURL(blob);
            a.download = filename || 'Invoice.pdf';
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(a.href);
          })
          .catch(function() {
            // Fallback: open in new tab
            window.open(url, '_blank');
          });
        return false;
      }

      // Close modal on back button
      window.addEventListener('popstate', function() { closeModal(); });
      </script>
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

exports.downloadSharedInvoice = onRequest(async (req, res) => {
  setSecurityHeaders(res);
  res.set('X-Robots-Tag', 'noindex, nofollow, noarchive, nosnippet, noimageindex');
  const pathParts = req.path.split('/').filter(Boolean);
  const shortCode = pathParts.length >= 2 ? pathParts[1] : null;

  if (!shortCode || !isValidSharedInvoiceShortCode(shortCode)) {
    res.status(404).send(notFoundPage());
    return;
  }

  try {
    try {
      await enforceRateLimit(
        `shared_download_${sanitizeRateLimitKeyPart(getRequestIp(req))}_${shortCode}`,
        120,
        60 * 60 * 1000,
        'Too many invoice download requests. Please try again later.',
      );
    } catch (rateLimitErr) {
      if (rateLimitErr instanceof HttpsError && rateLimitErr.code === 'resource-exhausted') {
        res.status(429).send('Too many download requests. Please try again later.');
        return;
      }
      throw rateLimitErr;
    }

    const doc = await db.collection('shared_invoices').doc(shortCode).get();
    if (!doc.exists) {
      res.status(404).send(notFoundPage());
      return;
    }

    const data = doc.data() || {};
    if (isSharedInvoiceExpired(data)) {
      res.status(404).send(notFoundPage('This invoice link has expired.'));
      return;
    }

    const storagePath = resolveSharedInvoiceStoragePath(data);
    if (!storagePath) {
      res.status(404).send(notFoundPage('This invoice PDF is unavailable.'));
      return;
    }

    const [signedUrl] = await admin.storage().bucket().file(storagePath).getSignedUrl({
      version: 'v4',
      action: 'read',
      expires: Date.now() + (5 * 60 * 1000),
      responseDisposition: `attachment; filename="${sanitizeSharedInvoiceFilename(data.invoiceNumber || shortCode)}"`,
      responseType: 'application/pdf',
    });

    res.redirect(302, signedUrl);
  } catch (err) {
    logger.error('[downloadSharedInvoice] Error:', err);
    res.status(500).send('Unable to download invoice right now.');
  }
});

// ════════════════════════════════════════════════════════════════════════════
// CLIENT BILLS API — returns previous invoices for a verified client
// ════════════════════════════════════════════════════════════════════════════

exports.clientBills = onRequest(async (req, res) => {
  setSecurityHeaders(res);
  // CORS headers — allow both custom domain and Firebase hosting domains
  const allowedOrigins = [
    'https://invoice.billraja.online',
    'https://billraja.com',
    'https://billeasy-3a6ad.firebaseapp.com',
  ];
  const origin = req.headers.origin || '';
  if (allowedOrigins.includes(origin)) {
    res.set('Access-Control-Allow-Origin', origin);
  } else if (origin) {
    res.status(403).json({ error: 'Origin not allowed' });
    return;
  }
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
    const sanitizedShortCode = String(shortCode || '').trim();
    if (!isValidSharedInvoiceShortCode(sanitizedShortCode)) {
      res.status(400).json({ error: 'shortCode is invalid' });
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

    await enforceRateLimit(
      `client_bills_${sanitizeRateLimitKeyPart(decodedToken.uid)}_${sanitizedShortCode}`,
      30,
      10 * 60 * 1000,
      'Too many portal requests. Please try again shortly.',
    );

    // Load current invoice metadata
    const invoiceDoc = await db.collection('shared_invoices').doc(sanitizedShortCode).get();
    if (!invoiceDoc.exists) {
      res.status(404).json({ error: 'Invoice not found' });
      return;
    }

    const invoiceData = invoiceDoc.data();
    if (isSharedInvoiceExpired(invoiceData)) {
      res.status(404).json({ error: 'Invoice link expired' });
      return;
    }
    const ownerId = invoiceData.ownerId;

    const normalizedVerified = normalizePhone(verifiedPhone);
    if (!normalizedVerified) {
      res.status(403).json({ error: 'Phone number not verified' });
      return;
    }

    let matchedClientName = safeString(invoiceData.clientName, 'Customer');
    let billsQuery = db.collection('shared_invoices')
      .where('ownerId', '==', ownerId)
      .orderBy('createdAt', 'desc');

    const invoiceClientId = safeString(invoiceData.clientId);
    let accessVerified = false;

    if (invoiceClientId) {
      const clientDoc = await db.collection('users').doc(ownerId).collection('clients').doc(invoiceClientId).get();
      if (clientDoc.exists) {
        const clientData = clientDoc.data() || {};
        const clientPhone = normalizePhone(clientData.phone || '');
        if (clientPhone && clientPhone === normalizedVerified) {
          accessVerified = true;
          matchedClientName = safeString(clientData.name, matchedClientName);
          billsQuery = billsQuery.where('clientId', '==', invoiceClientId);
        }
      }
    }

    if (!accessVerified) {
      const storedPhone = normalizePhone(invoiceData.clientPhoneNormalized || '');
      if (storedPhone && storedPhone === normalizedVerified) {
        accessVerified = true;
        billsQuery = billsQuery.where('clientPhoneNormalized', '==', storedPhone);
      }
    }

    if (!accessVerified) {
      res.status(403).json({ error: 'No bills found for this phone number' });
      return;
    }

    // Query all shared invoices for the verified client from this owner
    const billsSnapshot = await billsQuery
      .limit(50)
      .get();

    const bills = [];
    billsSnapshot.forEach((doc) => {
      const d = doc.data();
      if (isSharedInvoiceExpired(d)) {
        return;
      }
      bills.push({
        shortCode: doc.id,
        invoiceNumber: d.invoiceNumber || doc.id,
        date: d.date || '',
        amount: d.amount || 0,
        subtotal: d.subtotal || 0,
        status: normalizePortalBillStatus(d.status || 'pending'),
        downloadUrl: resolveSharedInvoiceStoragePath(d)
          ? buildSharedInvoiceDownloadUrl(doc.id)
          : '',
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
      clientName: matchedClientName,
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
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function fmtCur(num) {
  if (!num && num !== 0) return '\u20B90';
  return '\u20B9' + Number(num).toLocaleString('en-IN', { maximumFractionDigits: 0 });
}

function fmtQty(val) {
  if (val === Math.floor(val)) return String(Math.floor(val));
  return Number(val).toFixed(2).replace(/0+$/, '').replace(/\.$/, '');
}

function isSharedInvoiceExpired(data) {
  return !!(data && data.expiresAt && typeof data.expiresAt.toDate === 'function' && data.expiresAt.toDate() <= new Date());
}

function isValidSharedInvoiceShortCode(value) {
  return /^[a-f0-9]{32}$/i.test(String(value || '').trim());
}

function sanitizeSharedTemplateName(value) {
  return safeString(value).slice(0, 80);
}

function computeSharedInvoiceStatus(rawStatus, grandTotal, amountReceived) {
  const normalizedStatus = normalizeStatus(rawStatus);
  const total = roundMoney(toNumber(grandTotal));
  const received = roundMoney(toNumber(amountReceived));
  if (total > 0 && received >= total) return 'paid';
  if (received > 0) return 'partiallyPaid';
  if (normalizedStatus === 'overdue') return 'overdue';
  return 'pending';
}

function normalizePortalBillStatus(status) {
  return status === 'partiallyPaid' ? 'pending' : status;
}

function sanitizeSharedInvoiceItems(rawItems) {
  return (Array.isArray(rawItems) ? rawItems : []).slice(0, 200).map((item) => ({
    description: safeString(item && item.description).slice(0, 240),
    quantity: toNumber(item && item.quantity),
    unitPrice: roundMoney(toNumber(item && item.unitPrice)),
    unit: safeString(item && item.unit).slice(0, 40),
    hsnCode: safeString(item && item.hsnCode).slice(0, 40),
    gstRate: toNumber(item && item.gstRate),
    total: roundMoney(lineItemTotal(item || {})),
    discountPercent: toNumber(item && item.discountPercent),
  }));
}

function isTrustedSharedAssetUrl(value) {
  if (!value) return false;
  try {
    const url = new URL(String(value));
    if (url.protocol !== 'https:' || url.username || url.password) return false;
    const host = url.hostname.toLowerCase();
    if (!host || host === 'localhost' || host.endsWith('.local')) return false;
    if (/^(10|127|169\.254|172\.(1[6-9]|2\d|3[0-1])|192\.168)\./.test(host)) return false;
    return true;
  } catch (_) {
    return false;
  }
}

function sanitizeSharedAssetUrl(value) {
  return isTrustedSharedAssetUrl(value) ? String(value).trim() : '';
}

function isTrustedSharedDownloadUrl(value) {
  if (!value) return false;
  try {
    const url = new URL(String(value));
    if (url.protocol !== 'https:') return false;
    const host = url.hostname.toLowerCase();
    return host === 'firebasestorage.googleapis.com' ||
      host === 'storage.googleapis.com' ||
      host.endsWith('.googleapis.com');
  } catch (_) {
    return false;
  }
}

function extractStoragePathFromDownloadUrl(value) {
  if (!isTrustedSharedDownloadUrl(value)) return '';
  try {
    const url = new URL(String(value));
    const objectMatch = url.pathname.match(/\/o\/([^/?#]+)/);
    if (objectMatch) {
      return decodeURIComponent(objectMatch[1]);
    }

    const parts = url.pathname.split('/').filter(Boolean);
    if (url.hostname.toLowerCase() === 'storage.googleapis.com' && parts.length >= 2) {
      return decodeURIComponent(parts.slice(1).join('/'));
    }
  } catch (_) {
    return '';
  }
  return '';
}

function resolveSharedInvoiceStoragePath(data) {
  const storedPath = safeString(data && data.downloadStoragePath);
  if (storedPath.startsWith('invoices/')) {
    return storedPath;
  }

  const derivedPath = extractStoragePathFromDownloadUrl(data && data.downloadUrl);
  return derivedPath.startsWith('invoices/') ? derivedPath : '';
}

function buildSharedInvoiceDownloadUrl(shortCode) {
  return `https://invoice.billraja.online/d/${encodeURIComponent(shortCode)}`;
}

function sanitizeSharedInvoiceFilename(invoiceNumber) {
  const base = safeString(invoiceNumber, 'Invoice')
    .replace(/[^a-zA-Z0-9._-]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 80);
  return `${base || 'Invoice'}.pdf`;
}

function isValidUpiId(value) {
  return /^[a-zA-Z0-9._-]{2,}@[a-zA-Z]{2,}$/i.test(String(value || '').trim()) &&
    String(value || '').trim().length <= 80;
}

function sanitizePaymentDisplayName(value) {
  return safeString(value, 'Merchant').slice(0, 80);
}

function sanitizePaymentReference(value) {
  return safeString(value, 'Payment').slice(0, 80);
}

function normalizePaymentAmount(value) {
  const numeric = Number(value);
  if (!Number.isFinite(numeric)) return NaN;
  return Number(numeric.toFixed(2));
}

function paymentLinkPayload(pa, pn, amount, tn, exp) {
  return [
    String(pa || '').trim(),
    String(pn || '').trim(),
    normalizePaymentAmount(amount).toFixed(2),
    String(tn || '').trim(),
    String(exp || '').trim(),
  ].join('\n');
}

function getPaymentLinkSigningSecret() {
  return String(process.env.PAY_LINK_SIGNING_SECRET || '').trim();
}

function signPaymentLink(pa, pn, amount, tn, exp) {
  const secret = getPaymentLinkSigningSecret();
  if (!secret) {
    throw new HttpsError('failed-precondition', 'Payment link signing is unavailable right now.');
  }

  return crypto
    .createHmac('sha256', secret)
    .update(paymentLinkPayload(pa, pn, amount, tn, exp))
    .digest('hex');
}

function paymentLinkSignatureMatches(expected, actual) {
  const expectedBuffer = Buffer.from(String(expected || ''), 'utf8');
  const actualBuffer = Buffer.from(String(actual || ''), 'utf8');
  if (expectedBuffer.length === 0 || expectedBuffer.length !== actualBuffer.length) {
    return false;
  }

  return crypto.timingSafeEqual(expectedBuffer, actualBuffer);
}

async function isLegacyBillRajaMerchant(pa, pn) {
  const upiId = String(pa || '').trim();
  const merchantName = sanitizePaymentDisplayName(pn);
  if (!upiId || !merchantName) return false;

  const snapshot = await db.collection('users')
    .where('upiId', '==', upiId)
    .limit(5)
    .get();

  return snapshot.docs.some((doc) => sanitizePaymentDisplayName(doc.data().storeName) === merchantName);
}

exports.createUpiPaymentLink = onCall(
  { secrets: ['PAY_LINK_SIGNING_SECRET'], memory: '256MiB', timeoutSeconds: 30 },
  async (request) => {
    const uid = request.auth && request.auth.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Sign in required.');
    }

    await getPaymentLinkAccessContext(uid);

    const rawUpiId = String((request.data && request.data.upiId) || '').trim();
    const amount = normalizePaymentAmount((request.data && request.data.amount) || 0);
    const merchantName = sanitizePaymentDisplayName(request.data && request.data.businessName);
    const paymentRef = sanitizePaymentReference(request.data && request.data.invoiceNumber);

    if (!isValidUpiId(rawUpiId)) {
      throw new HttpsError('invalid-argument', 'UPI ID is invalid.');
    }
    if (!Number.isFinite(amount) || amount <= 0 || amount > MEMBERSHIP_MAX_MONEY) {
      throw new HttpsError('invalid-argument', 'Amount is invalid.');
    }
    if (!merchantName || !paymentRef) {
      throw new HttpsError('invalid-argument', 'Business name and reference are required.');
    }

    await enforceRateLimit(
      `signed_pay_link_${uid}`,
      600,
      60 * 60 * 1000,
      'Too many payment link requests. Please try again later.',
    );

    const expiresAt = Math.floor(Date.now() / 1000) + PAYMENT_LINK_DEFAULT_AGE_SECONDS;
    const signature = signPaymentLink(rawUpiId, merchantName, amount, paymentRef, expiresAt);

    return {
      url: `https://invoice.billraja.online/p?pa=${encodeURIComponent(rawUpiId)}&pn=${encodeURIComponent(merchantName)}&am=${encodeURIComponent(amount.toFixed(2))}&tn=${encodeURIComponent(paymentRef)}&exp=${expiresAt}&sig=${signature}`,
      expiresAt,
    };
  },
);

// ════════════════════════════════════════════════════════════════════════════
// UPI PAYMENT REDIRECT PAGE
// Serves a mobile-friendly HTML page that auto-opens the UPI app.
// WhatsApp renders HTTPS links as clickable — this bridges the gap
// since upi:// deep links are NOT clickable in WhatsApp messages.
// ════════════════════════════════════════════════════════════════════════════

exports.pay = onRequest({ secrets: ['PAY_LINK_SIGNING_SECRET'] }, async (req, res) => {
  setSecurityHeaders(res);
  const pa = String(req.query.pa || '').trim();
  const pn = String(req.query.pn || '').trim();
  const am = String(req.query.am || '').trim();
  const tn = String(req.query.tn || '').trim();
  const expRaw = String(req.query.exp || '').trim();
  const sig = String(req.query.sig || '').trim();

  if (!pa || !pn || !am || !tn) {
    res.status(400).send('Missing payment parameters');
    return;
  }

  try {
    await enforceRateLimit(
      `pay_${sanitizeRateLimitKeyPart(getRequestIp(req))}`,
      240,
      60 * 60 * 1000,
      'Too many payment page requests. Please try again later.',
    );
  } catch (err) {
    if (err instanceof HttpsError && err.code === 'resource-exhausted') {
      res.status(429).send(err.message);
      return;
    }
    throw err;
  }

  const amount = normalizePaymentAmount(am);
  const safeName = sanitizePaymentDisplayName(pn);
  const safeInvoice = sanitizePaymentReference(tn);
  const isValidAmount = /^\d+(\.\d{1,2})?$/.test(am) &&
    Number.isFinite(amount) &&
    amount > 0 &&
    amount <= MEMBERSHIP_MAX_MONEY;

  if (!isValidUpiId(pa) || !isValidAmount || !safeName || !safeInvoice) {
    res.status(400).send('Invalid payment parameters');
    return;
  }

  const nowSeconds = Math.floor(Date.now() / 1000);
  let signedLinkVerified = false;
  if (expRaw || sig) {
    const parsedExp = Number.parseInt(expRaw, 10);
    if (!Number.isFinite(parsedExp) ||
        parsedExp <= nowSeconds ||
        parsedExp > (nowSeconds + PAYMENT_LINK_MAX_AGE_SECONDS)) {
      res.status(400).send('This payment link is invalid or expired.');
      return;
    }

    try {
      const expectedSig = signPaymentLink(pa, safeName, amount, safeInvoice, parsedExp);
      if (!paymentLinkSignatureMatches(expectedSig, sig)) {
        res.status(400).send('This payment link is invalid or expired.');
        return;
      }
      signedLinkVerified = true;
    } catch (err) {
      logger.error('[pay] Signed link verification failed', {
        error: err && err.message ? err.message : String(err),
      });
      res.status(503).send('Payment link validation is temporarily unavailable.');
      return;
    }
  } else {
    const merchantExists = await isLegacyBillRajaMerchant(pa, safeName);
    if (!merchantExists) {
      res.status(400).send('This payment link is invalid or unsupported.');
      return;
    }
  }

  const upiParams = `pa=${encodeURIComponent(pa)}&pn=${encodeURIComponent(safeName)}&am=${encodeURIComponent(amount.toFixed(2))}&tn=${encodeURIComponent(safeInvoice)}&cu=INR`;
  const upiLink = `upi://pay?${upiParams}`;
  // Android intent:// URL forces the system app chooser instead of WhatsApp
  // intercepting the upi:// scheme in its in-app browser
  const intentLink = `intent://pay?${upiParams}#Intent;scheme=upi;end`;
  const displayAmount = fmtCur(amount);
  const displayName = esc(safeName || 'Merchant');
  const displayInvoice = esc(safeInvoice);
  const safetyNote = signedLinkVerified
    ? 'Secure BillRaja payment link'
    : 'Legacy BillRaja payment link. Verify merchant details before paying.';

  // Payment page with app-specific deep links.
  // WhatsApp's in-app browser intercepts upi:// and routes to WhatsApp Pay.
  // App-specific schemes (tez://, phonepe://, paytmmp://) bypass this.
  const gpayLink = `tez://upi/pay?${upiParams}`;
  const phonepeLink = `phonepe://pay?${upiParams}`;
  const paytmLink = `paytmmp://pay?${upiParams}`;

  res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Pay ${displayAmount} to ${displayName}</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f5f5f5; min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 20px; }
    .card { background: #fff; border-radius: 16px; box-shadow: 0 4px 24px rgba(0,0,0,0.08); padding: 32px 24px; max-width: 380px; width: 100%; text-align: center; }
    .logo { font-size: 24px; font-weight: 800; color: #F97316; margin-bottom: 4px; }
    .subtitle { color: #999; font-size: 12px; margin-bottom: 12px; }
    .amount { font-size: 36px; font-weight: 700; color: #1a1a1a; margin-bottom: 4px; }
    .to { color: #666; font-size: 14px; margin-bottom: 4px; }
    .invoice { color: #999; font-size: 12px; margin-bottom: 24px; }
    .apps { display: flex; flex-direction: column; gap: 10px; }
    .app-btn { display: flex; align-items: center; gap: 12px; padding: 14px 16px; border-radius: 12px; text-decoration: none; font-size: 15px; font-weight: 600; color: #fff; transition: transform 0.1s; }
    .app-btn:active { transform: scale(0.97); }
    .app-btn .icon { width: 28px; height: 28px; flex-shrink: 0; background: #fff; border-radius: 6px; display: flex; align-items: center; justify-content: center; }
    .app-btn .icon svg { width: 20px; height: 20px; }
    .gpay { background: #E8F0FE; color: #1a73e8; border: 1.5px solid #c2d7f2; }
    .gpay .icon { background: transparent; }
    .phonepe { background: #5F259F; }
    .paytm { background: #002E6E; }
    .other { background: #444; font-size: 13px; padding: 12px 16px; }
    .other .icon { background: transparent; }
    .other .icon svg { width: 22px; height: 22px; }
    .secure { margin-top: 16px; color: #777; font-size: 11px; line-height: 1.5; }
  </style>
</head>
<body>
  <div class="card">
    <div class="logo">BillRaja</div>
    <div class="subtitle">${esc(safetyNote)}</div>
    <div class="amount">${displayAmount}</div>
    <div class="to">to ${displayName}</div>
    ${displayInvoice ? `<div class="invoice">Invoice: ${displayInvoice}</div>` : '<div style="margin-bottom:24px"></div>'}
    <div class="apps">
      <a href="${gpayLink}" class="app-btn gpay">
        <span class="icon"><svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M3.963 7.235A3.963 3.963 0 00.422 9.419a3.963 3.963 0 000 3.559 3.963 3.963 0 003.541 2.184c1.07 0 1.97-.352 2.627-.957.748-.69 1.18-1.71 1.18-2.916a4.722 4.722 0 00-.07-.806H3.964v1.526h2.14a1.835 1.835 0 01-.79 1.205c-.356.241-.814.379-1.35.379-1.034 0-1.911-.697-2.225-1.636a2.375 2.375 0 010-1.517c.314-.94 1.191-1.636 2.225-1.636a2.152 2.152 0 011.52.594l1.132-1.13a3.808 3.808 0 00-2.652-1.033zm6.501.55v6.9h.886V11.89h1.465c.603 0 1.11-.196 1.522-.588a1.911 1.911 0 00.635-1.464 1.92 1.92 0 00-.635-1.456 2.125 2.125 0 00-1.522-.598zm2.427.85a1.156 1.156 0 01.823.365 1.176 1.176 0 010 1.686 1.171 1.171 0 01-.877.357H11.35V8.635h1.487a1.156 1.156 0 01.054 0zm4.124 1.175c-.842 0-1.477.308-1.907.925l.781.491c.288-.417.68-.626 1.175-.626a1.255 1.255 0 01.856.323 1.009 1.009 0 01.366.785v.202c-.34-.193-.774-.289-1.3-.289-.617 0-1.11.145-1.479.434-.37.288-.554.677-.554 1.165a1.476 1.476 0 00.525 1.156c.35.308.785.463 1.305.463.61 0 1.098-.27 1.465-.81h.038v.655h.848v-2.909c0-.61-.19-1.09-.568-1.44-.38-.35-.896-.525-1.551-.525zm2.263.154l1.946 4.422-1.098 2.38h.915L24 9.963h-.965l-1.368 3.391h-.02l-1.406-3.39zm-2.146 2.368c.494 0 .88.11 1.156.33 0 .372-.147.696-.44.973a1.413 1.413 0 01-.997.414 1.081 1.081 0 01-.69-.232.708.708 0 01-.293-.578c0-.257.12-.47.363-.647.24-.173.54-.26.9-.26Z" fill="#3c4043"/></svg></span>
        Pay with Google Pay
      </a>
      <a href="${phonepeLink}" class="app-btn phonepe">
        <span class="icon"><svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M10.206 9.941h2.949v4.692c-.402.201-.938.268-1.34.268-1.072 0-1.609-.536-1.609-1.743V9.941zm13.47 4.816c-1.523 6.449-7.985 10.442-14.433 8.919C2.794 22.154-1.199 15.691.324 9.243 1.847 2.794 8.309-1.199 14.757.324c6.449 1.523 10.442 7.985 8.919 14.433zm-6.231-5.888a.887.887 0 0 0-.871-.871h-1.609l-3.686-4.222c-.335-.402-.871-.536-1.407-.402l-1.274.401c-.201.067-.268.335-.134.469l4.021 3.82H6.386c-.201 0-.335.134-.335.335v.67c0 .469.402.871.871.871h.938v3.217c0 2.413 1.273 3.82 3.418 3.82.67 0 1.206-.067 1.877-.335v2.145c0 .603.469 1.072 1.072 1.072h.938a.432.432 0 0 0 .402-.402V9.874h1.542c.201 0 .335-.134.335-.335v-.67z" fill="#5F259F"/></svg></span>
        Pay with PhonePe
      </a>
      <a href="${paytmLink}" class="app-btn paytm">
        <span class="icon"><svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M15.85 8.167a.204.204 0 0 0-.04.004c-.68.19-.543 1.148-1.781 1.23h-.12a.23.23 0 0 0-.052.005h-.001a.24.24 0 0 0-.184.235v1.09c0 .134.106.241.237.241h.645v4.623c0 .132.104.238.233.238h1.058a.236.236 0 0 0 .233-.238v-4.623h.6c.13 0 .236-.107.236-.241v-1.09a.239.239 0 0 0-.236-.24h-.612V8.386a.218.218 0 0 0-.216-.22zm4.225 1.17c-.398 0-.762.15-1.042.395v-.124a.238.238 0 0 0-.234-.224h-1.07a.24.24 0 0 0-.236.242v5.92a.24.24 0 0 0 .236.242h1.07c.12 0 .217-.091.233-.209v-4.25a.393.393 0 0 1 .371-.408h.196a.41.41 0 0 1 .226.09.405.405 0 0 1 .145.319v4.074l.004.155a.24.24 0 0 0 .237.241h1.07a.239.239 0 0 0 .235-.23l-.001-4.246c0-.14.062-.266.174-.34a.419.419 0 0 1 .196-.068h.198c.23.02.37.2.37.408.005 1.396.004 2.8.004 4.224a.24.24 0 0 0 .237.241h1.07c.13 0 .236-.108.236-.241v-4.543c0-.31-.034-.442-.08-.577a1.601 1.601 0 0 0-1.51-1.09h-.015a1.58 1.58 0 0 0-1.152.5c-.291-.308-.7-.5-1.153-.5zM.232 9.4A.234.234 0 0 0 0 9.636v5.924c0 .132.096.238.216.241h1.09c.13 0 .237-.107.237-.24l.004-1.658H2.57c.857 0 1.453-.605 1.453-1.481v-1.538c0-.877-.596-1.484-1.453-1.484H.232zm9.032 0a.239.239 0 0 0-.237.241v2.47c0 .94.657 1.608 1.579 1.608h.675s.016 0 .037.004a.253.253 0 0 1 .222.253c0 .13-.096.235-.219.251l-.018.004-.303.006H9.739a.239.239 0 0 0-.236.24v1.09a.24.24 0 0 0 .236.242h1.75c.92 0 1.577-.669 1.577-1.608v-4.56a.239.239 0 0 0-.236-.24h-1.07a.239.239 0 0 0-.236.24c-.005.787 0 1.525 0 2.255a.253.253 0 0 1-.25.25h-.449a.253.253 0 0 1-.25-.255c.005-.754-.005-1.5-.005-2.25a.239.239 0 0 0-.236-.24zm-4.004.006a.232.232 0 0 0-.238.226v1.023c0 .132.113.24.252.24h1.413c.112.017.2.1.213.23v.14c-.013.124-.1.214-.207.224h-.7c-.93 0-1.594.63-1.594 1.515v1.269c0 .88.57 1.506 1.495 1.506h1.94c.348 0 .63-.27.63-.6v-4.136c0-1.004-.508-1.637-1.72-1.637zm-3.713 1.572h.678c.139 0 .25.115.25.256v.836a.253.253 0 0 1-.25.256h-.1c-.192.002-.386 0-.578 0zm4.67 1.977h.445c.139 0 .252.108.252.24v.932a.23.23 0 0 1-.014.076.25.25 0 0 1-.238.164h-.445a.247.247 0 0 1-.252-.24v-.933c0-.132.113-.239.252-.239Z" fill="#00BAF2"/></svg></span>
        Pay with Paytm
      </a>
      <a href="${upiLink}" class="app-btn other">
        <span class="icon"><svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="1.5" stroke-linecap="round"><rect x="3" y="6" width="18" height="12" rx="2"/><path d="M7 15l3-6 3 4 2-2 2 4"/></svg></span>
        Other UPI App
      </a>
    </div>
    <div class="secure">Only continue if the merchant name and amount match what you expect.</div>
  </div>
</body>
</html>`);
});

// ═══════════════════════════════════════════════════════════════════════════════
// ─── Admin Broadcast Notification ──────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Sends push notifications from the admin dashboard.
 *
 * Input: {
 *   title: string,
 *   body: string,
 *   target: { type: 'all' }
 *           | { type: 'plan', plan: 'pro' | 'enterprise' | 'trial' | 'expired' }
 *           | { type: 'user', uid: string }
 * }
 *
 * Returns: { success: true, sent: number, failed: number, total: number }
 */
exports.sendAdminNotification = onDocumentCreated(
  { document: 'notificationRequests/{requestId}', memory: '512MiB', timeoutSeconds: 120 },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const requestRef = snap.ref;
    const { title, body, target, sentBy, imageUrl } = snap.data();

    // ── Verify sender is an authorized admin ───────────────────────────────
    if (!sentBy) {
      await requestRef.update({ status: 'error', error: 'No sender email.' });
      return;
    }
    const adminDoc = await db.collection('authorizedAdmins').doc(sentBy).get();
    if (!adminDoc.exists) {
      await requestRef.update({ status: 'error', error: 'Not an authorized admin.' });
      return;
    }

    // ── Validate input ─────────────────────────────────────────────────────
    if (!title || !body || !target || !target.type) {
      await requestRef.update({ status: 'error', error: 'Missing title, body, or target.' });
      return;
    }

    // ── Collect target tokens ──────────────────────────────────────────────
    let tokenMap = {}; // { uid: fcmToken }

    if (target.type === 'user') {
      // Single user
      const userDoc = await db.collection('users').doc(target.uid).get();
      if (!userDoc.exists) {
        throw new HttpsError('not-found', `User ${target.uid} not found.`);
      }
      const token = userDoc.data().fcmToken;
      if (token) tokenMap[target.uid] = token;

    } else if (target.type === 'all') {
      // All users with an FCM token
      const snap = await db.collection('users')
        .where('fcmToken', '!=', '')
        .select('fcmToken')
        .get();
      snap.forEach(doc => { tokenMap[doc.id] = doc.data().fcmToken; });

    } else if (target.type === 'plan') {
      // Users on a specific plan
      let planUids = new Set();

      if (target.plan === 'trial' || target.plan === 'expired') {
        // Trial/expired users don't have subscription docs, or have inactive ones.
        // Get all users, then subtract those with active paid subscriptions.
        const activeSubs = await db.collection('subscriptions')
          .where('status', '==', 'active')
          .where('plan', 'in', ['pro', 'enterprise'])
          .select()
          .get();
        const paidUids = new Set(activeSubs.docs.map(d => d.id));

        const allUsers = await db.collection('users')
          .where('fcmToken', '!=', '')
          .select('fcmToken', 'createdAt')
          .get();

        const rcMonths = 6; // trial duration fallback
        const now = new Date();

        allUsers.forEach(doc => {
          if (paidUids.has(doc.id)) return; // skip paid users
          const data = doc.data();
          const createdAt = data.createdAt && data.createdAt.toDate
            ? data.createdAt.toDate()
            : null;

          if (target.plan === 'trial') {
            // In trial = created within last N months and not paid
            if (createdAt) {
              const trialEnd = new Date(createdAt);
              trialEnd.setMonth(trialEnd.getMonth() + rcMonths);
              if (trialEnd > now && data.fcmToken) {
                tokenMap[doc.id] = data.fcmToken;
              }
            }
          } else {
            // Expired = trial ended and not paid
            if (createdAt) {
              const trialEnd = new Date(createdAt);
              trialEnd.setMonth(trialEnd.getMonth() + rcMonths);
              if (trialEnd <= now && data.fcmToken) {
                tokenMap[doc.id] = data.fcmToken;
      }
    }
  }
});
      } else {
        // Pro or enterprise — query subscriptions
        const subs = await db.collection('subscriptions')
          .where('status', '==', 'active')
          .where('plan', '==', target.plan)
          .select()
          .get();
        subs.forEach(doc => planUids.add(doc.id));

        // Fetch tokens for those UIDs (batch in groups of 30 for 'in' query)
        const uidArray = Array.from(planUids);
        for (let i = 0; i < uidArray.length; i += 30) {
          const batch = uidArray.slice(i, i + 30);
          const snap = await db.collection('users')
            .where(FieldPath.documentId(), 'in', batch)
            .select('fcmToken')
            .get();
          snap.forEach(doc => {
            const token = doc.data().fcmToken;
            if (token) tokenMap[doc.id] = token;
          });
        }
      }
    }

    const uids = Object.keys(tokenMap);
    const tokens = Object.values(tokenMap);
    const totalTargeted = uids.length;

    logger.info(`[AdminNotif] Sending to ${totalTargeted} users`, {
      target: target.type,
      plan: target.plan || null,
    });

    // ── Store broadcast record for audit ───────────────────────────────────
    const broadcastRef = await db.collection('broadcasts').add({
      title: title.trim(),
      body: body.trim(),
      target,
      totalTargeted,
      sentBy,
      createdAt: FieldValue.serverTimestamp(),
    });

    // ── Send FCM in batches of 500 ─────────────────────────────────────────
    let sent = 0;
    let failed = 0;
    const BATCH_SIZE = 500;

    for (let i = 0; i < tokens.length; i += BATCH_SIZE) {
      const batchTokens = tokens.slice(i, i + BATCH_SIZE);
      try {
        const notification = { title: title.trim(), body: body.trim() };
        if (imageUrl) notification.imageUrl = imageUrl;

        const fcmData = {
          type: 'admin_broadcast',
          broadcastId: broadcastRef.id,
        };
        if (imageUrl) fcmData.imageUrl = imageUrl;

        const response = await admin.messaging().sendEachForMulticast({
          tokens: batchTokens,
          notification,
          data: fcmData,
          android: {
            priority: 'high',
            notification: imageUrl ? { imageUrl } : undefined,
          },
          apns: imageUrl ? {
            payload: { aps: { 'mutable-content': 1 } },
            fcmOptions: { imageUrl },
          } : undefined,
        });
        sent += response.successCount;
        failed += response.failureCount;
      } catch (err) {
        logger.error('[AdminNotif] Batch send failed', { error: err.message });
        failed += batchTokens.length;
      }
    }

    // ── Store notification in each user's sub-collection ───────────────────
    const notifData = {
      type: 'admin_broadcast',
      title: title.trim(),
      body: body.trim(),
      broadcastId: broadcastRef.id,
      createdAt: FieldValue.serverTimestamp(),
      read: false,
    };

    const notifPromises = uids.map(uid =>
      db.collection('users').doc(uid).collection('notifications').add(notifData)
        .catch(err => logger.warn(`[AdminNotif] Failed to store notif for ${uid}`, { error: err.message }))
    );
    await Promise.all(notifPromises).catch(() => {});

    // ── Update the request doc so admin dashboard knows it's done ──────────
    await requestRef.update({
      status: 'done',
      sent,
      failed,
      total: totalTargeted,
      completedAt: FieldValue.serverTimestamp(),
    });

    await broadcastRef.update({ sent, failed, completedAt: FieldValue.serverTimestamp() });
    logger.info(`[AdminNotif] Done: ${sent} sent, ${failed} failed`);
  }
);
