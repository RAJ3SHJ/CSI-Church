// Sends phone notifications when the church adds something new.
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

// Must be the same region as your Firestore database (Firestore console shows it).
const REGION = 'asia-south1';
const APP_URL = 'https://raj3shj.github.io/CSI-Church/';

async function send(tokens, title, body) {
  const unique = [...new Set(tokens)];
  for (let i = 0; i < unique.length; i += 500) {
    const batch = unique.slice(i, i + 500);
    const res = await admin.messaging().sendEachForMulticast({
      tokens: batch,
      notification: { title, body },
      webpush: { fcmOptions: { link: APP_URL } },
    });
    // Remove tokens of devices that no longer exist.
    const dead = [];
    res.responses.forEach((r, idx) => {
      const code = r.error && r.error.code;
      if (code === 'messaging/registration-token-not-registered' ||
          code === 'messaging/invalid-registration-token') dead.push(batch[idx]);
    });
    await Promise.all(dead.map((t) => db.collection('fcmTokens').doc(t).delete()));
  }
}

async function allTokens(role) {
  let q = db.collection('fcmTokens');
  if (role) q = q.where('role', '==', role);
  const snap = await q.get();
  return snap.docs.map((d) => d.id);
}

function notifyOnCreate(collection, label) {
  return onDocumentCreated({ document: `${collection}/{id}`, region: REGION }, async (event) => {
    const d = event.data && event.data.data();
    if (!d) return;
    const title = `${label}: ${d.title || ''}`.trim();
    const body = (d.description || d.location || '').toString().slice(0, 140);
    // Also show it in the app's Notifications tab.
    await db.collection('notifications').add({
      title, body, type: collection, createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await send(await allTokens(), title, body);
  });
}

exports.onEventCreated = notifyOnCreate('events', 'New event');
exports.onUpcomingCreated = notifyOnCreate('announcements', 'Upcoming event');
exports.onAnnouncementCreated = notifyOnCreate('notices', 'Announcement');
exports.onBulletinCreated = notifyOnCreate('bulletins', 'New bulletin');

// A member's prayer request goes to the admins.
exports.onPrayerRequest = onDocumentCreated(
  { document: 'prayer_requests/{id}', region: REGION },
  async (event) => {
    const d = event.data && event.data.data();
    if (!d) return;
    const who = d.isAnonymous ? 'A member' : (d.memberName || 'A member');
    await send(await allTokens('admin'), 'New prayer request', `${who} sent a prayer request.`);
  }
);
