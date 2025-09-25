const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.notifyIncidentUpdate = functions.firestore
  .document('incidents/{incidentId}')
  .onUpdate(async (change, context) => {
    const after = change.after.data();
    const before = change.before.data();
    const incidentId = context.params.incidentId;
    
    if (!after) return null;

    const userId = after.userId;
    if (!userId) {
      console.log(`Incident ${incidentId} missing userId; skipping notification.`);
      return null;
    }

    // Determine if we should notify (using safe property access)
    const previousStatus = (before && before.status) ? before.status : '';
    const currentStatus = after.status ? after.status : '';
    const previousNote = (before && before.latestAdminNote) ? before.latestAdminNote : '';
    const currentNote = after.latestAdminNote ? after.latestAdminNote : '';

    const shouldNotify = 
      (previousStatus !== currentStatus && currentStatus) ||
      (currentNote && currentNote !== previousNote);

    if (!shouldNotify) return null;

    // Get ONLY the incident owner's tokens
    let tokens = [];
    try {
      const userDoc = await admin.firestore().collection('users').doc(userId).get();
      if (userDoc.exists) {
        const userData = userDoc.data();
        if (userData.fcmTokens && Array.isArray(userData.fcmTokens)) {
          tokens = userData.fcmTokens.filter(function(token) {
            return token && token.length > 0;
          });
        }
      }

      if (tokens.length === 0) {
        console.log(`No FCM tokens found for user ${userId}`);
        return null;
      }

      console.log(`Sending notification to user ${userId} with ${tokens.length} token(s)`);

      const message = {
        notification: {
          title: 'Incident Status Updated',
          body: 'Status: ' + currentStatus
        },
        data: {
          incidentId: incidentId,
          type: 'status_update',
          newStatus: currentStatus || '',
          source: 'server'
        },
        tokens: tokens
      };

      const response = await admin.messaging().sendMulticast(message);
      console.log(`Successfully sent notification to ${response.successCount} device(s)`);
      return null;

    } catch (error) {
      console.error('Error in notifyIncidentUpdate:', error);
      return null;
    }
  });