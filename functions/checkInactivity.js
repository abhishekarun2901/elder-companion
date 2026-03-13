const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

function isDaytime(date) {
  const hour = date.getHours();
  return hour >= 7 && hour < 22;
}

exports.checkInactivity = onSchedule("every 2 hours", async () => {
  try {
    const now = new Date();

    const eldersSnapshot = await db
        .collection("users")
        .where("role", "==", "elder")
        .get();

    if (eldersSnapshot.empty) {
      console.log("No elder users found for inactivity check.");
      return null;
    }

    for (const elderDoc of eldersSnapshot.docs) {
      const elderId = elderDoc.id;
      const elderData = elderDoc.data() || {};

      if (!isDaytime(now)) {
        continue;
      }

      const customThreshold = Number(elderData.inactivityThreshold);
      const warningThreshold = Number.isFinite(customThreshold) && customThreshold > 0 ? customThreshold : 6;
      const criticalThreshold = 12;

      const lastActiveTs = elderData.lastActive;
      const lastActiveDate = lastActiveTs && lastActiveTs.toDate ? lastActiveTs.toDate() : null;
      const hoursInactive = lastActiveDate
          ? (Date.now() - lastActiveDate.getTime()) / (1000 * 60 * 60)
          : Number.POSITIVE_INFINITY;

      if (hoursInactive < warningThreshold) {
        continue;
      }

      const sixHoursAgo = admin.firestore.Timestamp.fromDate(
          new Date(Date.now() - 6 * 60 * 60 * 1000),
      );

      const recentAlert = await db
          .collection("users")
          .doc(elderId)
          .collection("alerts")
          .where("type", "==", "inactivity")
          .where("createdAt", ">=", sixHoursAgo)
          .limit(1)
          .get();

      if (!recentAlert.empty) {
        continue;
      }

      const severity = hoursInactive >= criticalThreshold ? "CRITICAL" : "WARNING";
      const hoursText = Number.isFinite(hoursInactive) ? `${hoursInactive.toFixed(1)}h` : "an unknown duration";
      const elderName = elderData.name || "Elder";

      await db
          .collection("users")
          .doc(elderId)
          .collection("alerts")
          .add({
            type: "inactivity",
            title: "Inactivity Alert",
            description: `No activity from ${elderName} for ${hoursText}.`,
            severity,
            isRead: false,
            metadata: {
              hoursInactive: Number.isFinite(hoursInactive) ? Number(hoursInactive.toFixed(2)) : null,
              thresholdHours: warningThreshold,
            },
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });

      const caregiverPhone = elderData.caregiverPhone;
      if (!caregiverPhone) {
        continue;
      }

      const caregiverSnap = await db
          .collection("users")
          .where("phoneNumber", "==", caregiverPhone)
          .limit(1)
          .get();

      if (caregiverSnap.empty) {
        continue;
      }

      const caregiverData = caregiverSnap.docs[0].data() || {};
      const fcmToken = caregiverData.fcmToken;
      if (!fcmToken) {
        console.log(`No caregiver FCM token found for elder ${elderId}`);
        continue;
      }

      try {
        await admin.messaging().send({
          token: fcmToken,
          notification: {
            title: severity === "CRITICAL" ? "🚨 Critical inactivity alert" : "⚠️ Inactivity alert",
            body: `No activity from ${elderName} for ${hoursText}.`,
          },
          data: {
            type: "inactivity",
            elderId,
            severity,
          },
          android: {priority: "high"},
        });
      } catch (pushErr) {
        console.error(`Failed to send inactivity push for elder ${elderId}:`, pushErr);
      }
    }

    return null;
  } catch (error) {
    console.error("checkInactivity failed:", error);
    return null;
  }
});
