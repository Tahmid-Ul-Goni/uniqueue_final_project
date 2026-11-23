const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const logger = require('firebase-functions/logger');

initializeApp();

const firestore = getFirestore();
const messaging = getMessaging();

// Push delivery stays in a trusted server environment; app clients never send FCM directly.
exports.dispatchQueueNotification = onDocumentCreated(
  {
    document: 'notifications/{notificationId}',
    region: 'asia-southeast1',
    retry: true,
  },
  async (event) => {
    const notification = event.data?.data();
    if (!notification?.userId) return;

    const userRef = firestore.collection('users').doc(notification.userId);
    const userSnapshot = await userRef.get();
    const fid = userSnapshot.data()?.fcmInstallationId;
    if (!fid) return;

    try {
      await messaging.send({
        fid,
        notification: {
          title: notification.title || 'UniQueue update',
          body: notification.message || 'Your queue status changed.',
        },
        data: {
          entryId: String(notification.entryId || ''),
          notificationId: event.params.notificationId,
        },
        android: { priority: 'high' },
      });
      await event.data.ref.update({ pushSentAt: FieldValue.serverTimestamp() });
    } catch (error) {
      logger.error('Unable to deliver queue notification', {
        notificationId: event.params.notificationId,
        error,
      });
      if (error?.code === 'messaging/installation-id-not-registered'
          || error?.code === 'messaging/registration-token-not-registered'
          || error?.code === 'messaging/invalid-registration-token') {
        await userRef.update({ fcmInstallationId: FieldValue.delete() });
        return;
      }
      throw error;
    }
  },
);
