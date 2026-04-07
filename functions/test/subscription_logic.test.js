const test = require('node:test');
const assert = require('node:assert/strict');

const {
  getSubscriptionTotalCount,
  hasPaidAppAccessStatus,
  isOpenSubscriptionStatus,
  isTerminalRazorpayCancellationError,
  normalizeSubscriptionStatus,
} = require('../subscription_logic');

test('paid app access is granted only to active and halted subscriptions', () => {
  assert.equal(hasPaidAppAccessStatus('active'), true);
  assert.equal(hasPaidAppAccessStatus('halted'), true);
  assert.equal(hasPaidAppAccessStatus('pending'), false);
  assert.equal(hasPaidAppAccessStatus('created'), false);
  assert.equal(hasPaidAppAccessStatus('authenticated'), false);
  assert.equal(hasPaidAppAccessStatus('cancelled'), false);
});

test('open subscription statuses include checkout and live states', () => {
  assert.equal(isOpenSubscriptionStatus('created'), true);
  assert.equal(isOpenSubscriptionStatus('authenticated'), true);
  assert.equal(isOpenSubscriptionStatus('pending'), true);
  assert.equal(isOpenSubscriptionStatus('active'), true);
  assert.equal(isOpenSubscriptionStatus('completed'), false);
});

test('subscription cycle count uses long-running practical limits', () => {
  assert.equal(getSubscriptionTotalCount('monthly'), 120);
  assert.equal(getSubscriptionTotalCount('annual'), 10);
  assert.equal(getSubscriptionTotalCount('unexpected'), 120);
});

test('terminal Razorpay cancel errors are classified safely', () => {
  assert.equal(isTerminalRazorpayCancellationError({ statusCode: 404 }), true);
  assert.equal(
    isTerminalRazorpayCancellationError({ message: 'Subscription already cancelled' }),
    true,
  );
  assert.equal(
    isTerminalRazorpayCancellationError({ message: 'subscription not found' }),
    true,
  );
  assert.equal(
    isTerminalRazorpayCancellationError({ statusCode: 500, message: 'timeout' }),
    false,
  );
  // 400 = bad request (subscription in non-cancellable state)
  assert.equal(isTerminalRazorpayCancellationError({ statusCode: 400 }), true);
  // Razorpay error.description field
  assert.equal(
    isTerminalRazorpayCancellationError({ error: { description: 'Subscription has expired' } }),
    true,
  );
  assert.equal(
    isTerminalRazorpayCancellationError({ message: 'subscription completed' }),
    true,
  );
  assert.equal(
    isTerminalRazorpayCancellationError({ message: 'subscription is paused' }),
    true,
  );
});

test('subscription statuses are normalized consistently', () => {
  assert.equal(normalizeSubscriptionStatus(' Active '), 'active');
  assert.equal(normalizeSubscriptionStatus(null), '');
});
