# BillRaja (billeasy) Deep Analysis Report

**Date:** April 8, 2026
**Scope:** GST calculation logic, data combining (team), save/share flow, security, and scalability
**Constraint:** All remedies must preserve existing app behaviour, features, and user flows

---

## 1. GST Calculation Logic

### 1.1 Architecture Summary

GST computation exists in **four independent locations**, each re-implementing the same math:

| Location | Purpose |
|----------|---------|
| `Invoice` model getters (`cgstAmount`, `igstAmount`, etc.) | Live display when stored values are null |
| `Invoice.toMap()` | Canonical computation for Firestore persistence |
| `CreateInvoiceScreen.build()` | Real-time preview in the create/edit form |
| `syncInvoiceAnalytics` Cloud Function (`buildInvoiceRecord`) | Server-side normalization and analytics |

### 1.2 Issues Found

#### ISSUE G-1: Dual-path discount model creates GST mismatch (Severity: HIGH)

The app has **two independent discount layers** that interact in a subtle, potentially confusing way:

- **Per-item discount** (`LineItem.discountPercent`) — applied at the line-item level, reducing `LineItem.total`.
- **Order-level discount** (`Invoice.discountType` / `discountValue`) — applied on the post-item-discount subtotal.

In `Invoice.toMap()` (lines 276-305), the GST tax base is computed as:

```
mapTaxableAmount = mapSubtotal - mapDiscountAmount
discRatio = mapTaxableAmount / mapSubtotal
per-item tax = item.total * discRatio * item.gstRate / (200 or 100)
```

However, `item.total` already has the per-item discount baked in (`rawTotal - discountAmount`). So the effective discount on the tax base is:

```
effective = 1 - (1 - itemDiscountPct/100) * discRatio
```

This is mathematically correct but **non-obvious** — a user applying 10% per-item discount + 10% order discount might expect 20% off, but the actual discount on the tax base is 19% (compounding). More critically:

**The `CreateInvoiceScreen.build()` preview (lines 367-401) uses a different calculation path** than `Invoice.toMap()`. The screen computes GST per-item during the loop using the live discount ratio against `subtotal` (which already excludes per-item discounts), while `toMap()` recomputes everything from scratch. If the rounding sequence differs by even one step, the preview total can be ₹0.01 off from the saved value.

**Remedy:** Add an `Invoice.computeFinancials()` static method that both `toMap()` and the screen's `build()` call. This eliminates the dual-path risk without changing any user flow. The method returns a `FinancialSummary` record that both locations consume.

#### ISSUE G-2: Per-item GST rate is not validated against allowed rates (Severity: MEDIUM)

`LineItem.gstRate` accepts any `double`. The `_clampGstRate()` in the screen clamps to the nearest allowed rate, but:

- Firestore security rules validate `isAllowedGstRate()` only on the **order-level** `gstRate` field — not on individual items inside the `items` array.
- A modified client or API call could write an item with `gstRate: 15`, which would pass security rules, compute silently, and produce GST amounts that don't match any legal slab.

**Remedy:** Add a Cloud Function validation in `reconcileInvoiceCreate` that checks each item's `gstRate` is in `[0, 5, 12, 18, 28]` and either rejects or normalizes. This is a server-side guardrail with zero client impact.

#### ISSUE G-3: Backward-compat backfill may assign wrong rates (Severity: LOW)

In `Invoice.fromMap()` (lines 218-233), when all items have `gstRate == 0` and the order has `gstEnabled == true`, the code backfills every item with the order-level rate. If the original invoice actually had some items at 0% GST (exempt) and others at 18%, the backfill incorrectly assigns 18% to everything.

**Remedy:** Only backfill if `schemaVersion < 2` (the field already exists). Add a version check: `if (map['schemaVersion'] == null || (map['schemaVersion'] as int) < 2)`.

#### ISSUE G-4: B2B/B2C classification inconsistency (Severity: LOW)

The `isB2B` getter checks `customerGstin.trim().length >= 15`, but `toMap()` checks `customerGstin.trim().isNotEmpty` for the `gstTransactionType` field. A 5-character partial GSTIN would be classified as B2C by the getter but generate a non-empty `gstTransactionType` of `'B2B'` in the persisted data.

**Remedy:** Unify both to use the same check. Replace line 349 with: `'gstTransactionType': customerGstin.trim().length >= 15 ? 'B2B' : 'B2C'`.

#### ISSUE G-5: `double` arithmetic for currency (Severity: INFORMATIONAL)

Using `double` (IEEE 754) for currency is inherently lossy. The `_roundCurrency` helper (`(v * 100).roundToDouble() / 100`) mitigates this well, and `toMap()` carefully avoids re-rounding derived totals. However, for invoices with many items (up to 200 allowed), accumulated floating-point drift before the final round could reach ₹0.01.

**Remedy:** No immediate action needed — the current rounding strategy is sound for the typical invoice size. For future-proofing, consider computing all amounts in **paisa (integer cents)** and dividing by 100 only for display. This is an internal refactor with no UI change.

---

## 2. Team Data Combining Flow

### 2.1 Architecture Summary

The team system pivots on `TeamService.getEffectiveOwnerId()`:

- Solo user → returns their own UID
- Team member → returns the team owner's UID

All services (Firebase, Client, Product, etc.) use this as the data-path key, so a team member reads/writes the owner's data collections.

### 2.2 Issues Found

#### ISSUE T-1: Offline write queuing under team context can orphan data (Severity: HIGH)

When a team member creates an invoice offline (`addInvoiceWithStock`, line 354), the write is fire-and-forget. If the member is later **removed from the team** before the device syncs, Firestore will reject the queued write with `PERMISSION_DENIED` — but the user already sees the invoice locally.

The `leaveTeam()` method (line 393-398) calls `_firestore.terminate()` and `clearPersistence()`, which discards pending writes. But `removeMember()` (invoked by the owner on the server) does NOT trigger any client-side cleanup on the removed member's device — they stay in the old team context until they restart the app.

**Remedy:** Add a `onDisconnect`-style listener in `TeamService._startMapListener`. When `_cachedMap` transitions from non-null to null (or the status changes to non-active), immediately:
1. Cancel all active Firestore listeners.
2. Show a `SnackBar` informing the user.
3. Navigate to the home screen.

This keeps the existing flow intact but prevents phantom writes.

#### ISSUE T-2: `_staleCacheThreshold` of 10 minutes is too generous (Severity: MEDIUM)

The `EffectivePermissions` getter (line 209-233) uses a 10-minute threshold before triggering a background refresh. During those 10 minutes, a team member could operate with revoked permissions (e.g., `canDeleteInvoice` was turned off by the owner 5 minutes ago, but the member's cache still says `true`).

The real-time listener (`_startTeamListener`) should keep this fresh, but if the listener fails silently (network issue), the stale cache persists.

**Remedy:** Reduce `_staleCacheThreshold` to 2 minutes. Also, in `_startTeamListener`'s `onError`, set `_lastSuccessfulUpdate` to `DateTime(0)` to force an immediate refresh on next `can` access.

#### ISSUE T-3: Race between `createdByUid` attribution and team role changes (Severity: LOW)

If a team member's role is changed to `viewer` **while** they have the create invoice screen open, the client-side permission check at save time (line 4815) catches it. But because `_preReservedNumber` was already fetched in `initState`, an invoice number is "wasted" (consumed but never used).

**Remedy:** Acceptable loss — invoice numbers are sequential and gaps don't affect correctness. Document this as expected behavior.

---

## 3. Save and Share Flow

### 3.1 Invoice Save Flow

```
CreateInvoiceScreen._saveInvoice()
  ├─ Validate form + discount + items
  ├─ Check team permissions (client-side)
  ├─ Check plan limits (client-side)
  ├─ Save/update client → ClientService
  ├─ Reserve invoice number → Cloud Function (or reuse pre-reserved)
  ├─ Build Invoice object
  ├─ addInvoiceWithStock() → Firestore batch (invoice + client upsert + stock)
  └─ Navigate to InvoiceDetailsScreen
```

### 3.2 Issues Found

#### ISSUE S-1: No idempotency guard on invoice creation (Severity: HIGH)

If the user double-taps the save button before `_isSaving` is set to `true`, two save operations could execute concurrently. The `_isSaving` flag (line 4857) provides UI-level protection, but it's set *after* async validation steps. The gap between line 4752 and 4857 includes multiple `await` calls (usage check, client save).

A network hiccup causing a retry could create a duplicate invoice with the same data but a different ID and invoice number.

**Remedy:** Move `setState(() { _isSaving = true; })` to the very first line of `_saveInvoice()`, before any validation. If validation fails, reset it. This is purely internal — the button is already disabled when `_isSaving` is true.

#### ISSUE S-2: `StockMovement.balanceAfter` is always 0 (Severity: MEDIUM)

In `addInvoiceWithStock()` (line 337), stock movements are created with `balanceAfter: 0` and a comment "Will be reconciled by server." However, there's no server-side reconciliation function for this. The `balanceAfter` field is never corrected.

This means stock movement history cannot show the running balance, reducing audit trail value.

**Remedy:** Add a `reconcileStockBalances` Cloud Function triggered on `stockMovements/{id}` creation. It reads the product's `currentStock` after the batch completes and patches `balanceAfter`. No client change needed.

#### ISSUE S-3: Offline invoice creation skips plan limit enforcement (Severity: MEDIUM)

When offline, the `UsageTrackingService.instance.getInvoiceCount()` call (line 4837) may return a cached/stale count or fail (caught on line 4850, allowing save). The server-side `reserveInvoiceNumber` enforces limits, but **the number was pre-reserved during `initState`** (line 231), so the actual save doesn't call the Cloud Function again.

This means an expired-plan user could create invoices offline beyond their limit.

**Remedy:** The `reconcileInvoiceCreate` Cloud Function already fires on document creation. Add a plan-limit check there: if the invoice exceeds the limit, mark it with a `pendingDeletion: true` flag and notify the user via the `notifications` subcollection. The invoice remains visible but can be gated in the UI.

### 3.3 Share Flow

The share flow is well-architected:

- **WhatsApp/SMS:** Generates PDF locally, creates a `shared_invoices` doc via Cloud Function, sends a link.
- **Link sharing:** Cloud Function creates/updates `shared_invoices/{shortCode}` with sanitized data.
- **Landing page:** `invoicePage` HTTP function serves branded HTML with rate limiting and expiry.

#### ISSUE S-4: Shared invoice data can become stale (Severity: LOW)

When an invoice is edited after sharing, the `shared_invoices` doc is not automatically updated. The shared link shows the old amounts. The user must manually re-share to update.

**Remedy:** In the `syncInvoiceAnalytics` trigger, check if a `shared_invoices` doc exists for this invoice (query by `invoiceId`). If found, update the financial fields. This is fully server-side.

---

## 4. Security Analysis

### 4.1 Strengths

The security posture is notably strong for a small-business app:

- **Strict invoice shape validation** (`hasValidInvoiceShape`, `hasValidInvoiceFinancials`) prevents malformed data.
- **Financial invariant enforcement** in Firestore rules (`grandTotal == taxableAmount + totalTax`).
- **GSTIN regex validation** matches the official 15-character pattern.
- **Status-only updates** are restricted to specific fields (`isValidInvoiceStatusUpdate`).
- **Team permissions** are checked both client-side and in security rules.
- **Rate limiting** on invoice creation, share links, and page views.
- **CSP headers** on the invoice landing page.
- **App Check** enforcement on Cloud Functions.

### 4.2 Issues Found

#### ISSUE SEC-1: Items array is not deeply validated in security rules (Severity: HIGH)

The rules check `items is list`, `items.size() > 0`, and `items.size() <= 200`, but they do NOT validate the shape or content of individual items. A malicious client could:

- Write an item with `{ "quantity": -100, "unitPrice": 1000 }` — creating a negative subtotal.
- Write an item with `{ "gstRate": 99 }` — bypassing the order-level rate validation.
- Write items with arbitrary extra fields (e.g., executable scripts in `description`).

The financial invariant rules would catch gross violations (negative totals), but a carefully crafted negative item could still produce a valid-looking invoice with artificially deflated tax.

**Remedy:** Add item-level validation in `reconcileInvoiceCreate`:
1. Verify each item has required fields (`description`, `quantity`, `unitPrice`).
2. Verify `quantity > 0` and `unitPrice >= 0`.
3. Verify `gstRate` is in `[0, 5, 12, 18, 28]`.
4. If violations are found, either reject (delete the doc and notify) or normalize.

Note: Firestore rules cannot iterate over list elements, so deep validation must happen in Cloud Functions.

#### ISSUE SEC-2: `updateInvoice` bypasses ownership validation when offline (Severity: MEDIUM)

The `updateInvoice()` method (line 468-482) calls `docRef.set(data)` directly without the `_resolveOwnedInvoiceRef` ownership check. While Firestore rules enforce ownership server-side, the **offline cache accepts the write immediately**, showing potentially unauthorized changes in the UI until the server rejects them.

**Remedy:** Add an `_resolveOwnedInvoiceRef` check at the start of `updateInvoice()`, matching the pattern used in `updateInvoiceStatus()` and `deleteInvoice()`.

#### ISSUE SEC-3: Admin email check uses document existence (Severity: LOW)

The `isAdmin()` rule checks `exists(/databases/$(database)/documents/authorizedAdmins/$(request.auth.token.email))`. If an attacker gains write access to `authorizedAdmins` (unlikely given the rules), they can escalate to admin. More practically, the admin check requires one document read per request, which counts against Firestore quotas.

**Remedy:** No immediate action — the current approach is standard. For future hardening, consider using Custom Claims on Firebase Auth tokens instead, which are free and don't consume reads.

#### ISSUE SEC-4: Payment recording allows arbitrary `newTotalReceived` (Severity: MEDIUM)

The `recordPayment` method accepts `newTotalReceived` as a parameter from the UI. A modified client could pass any value. While the Firestore rule checks `amountReceived <= grandTotal`, it doesn't verify that the increment matches the `paymentAmount`. Someone could record a ₹100 payment but set `newTotalReceived` to `grandTotal`, marking the invoice as fully paid.

**Remedy:** In the `recordPayment` transaction (line 562-593), read the current `amountReceived` from the doc and compute `newTotalReceived = current + paymentAmount` server-side, ignoring the client-supplied value. Alternatively, add a Cloud Function for payments that does this atomically.

---

## 5. Scalability Analysis

### 5.1 Strengths

- **Pagination** is implemented throughout (`FirestorePage`, cursor-based).
- **Composite indexes** cover all query patterns (31 indexes defined).
- **Cloud Functions** have appropriate memory/timeout settings.
- **Offline persistence** with 100MB cache.
- **Stream-based real-time updates** with proper error handling.

### 5.2 Issues Found

#### ISSUE SC-1: `getAllInvoices` can fetch up to 5,000 documents (Severity: HIGH)

The `getAllInvoices()` method (line 206-238) paginates internally but can return up to `maxResults = 5000` documents. For the GST report screen, this is called to load all invoices in a period. At ~2KB per invoice document, this is ~10MB of data transfer and memory usage — enough to cause OOM on low-end Android devices.

**Remedy:** The GST report should use the pre-computed `gstSummaries` from the analytics Cloud Function for summary cards, and only load individual invoices on-demand in the list view (which already paginates at 25). Modify `_loadInvoices` in `GstReportScreen` to use pagination exclusively rather than loading all at once.

#### ISSUE SC-2: `syncInvoiceAnalytics` re-aggregates ALL invoices on every write (Severity: HIGH)

The `updateAnalyticsForWrite` function (called from `syncInvoiceAnalytics`) appears to do full re-aggregation. For a user with 5,000 invoices, every single invoice create/update triggers a Cloud Function that reads thousands of documents. This has O(n) cost per write.

**Remedy:** Use **incremental aggregation** instead:
- On invoice create: increment totals by the new invoice's amounts.
- On invoice update: subtract old values, add new values (the delta).
- On invoice delete: decrement totals.

The `before`/`after` data is already available in the trigger event. Compute the delta and apply it with `FieldValue.increment()`. This reduces each invocation from O(n) reads to O(1).

#### ISSUE SC-3: `searchPrefixes` array can grow large (Severity: MEDIUM)

The `buildInvoiceSearchPrefixes` function generates prefix substrings for search. For a client name of 30 characters + invoice number of 13 characters, this produces ~43 prefixes. With 200 items * 43 = 8,600 array elements across an owner's invoices, the `arrayContains` queries perform well, but the document size grows.

The security rules limit the array to 60 entries and 100 chars each, which is reasonable.

**Remedy:** No immediate action needed. The current limits are well-calibrated.

#### ISSUE SC-4: Missing index for `createdByUid` + `gstEnabled` filter combination (Severity: LOW)

The `_buildInvoicesQuery` allows combining `createdByUid`, `status`, `gstEnabled`, and `searchPrefixes` filters. Some combinations (e.g., `createdByUid + gstEnabled + createdAt`) don't have a matching composite index, which will cause Firestore to return an error at runtime.

**Remedy:** Add the missing composite indexes or restrict the UI from combining these filters simultaneously. Check Firestore's error logs for "FAILED_PRECONDITION" errors indicating missing indexes.

#### ISSUE SC-5: Top-level `invoices` collection scaling concern (Severity: INFORMATIONAL)

All invoices for all users live in a single top-level `invoices` collection, filtered by `ownerId`. This works well up to ~100K total documents. Beyond that, the `ownerId` filter becomes the bottleneck since Firestore must scan the index across all owners.

**Remedy:** No immediate action needed — this is appropriate for the current scale. If the user base grows past ~10K active businesses, consider sharding or moving to `users/{uid}/invoices/{id}` (requires migration).

---

## 6. Remediation Plan (Priority Order)

All fixes below preserve existing app behaviour, features, and user flows.

### Critical (Fix Immediately)

| # | Issue | Fix | Effort |
|---|-------|-----|--------|
| 1 | SEC-1: Items not validated | Add item validation in `reconcileInvoiceCreate` CF | 2 hours |
| 2 | G-1: Dual-path GST calculation | Extract `Invoice.computeFinancials()` method, use in both screen and `toMap()` | 3 hours |
| 3 | S-1: No save idempotency | Move `_isSaving = true` before validation | 15 min |
| 4 | SEC-4: Payment amount bypass | Compute `newTotalReceived` server-side in transaction | 1 hour |

### High (Fix This Sprint)

| # | Issue | Fix | Effort |
|---|-------|-----|--------|
| 5 | SC-2: Full re-aggregation | Convert to incremental delta aggregation in CF | 4 hours |
| 6 | T-1: Orphaned offline writes | Add team-removal detection listener in `TeamService` | 2 hours |
| 7 | SC-1: 5K doc fetch | Refactor GST report to use pre-computed summaries | 3 hours |
| 8 | S-3: Offline plan bypass | Add plan check in `reconcileInvoiceCreate` | 1 hour |

### Medium (Fix Next Sprint)

| # | Issue | Fix | Effort |
|---|-------|-----|--------|
| 9 | G-2: Item GST rate validation | Add slab check in `reconcileInvoiceCreate` | 30 min |
| 10 | SEC-2: Offline update bypass | Add `_resolveOwnedInvoiceRef` to `updateInvoice()` | 30 min |
| 11 | T-2: Stale permission cache | Reduce threshold to 2 min + force refresh on error | 30 min |
| 12 | S-2: Stock balance not reconciled | Add `reconcileStockBalances` CF | 2 hours |
| 13 | S-4: Stale shared invoices | Auto-update shared doc in `syncInvoiceAnalytics` | 1 hour |

### Low (Backlog)

| # | Issue | Fix | Effort |
|---|-------|-----|--------|
| 14 | G-3: Backward-compat backfill | Add `schemaVersion` check | 15 min |
| 15 | G-4: B2B/B2C inconsistency | Unify check in `toMap()` | 10 min |
| 16 | SC-4: Missing composite indexes | Deploy additional indexes | 30 min |
| 17 | SEC-3: Admin claim migration | Move to Custom Claims (future) | 4 hours |
| 18 | G-5: Integer arithmetic | Migrate to paisa-based computation (future) | 8 hours |

---

## 7. Summary

**Overall assessment:** The codebase is well-structured for a startup-stage product. The Firestore security rules are more thorough than most apps at this stage, and the team permission system is architecturally sound. The main risks are:

1. **GST calculation divergence** between the preview screen and the persisted model — this is the most likely source of user-reported "my total is wrong" bugs.
2. **Unbounded reads** in analytics and GST reports — this will become a cost and performance problem as users grow.
3. **Item-level validation gap** in security rules — the only high-severity security issue, mitigated by the fact that a standard Flutter client can't easily send malformed data, but exploitable via a modified client or direct API calls.

All remedies are additive (new methods, new CF triggers) or internal refactors — none alter the user-facing flow.
