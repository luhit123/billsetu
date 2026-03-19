# BillRaja Firebase Functions

This folder contains the server-side Firebase Functions for invoice numbering,
derived invoice totals, dashboard analytics, overdue processing, and client
cleanup.

## Exports

- `reserveInvoiceNumber` - callable function that atomically reserves the next
  invoice number for the signed-in user.
- `syncInvoiceAnalytics` - Firestore trigger that persists derived invoice
  totals and updates dashboard/GST analytics after invoice writes.
- `markOverdueInvoices` - scheduled job that marks pending invoices overdue
  when their due date has passed.
- `cleanupInvoicesAfterClientDelete` - Firestore trigger that removes broken
  client references from invoices without deleting invoice history.

## Assumptions

- If an invoice does not already carry a due date, the scheduled overdue job
  uses `createdAt + 30 days`.
- GST analytics are stored under `users/{ownerId}/analytics/...`.
- Invoice numbering uses the `BR-<year>-00001` format in the `Asia/Kolkata`
  timezone.

## Deploy

1. `cd functions`
2. `npm install`
3. `firebase deploy --only functions`
