// functions/index.js
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {setGlobalOptions} = require("firebase-functions/v2");
const admin = require("firebase-admin");

admin.initializeApp();

// Set global options
setGlobalOptions({maxInstances: 10});

const db = admin.firestore();
const MAX_MEMORY_ENTRIES = 50;

// ============================================
// 1. STORE CONVERSATION MEMORY
// ============================================
exports.storeConversationMemory = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be logged in");
  }

  const userId = request.auth.uid;
  const {message, response, keyFacts} = request.data;

  if (!message || !response) {
    throw new HttpsError("invalid-argument", "Message and response are required");
  }

  try {
    const memoryRef = db.collection("users").doc(userId).collection("memory_entries").doc();

    await memoryRef.set({
      userMessage: message,
      aiResponse: response,
      keyFacts: keyFacts || [],
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      conversationDate: new Date().toISOString().split("T")[0],
    });

    await cleanupOldMemories(userId);

    return {success: true, memoryId: memoryRef.id};
  } catch (error) {
    console.error("Error storing memory:", error);
    throw new HttpsError("internal", "Failed to store memory");
  }
});

// ============================================
// 2. RETRIEVE RELEVANT MEMORIES
// ============================================
exports.getRelevantMemories = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be logged in");
  }

  const userId = request.auth.uid;
  const {currentMessage, limit = 10} = request.data;

  if (!currentMessage) {
    throw new HttpsError("invalid-argument", "Current message is required");
  }

  try {
    const snapshot = await db
        .collection("users")
        .doc(userId)
        .collection("memory_entries")
        .orderBy("timestamp", "desc")
        .limit(limit)
        .get();

    const memories = [];
    snapshot.forEach((doc) => {
      memories.push({
        id: doc.id,
        ...doc.data(),
      });
    });

    return {success: true, memories};
  } catch (error) {
    console.error("Error retrieving memories:", error);
    throw new HttpsError("internal", "Failed to retrieve memories");
  }
});

// ============================================
// 3. EXTRACT AND STORE KEY FACTS
// ============================================
exports.extractKeyFacts = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be logged in");
  }

  const userId = request.auth.uid;
  const {factType, factValue} = request.data;

  if (!factType || !factValue) {
    throw new HttpsError("invalid-argument", "Fact type and value are required");
  }

  try {
    const factsRef = db.collection("users").doc(userId).collection("key_facts").doc(factType);

    await factsRef.set(
        {
          value: factValue,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          factType: factType,
        },
        {merge: true},
    );

    return {success: true, factType, factValue};
  } catch (error) {
    console.error("Error storing fact:", error);
    throw new HttpsError("internal", "Failed to store fact");
  }
});

// ============================================
// 4. GET ALL KEY FACTS FOR USER
// ============================================
exports.getAllKeyFacts = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be logged in");
  }

  const userId = request.auth.uid;

  try {
    const snapshot = await db.collection("users").doc(userId).collection("key_facts").get();

    const keyFacts = {};
    snapshot.forEach((doc) => {
      keyFacts[doc.id] = doc.data().value;
    });

    return {success: true, keyFacts};
  } catch (error) {
    console.error("Error retrieving facts:", error);
    throw new HttpsError("internal", "Failed to retrieve facts");
  }
});

// ============================================
// 5. UPDATE LEARNED PREFERENCES
// ============================================
exports.updateUserPreferences = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be logged in");
  }

  const userId = request.auth.uid;
  const {preferences} = request.data;

  if (!preferences || typeof preferences !== "object") {
    throw new HttpsError("invalid-argument", "Preferences object is required");
  }

  try {
    await db.collection("users").doc(userId).update({
      learnedPreferences: admin.firestore.FieldValue.arrayUnion([
        {
          ...preferences,
          learnedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      ]),
    });

    return {success: true};
  } catch (error) {
    console.error("Error updating preferences:", error);
    throw new HttpsError("internal", "Failed to update preferences");
  }
});

// ============================================
// 6. GET CONVERSATION SUMMARY
// ============================================
exports.getConversationSummary = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be logged in");
  }

  const userId = request.auth.uid;
  const {days = 7} = request.data;

  try {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - days);

    const snapshot = await db
        .collection("users")
        .doc(userId)
        .collection("memory_entries")
        .where("timestamp", ">=", cutoffDate)
        .orderBy("timestamp", "desc")
        .get();

    const summary = {
      totalConversations: snapshot.size,
      topicsMentioned: [],
      moodTrend: [],
      lastConversation: null,
    };

    snapshot.forEach((doc) => {
      const docData = doc.data();
      if (summary.lastConversation === null) {
        summary.lastConversation = docData.timestamp ? docData.timestamp.toDate() : null;
      }

      if (docData.keyFacts && Array.isArray(docData.keyFacts)) {
        summary.topicsMentioned.push(...docData.keyFacts);
      }
    });

    summary.topicsMentioned = [...new Set(summary.topicsMentioned)];

    return {success: true, summary};
  } catch (error) {
    console.error("Error generating summary:", error);
    throw new HttpsError("internal", "Failed to generate summary");
  }
});

// ============================================
// 7. CLEANUP OLD MEMORIES (Helper)
// ============================================
async function cleanupOldMemories(userId) {
  try {
    const snapshot = await db
        .collection("users")
        .doc(userId)
        .collection("memory_entries")
        .orderBy("timestamp", "desc")
        .offset(MAX_MEMORY_ENTRIES)
        .get();

    const batch = db.batch();
    snapshot.forEach((doc) => {
      batch.delete(doc.ref);
    });

    await batch.commit();
  } catch (error) {
    console.error("Error cleaning up memories:", error);
  }
}

// ============================================
// 8. SCHEDULED CLEANUP (Run daily at 2 AM UTC)
// ============================================
exports.dailyMemoryCleanup = onSchedule("every day 02:00", async (event) => {
  try {
    const usersSnapshot = await db.collection("users").get();

    for (const userDoc of usersSnapshot.docs) {
      await cleanupOldMemories(userDoc.id);
    }

    console.log("Daily memory cleanup completed");
    return null;
  } catch (error) {
    console.error("Error in daily cleanup:", error);
    return null;
  }
});

// ============================================
// 9. EXPORT MEMORY ANALYTICS
// ============================================
exports.getMemoryAnalytics = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be logged in");
  }

  const userId = request.auth.uid;

  try {
    const memorySnapshot = await db
        .collection("users")
        .doc(userId)
        .collection("memory_entries")
        .get();

    const factsSnapshot = await db
        .collection("users")
        .doc(userId)
        .collection("key_facts")
        .get();

    const analytics = {
      totalMemoriesStored: memorySnapshot.size,
      totalKeyFacts: factsSnapshot.size,
      averageResponseLength: 0,
      mostRecentUpdate: null,
    };

    let totalResponseLength = 0;

    memorySnapshot.forEach((doc) => {
      const response = doc.data().aiResponse || "";
      totalResponseLength += response.length;

      const ts = doc.data().timestamp ? doc.data().timestamp.toDate() : null;
      const isNewer = ts > analytics.mostRecentUpdate;
      if (ts && (analytics.mostRecentUpdate === null || isNewer)) {
        analytics.mostRecentUpdate = ts;
      }
    });

    if (memorySnapshot.size > 0) {
      analytics.averageResponseLength = Math.round(
          totalResponseLength / memorySnapshot.size,
      );
    }

    return {success: true, analytics};
  } catch (error) {
    console.error("Error generating analytics:", error);
    throw new HttpsError("internal", "Failed to generate analytics");
  }
});

// ============================================
// 10. SEND SOS PUSH NOTIFICATION
// ============================================
exports.sendSosNotification = onDocumentUpdated("users/{userId}", async (event) => {
  const beforeData = event.data.before.data() || {};
  const afterData = event.data.after.data() || {};

  const wasActive = beforeData.emergencyState ? beforeData.emergencyState.isActive : false;
  const isActive = afterData.emergencyState ? afterData.emergencyState.isActive : false;

  // Only trigger if emergency state changed to TRUE
  if (!wasActive && isActive) {
    const elderName = afterData.name || "An elder";
    const emergencyContactPhone = afterData.emergencyContact ? afterData.emergencyContact.phone : null;

    if (!emergencyContactPhone) {
      console.log(`No emergency contact phone set for elder ${event.params.userId}. Skipping push notification.`);
      return null;
    }

    try {
      // Find the caregiver by phone number
      const caregiversSnapshot = await db.collection("users").where("phoneNumber", "==", emergencyContactPhone).limit(1).get();

      if (caregiversSnapshot.empty) {
        console.log(`Caregiver with phone ${emergencyContactPhone} not found in database.`);
        return null;
      }

      const caregiverData = caregiversSnapshot.docs[0].data();
      const fcmToken = caregiverData.fcmToken;

      if (!fcmToken) {
        console.log(`Caregiver ${caregiverData.name || emergencyContactPhone} does not have an FCM token registered.`);
        return null;
      }

      // Send the Push Notification
      const payload = {
        token: fcmToken,
        notification: {
          title: "🚨 ACTIVE EMERGENCY! 🚨",
          body: `${elderName} has triggered an SOS alert and needs immediate assistance!`,
        },
        data: {
          elderId: event.params.userId,
          type: "sos_alert",
          click_action: "FLUTTER_NOTIFICATION_CLICK"
        },
        android: {
          priority: "high",
          notification: {
            sound: "default",
            channelId: "instant_channel"
          }
        },
        apns: {
          payload: {
             aps: {
                sound: "default"
             }
          }
        }
      };

      const response = await admin.messaging().send(payload);
      console.log("Successfully sent SOS push notification:", response);
      return null;
    } catch (error) {
      console.error("Error sending SOS push notification:", error);
      return null;
    }
  }

  return null;
});

// ============================================
// 11. SCHEDULED APPOINTMENT REMINDERS
// ============================================
exports.checkUpcomingAppointments = onSchedule("every 15 minutes", async (event) => {
  try {
    const now = new Date();
    // Look for appointments happening between 45 and 60 minutes from now
    const next45Mins = new Date(now.getTime() + 45 * 60000);
    const next60Mins = new Date(now.getTime() + 60 * 60000);

    const snapshot = await db.collection("appointments")
      .where("dateTime", ">=", next45Mins.toISOString())
      .where("dateTime", "<=", next60Mins.toISOString())
      .where("notified", "!=", true)
      .get();

    if (snapshot.empty) {
      console.log("No upcoming appointments found in the next hour.");
      return null;
    }

    const batch = db.batch();
    const messaging = admin.messaging();
    
    for (const doc of snapshot.docs) {
      const data = doc.data();
      const elderId = data.elderId;
      const doctorName = data.doctorName || "Doctor";
      const timeString = new Date(data.dateTime).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'});

      // Fetch Elder and Caregiver tokens
      const elderSnapshot = await db.collection("users").doc(elderId).get();
      if (!elderSnapshot.exists) continue;

      const elderData = elderSnapshot.data();
      const elderToken = elderData.fcmToken;
      const elderName = elderData.name || "Elder";
      const caregiverPhone = elderData.caregiverPhone;

      let caregiverToken = null;
      if (caregiverPhone) {
        const cgSnapshot = await db.collection("users").where("phoneNumber", "==", caregiverPhone).limit(1).get();
        if (!cgSnapshot.empty) {
          caregiverToken = cgSnapshot.docs[0].data().fcmToken;
        }
      }

      // Prepare Notification Payload
      const payload = {
        notification: {
          title: "🗓 Upcoming Appointment!",
          body: `Reminder: Appointment with ${doctorName} at ${timeString}.`,
        },
        android: { priority: "high", notification: { sound: "default" } },
        apns: { payload: { aps: { sound: "default" } } }
      };

      // Send to Elder
      try {
        if (elderToken) {
          await messaging.send({ ...payload, token: elderToken });
          console.log(`Sent to elder ${elderName}`);
        }
      } catch (err) {
        console.error("Elder notification failed:", err);
      }

      // Send to Caregiver
      try {
        if (caregiverToken) {
          const cgPayload = {...payload};
          cgPayload.notification.body = `Reminder: ${elderName} has an appointment with ${doctorName} at ${timeString}.`;
          await messaging.send({ ...cgPayload, token: caregiverToken });
          console.log(`Sent to caregiver for ${elderName}`);
        }
      } catch (err) {
        console.error("Caregiver notification failed:", err);
      }

      // Mark as notified in batch
      batch.update(doc.ref, { notified: true });
    }

    await batch.commit();
    console.log("Finished sending appointment reminders.");
    return null;

  } catch (error) {
    console.error("Error checking upcoming appointments:", error);
    return null;
  }
});