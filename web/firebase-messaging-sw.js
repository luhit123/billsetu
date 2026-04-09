// Give the service worker access to Firebase Messaging.
// Note that you can only use Firebase Messaging here. Other Firebase libraries
// are not available in the service worker.
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

// Initialize the Firebase app in the service worker by passing in
// your app's Firebase config object.
firebase.initializeApp({
  apiKey: 'AIzaSyAQwciiy95IZmhNumtPLgqDHXF1ypiEMbc',
  appId: '1:742769968562:web:2b432531b9004cc327d0ab',
  messagingSenderId: '742769968562',
  projectId: 'billeasy-3a6ad',
  authDomain: 'auth.billraja.com',
  storageBucket: 'billeasy-3a6ad.firebasestorage.app',
  measurementId: 'G-YHK3H5LNRW',
});

// Retrieve an instance of Firebase Messaging so that it can handle background
// messages (when the PWA is not in the foreground).
const messaging = firebase.messaging();

messaging.onBackgroundMessage(function (payload) {
  const notificationTitle = payload.notification?.title || 'BillRaja';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data,
  };

  // If there's an image, add it (strip expired Storage tokens to avoid 403)
  function stripToken(url) {
    return url ? url.replace(/&token=[^&]+/, '') : url;
  }
  if (payload.notification?.image) {
    notificationOptions.image = stripToken(payload.notification.image);
  }
  if (payload.data?.imageUrl) {
    notificationOptions.image = stripToken(payload.data.imageUrl);
  }

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification click
self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  // Open the app when the notification is clicked
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (clientList) {
      // If there's already a window open, focus it
      for (var i = 0; i < clientList.length; i++) {
        var client = clientList[i];
        if ('focus' in client) {
          return client.focus();
        }
      }
      // Otherwise open a new window
      if (clients.openWindow) {
        return clients.openWindow('/');
      }
    })
  );
});
