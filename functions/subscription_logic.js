function normalizeSubscriptionStatus(status) {
  return String(status || '').trim().toLowerCase();
}

function hasPaidAppAccessStatus(status) {
  return ['active', 'halted'].includes(normalizeSubscriptionStatus(status));
}

function isOpenSubscriptionStatus(status) {
  return ['created', 'authenticated', 'pending', 'active'].includes(
    normalizeSubscriptionStatus(status),
  );
}

function isTerminalRazorpayCancellationError(error) {
  const message = String(error && error.message || '').toLowerCase();
  const description = String(
    error && error.error && error.error.description || '',
  ).toLowerCase();
  const combined = message + ' ' + description;
  return !!(error && (
    error.statusCode === 404 ||
    error.statusCode === 400 ||
    combined.includes('cancelled') ||
    combined.includes('canceled') ||
    combined.includes('not found') ||
    combined.includes('already') ||
    combined.includes('completed') ||
    combined.includes('expired') ||
    combined.includes('paused')
  ));
}

function getSubscriptionTotalCount(billingCycle) {
  // Razorpay enforces max ~30 years on mobile, stricter than API.
  // Use 10 years to stay well within all platform limits.
  return billingCycle === 'annual' ? 10 : 120;
}

module.exports = {
  getSubscriptionTotalCount,
  hasPaidAppAccessStatus,
  isOpenSubscriptionStatus,
  isTerminalRazorpayCancellationError,
  normalizeSubscriptionStatus,
};
