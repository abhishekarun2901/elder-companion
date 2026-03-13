const {onCall, HttpsError} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

exports.triggerGeofenceAlert = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be logged in");
  }

  const {uid, latitude, longitude, distanceMeters} = request.data || {};

  if (!uid || request.auth.uid !== uid) {
    throw new HttpsError("permission-denied", "Invalid uid");
  }

  if (typeof latitude !== "number" || typeof longitude !== "number") {
    throw new HttpsError("invalid-argument", "latitude and longitude are required numbers");
  }

  const elderRef = db.collection("users").doc(uid);
  const elderDoc = await elderRef.get();
  const elderData = elderDoc.data() || {};
  const elderName = elderData.name || "Elder";

  const roundedDistance = Number(distanceMeters || 0).toFixed(0);

  const alertPayload = {
    type: "geofence",
    title: "Geofence Alert",
    description: `${elderName} moved outside the home radius (${roundedDistance} m).`,
    severity: "WARNING",
    isRead: false,
    metadata: {
      latitude,
      longitude,
      distanceMeters: Number(distanceMeters || 0),
    },
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await elderRef.collection("alerts").add(alertPayload);

  const caregiverPhone = elderData.caregiverPhone;
  if (!caregiverPhone) {
    return {success: true, pushSent: false};
  }

  const caregiverSnap = await db
      .collection("users")
      .where("phoneNumber", "==", caregiverPhone)
      .limit(1)
      .get();

  if (caregiverSnap.empty) {
    return {success: true, pushSent: false};
  }

  const caregiverData = caregiverSnap.docs[0].data() || {};
  const token = caregiverData.fcmToken;

  if (!token) {
    return {success: true, pushSent: false};
  }

  try {
    await admin.messaging().send({
      token,
      notification: {
        title: "📍 Geofence Alert",
        body: `${elderName} has moved outside the configured radius.`,
      },
      data: {
        type: "geofence",
        elderId: uid,
        latitude: String(latitude),
        longitude: String(longitude),
        distanceMeters: String(Number(distanceMeters || 0)),
      },
      android: {priority: "high"},
    });
  } catch (error) {
    console.error("Geofence push failed:", error);
  }

  return {success: true, pushSent: true};
});
