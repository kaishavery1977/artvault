// Firebase Messaging Service Worker
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAlEmaqwhaF9X49NX56Z5CtgznjYsa3r-Q',
  authDomain: 'artvault-d69d0.firebaseapp.com',
  projectId: 'artvault-d69d0',
  storageBucket: 'artvault-d69d0.appspot.com',
  messagingSenderId: '629393260589',
  appId: '1:629393260589:web:c964a2dac4fad408fdb8a4',
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  const notificationTitle = payload.notification?.title || 'ArtVault';
  const notificationOptions = {
    body: payload.notification?.body || 'You have a new notification',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    vibrate: [100, 50, 100],
    data: payload.data?.url || '/',
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
