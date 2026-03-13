const {onCall, HttpsError} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

exports.triggerDistressAlert = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be logged in");
  }

  const {uid, keyword, severity, messageSnippet} = request.data || {};

  if (!uid || uid !== request.auth.uid) {
    throw new HttpsError("permission-denied", "Invalid uid");
  }

  if (!keyword || !severity || !messageSnippet) {
    throw new HttpsError("invalid-argument", "uid, keyword, severity, messageSnippet are required");
  }

  const normalizedSeverity = ["CRITICAL", "CAUTION"].includes(severity) ? severity : "CAUTION";
  const snippet = String(messageSnippet).slice(0, 100);

  const alertsColRef = db.collection("users").doc(uid).collection("alerts");

  const fiveMinsAgo = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 5 * 60 * 1000),
  );

  const duplicateSnapshot = await alertsColRef
      .where("type", "==", "distress")
      .where("keyword", "==", String(keyword).toLowerCase())
      .where("createdAt", ">=", fiveMinsAgo)
      .limit(1)
      .get();

  if (!duplicateSnapshot.empty) {
    return {success: true, suppressed: true};
  }

  const alertPayload = {
    type: "distress",
    title: normalizedSeverity === "CRITICAL" ? "Critical distress detected" : "Distress keyword detected",
    description: `Detected keyword: ${keyword}`,
    keyword: String(keyword).toLowerCase(),
    severity: normalizedSeverity,
    messageSnippet: snippet,
    isRead: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  const elderAlertRef = await alertsColRef.add(alertPayload);

  await db.collection("alerts").doc(elderAlertRef.id).set({
    elderId: uid,
    ...alertPayload,
  });

  const elderDoc = await db.collection("users").doc(uid).get();
  const elderData = elderDoc.data() || {};
  const elderName = elderData.name || "Elder";
  const caregiverPhone = elderData.caregiverPhone;

  if (!caregiverPhone) {
    console.log(`No caregiverPhone found for elder ${uid}. Alert stored without push.`);
    return {success: true, pushSent: false};
  }

  const caregiverSnapshot = await db
      .collection("users")
      .where("phoneNumber", "==", caregiverPhone)
      .limit(1)
      .get();

  if (caregiverSnapshot.empty) {
    console.log(`No caregiver user found for phone ${caregiverPhone}.`);
    return {success: true, pushSent: false};
  }

  const caregiverData = caregiverSnapshot.docs[0].data() || {};
  const caregiverToken = caregiverData.fcmToken;

  if (!caregiverToken) {
    console.log(`No caregiver FCM token for phone ${caregiverPhone}.`);
    return {success: true, pushSent: false};
  }

  try {
    await admin.messaging().send({
      token: caregiverToken,
      notification: {
        title: normalizedSeverity === "CRITICAL" ? "🚨 Distress Alert" : "⚠️ Distress Alert",
        body: `${elderName} may need attention (${keyword}).`,
      },
      data: {
        type: "distress",
        elderId: uid,
        severity: normalizedSeverity,
        keyword: String(keyword),
      },
      android: {
        priority: "high",
      },
    });
  } catch (error) {
    console.error("Failed to send distress push:", error);
  }

  return {success: true, pushSent: true};
});
