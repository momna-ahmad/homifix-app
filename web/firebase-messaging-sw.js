// firebase-messaging-sw.js
importScripts('https://www.gstatic.com/firebasejs/10.3.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.3.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyCgDD9D0Icpsmq_Gr_g3hdpSpuygVaojiY",
  authDomain: "homifix-app.firebaseapp.com",
  projectId: "homifix-app",
  storageBucket: "homifix-app.firebasestorage.app",
  messagingSenderId: "126857954367",
  appId: "1:126857954367:web:443b0c0bceb51fe207248a",
  measurementId: "G-K72RR5BZRL"
});

const messaging = firebase.messaging();
