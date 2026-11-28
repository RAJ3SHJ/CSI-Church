// Shows push notifications when the church app is closed.
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAEgxoBpw7NzjI9P2-bKF5EGi3jK05sFzM',
  appId: '1:98695526673:web:1488049be30d4263b174b0',
  messagingSenderId: '98695526673',
  projectId: 'templeapp-cf43e',
  authDomain: 'templeapp-cf43e.firebaseapp.com',
  storageBucket: 'templeapp-cf43e.firebasestorage.app',
});

// Messages that carry a "notification" are displayed automatically.
firebase.messaging();
