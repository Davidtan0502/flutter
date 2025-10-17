const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// constants
const CHUNK_SIZE = 500; // sendMulticast supports up to 500 tokens per call
const ANDROID_CHANNEL_ID = 'incident_updates_channel';

exports.notifyIncidentUpdate = functions.firestore
  .document('incidents/{incidentId}')
  .onUpdate(async (change, context) => {
    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;
    const incidentId = context.params.incidentId;

    if (!after) {
      console.log(`notifyIncidentUpdate: no 'after' data for ${incidentId}`);
      return null;
    }

    const userId = after.userId;
    if (!userId) {
      console.log(`Incident ${incidentId} missing userId; skipping notification.`);
      return null;
    }

    // Determine whether to notify (same logic as before)
    const previousStatus = before && before.status ? before.status : '';
    const currentStatus = after.status ? after.status : '';
    const previousNote = before && before.latestAdminNote ? before.latestAdminNote : '';
    const currentNote = after.latestAdminNote ? after.latestAdminNote : '';

    const shouldNotify =
      (previousStatus !== currentStatus && !!currentStatus) ||
      (currentNote && currentNote !== previousNote);

    if (!shouldNotify) {
      console.log(`No meaningful change for ${incidentId}; skipping notification.`);
      return null;
    }

    try {
      // Fetch owner's device tokens from users/{uid}.fcmTokens
      const userDocRef = admin.firestore().collection('users').doc(userId);
      const userDoc = await userDocRef.get();
      let tokens = [];
      if (userDoc.exists) {
        const userData = userDoc.data() || {};
        if (Array.isArray(userData.fcmTokens)) {
          tokens = userData.fcmTokens.filter(t => typeof t === 'string' && t.trim().length > 0);
        }
      }

      if (!tokens || tokens.length === 0) {
        console.log(`No FCM tokens found for user ${userId} (incident ${incidentId})`);
        return null;
      }

      // Deduplicate tokens
      tokens = Array.from(new Set(tokens));
      console.log(`Sending notification to user ${userId} for incident ${incidentId} (${tokens.length} token(s) after dedupe)`);

      const title = 'Incident Status Updated';
      const body = `Status: ${currentStatus || 'Updated'}`;

      // Base message fields (shared across chunks)
      const baseMessage = {
        notification: {
          title: title,
          body: body,
        },
        data: {
          incidentId: incidentId,
          type: 'status_update',
          newStatus: currentStatus || '',
          source: 'server',
        },
        android: {
          priority: 'high',
          ttl: '3600s', // keep message alive for 1 hour if device is temporarily offline
          notification: {
            channelId: ANDROID_CHANNEL_ID,
            defaultVibrateTimings: true,
            defaultSound: true,
          },
        },
        apns: {
          headers: {
            'apns-priority': '10',
            'apns-push-type': 'alert',
          },
          payload: {
            aps: {
              alert: {
                title: title,
                body: body,
              },
              sound: 'default',
              badge: 1,
              'mutable-content': 1
            },
          },
        },
      };

      // Send tokens in chunks of CHUNK_SIZE
      let totalSuccess = 0;
      let totalFailure = 0;
      const invalidTokens = [];

      for (let i = 0; i < tokens.length; i += CHUNK_SIZE) {
        const chunk = tokens.slice(i, i + CHUNK_SIZE);
        const message = { ...baseMessage, tokens: chunk };

        try {
          const response = await admin.messaging().sendMulticast(message);
          console.log(`Chunk send result: success=${response.successCount}, failure=${response.failureCount}`);
          totalSuccess += response.successCount;
          totalFailure += response.failureCount;

          // Collect invalid tokens for cleanup
          response.responses.forEach((r, idx) => {
            if (!r.success) {
              const err = r.error;
              // common invalid codes that indicate token should be removed
              if (err && (err.code === 'messaging/invalid-registration-token' || err.code === 'messaging/registration-token-not-registered')) {
                invalidTokens.push(chunk[idx]);
              } else {
                console.warn(`FCM send error for token index ${idx} (chunk start ${i}):`, err ? err.code || err.message : r);
              }
            }
          });
        } catch (sendErr) {
          // Log send errors for this chunk; optionally you could retry transient errors here
          console.error('sendMulticast chunk error:', sendErr);
        }
      }

      console.log(`Total send result for user ${userId}: success=${totalSuccess}, failure=${totalFailure}`);

      // Cleanup invalid tokens (best-effort)
      if (invalidTokens.length > 0) {
        // dedupe invalid tokens as well
        const uniqueInvalid = Array.from(new Set(invalidTokens));
        console.log(`Cleaning up ${uniqueInvalid.length} invalid token(s) for user ${userId}`);
        try {
          const batch = admin.firestore().batch();

          // Remove from user's fcmTokens array (guard in case uniqueInvalid is empty)
          if (uniqueInvalid.length > 0) {
            batch.update(userDocRef, { fcmTokens: admin.firestore.FieldValue.arrayRemove(...uniqueInvalid) });
            // Delete token docs from fcm_tokens collection
            uniqueInvalid.forEach(t => {
              const tokenRef = admin.firestore().collection('fcm_tokens').doc(t);
              batch.delete(tokenRef);
            });
            await batch.commit();
            console.log('Invalid token cleanup batch committed.');
          }
        } catch (cleanupErr) {
          console.warn('Token cleanup failed (best-effort):', cleanupErr);
        }
      }

      return null;
    } catch (error) {
      console.error('Error in notifyIncidentUpdate:', error);
      return null;
    }
  });
