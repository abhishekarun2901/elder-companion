const {onCall, HttpsError} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const {GoogleGenerativeAI} = require("@google/generative-ai");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

function buildTranscript(messages = []) {
  return messages
      .map((m) => {
        const role = (m.role || "user").toString().toUpperCase();
        const text = (m.text || "").toString().trim();
        return `${role}: ${text}`;
      })
      .filter((line) => line.length > 6)
      .join("\n");
}

function fallbackSummary(messages = []) {
  const userMessages = messages
      .filter((m) => m.role === "user")
      .map((m) => (m.text || "").toString().trim())
      .filter(Boolean);

  if (userMessages.length === 0) {
    return "The elder had a brief conversation with Mitra. No clear topic was identified in this session.";
  }

  const first = userMessages[0];
  const last = userMessages[userMessages.length - 1];

  return `The elder discussed ${first.length > 80 ? "personal topics" : first.toLowerCase()}. ` +
    `The session ended with ${last.length > 80 ? "continued conversation" : last.toLowerCase()}. ` +
    "Overall tone appears neutral based on available context.";
}

exports.generateChatSummary = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be logged in");
  }

  const {uid, messages, sessionStart, sessionEnd} = request.data || {};

  if (!uid || request.auth.uid !== uid) {
    throw new HttpsError("permission-denied", "Invalid uid");
  }

  if (!Array.isArray(messages) || messages.length === 0) {
    throw new HttpsError("invalid-argument", "messages array is required");
  }

  const startDate = sessionStart ? new Date(sessionStart) : new Date();
  const endDate = sessionEnd ? new Date(sessionEnd) : new Date();

  if (Number.isNaN(startDate.getTime()) || Number.isNaN(endDate.getTime())) {
    throw new HttpsError("invalid-argument", "Invalid session timestamps");
  }

  const userDocRef = db.collection("users").doc(uid);
  const userDoc = await userDocRef.get();
  const mood = userDoc.exists ? (userDoc.data().lastMood || "unknown") : "unknown";

  let summary = "";

  try {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      summary = fallbackSummary(messages);
    } else {
      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({model: "gemini-1.5-flash"});
      const transcript = buildTranscript(messages);

      const prompt = [
        "You are summarising a conversation between an elderly person and their AI companion for a caregiver.",
        "Write exactly 2-3 neutral sentences describing key topics discussed and the elder's apparent emotional state.",
        "Do not include sensitive details verbatim. Do not quote exact messages.",
        "Use clear, caregiver-friendly language.",
        "Conversation transcript:",
        transcript,
      ].join("\n\n");

      const result = await model.generateContent(prompt);
      summary = result.response.text().trim();
    }
  } catch (error) {
    console.error("Gemini summary generation failed:", error);
    summary = fallbackSummary(messages);
  }

  const sessionId = `${startDate.getTime()}_${Math.random().toString(36).slice(2, 8)}`;

  await userDocRef.collection("chat_summaries").doc(sessionId).set({
    summary,
    sessionStart: admin.firestore.Timestamp.fromDate(startDate),
    sessionEnd: admin.firestore.Timestamp.fromDate(endDate),
    messageCount: messages.length,
    mood,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {success: true, sessionId};
});
