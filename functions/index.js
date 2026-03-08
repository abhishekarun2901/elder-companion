// functions/index.js
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
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