# Subscription Management System — Implementation Plan for BillRaja

## The Big Picture

You want gym owners, swimming pool operators, coaching centers, etc. to manage their **members' recurring subscriptions** through BillRaja — track who's active, who's overdue, auto-generate renewal invoices, and send reminders. Here's how it all fits together with your existing architecture.

---

## 1. New Data Models

### 1a. `SubscriptionPlan` — the plans a business offers

Stored at: `/users/{userId}/subscriptionPlans/{planId}`

```dart
class SubscriptionPlan {
  String id;
  String name;              // "Monthly Gym", "Quarterly Pool", "Annual Coaching"
  String description;
  double amount;            // ₹1500
  String billingCycle;      // 'monthly' | 'quarterly' | 'half_yearly' | 'yearly' | 'custom'
  int customDays;           // only used when billingCycle == 'custom' (e.g., 45 days)
  bool gstEnabled;
  double gstRate;
  bool isActive;            // soft-delete / archive
  DateTime createdAt;
  DateTime updatedAt;
}
```

**Why this model?** Your gym owner creates plans once ("Monthly ₹1500", "Quarterly ₹4000", "Yearly ₹15000") and then assigns them to members. This is separate from your app's own PlanService (Free/Starter/Pro) — this is for the *business owner's customers*.

### 1b. `MemberSubscription` — a client's active/past subscription

Stored at: `/users/{userId}/memberSubscriptions/{subscriptionId}`

```dart
enum MemberSubscriptionStatus { active, expired, cancelled, paused }

class MemberSubscription {
  String id;
  String clientId;          // links to existing Client model
  String clientName;        // denormalized for quick display
  String planId;            // links to SubscriptionPlan
  String planName;          // denormalized
  double amount;            // locked at time of subscription (price may change later)
  String billingCycle;

  DateTime startDate;
  DateTime currentPeriodEnd;  // THE KEY FIELD — when this period expires
  DateTime? nextRenewalDate;  // when to generate next invoice

  MemberSubscriptionStatus status;
  bool autoRenew;           // should the system auto-generate invoice on renewal?

  int renewalCount;         // how many times renewed so far
  String? lastInvoiceId;    // link to the last generated invoice

  String? pauseReason;
  DateTime? pausedAt;
  DateTime? cancelledAt;

  // Reminder tracking
  bool reminderSent7Day;    // 7 days before expiry
  bool reminderSent3Day;    // 3 days before expiry
  bool reminderSentOnExpiry;
  bool reminderSentOverdue;

  DateTime createdAt;
  DateTime updatedAt;
}
```

**Key design decisions:**
- `currentPeriodEnd` is the single source of truth for "is this subscription overdue?"
- Reminder flags prevent duplicate notifications
- `amount` is frozen at subscription time so plan price changes don't retroactively affect active subscriptions
- Links to your existing `Client` model — no duplicate member management needed

### 1c. `SubscriptionEvent` — audit log

Stored at: `/users/{userId}/memberSubscriptions/{subscriptionId}/events/{eventId}`

```dart
class SubscriptionEvent {
  String id;
  String type;    // 'created' | 'renewed' | 'expired' | 'cancelled' | 'paused' | 'resumed' | 'reminder_sent' | 'invoice_generated'
  DateTime timestamp;
  String? invoiceId;
  String? notes;
  Map<String, dynamic>? metadata;
}
```

This gives the business owner a full history: "Ramesh joined Jan 1, renewed Feb 1, missed March, got 3 reminders, cancelled April 15."

---

## 2. Firestore Indexes You'll Need

Add these to `firestore.indexes.json`:

```json
// Member subscriptions by status (dashboard filtering)
{ "collectionGroup": "memberSubscriptions", "fields": [
  { "fieldPath": "status", "order": "ASCENDING" },
  { "fieldPath": "currentPeriodEnd", "order": "ASCENDING" }
]}

// Expiring soon query (for Cloud Function reminder job)
{ "collectionGroup": "memberSubscriptions", "fields": [
  { "fieldPath": "status", "order": "ASCENDING" },
  { "fieldPath": "nextRenewalDate", "order": "ASCENDING" }
]}

// By client (show all subscriptions for a client)
{ "collectionGroup": "memberSubscriptions", "fields": [
  { "fieldPath": "clientId", "order": "ASCENDING" },
  { "fieldPath": "createdAt", "order": "DESCENDING" }
]}
```

---

## 3. Firestore Security Rules

Add alongside your existing rules:

```javascript
match /users/{userId}/subscriptionPlans/{planId} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}

match /users/{userId}/memberSubscriptions/{subId} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}

match /users/{userId}/memberSubscriptions/{subId}/events/{eventId} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```

Same owner-isolation pattern you already use for clients, products, etc.

---

## 4. Cloud Functions — The Backend Brain

### 4a. `checkSubscriptionReminders` — Daily scheduled function

Add to `functions/index.js`, runs alongside your existing `markOverdueInvoices`:

```javascript
exports.checkSubscriptionReminders = onSchedule(
  { schedule: 'every day 08:00', timeZone: 'Asia/Kolkata' },
  async () => {
    const now = new Date();
    const in7Days = addDays(now, 7);
    const in3Days = addDays(now, 3);

    // Query ALL users' memberSubscriptions using collectionGroup
    // (requires the composite indexes above)

    // 1. Find subscriptions expiring in 7 days (not yet reminded)
    const expiring7 = await db.collectionGroup('memberSubscriptions')
      .where('status', '==', 'active')
      .where('currentPeriodEnd', '<=', Timestamp.fromDate(in7Days))
      .where('currentPeriodEnd', '>', Timestamp.fromDate(in3Days))
      .where('reminderSent7Day', '==', false)
      .get();

    // 2. Find subscriptions expiring in 3 days
    const expiring3 = await db.collectionGroup('memberSubscriptions')
      .where('status', '==', 'active')
      .where('currentPeriodEnd', '<=', Timestamp.fromDate(in3Days))
      .where('currentPeriodEnd', '>', Timestamp.fromDate(now))
      .where('reminderSent3Day', '==', false)
      .get();

    // 3. Find subscriptions that expired today
    const justExpired = await db.collectionGroup('memberSubscriptions')
      .where('status', '==', 'active')
      .where('currentPeriodEnd', '<', Timestamp.fromDate(now))
      .where('reminderSentOnExpiry', '==', false)
      .get();

    // For each batch:
    // - Send FCM push to the business owner (using their stored fcmToken)
    // - Update the reminder flag to prevent duplicates
    // - Log a SubscriptionEvent
    // - For justExpired: update status to 'expired'
    // - For autoRenew subscriptions: generate a new invoice automatically
  }
);
```

### 4b. `processSubscriptionRenewal` — Callable function

When a subscription auto-renews or the owner clicks "Renew":

```javascript
exports.processSubscriptionRenewal = onCall(async (request) => {
  // 1. Validate auth
  // 2. Read the memberSubscription doc
  // 3. Calculate new currentPeriodEnd based on billingCycle
  // 4. Create a new Invoice in /invoices (reuse your existing invoice format!)
  // 5. Update the memberSubscription:
  //    - Advance currentPeriodEnd
  //    - Reset all reminder flags
  //    - Increment renewalCount
  //    - Set lastInvoiceId
  //    - Set status back to 'active'
  // 6. Log a SubscriptionEvent
  // 7. Return the new invoice ID
});
```

**This is the beauty of your architecture** — the renewal just creates a standard Invoice that flows through your existing `syncInvoiceAnalytics` pipeline. No new analytics code needed.

### 4c. `sendSubscriptionReminder` — Send reminder to the member

```javascript
exports.sendSubscriptionReminder = onCall(async (request) => {
  // 1. Get the memberSubscription and client details
  // 2. Send WhatsApp message (if phone exists) or SMS via a provider
  // 3. Send FCM notification to the business owner confirming reminder was sent
  // 4. Log a SubscriptionEvent with type 'reminder_sent'
});
```

---

## 5. Flutter Services

### 5a. `SubscriptionPlanService`

```dart
class SubscriptionPlanService {
  // CRUD for business's subscription plans
  Future<List<SubscriptionPlan>> getPlans();
  Future<void> createPlan(SubscriptionPlan plan);
  Future<void> updatePlan(SubscriptionPlan plan);
  Future<void> archivePlan(String planId);
  Stream<List<SubscriptionPlan>> watchPlans();  // real-time
}
```

### 5b. `MemberSubscriptionService`

```dart
class MemberSubscriptionService {
  // Core operations
  Future<void> assignSubscription(String clientId, String planId, DateTime startDate);
  Future<void> renewSubscription(String subscriptionId);  // calls Cloud Function
  Future<void> cancelSubscription(String subscriptionId, String reason);
  Future<void> pauseSubscription(String subscriptionId, String reason);
  Future<void> resumeSubscription(String subscriptionId);

  // Queries
  Stream<List<MemberSubscription>> watchActiveSubscriptions();
  Stream<List<MemberSubscription>> watchExpiringSubscriptions(int withinDays);
  Stream<List<MemberSubscription>> watchOverdueSubscriptions();
  Future<List<MemberSubscription>> getSubscriptionsForClient(String clientId);

  // Dashboard stats
  Future<SubscriptionDashboard> getDashboardStats();
  // Returns: totalActive, totalExpired, totalRevenue, expiringThisWeek, overdueCount

  // Reminder actions
  Future<void> sendReminderToMember(String subscriptionId);
  Future<void> sendBulkReminders(List<String> subscriptionIds);
}
```

### 5c. Update `NotificationService`

Add a subscription-specific check alongside your existing `scheduleOverdueCheck()`:

```dart
Future<void> checkExpiringSubscriptions() async {
  // Query memberSubscriptions where currentPeriodEnd is within 3 days
  // Show local notification: "5 memberships expiring this week!"
}
```

---

## 6. Flutter Screens

### 6a. Subscription Plans Management Screen
- List of plans the business offers (Monthly ₹1500, Quarterly ₹4000, etc.)
- Create/edit/archive plans
- Simple list with FAB to add new plan

### 6b. Member Subscriptions Dashboard Screen
- **Summary cards at top**: Active (green), Expiring Soon (orange), Overdue (red), Paused (grey)
- **Tabbed list below**: All | Active | Expiring | Overdue | Cancelled
- Each item shows: member name, plan name, amount, expiry date, status chip
- Tap to see full subscription details and history

### 6c. Assign Subscription Screen
- Select client (from existing clients list)
- Select plan (dropdown from subscriptionPlans)
- Pick start date
- Toggle auto-renew
- Preview: "₹1500/month, first invoice on March 20, next renewal April 20"
- Creates subscription + first invoice in one action

### 6d. Subscription Detail Screen
- Member info, plan details, timeline of all events
- Action buttons: Renew Now, Send Reminder, Pause, Cancel
- History of all invoices generated for this subscription
- Renewal history with event log

### 6e. Update Existing Screens
- **Customer Detail Screen**: Add a "Subscriptions" tab showing all subscriptions for that client
- **Home Screen Dashboard**: Add subscription summary widget (X active, Y expiring, Z overdue)
- **Settings Screen**: Add "Subscription Reminders" toggle with configurable reminder days

---

## 7. Reminder & Notification Flow

Here's the complete flow for how reminders work:

```
Daily at 8:00 AM IST (Cloud Function)
  │
  ├─ Scan all active subscriptions
  │
  ├─ 7 days before expiry?
  │   ├─ Push notification to business owner: "5 memberships expiring next week"
  │   └─ Mark reminderSent7Day = true
  │
  ├─ 3 days before expiry?
  │   ├─ Push notification to business owner: "Ramesh's gym membership expires in 3 days"
  │   └─ Mark reminderSent3Day = true
  │
  ├─ Expired today?
  │   ├─ If autoRenew ON:
  │   │   ├─ Auto-generate invoice
  │   │   ├─ Extend currentPeriodEnd
  │   │   └─ Notify owner: "Auto-renewed 3 memberships, invoices created"
  │   ├─ If autoRenew OFF:
  │   │   ├─ Mark status = 'expired'
  │   │   └─ Notify owner: "Ramesh's membership expired. Send reminder?"
  │   └─ Mark reminderSentOnExpiry = true
  │
  └─ Overdue (expired > 3 days, no payment)?
      ├─ Push notification: "8 memberships overdue. Send reminders?"
      └─ Mark reminderSentOverdue = true

Business owner can also manually:
  ├─ Tap "Send Reminder" → WhatsApp/SMS to the member
  ├─ Tap "Renew Now" → Creates invoice + extends subscription
  └─ Tap "Send Bulk Reminders" → Reminds all overdue members at once
```

---

## 8. Sending Reminders to End Members (the gym goers)

For actually reaching the members (not just notifying the business owner), you have a few options:

**Option A — WhatsApp Business API (Recommended for India)**
- Use a provider like Twilio, Gupshup, or Wati
- Cloud Function calls the API with the member's phone number
- Template message: "Hi {name}, your {plan} membership at {business} expires on {date}. Please renew to continue."
- Cost: ~₹0.50-1.00 per message

**Option B — SMS via a gateway**
- Providers: MSG91, Textlocal, Twilio
- Cheaper but less engagement than WhatsApp
- Good as a fallback

**Option C — In-app notification (if members also use the app)**
- Only works if you build a member-facing app in the future
- For now, stick with WhatsApp/SMS

**My recommendation**: Start with WhatsApp (most Indian businesses and their customers use it), with SMS as fallback. Add a `reminderChannel` preference to the business profile.

---

## 9. Implementation Phases

### Phase 1 — Foundation (1-2 weeks)
- SubscriptionPlan model + service + CRUD screen
- MemberSubscription model + service
- Assign subscription to client flow
- Basic list/detail screens

### Phase 2 — Invoicing Integration (1 week)
- Auto-generate invoice on subscription creation
- Renewal flow (manual "Renew Now" button)
- Link invoices to subscriptions
- Show subscription info on invoice detail

### Phase 3 — Reminders & Automation (1-2 weeks)
- Cloud Function for daily subscription check
- Push notifications to business owner
- Manual "Send Reminder" to member (WhatsApp API)
- Bulk reminder action
- Reminder preferences in settings

### Phase 4 — Dashboard & Polish (1 week)
- Subscription analytics dashboard
- Home screen subscription widget
- Subscription tab on customer detail
- Export subscription data (CSV)

### Phase 5 — Advanced (Future)
- Auto-renewal with auto-invoice
- Grace period handling (allow X days after expiry before marking expired)
- Proration for plan changes mid-cycle
- Attendance/check-in tracking (gym members)
- Member-facing portal/app

---

## 10. How It Fits Your Existing Architecture

| What exists today | How subscriptions plug in |
|---|---|
| `Client` model | Members ARE clients — no new entity needed |
| `Invoice` model | Subscription renewals generate standard invoices |
| `syncInvoiceAnalytics` Cloud Function | Automatically picks up subscription invoices |
| `markOverdueInvoices` scheduler | Subscription invoices flow through this too |
| `NotificationService` with FCM | Reuse for subscription push notifications |
| `PlanService` (Free/Starter/Pro) | Gate subscription features behind Starter/Pro plans |
| `CustomerGroup` model | Use groups like "Gym Members", "Pool Members" |
| Firestore security rules pattern | Same `userId` isolation for subscription collections |

The subscription system is essentially a **layer on top** of your existing client + invoice system, not a replacement. A subscription is just a rule that says "generate an invoice for this client on this schedule."
