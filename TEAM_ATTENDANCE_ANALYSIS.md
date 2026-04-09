# BillRaja — Team & Attendance Management System: Deep Security & Scalability Analysis

**Date:** April 8, 2026  
**Scope:** Team management, attendance system, employee states, RBAC, Firestore rules, Cloud Functions  
**Constraint:** All remedies preserve existing app behaviour, features, and user flows.

---

## 1. Architecture Summary

The system has two distinct domains sharing infrastructure:

**Team Management** — role-based multi-user access to a single business workspace. The team owner's Firebase UID doubles as the team ID, so all existing data paths (`users/{uid}/...`) work unchanged when a member calls `getEffectiveOwnerId()`.

**Membership/Attendance** — gym/club member tracking with plan lifecycle (active → frozen → expired → cancelled) and four attendance methods (QR, code, manual, geo).

Both domains delegate all mutations to Cloud Functions (Admin SDK writes), with Firestore rules set to `isAdmin()` for write paths. The client is read-heavy and write-light by design.

---

## 2. Security Analysis

### 2.1 Strengths (What's Done Well)

**Server-side authority for all mutations.** Every team operation (invite, accept, remove, role change, geo check-in/out) and every membership operation (save, freeze, unfreeze, renew, mark attendance) goes through a Cloud Function. Firestore rules lock writes to `isAdmin()`, meaning a tampered client cannot directly write to team/member/attendance documents. This is a strong security posture.

**Permission checks are dual-layered.** Both the Firestore rules (`teamMemberHasPermission`) and Cloud Functions (`hasPermission`) enforce the same role + override logic. An attacker who bypasses the client still hits server-side permission checks.

**Audit trail.** `writeAuditLog()` records team actions (invite, accept, remove, role change, leave) to `teams/{teamId}/auditLogs`. This is fire-and-forget but provides forensic traceability.

**Rate limiting on invites.** `enforceRateLimit` caps invites at 20/hour per UID, preventing invite spam.

**Geofence validated server-side.** The Cloud Function computes Haversine distance and rejects check-ins outside the radius. The client also validates locally (for UX), but the server is the authority.

**Input sanitization.** Phone normalization strips non-digit characters, email is lowercased/trimmed, role values are allowlisted, coordinate ranges are validated.

---

### 2.2 Issues Found

#### ISSUE S-1: `collectionGroup('members')` in `syncMembershipStates` is Unscoped (CRITICAL)

**File:** `functions/index.js`, line 3029

The scheduled function queries `db.collectionGroup('members').where('status', '==', 'active').where('endDate', '<', now)`. A `collectionGroup` query matches **every** subcollection named `members` across the entire database — this includes both `users/{uid}/members/{memberId}` (gym members) AND `teams/{teamId}/members/{memberUid}` (team members).

If a team member document happens to have a stale `endDate` field (or one is added accidentally), the function would flip that team member's status to `expired`, effectively locking them out.

**Impact:** A scheduled job could silently corrupt team member records, revoking access for legitimate team members.

**Remedy:** Add a discriminator field (`docType: 'membership_member'`) to membership member documents and filter on it in the collectionGroup query. This is additive — it doesn't change any existing read/write flows. The Cloud Function that creates membership members (`saveMembershipMember`) would set this field, and a one-time backfill migration adds it to existing docs.

---

#### ISSUE S-2: Geo Check-Out Does Not Re-validate Geofence (MEDIUM)

**File:** `functions/index.js`, line 2475

`teamGeoCheckOut` accepts only a `logId` and does not require or validate coordinates. The client passes `latitude`/`longitude` to `geoCheckOut()` in `membership_service.dart` (line 336–337) but the Cloud Function ignores them.

**Impact:** A team member could check in from inside the geofence, leave the office, and check out from anywhere. Depending on business requirements, this may undermine attendance accuracy. Not a data integrity issue, but a policy enforcement gap.

**Remedy:** Add optional coordinate validation to `teamGeoCheckOut`. Accept `latitude`/`longitude`, and if the team document has `requireGeofenceOnCheckout: true` (a new optional boolean, defaulting to `false`), validate the distance. Existing behaviour is unchanged because the default is `false`.

---

#### ISSUE S-3: No Duplicate Check-In Guard Across Methods (MEDIUM)

**File:** `functions/index.js`, line 2446 (geo) and line 2943 (membership attendance)

The geo check-in function checks for an open check-in only in `teams/{teamId}/members/{uid}/attendance`. The membership attendance function (`markMembershipAttendance`) writes to `users/{ownerId}/members/{memberId}/attendance`. These are completely separate collections with no cross-validation.

**Impact:** A gym member who is also a team member could theoretically have overlapping check-in records in both domains. More importantly, within the membership domain, `markMembershipAttendance` does not check for an existing open attendance log before creating a new one — it always creates a new check-in record.

**Remedy:** Add an "already checked in today" guard to `markMembershipAttendance`, mirroring what `teamGeoCheckIn` already does (query for today's logs without a `checkOutTime`). This is purely additive.

---

#### ISSUE S-4: SharedPreferences Cache Poisoning Window (LOW)

**File:** `lib/services/team_service.dart`, lines 495–540

The `TeamService` persists `_cachedMap` (including role) and `_cachedTeam` (including `rolePermissions`) to `SharedPreferences`. If an attacker on a rooted device modifies these values, the client-side `EffectivePermissions` would report elevated permissions, showing UI elements that should be hidden.

**Impact:** Low, because all mutations go through Cloud Functions that independently verify permissions. The risk is limited to UI spoofing (seeing menu items that fail on tap). However, on sensitive screens (e.g., viewing revenue reports that are read from Firestore), the Firestore rule for reads checks `isOwnerOrTeamMember` but does not check `canViewRevenue` — so a viewer could potentially read revenue analytics data if they know the path.

**Remedy:** For sensitive read-only data (analytics, revenue), add permission-level read rules in Firestore. For example, the analytics subcollection rule could add a `canViewReports` check for non-owner team members. This is additive and doesn't change the existing owner/solo experience.

---

#### ISSUE S-5: `canManageMembershipFor` Only Allows Owner/CoOwner (LOW)

**File:** `firestore.rules`, line 84

The `canManageMembershipFor` helper restricts membership reads to `owner` and `coOwner` roles. A manager with `canMarkAttendance: true` cannot read the membership member list from Firestore, even though the Cloud Function allows them to mark attendance.

**Impact:** Managers and sales staff who should be able to mark attendance via QR/manual methods cannot load the member list client-side. This may already be working only because the Cloud Function handles the write, but the client's `watchMembers()` stream would fail with permission denied for non-owner roles.

**Remedy:** Add a `canMarkAttendance` check as an alternative in the Firestore read rule for `members/{memberId}` and `members/{memberId}/attendance/{logId}`. Something like: `allow read: if canManageMembershipFor(userId) || (isTeamMember(userId) && teamMemberHasPermission(userId, 'canMarkAttendance', ['owner', 'coOwner', 'manager', 'sales'])) || isAdmin();`

---

#### ISSUE S-6: `createTeamCF` Does Not Verify Subscription Plan (MEDIUM)

**File:** `functions/index.js`, line 1470

The `createTeamCF` function creates a team without checking whether the caller has an active Pro/Enterprise subscription. The invite function (`createTeamInvite`) does check `getMaxTeamMembersForOwner`, but team creation itself is unguarded.

**Impact:** A free/expired user could create a team document. They couldn't add members (invite checks the plan), but the stale team document occupies Firestore space and could cause confusion.

**Remedy:** Add a plan check at the top of `createTeamCF`: call `getResolvedOwnerPlan(uid)` and reject if the plan is `'expired'`. This is a server-side-only change.

---

## 3. Scalability Analysis

### 3.1 Strengths

**Paginated batch processing.** `syncMembershipStates` and `cleanupExpiredTeamInvites` both use 500-doc pages with `startAfter` cursors and `bulkWriter`. This handles growth well.

**CollectionGroup indexes are declared.** The `firestore.indexes.json` includes collectionGroup indexes for `members` (status+endDate, status+frozenUntil) and `attendance` (attendanceDomain+markedBy+checkInTime). These support the scheduled functions and dashboard queries.

**Cloud Function memory is conservatively allocated** (256MiB) which is appropriate for the workload and cost-efficient.

---

### 3.2 Issues Found

#### ISSUE P-1: `getDashboardStats()` Loads All Members Into Memory (HIGH)

**File:** `lib/services/membership_service.dart`, line 421

`getDashboardStats()` calls `_membersCol().get()` — a full collection read with no limit. For a gym with 10,000 members, this fetches 10K documents to the client to compute counts and revenue.

**Impact:** At scale, this causes slow screen loads, excessive bandwidth usage, and high Firestore read costs. The code comment acknowledges this: "For very large gyms (>10K members), consider denormalizing stats into a summary document."

**Remedy:** Create a Cloud Function trigger (`onDocumentWritten` on `users/{uid}/members/{memberId}`) that maintains a denormalized stats document at `users/{uid}/membershipStats/current` with pre-computed `totalMembers`, `active`, `expired`, `frozen`, `expiringThisWeek`, and `totalRevenue`. The client reads a single document instead of the entire collection. The existing `getDashboardStats` method can be kept as a fallback for small datasets while the trigger backfills.

---

#### ISSUE P-2: `getTodayAttendance()` CollectionGroup Query May Hit Unrelated Documents (MEDIUM)

**File:** `lib/services/membership_service.dart`, line 247

The `collectionGroup('attendance')` query filters by `attendanceDomain == 'membership'` and `markedBy == uid`. This scans across ALL attendance subcollections in the database. As the total attendance volume grows across all users, this query's cost grows linearly with the total number of attendance documents in the system, not just the current user's.

**Impact:** Read costs scale with total system size, not per-user size. For a platform with 1,000 businesses each having 100 members with daily attendance, the collectionGroup index covers millions of documents.

**Remedy:** The existing composite index (attendanceDomain + markedBy + checkInTime) already narrows the scan efficiently thanks to Firestore's index-based query execution. However, if cost becomes a concern at scale, consider switching to a scoped query: instead of collectionGroup, iterate over the owner's known member IDs and query each member's attendance subcollection. Alternatively, maintain a flat `dailyAttendance/{ownerId}_{date}` summary document updated by the Cloud Function.

---

#### ISSUE P-3: `watchMembers()` in TeamService Has No Pagination (MEDIUM)

**File:** `lib/services/team_service.dart`, line 344

`watchMembers()` streams all active team members with no limit. Current team sizes are small (3–5 for Pro, unlimited for Enterprise), but if Enterprise teams grow to 50+ members, this real-time listener triggers for every member status change.

**Impact:** For large Enterprise teams, frequent snapshot updates could cause UI jank and increased Firestore listener costs.

**Remedy:** Add a `.limit(100)` to the query as a safety cap. For teams exceeding this, implement pagination in the team management screen. Since current plans cap at reasonable numbers, this is a future-proofing measure.

---

#### ISSUE P-4: `hasPermission` in Cloud Functions Makes an Extra Firestore Read (LOW)

**File:** `functions/index.js`, line 241

When `teamData` is not passed, `hasPermission` fetches the team document. Several Cloud Functions call `getValidatedTeamContext` (which reads `userTeamMap` + `members/{uid}`) and then separately call `hasPermission` (which reads `teams/{teamId}` again). That's 3 reads per function invocation.

**Impact:** Extra Firestore reads add latency (~20–50ms each) and cost. For a team geo check-in, that's 3 reads before the actual write.

**Remedy:** Have `getValidatedTeamContext` also fetch and return the team document data, then pass it to `hasPermission` as the optional `teamData` parameter. This reduces reads from 3 to 2 per invocation. Purely internal refactor, no API changes.

---

#### ISSUE P-5: No Composite Index for Team Attendance Dashboard Queries (LOW)

The `attendance_dashboard_screen.dart` likely queries attendance by date range per team member. The existing indexes cover `checkInTime` ordering within a single member's attendance subcollection, but if the dashboard aggregates across all team members, it would need multiple sequential queries (one per member).

**Remedy:** For the attendance dashboard, consider a denormalized `dailyTeamAttendance/{teamId}_{date}` document that the geo check-in/check-out Cloud Functions update atomically. The dashboard reads one document per day instead of N queries (one per team member).

---

## 4. Employee State Machine Analysis

### 4.1 Membership Member States

The `Member` model has four states: `active`, `expired`, `frozen`, `cancelled`.

**State transitions:**

```
[new] → active (on creation via saveMembershipMember)
active → expired (syncMembershipStates when endDate < now)
active → frozen (freezeMembershipMember)
frozen → active (unfreezeMembershipMember, with endDate extension)
frozen → expired (syncMembershipStates when frozenUntil <= now AND new endDate < now)
active → cancelled (not implemented in any Cloud Function)
```

**Issue SM-1:** The `cancelled` state exists in the enum but has no Cloud Function that transitions to it. It's a dead state — members can never reach it through any server-side operation. If cancellation is intended as a feature, it needs a `cancelMembershipMember` Cloud Function. If not, it should be documented as reserved/unused to avoid confusion.

**Issue SM-2:** The `isActive`, `isExpired`, and `isFrozen` computed properties on the `Member` model (lines 68–75) use client-side `DateTime.now()` for status derivation, which may disagree with the server-set `status` field. For example, `isExpired` returns true if `endDate.isBefore(DateTime.now())` even when `status` is still `'active'` (the scheduled function hasn't run yet). This dual-source-of-truth can cause UI inconsistencies.

**Remedy for SM-2:** The computed properties are correct as defensive checks (the server runs every 6 hours, so there's a window). Document this explicitly and consider renaming them to `isEffectivelyActive` / `isEffectivelyExpired` to clarify they account for real-time state, while `status` reflects the last server-synced state.

### 4.2 Team Member States

States: `invited`, `active`, `removed`.

**Transitions:**

```
[invite created] → invited (in teamInvites collection, not yet a member doc)
invited → active (acceptTeamInvite creates the member doc as 'active')
active → removed (removeTeamMember sets status to 'removed')
active → [deleted] (leaveTeam deletes the member doc entirely)
```

**Issue SM-3:** `removeTeamMember` sets status to `'removed'` but `leaveTeam` deletes the document entirely. This inconsistency means removed-by-owner members leave an audit trail in the member doc, while voluntary departures don't. Both actions write to the audit log, so the forensic trail exists, but the member subcollection is inconsistent.

**Remedy:** This is a design choice rather than a bug. If consistency is desired, `leaveTeam` could set status to `'left'` instead of deleting. But since the existing behaviour works and the audit log captures both events, this is low priority.

### 4.3 Team Invite States

States: `pending`, `accepted`, `declined`, `expired`.

**Transitions are clean and well-guarded:** expiry is enforced both by client-side check (`inviteIsExpired`) and server-side cleanup (`cleanupExpiredTeamInvites`). Duplicate invites are deduplicated by phone/email match. The 7-day expiry window is reasonable.

---

## 5. Prioritized Remedy Plan

All remedies below are additive. None alter existing app behaviour, features, or user flows.

### Priority 1 — Critical (Do First)

| # | Issue | Remedy | Effort |
|---|-------|--------|--------|
| S-1 | collectionGroup('members') unscoped | Add `docType` discriminator field to membership members; filter in syncMembershipStates | 2–3 hours |

### Priority 2 — High (This Sprint)

| # | Issue | Remedy | Effort |
|---|-------|--------|--------|
| P-1 | getDashboardStats loads all members | Add Cloud Function trigger to maintain denormalized stats doc | 4–6 hours |
| S-6 | createTeamCF skips plan check | Add `getResolvedOwnerPlan` check at function start | 30 min |

### Priority 3 — Medium (Next Sprint)

| # | Issue | Remedy | Effort |
|---|-------|--------|--------|
| S-2 | Geo check-out skips geofence | Add optional `requireGeofenceOnCheckout` flag | 1–2 hours |
| S-3 | No duplicate check-in guard in membership attendance | Add open-log check before creating new attendance | 1 hour |
| S-5 | canManageMembershipFor too restrictive for readers | Add canMarkAttendance as alternative read permission | 1 hour |
| P-4 | Extra Firestore read in hasPermission | Pass teamData from getValidatedTeamContext | 1 hour |

### Priority 4 — Low (Backlog)

| # | Issue | Remedy | Effort |
|---|-------|--------|--------|
| S-4 | SharedPreferences cache spoofing | Add permission-level Firestore read rules for sensitive data | 2–3 hours |
| P-2 | collectionGroup attendance cost at scale | Monitor; add scoped queries or daily summary docs if needed | 3–4 hours |
| P-3 | watchMembers unbounded | Add .limit(100) safety cap | 15 min |
| P-5 | No attendance dashboard denormalization | Add dailyTeamAttendance summary docs | 3–4 hours |
| SM-1 | cancelled state unreachable | Add cancelMembershipMember CF or document as reserved | 1–2 hours |

---

## 6. Summary

The team and attendance management system is architecturally sound. The decision to funnel all writes through Cloud Functions is the right call for a multi-tenant system — it makes the Firestore rules simpler and the security model auditable. The RBAC system with role defaults + per-role overrides is flexible and well-implemented across both client and server.

The most pressing issue is **S-1** (unscoped collectionGroup query in the scheduled function), which could silently corrupt team member records. The highest-impact performance issue is **P-1** (full collection scan for dashboard stats), which will degrade as gym membership counts grow.

Everything else is incremental hardening — tightening geofence validation, adding duplicate guards, reducing redundant Firestore reads, and future-proofing for Enterprise-scale teams.
