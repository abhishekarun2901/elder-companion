const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

function formatDate(date) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

exports.dailyMedicationCheck = onSchedule("every day 22:00", async () => {
  try {
    const today = new Date();
    const todayStr = formatDate(today);

    const medicinesSnap = await db.collection("medicines").get();
    if (medicinesSnap.empty) {
      console.log("No medicines found for daily check.");
      return null;
    }

    for (const medDoc of medicinesSnap.docs) {
      const medData = medDoc.data() || {};
      const elderId = medData.elderId;

      if (!elderId) {
        continue;
      }

      const adherenceDoc = await medDoc.ref
          .collection("adherence_logs")
          .doc(todayStr)
          .get();

      if (adherenceDoc.exists) {
        continue;
      }

      const existingAlert = await db
          .collection("users")
          .doc(elderId)
          .collection("alerts")
          .where("type", "==", "medication_miss")
          .where("date", "==", todayStr)
          .where("metadata.medicineId", "==", medDoc.id)
          .limit(1)
          .get();

      if (!existingAlert.empty) {
        continue;
      }

      const medicineName = medData.medicineName || "Medicine";

      await db
          .collection("users")
          .doc(elderId)
          .collection("alerts")
          .add({
            type: "medication_miss",
            title: "Medication Missed",
            description: `${medicineName} appears to be missed today (${todayStr}).`,
            severity: "WARNING",
            isRead: false,
            date: todayStr,
            metadata: {
              medicineId: medDoc.id,
              medicineName,
            },
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
    }

    console.log("dailyMedicationCheck completed");
    return null;
  } catch (error) {
    console.error("dailyMedicationCheck failed:", error);
    return null;
  }
});
